import 'package:flutter/material.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_theme.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage>
    with WidgetsBindingObserver {
  final _service = NotificationService.instance;

  bool _isBusy = false;
  bool? _notificationsEnabled;
  bool? _exactAlarmsEnabled;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    if (!_service.isSupported) return;

    try {
      final notifications = await _service.notificationsEnabled();
      final exactAlarms = await _service.exactAlarmsEnabled();

      if (!mounted) return;

      setState(() {
        _notificationsEnabled = notifications;
        _exactAlarmsEnabled = exactAlarms;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Bildirim durumu alınamadı. Yeniden deneyin.';
      });
    }
  }

  Future<void> _runAction(Future<String> Function() action) async {
    if (_isBusy) return;

    setState(() => _isBusy = true);

    try {
      final message = await action();

      if (!mounted) return;

      _showMessage(message);
    } catch (error, stackTrace) {
      debugPrint('Bildirim işlemi başarısız: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      final message = error is StateError
          ? error.message.toString()
          : 'Bildirim işlemi tamamlanamadı. Tekrar deneyin.';

      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
        await _refreshStatus();
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _permissionLabel(bool? enabled) {
    return switch (enabled) {
      true => 'Açık',
      false => 'Kapalı',
      null => 'Kontrol ediliyor',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!_service.isSupported) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Bildirim testleri şu anda Android cihazlarda kullanılabilir.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Hatırlatıcılar',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Önce cihazınızın bildirim izinlerini ve '
          'zamanlanmış bildirimleri kontrol edelim.',
          style: TextStyle(color: AppColors.muted, height: 1.5),
        ),
        const SizedBox(height: 20),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.notifications_active_outlined,
                title: 'Bildirim izinleri',
              ),
              const SizedBox(height: 16),
              _StatusRow(
                title: 'Bildirimler',
                value: _permissionLabel(_notificationsEnabled),
              ),
              const SizedBox(height: 12),
              _StatusRow(
                title: 'Kesin zamanlama',
                value: _permissionLabel(_exactAlarmsEnabled),
              ),
              const SizedBox(height: 16),
              const Text(
                'Kesin zamanlama kapalıysa yaklaşık zamanlama kullanılır. '
                'Bu durumda Android bildirimi geciktirebilir.',
                style: TextStyle(color: AppColors.muted, height: 1.5),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isBusy
                    ? null
                    : () => _runAction(() async {
                        final granted = await _service
                            .requestNotificationPermission();

                        return granted
                            ? 'Bildirim izni açık.'
                            : 'Bildirim izni verilmedi. '
                                  'Cihaz ayarlarından etkinleştirebilirsiniz.';
                      }),
                icon: const Icon(Icons.notifications_outlined),
                label: const Text('Bildirim izni ver'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isBusy
                    ? null
                    : () => _runAction(() async {
                        await _service.requestExactAlarmPermission();

                        return 'İzin durumunu bu ekrandan kontrol edebilirsiniz.';
                      }),
                icon: const Icon(Icons.alarm),
                label: const Text('Kesin zamanlama izni'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _isBusy
                    ? null
                    : () => _runAction(() async {
                        await _service.openNotificationSettings();

                        return 'Bildirim ayarları kontrol edildi.';
                      }),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Cihazın bildirim ayarları'),
              ),
              TextButton.icon(
                onPressed: _isBusy ? null : _refreshStatus,
                icon: const Icon(Icons.refresh),
                label: const Text('Durumu yenile'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.science_outlined,
                title: 'Bildirim testi',
              ),
              const SizedBox(height: 12),
              const Text(
                'Bunlar yalnızca test bildirimleridir. '
                'Ölçüm veya insülin kaydı oluşturmaz.',
                style: TextStyle(color: AppColors.muted, height: 1.5),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isBusy
                    ? null
                    : () => _runAction(() async {
                        await _service.showTestNotification();

                        return 'Test bildirimi gönderildi. '
                            'Bildirim çubuğunu kontrol edin.';
                      }),
                icon: const Icon(Icons.send_outlined),
                label: const Text('Şimdi test bildirimi gönder'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isBusy
                    ? null
                    : () => _runAction(() async {
                        final exact = await _service.scheduleTestNotification();

                        return exact
                            ? 'Test 1 dakika sonrasına planlandı. '
                                  'Uygulamayı ana ekran tuşuyla arka plana alın.'
                            : 'Test yaklaşık zamanlamayla planlandı. '
                                  'Bildirim 1 dakikadan daha geç gelebilir.';
                      }),
                icon: const Icon(Icons.schedule),
                label: const Text('1 dakika sonrasına test planla'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _isBusy
                    ? null
                    : () => _runAction(() async {
                        await _service.cancelTestNotifications();

                        return 'Test bildirimleri iptal edildi.';
                      }),
                icon: const Icon(Icons.notifications_off_outlined),
                label: const Text('Test bildirimlerini iptal et'),
              ),
              if (_isBusy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Bildirim görünümü ve sesi cihaz ayarlarına bağlıdır. '
          'Rahatsız Etmeyin veya pil kısıtlamaları bildirimin '
          'görünmesini ya da zamanını etkileyebilir.',
          style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Text(title),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
