import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/notifications/notification_occurrence.dart';
import '../../../core/notifications/notification_service.dart';
import '../domain/reminder.dart';

class ReminderScheduler {
  ReminderScheduler._();

  static final ReminderScheduler instance = ReminderScheduler._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  String? _userId;
  int _generation = 0;

  void startSession(String userId) {
    _generation++;
    _userId = userId;

    NotificationService.instance.setSessionUser(userId);
  }

  void detachSession(String userId) {
    if (_userId != userId) return;

    _generation++;
    _userId = null;

    // Bu nesne ayrıldığında mevcut zamanlamalar korunur.
    // Gerçek çıkış işlemi stopSession tarafından yönetilir.
  }

  String _scheduleKey(Reminder reminder) {
    return NotificationService.scheduleKey(
      type: reminder.type.code,
      hour: reminder.hour,
      minute: reminder.minute,
      weekdays: reminder.weekdays,
      note: reminder.note,
    );
  }

  Future<String> synchronize({
    required String userId,
    required List<Reminder> reminders,
  }) {
    final generation = _generation;
    final items = List<Reminder>.of(reminders);
    final service = NotificationService.instance;

    bool isCurrentSession() {
      return generation == _generation && _userId == userId;
    }

    return service.runExclusive(() async {
      if (!isCurrentSession()) {
        return 'Zamanlama oturumu değişti.';
      }

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

      final activeById = {
        for (final reminder in activeReminders) reminder.id: reminder,
      };

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

      final pending = await _plugin.pendingNotificationRequests();

      final usedIds = <int>{...NotificationService.reservedIds};

      for (final notification in pending) {
        if (!isCurrentSession()) {
          return 'Zamanlama oturumu değişti.';
        }

        final data = NotificationService.parseReminderPayload(
          notification.payload,
        );

        if (data == null) {
          usedIds.add(notification.id);
          continue;
        }

        final reminder = activeById[data['reminderId']];
        final scheduledAtMs = data['scheduledAtMs'];

        final reminderScopedSnooze =
            data['version'] == 2 &&
            data['snoozeScope'] == 'reminder' &&
            data['occurrence'] == null &&
            data['type'] == 'insulin' &&
            reminder != null &&
            data['hour'] == reminder.hour &&
            data['minute'] == reminder.minute &&
            reminder.weekdays.contains(data['weekday']) &&
            data['timeZoneId'] is String;

        final validInsulinTarget =
            reminder?.type != ReminderType.insulin ||
            (data['version'] == 2 &&
                reminder != null &&
                NotificationOccurrence.read(
                      data['occurrence'],
                      reminderId: reminder.id,
                    ) !=
                    null) ||
            reminderScopedSnooze;

        final preserveSnooze =
            notificationsEnabled &&
            data['kind'] == 'snooze' &&
            data['userId'] == userId &&
            reminder != null &&
            data['scheduleKey'] == _scheduleKey(reminder) &&
            scheduledAtMs is int &&
            scheduledAtMs > DateTime.now().millisecondsSinceEpoch &&
            validInsulinTarget;

        if (preserveSnooze) {
          usedIds.add(notification.id);
        } else {
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

      var usedApproximateScheduling = !canUseExactAlarms;

      try {
        for (final reminder in activeReminders) {
          final days = reminder.weekdays.toSet().toList()..sort();

          for (final weekday in days) {
            if (!isCurrentSession()) {
              return 'Zamanlama oturumu değişti.';
            }

            final key = '$userId/${reminder.id}/$weekday';

            // Normal tekrarlar alt aralıkta, ertelemeler üst aralıkta.
            var notificationId = NotificationService.stableHash(key) + 1;

            while (!usedIds.add(notificationId)) {
              notificationId = notificationId >= 1000000000
                  ? 1
                  : notificationId + 1;
            }

            final scheduledDate = _nextOccurrence(
              location: location!,
              weekday: weekday,
              hour: reminder.hour,
              minute: reminder.minute,
            );

            final payloadData = {
              'version': 2,
              'userId': userId,
              'reminderId': reminder.id,
              'type': reminder.type.code,
              'kind': 'regular',
              'scheduleKey': _scheduleKey(reminder),
              'weekday': weekday,
              'hour': reminder.hour,
              'minute': reminder.minute,
              'timeZoneId': location.name,
            };

            final payload =
                '${NotificationService.reminderPayloadPrefix}'
                '${jsonEncode(payloadData)}';

            Future<void> schedule(AndroidScheduleMode mode) async {
              await _plugin.zonedSchedule(
                id: notificationId,
                title: 'Şeker Takibi',
                body: NotificationService.reminderBody(reminder.type.code),
                scheduledDate: scheduledDate,
                notificationDetails: NotificationService.detailsForType(
                  reminder.type.code,
                ),
                androidScheduleMode: mode,
                matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
                payload: payload,
              );

              debugPrint(
                '[HATIRLATICI] '
                'tur=${reminder.type.code} '
                'gun=$weekday '
                'planlanan=$scheduledDate '
                'yontem=${mode.name}',
              );
            }

            try {
              await schedule(
                canUseExactAlarms
                    ? AndroidScheduleMode.exactAllowWhileIdle
                    : AndroidScheduleMode.inexactAllowWhileIdle,
              );
            } on PlatformException catch (error) {
              if (error.code != 'exact_alarms_not_permitted') rethrow;

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

      service.notifyScheduleChanges();

      return usedApproximateScheduling
          ? 'Hatırlatıcılar yaklaşık zamanlamayla kuruldu. '
                'Android bildirimleri geciktirebilir.'
          : 'Aktif hatırlatıcılar bu cihazda zamanlandı.';
    });
  }

  Future<void> stopSession() {
    _generation++;
    _userId = null;

    final service = NotificationService.instance;

    service.setSessionUser(null);
    service.clearPendingPayload();

    return service.runExclusive(() async {
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
}
