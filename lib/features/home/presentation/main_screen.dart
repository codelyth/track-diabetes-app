import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _isSigningOut = false;

  static const _titles = ['Özet', 'Kayıtlar', 'Hatırlatıcılar', 'Ayarlar'];

  Future<void> _signOut() async {
    if (_isSigningOut) return;

    setState(() => _isSigningOut = true);

    try {
      await AuthService.signOut();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AuthService.errorMessage(error))));
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            const _OverviewPage(),
            const _EmptyPage(
              icon: Icons.table_rows_outlined,
              title: 'Ölçüm Kayıtlarınız',
              description: 'Şeker, insülin ve HbA1c kayıtlarınızı burada listeleyeceğiz.',
            ),
            const _EmptyPage(
              icon: Icons.notifications_active_outlined,
              title: 'Hatırlatıcılar',
              description:
                  'Ölçüm ve insülin kaydı hatırlatıcılarınızı '
                  'buradan yöneteceksiniz.',
            ),
            _SettingsPage(isSigningOut: _isSigningOut, onSignOut: _signOut),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.lavender,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
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

class _OverviewPage extends StatelessWidget {
  const _OverviewPage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Günlük Takibiniz',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: AppColors.text, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ölçümlerinize ve günlük kayıtlarınıza buradan ulaşın.',
          style: TextStyle(color: AppColors.muted, height: 1.5),
        ),
        const SizedBox(height: 24),
        const _SummaryCard(
          icon: Icons.water_drop_outlined,
          title: 'Son Şeker Ölçümü',
          value: 'Henüz ölçüm yok',
          description: 'Kaydedilen son değer ve zamanı burada görünecek.',
        ),
        const SizedBox(height: 16),
        const _SummaryCard(
          icon: Icons.query_stats,
          title: 'Ölçüm Ortalamaları',
          value: 'Henüz veri yok',
          description: 'Açlık ve tokluk ortalamaları, ölçüm kayıtlarınızdan hesaplanacak.',
        ),
        const SizedBox(height: 16),
        const _SummaryCard(
          icon: Icons.alarm_outlined,
          title: 'Sıradaki Hatırlatıcı',
          value: 'Henüz hatırlatıcı yok',
          description: 'Planladığınız sıradaki hatırlatma burada görünecek.',
        ),
        const SizedBox(height: 16),
        const _SummaryCard(
          icon: Icons.science_outlined,
          title: 'Son HbA1c Sonucu',
          value: 'Henüz sonuç yok',
          description: 'Laboratuvar sonucu ve test tarihi burada görünecek.',
        ),
        const SizedBox(height: 16),
        const _SummaryCard(
          icon: Icons.vaccines_outlined,
          title: 'Bugünkü İnsülin Kayıtları',
          value: 'Henüz kayıt yok',
          description: 'Kaydettiğiniz uygulamalar burada listelenecek.',
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String value;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(color: AppColors.muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _EmptyPage extends StatelessWidget {
  const _EmptyPage({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.lavender,
              child: Icon(icon, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.5),
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
        const _SummaryCard(
          icon: Icons.settings_outlined,
          title: 'Uygulama ayarları',
          value: 'Tercihleriniz',
          description:
              'Profil, bildirim ve widget ayarlarını burada tamamlayacağız.',
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: isSigningOut ? null : onSignOut,
          icon: const Icon(Icons.logout),
          label: Text(isSigningOut ? 'Çıkış yapılıyor...' : 'Çıkış Yap'),
        ),
      ],
    );
  }
}
