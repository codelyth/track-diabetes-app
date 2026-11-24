import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/delete_account_screen.dart';
import 'update_account_screen.dart';
import 'notification_settings_page.dart';

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

class _SettingsPageState extends State<SettingsPage> {
  late final Stream<User?> _userStream;
  bool get _busy => widget.isSigningOut;

  @override
  void initState() {
    super.initState();
    _userStream = FirebaseAuth.instance.userChanges();
  }

  Future<void> _openNotificationSettings() async {
    if (_busy) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const NotificationSettingsPage()),
    );
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
                fontSize: AppTypography.cardTitleSize,
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
                              fontSize: AppTypography.bodySize,
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Bildirim Ayarları'),
                  subtitle: const Text(
                    'Bildirim ve zamanlama izinlerini yönetin.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: !_busy,
                  onTap: _openNotificationSettings,
                ),
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
