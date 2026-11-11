import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../glucose/presentation/add_glucose_screen.dart';
import '../../hba1c/presentation/add_hba1c_screen.dart';
import '../../insulin/presentation/add_insulin_screen.dart';
import '../../reminders/data/reminder_scheduler.dart';
import '../../reminders/presentation/reminders_page.dart';
import 'overview_page.dart';
import 'records_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _notifications = NotificationService.instance;

  int _selectedIndex = 0;
  bool _isSigningOut = false;
  bool _isOpeningNotification = false;

  RecordTab _recordTab = RecordTab.glucose;

  static const _titles = ['Özet', 'Kayıtlar', 'Hatırlatıcılar', 'Ayarlar'];

  @override
  void initState() {
    super.initState();

    _notifications.pendingPayload.addListener(_onNotification);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_initializeNotifications());
      }
    });
  }

  @override
  void dispose() {
    _notifications.pendingPayload.removeListener(_onNotification);
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    if (!_notifications.isSupported) return;

    try {
      await _notifications.initialize();

      if (!mounted) return;

      await _openPendingNotification();
    } catch (error, stackTrace) {
      debugPrint('Bildirim yönlendirmesi başlatılamadı: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _onNotification() {
    if (_notifications.pendingPayload.value == null) return;

    unawaited(_openPendingNotification());
  }

  Future<void> _openPendingNotification() async {
    if (!mounted || _isSigningOut || _isOpeningNotification) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    _isOpeningNotification = true;

    try {
      final payload = _notifications.takePendingPayload();

      if (payload == null) return;

      const prefix = NotificationService.reminderPayloadPrefix;

      if (!payload.startsWith(prefix)) return;

      final decoded = jsonDecode(payload.substring(prefix.length));

      if (decoded is! Map<String, dynamic>) return;

      final payloadUserId = decoded['userId'];
      final reminderId = decoded['reminderId'];

      if (payloadUserId is! String ||
          reminderId is! String ||
          reminderId.isEmpty ||
          reminderId.contains('/')) {
        return;
      }

      if (payloadUserId != user.uid) {
        _showMessage('Bu bildirim mevcut hesaba ait değil.');
        return;
      }

      final document = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reminders')
          .doc(reminderId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      if (!mounted ||
          _isSigningOut ||
          FirebaseAuth.instance.currentUser?.uid != user.uid) {
        return;
      }

      final data = document.data();

      if (!document.exists || data == null || data['isEnabled'] != true) {
        _showMessage('Bu hatırlatıcı silinmiş veya kapatılmış.');
        return;
      }

      // Bildirimdeki tür yerine güncel sunucu kaydını kullan.
      final type = data['type'];

      final RecordTab tab;

      if (type == 'fasting' || type == 'postMeal') {
        tab = RecordTab.glucose;
      } else if (type == 'insulin') {
        tab = RecordTab.insulin;
      } else {
        _showMessage('Hatırlatıcı türü tanınamadı.');
        return;
      }

      _openRecords(tab);

      await _openAddRecord();
    } catch (error, stackTrace) {
      debugPrint('Bildirimden kayıt formu açılamadı: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted && !_isSigningOut) {
        _showMessage(
          'Hatırlatıcı kontrol edilemedi. Bağlantınızı kontrol edin. '
          'Kaydınızı Kayıtlar bölümünden ekleyebilirsiniz.',
        );
      }
    } finally {
      _isOpeningNotification = false;

      if (mounted &&
          !_isSigningOut &&
          _notifications.pendingPayload.value != null) {
        unawaited(_openPendingNotification());
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

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

    if (user == null || _isSigningOut) return;

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

    if (!mounted ||
        saved != true ||
        FirebaseAuth.instance.currentUser?.uid != user.uid) {
      return;
    }

    final message = switch (tab) {
      RecordTab.glucose => 'Ölçüm kaydedildi.',
      RecordTab.insulin => 'İnsülin uygulaması kaydedildi.',
      RecordTab.hba1c => 'HbA1c sonucu kaydedildi.',
    };

    _showMessage(message);
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;

    setState(() => _isSigningOut = true);

    try {
      await ReminderScheduler.instance.stopSession();
      _notifications.clearPendingPayload();

      await AuthService.signOut();
    } catch (error) {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        ReminderScheduler.instance.startSession(user.uid);
      }

      if (!mounted) return;

      _showMessage(
        'Çıkış tamamlanamadı. Tekrar deneyin. '
        'Oturumunuz açıksa hatırlatıcıları Yenile ile kontrol edin.',
      );

      debugPrint('Çıkış işlemi başarısız: $error');
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
            RemindersPage(
              key: ValueKey('reminders-${user.uid}'),
              userId: user.uid,
            ),
            _SettingsPage(isSigningOut: _isSigningOut, onSignOut: _signOut),
          ],
        ),
      ),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton.extended(
              onPressed: _isSigningOut ? null : _openAddRecord,
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
