import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const reminderPayloadPrefix = 'diabetes-reminder:';
  static const snoozeActionId = 'snooze_10_minutes';
  static const openActionId = 'open_record';

  static const snoozeDuration = Duration(minutes: 10);

  static const _instantTestId = 900001;
  static const _scheduledTestId = 900002;
  static const _feedbackId = 900003;

  static const reservedIds = {_instantTestId, _scheduledTestId, _feedbackId};

  final ValueNotifier<String?> pendingPayload = ValueNotifier<String?>(null);

  final ValueNotifier<int> scheduleChanges = ValueNotifier<int>(0);

  void notifyScheduleChanges() {
    scheduleChanges.value++;
  }

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void>? _initialization;
  Future<void> _queue = Future<void>.value();

  bool _launchDetailsRead = false;

  String? _sessionUserId;
  int _sessionVersion = 0;
  bool _sessionWasSet = false;

  final Set<String> _processingActions = {};

  static const _testChannel = AndroidNotificationChannel(
    'reminder_tests_v1',
    'Bildirim testleri',
    description:
        'Hatırlatıcı altyapısını kontrol etmek için test bildirimleri.',
    importance: Importance.high,
  );

  static const _testDetails = NotificationDetails(
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

  static const reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'diabetes_reminders_v1',
      'Takip hatırlatıcıları',
      channelDescription: 'Ölçüm ve insülin takip hatırlatıcıları.',
      icon: 'ic_notification',
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.private,
      autoCancel: true,
      actions: [
        AndroidNotificationAction(
          openActionId,
          'Kaydı aç',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          snoozeActionId,
          '10 dakika ertele',
          showsUserInterface: true,
          cancelNotification: false,
        ),
      ],
    ),
  );

  // Erteleme sonucu aynı görünür bildirimin yerine yazılır.
  // Bu işlem zamanlanmış haftalık alarmı iptal etmez.
  static const _feedbackDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'notification_status_v1',
      'Bildirim işlem sonuçları',
      channelDescription: 'Erteleme işlemlerinin sonuçları.',
      icon: 'ic_notification',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: false,
      enableVibration: false,
      visibility: NotificationVisibility.private,
      autoCancel: true,
    ),
  );

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

  void setSessionUser(String? userId) {
    _sessionWasSet = true;

    if (_sessionUserId != userId) {
      _sessionVersion++;
      _sessionUserId = userId;
    }
  }

  /// Zamanlama, erteleme ve iptal işlemleri aynı sırayı kullanır.
  Future<T> runExclusive<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());

    _queue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );

    return result;
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
    if (!_sessionWasSet) {
      setSessionUser(FirebaseAuth.instance.currentUser?.uid);
    }

    final initialized = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
      onDidReceiveNotificationResponse: (response) {
        unawaited(_handleResponse(response));
      },
    );

    if (initialized != true) {
      throw StateError('Bildirim servisi başlatılamadı.');
    }

    await _android.createNotificationChannel(_testChannel);

    tz_data.initializeTimeZones();

    if (!_launchDetailsRead) {
      final details = await _plugin.getNotificationAppLaunchDetails();
      _launchDetailsRead = true;

      final response = details?.notificationResponse;

      if (details?.didNotificationLaunchApp == true && response != null) {
        // initialize tamamlanmadan kendisini beklememesi için await etmiyoruz.
        unawaited(_handleResponse(response));
      }
    }
  }

  Future<void> _handleResponse(NotificationResponse response) async {
    final payload = response.payload;

    if (parseReminderPayload(payload) == null) return;

    if (response.actionId == snoozeActionId) {
      final actionKey = '${response.id}:$payload';

      if (!_processingActions.add(actionKey)) return;

      try {
        await initialize();
        await _snooze(response);
      } catch (error, stackTrace) {
        debugPrint('Erteleme başarısız: $error');
        debugPrintStack(stackTrace: stackTrace);

        final message = error is StateError
            ? error.message.toString()
            : 'Hatırlatıcı ertelenemedi. Bağlantınızı kontrol edip '
                  'bildirimdeki düğmeden tekrar deneyin.';

        await _showFeedback(title: 'Erteleme tamamlanamadı', body: message);
      } finally {
        _processingActions.remove(actionKey);
      }

      return;
    }

    final actionId = response.actionId;

    if (actionId == null || actionId.isEmpty || actionId == openActionId) {
      pendingPayload.value = payload;
    }
  }

  static Map<String, dynamic>? parseReminderPayload(String? payload) {
    if (payload == null || !payload.startsWith(reminderPayloadPrefix)) {
      return null;
    }

    try {
      final decoded = jsonDecode(
        payload.substring(reminderPayloadPrefix.length),
      );

      if (decoded is! Map<String, dynamic>) return null;

      final userId = decoded['userId'];
      final reminderId = decoded['reminderId'];

      if (userId is! String ||
          userId.isEmpty ||
          reminderId is! String ||
          reminderId.isEmpty ||
          reminderId.contains('/')) {
        return null;
      }

      return decoded;
    } catch (_) {
      return null;
    }
  }

  static String scheduleKey({
    required String type,
    required int hour,
    required int minute,
    required List<int> weekdays,
    required String note,
  }) {
    final days = weekdays.toSet().toList()..sort();

    return jsonEncode([type, hour, minute, days, note.trim()]);
  }

  static String reminderBody(String type) {
    return switch (type) {
      'fasting' => 'Açlık ölçümü hatırlatıcınızın zamanı geldi.',
      'postMeal' => 'Tokluk ölçümü hatırlatıcınızın zamanı geldi.',
      'insulin' => 'İnsülin takip hatırlatıcınızın zamanı geldi.',
      _ => throw StateError('Hatırlatıcı türü tanınamadı.'),
    };
  }

  Future<void> _snooze(NotificationResponse response) {
    final user = FirebaseAuth.instance.currentUser;
    final data = parseReminderPayload(response.payload);

    if (user == null || data == null || data['userId'] != user.uid) {
      throw StateError('Bu bildirim mevcut hesaba ait değil.');
    }

    final userId = user.uid;
    final version = _sessionVersion;

    bool isCurrentSession() {
      return version == _sessionVersion &&
          _sessionUserId == userId &&
          FirebaseAuth.instance.currentUser?.uid == userId;
    }

    return runExclusive(() async {
      if (!isCurrentSession()) {
        throw StateError('Oturum değişti. Erteleme yapılmadı.');
      }

      final reminderId = data['reminderId'] as String;

      final document = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reminders')
          .doc(reminderId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      if (!isCurrentSession()) {
        throw StateError('Oturum değişti. Erteleme yapılmadı.');
      }

      final reminder = document.data();

      if (!document.exists ||
          reminder == null ||
          reminder['isEnabled'] != true) {
        throw StateError('Bu hatırlatıcı silinmiş veya kapatılmış.');
      }

      final type = reminder['type'] as String;

      final currentKey = scheduleKey(
        type: type,
        hour: reminder['hour'] as int,
        minute: reminder['minute'] as int,
        weekdays: List<int>.from(reminder['weekdays'] as List),
        note: reminder['note'] as String,
      );

      final originalKey = data['scheduleKey'];

      if (originalKey != null && originalKey != currentKey) {
        throw StateError(
          'Hatırlatıcı değiştirilmiş. Güncel kaydı Hatırlatıcılar '
          'bölümünden kontrol edin.',
        );
      }

      if (!await notificationsEnabled()) {
        throw StateError('Bildirim izni kapalı. Erteleme yapılamadı.');
      }

      final pending = await _plugin.pendingNotificationRequests();

      int? existingId;

      for (final item in pending) {
        final itemData = parseReminderPayload(item.payload);

        if (itemData?['kind'] == 'snooze' &&
            itemData?['userId'] == userId &&
            itemData?['reminderId'] == reminderId) {
          existingId = item.id;
          break;
        }
      }

      final usedIds = pending.map((item) => item.id).toSet()
        ..addAll(reservedIds);

      var id =
          existingId ?? (1000000000 + stableHash('$userId/$reminderId/snooze'));

      if (existingId == null) {
        while (usedIds.contains(id)) {
          id = id >= 1999999999 ? 1000000000 : id + 1;
        }
      }

      final exact = await exactAlarmsEnabled();

      if (!isCurrentSession()) {
        throw StateError('Oturum değişti. Erteleme yapılmadı.');
      }

      final scheduledDate = tz.TZDateTime.now(tz.UTC).add(snoozeDuration);

      final payload =
          '$reminderPayloadPrefix${jsonEncode({'userId': userId, 'reminderId': reminderId, 'type': type, 'kind': 'snooze', 'scheduleKey': currentKey, 'scheduledAtMs': scheduledDate.millisecondsSinceEpoch})}';

      var approximate = !exact;

      Future<void> schedule(AndroidScheduleMode mode) {
        return _plugin.zonedSchedule(
          id: id,
          title: 'Şeker Takibi',
          body: reminderBody(type),
          scheduledDate: scheduledDate,
          notificationDetails: reminderDetails,
          androidScheduleMode: mode,
          payload: payload,
        );
      }

      try {
        await schedule(
          exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } on PlatformException catch (error) {
        if (error.code != 'exact_alarms_not_permitted') rethrow;

        approximate = true;
        await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
      }

      if (!isCurrentSession()) {
        await _plugin.cancel(id: id);
        return;
      }

      notifyScheduleChanges();

      debugPrint(
        '[ERTELEME] id=$id '
        'planlanan=$scheduledDate '
        'yaklasik=$approximate',
      );

      final localDate = scheduledDate.toLocal();
      final hour = localDate.hour.toString().padLeft(2, '0');
      final minute = localDate.minute.toString().padLeft(2, '0');

      // cancel(id: response.id) kullanmıyoruz:
      // asıl haftalık zamanlamayı da iptal edebilir.
      await _showFeedback(
        id: response.id,
        title: 'Hatırlatıcı ertelendi',
        body: approximate
            ? 'Yaklaşık 10 dakika sonrasına planlandı. '
                  'Android bildirimi geciktirebilir.'
            : 'Sonraki bildirim: $hour:$minute · 24 saat. '
                  'Normal tekrar saatiniz değişmedi.',
      );
    });
  }

  Future<void> _showFeedback({
    int? id,
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.show(
        id: id ?? _feedbackId,
        title: title,
        body: body,
        notificationDetails: _feedbackDetails,
      );
    } catch (error) {
      debugPrint('Bildirim işlem sonucu gösterilemedi: $error');
    }
  }

  static int stableHash(String value) {
    var hash = 0;

    for (final codeUnit in value.codeUnits) {
      hash = (hash * 31 + codeUnit) % 1000000000;
    }

    return hash;
  }

  String? takePendingPayload() {
    final payload = pendingPayload.value;
    pendingPayload.value = null;
    return payload;
  }

  void clearPendingPayload() {
    pendingPayload.value = null;
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
      notificationDetails: _testDetails,
    );
  }

  Future<bool> scheduleTestNotification() async {
    await initialize();
    await _ensureNotificationPermission();

    tz_data.initializeTimeZones();

    final timezone = await FlutterTimezone.getLocalTimezone();
    final identifier = timezone.identifier.trim();

    final location = switch (identifier) {
      'GMT' || 'Etc/GMT' || 'UTC' || 'Etc/UTC' => tz.UTC,
      _ => tz.getLocation(identifier),
    };

    final scheduledDate = tz.TZDateTime.now(location)
        .add(const Duration(minutes: 1));

    final useExactAlarm = await exactAlarmsEnabled();

    await _plugin.zonedSchedule(
      id: _scheduledTestId,
      title: 'Zamanlanmış bildirim testi',
      body: 'Arka plan bildirim testi tamamlandı.',
      scheduledDate: scheduledDate,
      notificationDetails: _testDetails,
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
