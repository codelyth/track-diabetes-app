import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/notifications/notification_service.dart';
import '../domain/reminder.dart';

class ReminderScheduler {
  ReminderScheduler._();

  static final ReminderScheduler instance = ReminderScheduler._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> _queue = Future<void>.value();

  String? _userId;
  int _generation = 0;

  static const _payloadPrefix = 'diabetes-reminder:';

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'diabetes_reminders_v1',
      'Takip hatırlatıcıları',
      channelDescription: 'Ölçüm ve insülin takip hatırlatıcıları.',
      icon: 'ic_notification',
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.private,
      autoCancel: true,
    ),
  );

  void startSession(String userId) {
    _generation++;
    _userId = userId;
  }

  /// Sayfa kapanınca devam eden eski senkronizasyonları durdurur.
  /// Önceden kurulmuş bildirimleri iptal etmez.
  void detachSession(String userId) {
    if (_userId != userId) return;

    _generation++;
    _userId = null;
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());

    // Bir işlem hata verse de sonraki işlemler çalışabilsin.
    _queue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );

    return result;
  }

  Future<String> synchronize({
    required String userId,
    required List<Reminder> reminders,
  }) {
    final generation = _generation;
    final items = List<Reminder>.of(reminders);

    bool isCurrentSession() {
      return generation == _generation && _userId == userId;
    }

    return _enqueue(() async {
      if (!isCurrentSession()) {
        return 'Zamanlama oturumu değişti.';
      }

      final service = NotificationService.instance;

      if (!service.isSupported) {
        return 'Bildirim zamanlaması şu anda Android için kullanılabilir.';
      }

      await service.initialize();

      if (!isCurrentSession()) {
        return 'Zamanlama oturumu değişti.';
      }

      final notificationsEnabled = await service.notificationsEnabled();
      final activeReminders = items.where((item) => item.isEnabled).toList()
        ..sort((first, second) => first.id.compareTo(second.id));

      // Hazırlık işlemleri başarılı olmadan mevcut zamanlamayı silmeyelim.
      tz.Location? location;

      if (notificationsEnabled && activeReminders.isNotEmpty) {
        tz_data.initializeTimeZones();

        final timezone = await FlutterTimezone.getLocalTimezone();
        final identifier = timezone.identifier.trim();

        location = switch (identifier) {
          'GMT' || 'Etc/GMT' || 'UTC' || 'Etc/UTC' => tz.UTC,
          _ => tz.getLocation(identifier),
        };
      }

      final canUseExactAlarms = notificationsEnabled
          ? await service.exactAlarmsEnabled()
          : false;

      if (!isCurrentSession()) {
        return 'Zamanlama oturumu değişti.';
      }

      // Yalnızca gerçek hatırlatıcı zamanlamalarını temizle.
      // Test bildirimlerine dokunma.
      final pending = await _plugin.pendingNotificationRequests();

      for (final notification in pending) {
        if (!isCurrentSession()) {
          return 'Zamanlama oturumu değişti.';
        }

        if (notification.payload?.startsWith(_payloadPrefix) ?? false) {
          await _plugin.cancel(id: notification.id);
        }
      }

      if (!notificationsEnabled) {
        return 'Bildirim izni kapalı. Aktif kayıtlar bu cihazda '
            'zamanlanmadı. İzin verdikten sonra Yenile’ye basın.';
      }

      if (activeReminders.isEmpty) {
        return 'Aktif hatırlatıcı yok.';
      }

      final usedIds = <int>{900001, 900002};
      var usedApproximateScheduling = !canUseExactAlarms;

      try {
        for (final reminder in activeReminders) {
          final days = reminder.weekdays.toSet().toList()..sort();

          for (final weekday in days) {
            if (!isCurrentSession()) {
              return 'Zamanlama oturumu değişti.';
            }

            final key = '$userId/${reminder.id}/$weekday';
            var notificationId = _notificationId(key);

            while (!usedIds.add(notificationId)) {
              notificationId = notificationId == 2000000000
                  ? 1
                  : notificationId + 1;
            }

            final scheduledDate = _nextOccurrence(
              location: location!,
              weekday: weekday,
              hour: reminder.hour,
              minute: reminder.minute,
            );

            final payload =
                '$_payloadPrefix${jsonEncode({'userId': userId, 'reminderId': reminder.id, 'type': reminder.type.code})}';

            Future<void> schedule(AndroidScheduleMode mode) async {
              debugPrint(
                '[HATIRLATICI] '
                'tur=${reminder.type.code} '
                'gun=$weekday '
                'simdi=${tz.TZDateTime.now(location!)} '
                'planlanan=$scheduledDate '
                'saatDilimi=${location.name} '
                'yontem=${mode.name}',
              );

              await _plugin.zonedSchedule(
                id: notificationId,
                title: 'Şeker Takibi',
                body: switch (reminder.type) {
                  ReminderType.fasting =>
                    'Açlık ölçümü hatırlatıcınızın zamanı geldi.',
                  ReminderType.postMeal =>
                    'Tokluk ölçümü hatırlatıcınızın zamanı geldi.',
                  ReminderType.insulin =>
                    'İnsülin takip hatırlatıcınızın zamanı geldi.',
                },
                scheduledDate: scheduledDate,
                notificationDetails: _details,
                androidScheduleMode: mode,
                matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
                payload: payload,
              );

              final pending = await _plugin.pendingNotificationRequests();
              final registered = pending.any(
                (notification) => notification.id == notificationId,
              );

              debugPrint(
                '[HATIRLATICI] '
                'id=$notificationId '
                'cihazdaKayitli=$registered',
              );
            }

            try {
              await schedule(
                canUseExactAlarms
                    ? AndroidScheduleMode.exactAllowWhileIdle
                    : AndroidScheduleMode.inexactAllowWhileIdle,
              );
            } on PlatformException catch (error) {
              // İzin, kontrol ile zamanlama arasında kaldırılmış olabilir.
              if (error.code != 'exact_alarms_not_permitted') {
                rethrow;
              }

              usedApproximateScheduling = true;

              await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
            }
          }
        }
      } catch (error, stackTrace) {
        debugPrint('Hatırlatıcı zamanlaması başarısız: $error');
        debugPrintStack(stackTrace: stackTrace);

        rethrow;
      }

      return usedApproximateScheduling
          ? 'Hatırlatıcılar yaklaşık zamanlamayla kuruldu. '
                'Android bildirimleri geciktirebilir.'
          : 'Aktif hatırlatıcılar bu cihazda zamanlandı.';
    });
  }

  /// Çıkış sırasında yeni zamanlama yapılmasını engeller ve
  /// cihazdaki tüm uygulama bildirimlerini iptal eder.
  Future<void> stopSession() {
    _generation++;
    _userId = null;

    return _enqueue(() async {
      final service = NotificationService.instance;

      if (!service.isSupported) return;

      await service.initialize();
      await _plugin.cancelAll();
    });
  }

  tz.TZDateTime _nextOccurrence({
    required tz.Location location,
    required int weekday,
    required int hour,
    required int minute,
  }) {
    final now = tz.TZDateTime.now(location);
    var daysAhead = (weekday - now.weekday + 7) % 7;

    var candidate = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day + daysAhead,
      hour,
      minute,
    );

    if (!candidate.isAfter(now)) {
      daysAhead += 7;

      candidate = tz.TZDateTime(
        location,
        now.year,
        now.month,
        now.day + daysAhead,
        hour,
        minute,
      );
    }

    return candidate;
  }

  int _notificationId(String value) {
    // Dart hashCode yerine yeniden açılışlarda aynı sonucu veren kimlik.
    var hash = 0;

    for (final codeUnit in value.codeUnits) {
      hash = (hash * 31 + codeUnit) % 2000000000;
    }

    return hash + 1;
  }
}
