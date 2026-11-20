import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/notifications/notification_occurrence.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../insulin/presentation/add_insulin_screen.dart';
import '../data/insulin_occurrence_repository.dart';
import '../domain/insulin_occurrence.dart';

class InsulinNotificationScreen extends StatefulWidget {
  const InsulinNotificationScreen({
    super.key,
    required this.userId,
    required this.payload,
  });

  final String userId;
  final Map<String, dynamic> payload;

  @override
  State<InsulinNotificationScreen> createState() =>
      _InsulinNotificationScreenState();
}

class _InsulinNotificationScreenState extends State<InsulinNotificationScreen> {
  final _notifications = NotificationService.instance;

  late final InsulinOccurrenceRepository _repository;

  Map<String, dynamic>? _reminder;
  NotificationOccurrence? _target;

  bool _loading = true;
  bool _busy = false;
  bool _fixedDate = false;

  String? _status;
  String? _error;

  String get _reminderId => widget.payload['reminderId'] as String;

  String get _action {
    final action = widget.payload['action'];

    return action is String &&
            const ['complete', 'skip', 'snooze', 'open'].contains(action)
        ? action
        : 'open';
  }

  String get _timeZoneId => widget.payload['timeZoneId'] as String;

  int get _weekday => widget.payload['weekday'] as int;

  bool get _sameUser => FirebaseAuth.instance.currentUser?.uid == widget.userId;

  @override
  void initState() {
    super.initState();

    _repository = InsulinOccurrenceRepository(userId: widget.userId);
    _load();
  }

  void _requireUser() {
    if (!_sameUser) {
      throw StateError('Oturum değişti. Bu ekranı kapatın.');
    }
  }

  String _message(Object error) {
    if (error is InsulinPlanException) return error.message;

    if (error is StateError) {
      return error.message.toString();
    }

    if (error is FormatException) {
      return error.message;
    }

    return 'İşlem tamamlanamadı. '
        'İnternet bağlantınızı kontrol edip tekrar deneyin.';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _reminder = null;
      _target = null;
      _status = null;
      _fixedDate = false;
    });

    try {
      _requireUser();

      await _notifications.initialize();

      final payload = widget.payload;

      if (payload['version'] != 2 ||
          payload['type'] != 'insulin' ||
          payload['userId'] != widget.userId ||
          payload['reminderId'] is! String ||
          payload['weekday'] is! int ||
          payload['hour'] is! int ||
          payload['minute'] is! int ||
          payload['timeZoneId'] is! String) {
        throw StateError(
          'Bu eski bildirimin plan tarihi doğrulanamıyor. '
          'Güncel takibi Hatırlatıcılar bölümünden açın.',
        );
      }

      NotificationOccurrence.locationFor(_timeZoneId);

      final firestore = FirebaseFirestore.instance;

      final deletion = await firestore
          .collection('account_deletions')
          .doc(widget.userId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      _requireUser();

      if (deletion.exists) {
        throw StateError('Bu hesap için silme işlemi başlatılmış.');
      }

      final document = await firestore
          .collection('users')
          .doc(widget.userId)
          .collection('reminders')
          .doc(_reminderId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      _requireUser();

      final data = document.data();

      if (!document.exists ||
          data == null ||
          data['type'] != 'insulin' ||
          data['isEnabled'] != true) {
        throw StateError('Bu insülin hatırlatıcısı silinmiş veya kapatılmış.');
      }

      final weekdays = List<int>.from(data['weekdays'] as List);

      final key = NotificationService.scheduleKey(
        type: data['type'] as String,
        hour: data['hour'] as int,
        minute: data['minute'] as int,
        weekdays: weekdays,
        note: data['note'] as String,
      );

      if (payload['scheduleKey'] != key ||
          payload['hour'] != data['hour'] ||
          payload['minute'] != data['minute'] ||
          !weekdays.contains(_weekday)) {
        throw StateError(
          'Hatırlatıcı değiştirilmiş. Güncel planı '
          'Hatırlatıcılar bölümünden kontrol edin.',
        );
      }

      if (!mounted) return;

      _reminder = data;

      final encodedTarget = payload['occurrence'];

      if (encodedTarget != null) {
        final target = NotificationOccurrence.read(
          encodedTarget,
          reminderId: _reminderId,
        );

        if (target == null ||
            target.timeZoneId !=
                NotificationOccurrence.locationFor(_timeZoneId).name ||
            target.weekday != _weekday ||
            !_validTarget(target)) {
          throw StateError('Bildirimin plan tarihi doğrulanamadı.');
        }

        _target = target;
        _fixedDate = true;

        await _readStatus();
      } else if (payload['kind'] != 'regular' &&
          !(payload['kind'] == 'snooze' &&
              payload['snoozeScope'] == 'reminder')) {
        throw StateError('Ertelenen bildirimin plan bilgisi eksik.');
      }
    } catch (error, stackTrace) {
      debugPrint('[İNSÜLİN BİLDİRİMİ] Ekran yüklenemedi: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        _reminder = null;
        _target = null;
        _status = null;
        _fixedDate = false;
        _error = _message(error);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool _validTarget(NotificationOccurrence target) {
    final data = _reminder;
    if (data == null) return false;

    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];

    return createdAt is Timestamp &&
        updatedAt is Timestamp &&
        target.hour == data['hour'] &&
        target.minute == data['minute'] &&
        target.weekday == _weekday &&
        !target.scheduledAt.isAfter(DateTime.now()) &&
        !createdAt.toDate().isAfter(target.scheduledAt) &&
        !updatedAt.toDate().isAfter(target.scheduledAt);
  }

  NotificationOccurrence _targetForDate(DateTime date) {
    return NotificationOccurrence.forDate(
      reminderId: _reminderId,
      date: date,
      hour: _reminder!['hour'] as int,
      minute: _reminder!['minute'] as int,
      timeZoneId: _timeZoneId,
    );
  }

  bool _selectableDate(DateTime date) {
    try {
      return _validTarget(_targetForDate(date));
    } catch (_) {
      return false;
    }
  }

  Future<void> _readStatus() async {
    final target = _target;
    if (target == null) return;

    final document = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('insulin_occurrences')
        .doc(target.id)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 10));

    _requireUser();

    if (!mounted) return;

    final data = document.data();
    final status = data?['status'];

    if (document.exists && status != 'completed' && status != 'skipped') {
      throw StateError('Bu planın kayıt durumu doğrulanamadı.');
    }

    _status = status is String ? status : null;
  }

  Future<void> _pickDate() async {
    if (_busy || _fixedDate || _reminder == null) return;

    try {
      final location = NotificationOccurrence.locationFor(_timeZoneId);
      final now = tz.TZDateTime.now(location);

      final daysBack = (now.weekday - _weekday + 7) % 7;

      var initial = DateTime(now.year, now.month, now.day - daysBack);

      if (_targetForDate(initial).scheduledAt.isAfter(now)) {
        initial = DateTime(initial.year, initial.month, initial.day - 7);
      }

      if (!_selectableDate(initial)) {
        throw StateError(
          'Bu hatırlatıcı için henüz işaretlenebilecek '
          'geçmiş bir plan saati yok.',
        );
      }

      final createdAt = (_reminder!['createdAt'] as Timestamp).toDate();
      final createdLocal = tz.TZDateTime.from(createdAt, location);

      final selected = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(
          createdLocal.year,
          createdLocal.month,
          createdLocal.day,
        ),
        lastDate: DateTime(now.year, now.month, now.day),
        selectableDayPredicate: _selectableDate,
        helpText: 'Bildirimin ait olduğu plan gününü seçin',
        cancelText: 'Vazgeç',
        confirmText: 'Bu günü seç',
      );

      if (!mounted || selected == null) return;

      _requireUser();

      setState(() {
        _busy = true;
        _error = null;
        _target = _targetForDate(selected);
        _status = null;
      });

      await _readStatus();
    } catch (error, stackTrace) {
      debugPrint('[İNSÜLİN BİLDİRİMİ] Tarih kontrolü başarısız: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        setState(() {
          _target = null;
          _status = null;
          _error = _message(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  InsulinOccurrence _toOccurrence(NotificationOccurrence target) {
    return InsulinOccurrence(
      id: target.id,
      reminderId: target.reminderId,
      dateKey: target.dateKey,
      weekday: target.weekday,
      hour: target.hour,
      minute: target.minute,
      scheduledAt: target.scheduledAt,
    );
  }

  Future<void> _finish({required bool skipped}) async {
    final target = _target!;

    setState(() {
      _status = skipped ? 'skipped' : 'completed';
    });

    final id = widget.payload['notificationId'];

    try {
      await _notifications.acknowledgeInsulinOccurrence(
        userId: widget.userId,
        occurrenceId: target.id,
        skipped: skipped,
        notificationId: id is int ? id : null,
      );
    } catch (error, stackTrace) {
      debugPrint('Bildirim temizliği tamamlanamadı: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        setState(() {
          _error =
              'İşlem kaydedildi ancak ilgili ertelenmiş '
              'bildirimler temizlenemedi. Hatırlatıcılar bölümünde '
              'Yenile’ye basın.';
        });
      }

      return;
    }

    if (!mounted || !_sameUser) return;

    Navigator.of(context).pop(true);
  }

  Future<void> _perform(String action) async {
    final target = _target;

    if (_busy || _reminder == null || _status != null) return;
    if (action != 'snooze' && target == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      _requireUser();

      if (target != null) {
        await _readStatus();

        if (!mounted) return;

        _requireUser();

        if (_status != null) {
          setState(() {});
          return;
        }
      }

      if (action == 'complete' && target != null) {
        final saved = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => AddInsulinScreen(
              userId: widget.userId,
              plannedOccurrence: _toOccurrence(target),
            ),
          ),
        );

        if (!mounted || saved != true) return;

        _requireUser();

        await _finish(skipped: false);
      } else if (action == 'skip' && target != null) {
        await _repository.skip(_toOccurrence(target));

        if (!mounted) return;

        _requireUser();

        await _finish(skipped: true);
      } else if (action == 'snooze') {
        final data = Map<String, dynamic>.from(widget.payload);

        if (target != null) {
          data['occurrence'] = target.toMap();
        }

        final scheduledAt = await _notifications.snoozeInsulin(data: data);

        if (!mounted) return;

        _requireUser();

        String twoDigits(int value) => value.toString().padLeft(2, '0');

        final date =
            '${twoDigits(scheduledAt.day)}.'
            '${twoDigits(scheduledAt.month)}.'
            '${scheduledAt.year}';

        final time =
            '${twoDigits(scheduledAt.hour)}:'
            '${twoDigits(scheduledAt.minute)}';

        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => PopScope(
            canPop: false,
            child: AlertDialog(
              icon: const Icon(Icons.snooze_outlined),
              title: const Text('Hatırlatıcı ertelendi'),
              content: Text(
                '$date günü saat $time için bildirim '
                'cihazda kayıtlı.\n\n'
                'Normal tekrar saatiniz değişmedi.\n'
                'Kesin alarm izni kapalıysa Android bildirimi '
                'geciktirebilir.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Tamam'),
                ),
              ],
            ),
          ),
        );

        if (!mounted || !_sameUser) return;

        Navigator.of(context).pop(true);
      }
    } catch (error, stackTrace) {
      debugPrint('[İNSÜLİN BİLDİRİMİ] $action başarısız: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        setState(() => _error = _message(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = _target;
    final ready = !_loading && _reminder != null;
    final resolved = _status != null;

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !_busy,
          title: const Text('İnsülin hatırlatıcısı'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_loading)
                      const Center(child: CircularProgressIndicator()),
                    if (ready) ...[
                      const Icon(
                        Icons.medication_outlined,
                        size: 48,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _fixedDate ? 'İnsülin planı' : 'İnsülin takibi',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _fixedDate
                            ? 'Bu bildirim aşağıdaki plana bağlıdır. '
                                  'Erteleme, planın tarihini değiştirmez.'
                            : 'Yapıldı veya Atlandı işlemi için ilgili '
                                  'plan gününü seçin. Yalnızca bildirimi '
                                  'ertelemek için tarih seçmeniz gerekmez.',
                        style: const TextStyle(height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Plan saat dilimi: $_timeZoneId',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _busy || _fixedDate ? null : _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          target == null
                              ? 'Kayıt için plan tarihini seç'
                              : '${target.dateLabel} · ${target.timeLabel}',
                        ),
                      ),
                      if (resolved) ...[
                        const SizedBox(height: 20),
                        Text(
                          _status == 'completed'
                              ? 'Bu plan zaten Yapıldı olarak kaydedilmiş.'
                              : 'Bu plan zaten Atlandı olarak kaydedilmiş.',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tekrar kayıt oluşturulmadı. '
                          'Durumu Kayıtlar veya insülin takibi '
                          'ekranından kontrol edebilirsiniz.',
                          style: TextStyle(height: 1.5),
                        ),
                      ] else ...[
                        const SizedBox(height: 20),
                        if (_action == 'complete' || _action == 'open')
                          FilledButton.icon(
                            onPressed: _busy || target == null
                                ? null
                                : () => _perform('complete'),
                            icon: const Icon(Icons.check),
                            label: const Text('Yapılan uygulamayı kaydet'),
                          ),
                        if (_action == 'skip' || _action == 'open') ...[
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _busy || target == null
                                ? null
                                : () => _perform('skip'),
                            child: const Text(
                              'Seçilen planı Atlandı olarak onayla',
                            ),
                          ),
                        ],
                        if (_action == 'snooze' || _action == 'open') ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : () => _perform('snooze'),
                            icon: const Icon(Icons.snooze),
                            label: Text(
                              target == null
                                  ? 'Bildirimi 10 dakika ertele'
                                  : 'Bu planı 10 dakika ertele',
                            ),
                          ),
                        ],
                      ],
                    ],
                    if (_busy) ...[
                      const SizedBox(height: 20),
                      const LinearProgressIndicator(),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 20),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    if (!_loading && _reminder == null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _busy ? null : _load,
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Kapat'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
