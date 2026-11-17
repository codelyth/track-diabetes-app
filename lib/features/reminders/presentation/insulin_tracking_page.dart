import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../insulin/presentation/add_insulin_screen.dart';
import '../data/insulin_occurrence_repository.dart';
import '../domain/insulin_occurrence.dart';
import '../domain/reminder.dart';

class InsulinTrackingPage extends StatefulWidget {
  const InsulinTrackingPage({super.key, required this.userId});

  final String userId;

  @override
  State<InsulinTrackingPage> createState() => _InsulinTrackingPageState();
}

class _InsulinTrackingPageState extends State<InsulinTrackingPage>
    with WidgetsBindingObserver {
  late final InsulinOccurrenceRepository _repository;

  late Stream<QuerySnapshot<Map<String, dynamic>>> _reminderStream;
  late Stream<List<InsulinOccurrence>> _occurrenceStream;

  Timer? _timer;
  DateTime _now = DateTime.now();

  bool _busy = false;

  String get _dateKey => InsulinOccurrence.dateKeyFor(_now);

  @override
  void initState() {
    super.initState();

    _repository = InsulinOccurrenceRepository(userId: widget.userId);

    _createStreams();

    WidgetsBinding.instance.addObserver(this);

    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _updateClock());
  }

  void _createStreams() {
    _reminderStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('reminders')
        .snapshots();

    _occurrenceStream = _repository.watchDay(_dateKey);
  }

  void _updateClock() {
    if (!mounted) return;

    final now = DateTime.now();
    final dayChanged = InsulinOccurrence.dateKeyFor(now) != _dateKey;

    setState(() {
      _now = now;

      if (dayChanged) {
        _occurrenceStream = _repository.watchDay(_dateKey);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateClock();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorMessage(Object error) {
    if (error is InsulinPlanException) return error.message;

    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'İşlem izni alınamadı. Firestore kurallarını kontrol edin.';
    }

    return 'İşlem tamamlanamadı. İnternet bağlantınızı kontrol edin.';
  }

  Future<void> _complete(InsulinOccurrence occurrence) async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => AddInsulinScreen(
            userId: widget.userId,
            plannedOccurrence: occurrence,
          ),
        ),
      );

      if (saved == true) {
        _showMessage('İnsülin kaydedildi ve plan yapıldı olarak işaretlendi.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _updateClock();
      }
    }
  }

  Future<void> _skip(InsulinOccurrence occurrence) async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atlandı olarak işaretlensin mi?'),
        content: Text(
          '${occurrence.timeLabel} planı için '
          'insülin uygulaması kaydı oluşturulmayacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Atlandı'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    await _run(() => _repository.skip(occurrence));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      await action();
    } catch (error) {
      _showMessage(_errorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _updateClock();
      }
    }
  }

  List<InsulinOccurrence> _buildOccurrences(
    QuerySnapshot<Map<String, dynamic>> reminderSnapshot,
    List<InsulinOccurrence> saved,
  ) {
    // Kaydedilmiş durumlar, hatırlatıcı sonradan değiştirilse
    // veya silinse de bugünkü listede korunur.
    final byId = {for (final occurrence in saved) occurrence.id: occurrence};

    for (final document in reminderSnapshot.docs) {
      if (document.metadata.hasPendingWrites) continue;

      final reminder = Reminder.fromDocument(document);

      if (reminder.type != ReminderType.insulin ||
          !reminder.isEnabled ||
          !reminder.weekdays.contains(_now.weekday)) {
        continue;
      }

      final occurrence = InsulinOccurrence.fromReminder(
        reminder: reminder,
        date: _now,
      );

      if (byId.containsKey(occurrence.id)) continue;

      final data = document.data();
      final createdAt = data['createdAt'];
      final updatedAt = data['updatedAt'];

      if (createdAt is! Timestamp || updatedAt is! Timestamp) {
        continue;
      }

      // Yeni oluşturulmuş veya değişmiş planlardan
      // geçmiş saatler için yapay eksik kayıt üretme.
      if (createdAt.toDate().isAfter(occurrence.scheduledAt) ||
          updatedAt.toDate().isAfter(occurrence.scheduledAt)) {
        continue;
      }

      byId[occurrence.id] = occurrence;
    }

    final result = byId.values.toList();

    result.sort((first, second) {
      final comparison = (first.hour * 60 + first.minute).compareTo(
        second.hour * 60 + second.minute,
      );

      return comparison != 0 ? comparison : first.id.compareTo(second.id);
    });

    return result;
  }

  Widget _card(InsulinOccurrence occurrence) {
    final completed = occurrence.status == InsulinOccurrenceStatus.completed;
    final skipped = occurrence.status == InsulinOccurrenceStatus.skipped;
    final future = occurrence.scheduledAt.isAfter(_now);

    final label = completed
        ? 'Yapıldı'
        : skipped
        ? 'Atlandı'
        : future
        ? 'Saati bekleniyor'
        : 'İşaretlenmedi';

    final icon = completed
        ? Icons.check_circle_outline
        : skipped
        ? Icons.remove_circle_outline
        : Icons.schedule;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.medication_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  occurrence.timeLabel,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(label)),
            ],
          ),
          if (completed) ...[
            const SizedBox(height: 10),
            const Text(
              'Bağlı uygulama kaydı Kayıtlar → İnsülin bölümünde. '
              'Kaydı silerseniz bu işaret de kaldırılır.',
              style: TextStyle(
                color: AppColors.muted,
                height: 1.4,
                fontSize: 12,
              ),
            ),
          ] else if (skipped) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(() => _repository.undoSkip(occurrence)),
              child: const Text('Atlandı işaretini geri al'),
            ),
          ] else if (!future) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : () => _complete(occurrence),
                  icon: const Icon(Icons.check),
                  label: const Text('Yapıldı'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _skip(occurrence),
                  child: const Text('Atlandı'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'İnsülin takibi yüklenemedi. '
              'Bağlantınızı ve Firestore kurallarını kontrol edin.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(_createStreams);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = _now.day.toString().padLeft(2, '0');
    final month = _now.month.toString().padLeft(2, '0');

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !_busy,
          title: const Text('Bugünkü insülin takibi'),
        ),
        body: SafeArea(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _reminderStream,
            builder: (context, reminderSnapshot) {
              if (reminderSnapshot.hasError) return _errorView();

              if (!reminderSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<List<InsulinOccurrence>>(
                key: ValueKey(_dateKey),
                stream: _occurrenceStream,
                builder: (context, occurrenceSnapshot) {
                  if (occurrenceSnapshot.hasError) {
                    return _errorView();
                  }

                  if (!occurrenceSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final occurrences = _buildOccurrences(
                    reminderSnapshot.data!,
                    occurrenceSnapshot.data!,
                  );

                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        '$day.$month.${_now.year}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Bugünkü etkin insülin hatırlatıcılarınızı '
                        've kaydedilmiş yanıtlarınızı takip edin.',
                        style: TextStyle(height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      if (_busy) ...[
                        const LinearProgressIndicator(),
                        const SizedBox(height: 16),
                      ],
                      if (occurrences.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'Bugün için gösterilecek insülin planı yok.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        ...occurrences.map(_card),
                      const SizedBox(height: 12),
                      const Text(
                        'Yanıt verilmeyen planlar otomatik olarak '
                        'atlandı sayılmaz. Yapıldı seçeneği yalnızca '
                        'uygulama kaydı başarıyla kaydedilince işaretlenir.\n\n'
                        'Bugünkü işaretlenmemiş planlar mevcut etkin '
                        'hatırlatıcılardan hesaplanır. Planı değiştirirseniz '
                        'veya kapatırsanız bu liste de değişebilir.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
