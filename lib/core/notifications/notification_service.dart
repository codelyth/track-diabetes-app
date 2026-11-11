import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _instantTestId = 900001;
  static const _scheduledTestId = 900002;

  static const _channel = AndroidNotificationChannel(
    'reminder_tests_v1',
    'Bildirim testleri',
    description:
        'Hatırlatıcı altyapısını kontrol etmek için test bildirimleri.',
    importance: Importance.high,
  );

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminder_tests_v1',
      'Bildirim testleri',
      channelDescription:
          'Hatırlatıcı altyapısını kontrol etmek için test bildirimleri.',
      icon: 'ic_notification',
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.private,
      autoCancel: true,
    ),
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void>? _initialization;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  AndroidFlutterLocalNotificationsPlugin get _android {
    final implementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (implementation == null) {
      throw StateError('Android bildirim servisine ulaşılamadı.');
    }

    return implementation;
  }

  Future<void> initialize() async {
    if (!isSupported) {
      throw UnsupportedError(
        'Bu bildirim altyapısı şu anda Android için hazırlanmıştır.',
      );
    }

    final initialization = _initialization ??= _initialize();

    try {
      await initialization;
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    final initialized = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
    );

    if (initialized != true) {
      throw StateError('Bildirim servisi başlatılamadı.');
    }

    await _android.createNotificationChannel(_channel);

    tz_data.initializeTimeZones();
  }

  Future<bool> notificationsEnabled() async {
    await initialize();
    return await _android.areNotificationsEnabled() ?? false;
  }

  Future<bool> requestNotificationPermission() async {
    await initialize();

    await _android.requestNotificationsPermission();

    return await _android.areNotificationsEnabled() ?? false;
  }

  Future<bool> exactAlarmsEnabled() async {
    await initialize();
    return await _android.canScheduleExactNotifications() ?? false;
  }

  Future<void> requestExactAlarmPermission() async {
    await initialize();
    await _android.requestExactAlarmsPermission();
  }

  Future<void> openNotificationSettings() async {
    await initialize();
    await _android.openAppNotificationSettings();
  }

  Future<void> _ensureNotificationPermission() async {
    if (!await notificationsEnabled()) {
      throw StateError(
        'Bildirim izni kapalı. Önce bildirim iznini etkinleştirin.',
      );
    }
  }

  Future<void> showTestNotification() async {
    await initialize();
    await _ensureNotificationPermission();

    await _plugin.show(
      id: _instantTestId,
      title: 'Bildirim testi',
      body: 'Şeker Takibi bildirim servisi çalışıyor.',
      notificationDetails: _details,
    );
  }

  /// Aynı test yeniden başlatıldığında önceki zamanlama değiştirilir.
  ///
  /// true: kesin zamanlama kullanıldı.
  /// false: yaklaşık zamanlama kullanıldı; Android bildirimi geciktirebilir.
  Future<bool> scheduleTestNotification() async {
    await initialize();
    await _ensureNotificationPermission();

    // Zamanlama öncesinde saat dilimi verisini hazırla.
    tz_data.initializeTimeZones();

    final timezone = await FlutterTimezone.getLocalTimezone();
    final identifier = timezone.identifier.trim();

    final location = switch (identifier) {
      'GMT' || 'Etc/GMT' || 'UTC' || 'Etc/UTC' => tz.UTC,
      _ => tz.getLocation(identifier),
    };

    final scheduledDate = tz.TZDateTime.now(
      location,
    ).add(const Duration(minutes: 1));

    final useExactAlarm = await exactAlarmsEnabled();

    await _plugin.zonedSchedule(
      id: _scheduledTestId,
      title: 'Zamanlanmış bildirim testi',
      body: 'Arka plan bildirim testi tamamlandı.',
      scheduledDate: scheduledDate,
      notificationDetails: _details,
      androidScheduleMode: useExactAlarm
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );

    return useExactAlarm;
  }

  Future<void> cancelTestNotifications() async {
    if (!isSupported) return;

    await initialize();

    await _plugin.cancel(id: _instantTestId);
    await _plugin.cancel(id: _scheduledTestId);
  }
}
