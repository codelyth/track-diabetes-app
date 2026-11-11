import 'dart:async';

import 'next_reminder_card.dart';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/reminder_repository.dart';
import '../data/reminder_scheduler.dart';
import '../domain/reminder.dart';
import 'add_reminder_screen.dart';
import 'notification_test_page.dart';

enum _ReminderAction { edit, delete }

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key, required this.userId});

  final String userId;

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage>
    with WidgetsBindingObserver {
  late final ReminderRepository _repository;

  final _scheduler = ReminderScheduler.instance;

  StreamSubscription<List<Reminder>>? _subscription;

  List<Reminder> _reminders = [];

  bool _isLoading = true;
  bool _isWorking = false;
  bool _hasData = false;

  String? _loadError;
  String _scheduleStatus = 'Hatırlatıcılar yükleniyor...';

  int _syncVersion = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _repository = ReminderRepository(userId: widget.userId);
    _scheduler.startSession(widget.userId);

    _listen();
  }

  void _listen() {
    _subscription = _repository.watchReminders().listen(
      (reminders) {
        if (!mounted) return;

        setState(() {
          _reminders = reminders;
          _isLoading = false;
          _hasData = true;
          _loadError = null;
        });

        unawaited(_synchronize());
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Hatırlatıcılar yüklenemedi: $error');
        debugPrintStack(stackTrace: stackTrace);

        if (!mounted) return;

        setState(() {
          _isLoading = false;
          _loadError =
              'Hatırlatıcılar alınamadı. '
              'Bağlantınızı ve Firestore kurallarını kontrol edin.';
        });
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _hasData) {
      unawaited(_synchronize());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _scheduler.detachSession(widget.userId);

    final subscription = _subscription;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    super.dispose();
  }

  Future<void> _synchronize() async {
    if (!_hasData) return;

    final version = ++_syncVersion;

    try {
      final status = await _scheduler.synchronize(
        userId: widget.userId,
        reminders: _reminders,
      );

      if (!mounted || version != _syncVersion) return;

      setState(() => _scheduleStatus = status);
    } catch (error, stackTrace) {
      debugPrint('Bildirimler eşitlenemedi: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted || version != _syncVersion) return;

      setState(() {
        _scheduleStatus =
            'Bildirim zamanlaması tamamlanamadı. '
            'Bazı bildirimler kurulmamış olabilir. Yenile’ye basın.';
      });
    }
  }

  Future<void> _refresh() async {
    if (_isWorking) return;

    await _subscription?.cancel();

    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    _listen();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openForm([Reminder? reminder]) async {
    if (_isWorking) return;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            AddReminderScreen(userId: widget.userId, initialReminder: reminder),
      ),
    );

    if (!mounted || saved != true) return;

    _showMessage(
      reminder == null
          ? 'Hatırlatıcı kaydedildi. Açmak için anahtarını etkinleştirin.'
          : 'Hatırlatıcı güncellendi.',
    );
  }

  Future<void> _setEnabled(Reminder reminder, bool enabled) async {
    if (_isWorking) return;

    setState(() => _isWorking = true);

    try {
      await _repository.setEnabled(reminderId: reminder.id, isEnabled: enabled);

      _showMessage(
        enabled
            ? 'Hatırlatıcı açıldı. Cihazdaki zamanlama durumunu kontrol edin.'
            : 'Hatırlatıcı kapatıldı.',
      );
    } catch (error) {
      debugPrint('Hatırlatıcı durumu değiştirilemedi: $error');

      _showMessage(
        'İşlem tamamlanamadı. Bağlantınızı kontrol edip tekrar deneyin.',
      );
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  Future<void> _delete(Reminder reminder) async {
    if (_isWorking) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hatırlatıcı silinsin mi?'),
        content: Text(
          '${reminder.type.label} • ${reminder.timeLabel}\n'
          'Bu hatırlatıcının zamanlaması da kaldırılacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() => _isWorking = true);

    try {
      await _repository.deleteReminder(reminder.id);
      _showMessage('Hatırlatıcı silindi.');
    } catch (error) {
      debugPrint('Hatırlatıcı silinemedi: $error');

      _showMessage('Hatırlatıcı silinemedi. Tekrar deneyin.');
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  Future<void> _openTests() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Bildirim ayarları ve test')),
          body: const SafeArea(child: NotificationTestPage()),
        ),
      ),
    );

    if (!mounted) return;

    await _synchronize();
  }

  IconData _iconFor(ReminderType type) {
    return switch (type) {
      ReminderType.fasting => Icons.water_drop_outlined,
      ReminderType.postMeal => Icons.restaurant,
      ReminderType.insulin => Icons.medication_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Takip hatırlatıcıları',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ölçüm ve insülin takibiniz için saatler belirleyin.',
          style: TextStyle(color: AppColors.muted, height: 1.5),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.lavender,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bu cihazdaki bildirimler',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(_scheduleStatus, style: const TextStyle(height: 1.5)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _isWorking ? null : _openTests,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('İzinler ve test'),
                  ),
                  TextButton.icon(
                    onPressed: _isWorking ? null : _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Yenile'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _isWorking ? null : () => _openForm(),
          icon: const Icon(Icons.add),
          label: const Text('Hatırlatıcı Ekle'),
        ),
        const SizedBox(height: 20),
        if (_isWorking) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
          const Text(
            'Sunucu onayı bekleniyor. Bağlantı yoksa işlem uzayabilir.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
        ],
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_loadError != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_loadError!, textAlign: TextAlign.center),
          )
        else if (_reminders.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40, horizontal: 16),
            child: Column(
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 48,
                  color: AppColors.primary,
                ),
                SizedBox(height: 16),
                Text(
                  'Henüz hatırlatıcı yok',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text(
                  'İlk hatırlatıcınızı ekleyerek başlayın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          )
        else
          ..._reminders.map(_buildReminderCard),
        const SizedBox(height: 12),
        const Text(
          'Açık anahtar, kaydın aktif olduğunu gösterir. '
          'Bildirimlerin bu cihazda kurulup kurulmadığını üstteki '
          'durum alanından kontrol edin.\n\n'
          'Hatırlatıcıyı kapatmak veya bildirimi silmek, '
          'ölçüm ya da insülin uygulaması kaydı oluşturmaz.',
          style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildReminderCard(Reminder reminder) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _isWorking ? null : () => _openForm(reminder),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_iconFor(reminder.type), color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        reminder.type.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Switch(
                      value: reminder.isEnabled,
                      onChanged: _isWorking
                          ? null
                          : (value) => _setEnabled(reminder, value),
                    ),
                    PopupMenuButton<_ReminderAction>(
                      enabled: !_isWorking,
                      onSelected: (action) {
                        switch (action) {
                          case _ReminderAction.edit:
                            unawaited(_openForm(reminder));
                            break;
                          case _ReminderAction.delete:
                            unawaited(_delete(reminder));
                            break;
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: _ReminderAction.edit,
                          child: Text('Düzenle'),
                        ),
                        PopupMenuItem(
                          value: _ReminderAction.delete,
                          child: Text('Sil'),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  reminder.timeLabel,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reminder.repeatLabel,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                ReminderNextTime(
                  key: ValueKey('next-time-${reminder.id}'),
                  reminder: reminder,
                ),
                if (reminder.note.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(reminder.note, style: const TextStyle(height: 1.4)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
