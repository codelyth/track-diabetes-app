import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder.dart';

class ReminderTime {
  ReminderTime._();

  static Future<tz.Location> deviceLocation() async {
    tz_data.initializeTimeZones();

    final timezone = await FlutterTimezone.getLocalTimezone();
    final identifier = timezone.identifier.trim();

    return switch (identifier) {
      'GMT' || 'Etc/GMT' || 'UTC' || 'Etc/UTC' => tz.UTC,
      _ => tz.getLocation(identifier),
    };
  }

  static tz.TZDateTime? nextOccurrence({
    required Reminder reminder,
    required tz.Location location,
  }) {
    if (!reminder.isEnabled || reminder.weekdays.isEmpty) {
      return null;
    }

    final now = tz.TZDateTime.now(location);
    tz.TZDateTime? next;

    for (final weekday in reminder.weekdays.toSet()) {
      var daysAhead = (weekday - now.weekday + 7) % 7;

      var candidate = tz.TZDateTime(
        location,
        now.year,
        now.month,
        now.day + daysAhead,
        reminder.hour,
        reminder.minute,
      );

      if (!candidate.isAfter(now)) {
        daysAhead += 7;

        candidate = tz.TZDateTime(
          location,
          now.year,
          now.month,
          now.day + daysAhead,
          reminder.hour,
          reminder.minute,
        );
      }

      if (next == null || candidate.isBefore(next)) {
        next = candidate;
      }
    }

    return next;
  }

  static String time(DateTime value) {
    return '${_two(value.hour)}:${_two(value.minute)}';
  }

  static String date(DateTime value) {
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];

    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  static String label(DateTime value) {
    return '${date(value)} · ${time(value)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
