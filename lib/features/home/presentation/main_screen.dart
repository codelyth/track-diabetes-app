import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../glucose/presentation/add_glucose_screen.dart';
import '../../hba1c/presentation/add_hba1c_screen.dart';
import '../../insulin/presentation/add_insulin_screen.dart';
import '../../reminders/presentation/reminders_page.dart';
import 'overview_page.dart';
import 'records_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _isSigningOut = false;

  RecordTab _recordTab = RecordTab.glucose;

  static const _titles = ['Özet', 'Kayıtlar', 'Hatırlatıcılar', 'Ayarlar'];

  void _selectPage(int index) {
    setState(() => _selectedIndex = index);
  }

  void _openRecords(RecordTab tab) {
    setState(() {
      _recordTab = tab;
      _selectedIndex = 1;
    });
  }

  Future<void> _openAddRecord() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final tab = _recordTab;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) {
          return switch (tab) {
            RecordTab.glucose => AddGlucoseScreen(userId: user.uid),
            RecordTab.insulin => AddInsulinScreen(userId: user.uid),
            RecordTab.hba1c => AddHba1cScreen(userId: user.uid),
          };
        },
      ),
    );

    if (!mounted || saved != true) return;

    final message = switch (tab) {
      RecordTab.glucose => 'Ölçüm kaydedildi.',
      RecordTab.insulin => 'İnsülin uygulaması kaydedildi.',
      RecordTab.hba1c => 'HbA1c sonucu kaydedildi.',
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;

    setState(() => _isSigningOut = true);

    try {
      await NotificationService.instance.cancelTestNotifications();
      await AuthService.signOut();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(AuthService.errorMessage(error))),
        );
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Şeker Takibi',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              _titles[_selectedIndex],
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            OverviewPage(
              key: ValueKey('overview-${user.uid}'),
              userId: user.uid,
              onOpenRecords: () => _openRecords(RecordTab.glucose),
              onOpenReminders: () => _selectPage(2),
              onOpenHba1c: () => _openRecords(RecordTab.hba1c),
              onOpenInsulin: () => _openRecords(RecordTab.insulin),
            ),
            RecordsPage(
              key: ValueKey('records-${user.uid}'),
              userId: user.uid,
              selectedTab: _recordTab,
              onTabChanged: (tab) {
                setState(() => _recordTab = tab);
              },
            ),
            RemindersPage(key: ValueKey('reminders-${user.uid}')),
            _SettingsPage(isSigningOut: _isSigningOut, onSignOut: _signOut),
          ],
        ),
      ),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton.extended(
              onPressed: _openAddRecord,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text(switch (_recordTab) {
                RecordTab.glucose => 'Ölçüm Ekle',
                RecordTab.insulin => 'İnsülin Kaydı Ekle',
                RecordTab.hba1c => 'HbA1c Ekle',
              }),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.lavender,
        onDestinationSelected: _selectPage,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Özet',
          ),
          NavigationDestination(
            icon: Icon(Icons.format_list_bulleted),
            label: 'Kayıtlar',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Hatırlatıcılar',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.isSigningOut, required this.onSignOut});

  final bool isSigningOut;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.settings_outlined, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Uygulama ayarları',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Tercihleriniz',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Profil, bildirim ve widget ayarlarını '
                'burada tamamlayacağız.',
                style: TextStyle(color: AppColors.muted, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: isSigningOut ? null : onSignOut,
          icon: const Icon(Icons.logout),
          label: Text(isSigningOut ? 'Çıkış yapılıyor...' : 'Çıkış yap'),
        ),
      ],
    );
  }
}
