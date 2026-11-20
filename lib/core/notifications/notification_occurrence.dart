import 'package:timezone/timezone.dart' as tz;

class NotificationOccurrence {
  const NotificationOccurrence._({
    required this.id,
    required this.reminderId,
    required this.dateKey,
    required this.weekday,
    required this.hour,
    required this.minute,
    required this.scheduledAt,
    required this.timeZoneId,
  });

  final String id;
  final String reminderId;
  final String dateKey;
  final int weekday;
  final int hour;
  final int minute;
  final DateTime scheduledAt;
  final String timeZoneId;

  static tz.Location locationFor(String identifier) {
    return switch (identifier.trim()) {
      'GMT' || 'Etc/GMT' || 'UTC' || 'Etc/UTC' => tz.UTC,
      _ => tz.getLocation(identifier.trim()),
    };
  }

  factory NotificationOccurrence.forDate({
    required String reminderId,
    required DateTime date,
    required int hour,
    required int minute,
    required String timeZoneId,
  }) {
    final location = locationFor(timeZoneId);

    final planned = tz.TZDateTime(
      location,
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );

    // Saat değişimlerinde bulunmayan bir saat başka saate kaymasın.
    if (planned.year != date.year ||
        planned.month != date.month ||
        planned.day != date.day ||
        planned.hour != hour ||
        planned.minute != minute) {
      throw const FormatException(
        'Seçilen tarih ve saat bu saat diliminde bulunmuyor.',
      );
    }

    final dateKey =
        '${planned.year.toString().padLeft(4, '0')}'
        '${planned.month.toString().padLeft(2, '0')}'
        '${planned.day.toString().padLeft(2, '0')}';

    return NotificationOccurrence._(
      id: '${reminderId}_${dateKey}_${hour}_$minute',
      reminderId: reminderId,
      dateKey: dateKey,
      weekday: planned.weekday,
      hour: hour,
      minute: minute,
      scheduledAt: planned.toUtc(),
      timeZoneId: location.name,
    );
  }

  static NotificationOccurrence? read(
    Object? value, {
    required String reminderId,
  }) {
    if (value is! Map) return null;

    try {
      final milliseconds = value['scheduledAtMs'];
      final timeZoneId = value['timeZoneId'];

      if (milliseconds is! int || timeZoneId is! String) {
        return null;
      }

      final location = locationFor(timeZoneId);

      final planned = tz.TZDateTime.fromMillisecondsSinceEpoch(
        location,
        milliseconds,
      );

      final result = NotificationOccurrence.forDate(
        reminderId: reminderId,
        date: DateTime(planned.year, planned.month, planned.day),
        hour: planned.hour,
        minute: planned.minute,
        timeZoneId: location.name,
      );

      if (result.scheduledAt.millisecondsSinceEpoch != milliseconds ||
          value['id'] != result.id ||
          value['dateKey'] != result.dateKey ||
          value['weekday'] != result.weekday ||
          value['hour'] != result.hour ||
          value['minute'] != result.minute) {
        return null;
      }

      return result;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dateKey': dateKey,
      'weekday': weekday,
      'hour': hour,
      'minute': minute,
      'scheduledAtMs': scheduledAt.millisecondsSinceEpoch,
      'timeZoneId': timeZoneId,
    };
  }

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';

  String get dateLabel =>
      '${dateKey.substring(6, 8)}.'
      '${dateKey.substring(4, 6)}.'
      '${dateKey.substring(0, 4)}';
}
