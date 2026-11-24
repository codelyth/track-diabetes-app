import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_theme.dart';

/// Cihaz başına bir kez gösterilir; hesaplar arasında izin tekrar istenmez.
Future<void> showNotificationIntroduction(BuildContext context) async {
  final service = NotificationService.instance;
  if (!service.isSupported) return;
  final preferences = SharedPreferencesAsync();
  const key = 'notification_introduction_seen_v1';
  if (await preferences.getBool(key) == true) return;
  final enabled = await service.notificationsEnabled();
  if (!context.mounted) return;
  if (enabled) {
    await preferences.setBool(key, true);
    return;
  }
  // Sistem ekranı veya uygulama kapanışı sonrası tekrar gösterilmez.
  await preferences.setBool(key, true);
  if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => const NotificationSettingsPage(isIntroduction: true),
    ),
  );
}

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key, this.isIntroduction = false});
  final bool isIntroduction;

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage>
    with WidgetsBindingObserver {
  final _service = NotificationService.instance;
  bool? _notifications;
  bool? _exact;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    ++_revision;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (!_service.isSupported) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notifications = await _service.notificationsEnabled();
      final exact = await _service.exactAlarmsEnabled();
      if (!mounted || revision != _revision) return;
      setState(() {
        _notifications = notifications;
        _exact = exact;
      });
    } catch (_) {
      if (!mounted || revision != _revision) return;
      setState(() {
        _notifications = null;
        _exact = null;
        _error = 'İzinler kontrol edilemedi. Yeniden deneyin.';
      });
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || _loading) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ayar açılamadı. Tekrar deneyin.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _refresh();
      }
    }
  }

  Widget _permission({
    required IconData icon,
    required String title,
    required String description,
    required bool? enabled,
    required String actionLabel,
    required Future<void> Function() action,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(description, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            Text(
              _loading
                  ? 'Kontrol ediliyor…'
                  : enabled == null
                  ? 'Durum alınamadı.'
                  : enabled
                  ? 'Açık'
                  : 'Kapalı',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (!_loading && enabled == false) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy ? null : () => _run(action),
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirim Ayarları')),
      body: SafeArea(
        child: !_service.isSupported
            ? const Center(
                child: Text(
                  'Bildirim ayarları Android cihazlarda kullanılabilir.',
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (widget.isIntroduction) ...[
                    Text(
                      'Hatırlatıcılarınız size ulaşsın.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ölçüm ve insülin hatırlatıcılarınız için bildirimleri açabilirsiniz. Bu tercihleri daha sonra Ayarlar’dan değiştirebilirsiniz.',
                    ),
                    const SizedBox(height: 20),
                  ],
                  _permission(
                    icon: Icons.notifications_outlined,
                    title: 'Bildirimler',
                    description: 'Planladığınız hatırlatıcıların bu cihazda gösterilmesini sağlar.',
                    enabled: _notifications,
                    actionLabel: 'Bildirimlere İzin Ver',
                    action: () async {
                      final granted = await _service
                          .requestNotificationPermission();
                      if (!granted && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'İzni cihaz ayarlarından açabilirsiniz.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _permission(
                    icon: Icons.alarm_outlined,
                    title: 'Zamanında Hatırlatma',
                    description: 'Hatırlatıcıların seçtiğiniz saatte planlanmasını sağlar. Kapalıysa yaklaşık zamanlama kullanılır ve bildirimler gecikebilir.',
                    enabled: _exact,
                    actionLabel: 'Zamanlama İznini Aç',
                    action: _service.requestExactAlarmPermission,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    TextButton(
                      onPressed: _busy || _loading ? null : _refresh,
                      child: const Text('Yeniden Dene'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _busy || _loading
                        ? null
                        : () => _run(_service.openNotificationSettings),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Cihazın Bildirim Ayarları'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bildirim sesi ve görünümü cihaz ayarlarınıza bağlıdır. Pil kısıtlamaları ve Rahatsız Etmeyin modu bildirimleri etkileyebilir.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                  if (widget.isIntroduction) ...[
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy || _loading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(
                        _notifications == true ? 'Devam Et' : 'Şimdi Değil',
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
