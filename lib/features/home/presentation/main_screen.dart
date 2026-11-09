import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../glucose/presentation/add_glucose_screen.dart';
import '../../hba1c/presentation/add_hba1c_screen.dart';
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
          if (tab == RecordTab.hba1c) {
            return AddHba1cScreen(userId: user.uid);
          }

          return AddGlucoseScreen(userId: user.uid);
        },
      ),
    );

    if (!mounted || saved != true) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            tab == RecordTab.hba1c
                ? 'HbA1c sonucu kaydedildi.'
                : 'Ölçüm kaydedildi.',
          ),
        ),
      );
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;

    setState(() => _isSigningOut = true);

    try {
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
            ),
            RecordsPage(
              key: ValueKey('records-${user.uid}'),
              userId: user.uid,
              selectedTab: _recordTab,
              onTabChanged: (tab) {
                setState(() => _recordTab = tab);
              },
            ),
            const _RemindersPlaceholder(),
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
              label: Text(
                _recordTab == RecordTab.hba1c ? 'HbA1c ekle' : 'Ölçüm ekle',
              ),
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

class _RemindersPlaceholder extends StatelessWidget {
  const _RemindersPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.lavender,
              child: Icon(
                Icons.notifications_active_outlined,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Hatırlatıcılar',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'Ölçüm ve insülin kaydı hatırlatıcılarınızı '
              'buradan yöneteceksiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
          ],
        ),
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
