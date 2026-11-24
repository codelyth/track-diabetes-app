import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/delete_account_screen.dart';
import 'update_account_screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.isSigningOut,
    required this.onSignOut,
  });

  final bool isSigningOut;
  final Future<void> Function() onSignOut;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  final _notifications = NotificationService.instance;

  late final Stream<User?> _userStream;

  bool? _notificationsEnabled;
  bool? _exactAlarmsEnabled;

  bool _checkingPermissions = false;
  bool _permissionActionRunning = false;

  String? _permissionError;
  int _permissionRevision = 0;

  bool get _busy => widget.isSigningOut || _permissionActionRunning;

  @override
  void initState() {
    super.initState();

    _userStream = FirebaseAuth.instance.userChanges();

    WidgetsBinding.instance.addObserver(this);

    unawaited(_loadPermissions());
  }

  @override
  void dispose() {
    ++_permissionRevision;
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadPermissions());
    }
  }

  Future<void> _loadPermissions() async {
    if (!_notifications.isSupported || !mounted) return;

    final revision = ++_permissionRevision;

    setState(() {
      _checkingPermissions = true;
      _permissionError = null;
    });

    try {
      final enabled = await _notifications.notificationsEnabled();
      final exact = await _notifications.exactAlarmsEnabled();

      if (!mounted || revision != _permissionRevision) return;

      setState(() {
        _notificationsEnabled = enabled;
        _exactAlarmsEnabled = exact;
      });
    } catch (error) {
      if (!mounted || revision != _permissionRevision) return;

      setState(() {
        _notificationsEnabled = null;
        _exactAlarmsEnabled = null;
        _permissionError = 'İzin durumu kontrol edilemedi.';
      });

      debugPrint('Ayarlar izin kontrolü başarısız: $error');
    } finally {
      if (mounted && revision == _permissionRevision) {
        setState(() => _checkingPermissions = false);
      }
    }
  }

  Future<void> _runPermissionAction(Future<void> Function() action) async {
    if (_busy) return;

    setState(() => _permissionActionRunning = true);

    try {
      await action();
      await _loadPermissions();
    } catch (error) {
      if (mounted) {
        _showMessage('İşlem tamamlanamadı. Tekrar deneyin.');
      }

      debugPrint('Bildirim ayarı değiştirilemedi: $error');
    } finally {
      if (mounted) {
        setState(() => _permissionActionRunning = false);
      }
    }
  }

  Future<void> _openAccountEditor({required bool changePassword}) async {
    if (_busy) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            UpdateAccountScreen(userId: userId, changePassword: changePassword),
      ),
    );

    if (!mounted ||
        saved != true ||
        FirebaseAuth.instance.currentUser?.uid != userId) {
      return;
    }

    _showMessage(
      changePassword ? 'Şifreniz güncellendi.' : 'Profiliniz güncellendi.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _permissionLabel(bool? enabled) {
    if (_checkingPermissions) return 'Kontrol ediliyor…';
    if (enabled == null) return 'Kontrol edilemedi.';

    return enabled ? 'Açık' : 'Kapalı';
  }

  Widget _section({required String title, required List<Widget> children}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _userStream,
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final name = user?.displayName?.trim();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _section(
              title: 'Hesabım',
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 25,
                      backgroundColor: AppColors.lavender,
                      child: Icon(
                        Icons.person_outline,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name == null || name.isEmpty ? 'Kullanıcı' : name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Profili Düzenle'),
                  subtitle: const Text('Ad ve soyadınızı değiştirin.'),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: !_busy,
                  onTap: () => _openAccountEditor(changePassword: false),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Şifre Değiştir'),
                  subtitle: const Text('Hesap şifrenizi güncelleyin.'),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: !_busy,
                  onTap: () => _openAccountEditor(changePassword: true),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _section(
              title: 'Bildirimler',
              children: [
                if (!_notifications.isSupported)
                  const Text('Bildirim ayarları bu platformda desteklenmiyor.')
                else ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Bildirim İzni'),
                    subtitle: Text(_permissionLabel(_notificationsEnabled)),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.alarm_outlined),
                    title: const Text('Zamanında Hatırlatma İzni'),
                    subtitle: Text(_permissionLabel(_exactAlarmsEnabled)),
                  ),
                  const Text(
                    'Zamanında hatırlatma izni kapalıysa '
                    'bildirimler sistem tarafından geciktirilebilir.',
                    style: TextStyle(color: AppColors.muted, height: 1.4),
                  ),
                  if (_permissionError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _permissionError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_notificationsEnabled == false)
                        OutlinedButton(
                          onPressed: _busy || _checkingPermissions
                              ? null
                              : () => _runPermissionAction(() async {
                                  await _notifications
                                      .requestNotificationPermission();
                                }),
                          child: const Text('Bildirim izni ver.'),
                        ),
                      if (_exactAlarmsEnabled == false)
                        OutlinedButton(
                          onPressed: _busy || _checkingPermissions
                              ? null
                              : () => _runPermissionAction(
                                  _notifications.requestExactAlarmPermission,
                                ),
                          child: const Text('Zamanlama izni ver.'),
                        ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _runPermissionAction(
                                _notifications.openNotificationSettings,
                              ),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Sistem Ayarları'),
                      ),
                      TextButton.icon(
                        onPressed: _busy || _checkingPermissions
                            ? null
                            : _loadPermissions,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Yenile'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            _section(
              title: 'Ana Ekran Widget’ı',
              children: const [
                Text(
                  'Ana ekranda boş bir alana basılı tutun. '
                  'Widget’lar bölümünden Şeker Takibi’ni ekleyin.',
                  style: TextStyle(color: AppColors.muted, height: 1.5),
                ),
                SizedBox(height: 8),
                Text(
                  'Son ölçüm, bugünün ortalaması ve sıradaki '
                  'hatırlatıcı burada gösterilir.',
                  style: TextStyle(color: AppColors.muted, height: 1.5),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : widget.onSignOut,
              icon: const Icon(Icons.logout),
              label: Text(
                widget.isSigningOut ? 'Çıkış yapılıyor…' : 'Çıkış Yap',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: _busy ? null : _openDeleteAccount,
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Hesabımı Sil'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openDeleteAccount() async {
    if (_busy) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DeleteAccountScreen(userId: userId),
      ),
    );
  }
}
