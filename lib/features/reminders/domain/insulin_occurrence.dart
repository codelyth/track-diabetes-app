import 'package:cloud_firestore/cloud_firestore.dart';

import 'reminder.dart';

enum InsulinOccurrenceStatus { unmarked, completed, skipped }

class InsulinOccurrence {
  const InsulinOccurrence({
    required this.id,
    required this.reminderId,
    required this.dateKey,
    required this.weekday,
    required this.hour,
    required this.minute,
    required this.scheduledAt,
    this.status = InsulinOccurrenceStatus.unmarked,
    this.insulinEntryId,
  });

  final String id;
  final String reminderId;
  final String dateKey;

  final int weekday;
  final int hour;
  final int minute;

  final DateTime scheduledAt;
  final InsulinOccurrenceStatus status;
  final String? insulinEntryId;

  static String dateKeyFor(DateTime date) {
    final local = date.toLocal();

    return '${local.year.toString().padLeft(4, '0')}'
        '${local.month.toString().padLeft(2, '0')}'
        '${local.day.toString().padLeft(2, '0')}';
  }

  String get timeLabel {
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  factory InsulinOccurrence.fromReminder({
    required Reminder reminder,
    required DateTime date,
  }) {
    final local = date.toLocal();
    final dateKey = dateKeyFor(local);

    return InsulinOccurrence(
      id: '${reminder.id}_${dateKey}_${reminder.hour}_${reminder.minute}',
      reminderId: reminder.id,
      dateKey: dateKey,
      weekday: local.weekday,
      hour: reminder.hour,
      minute: reminder.minute,
      scheduledAt: DateTime(
        local.year,
        local.month,
        local.day,
        reminder.hour,
        reminder.minute,
      ),
    );
  }

  factory InsulinOccurrence.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    final status = switch (data['status']) {
      'completed' => InsulinOccurrenceStatus.completed,
      'skipped' => InsulinOccurrenceStatus.skipped,
      _ => throw const FormatException('Geçersiz uygulama durumu.'),
    };

    return InsulinOccurrence(
      id: document.id,
      reminderId: data['reminderId'] as String,
      dateKey: data['dateKey'] as String,
      weekday: data['weekday'] as int,
      hour: data['hour'] as int,
      minute: data['minute'] as int,
      scheduledAt: (data['scheduledAt'] as Timestamp).toDate(),
      status: status,
      insulinEntryId: data['insulinEntryId'] as String?,
    );
  }

  Map<String, dynamic> toData({
    required String status,
    required String? insulinEntryId,
  }) {
    return {
      'reminderId': reminderId,
      'dateKey': dateKey,
      'weekday': weekday,
      'hour': hour,
      'minute': minute,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'status': status,
      'insulinEntryId': insulinEntryId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
