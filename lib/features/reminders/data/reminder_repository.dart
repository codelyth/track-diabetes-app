import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/reminder.dart';

class ReminderRepository {
  ReminderRepository({required String userId, FirebaseFirestore? firestore})
    : _collection = (firestore ?? FirebaseFirestore.instance)
          .collection('users')
          .doc(userId)
          .collection('reminders') {
    if (userId.trim().isEmpty) {
      throw ArgumentError('Kullanıcı kimliği boş olamaz.');
    }
  }

  final CollectionReference<Map<String, dynamic>> _collection;

  Stream<List<Reminder>> watchReminders() {
    return _collection.snapshots().map((snapshot) {
      final reminders = snapshot.docs.map(Reminder.fromDocument).toList();

      reminders.sort((first, second) {
        final firstMinutes = first.hour * 60 + first.minute;
        final secondMinutes = second.hour * 60 + second.minute;

        final timeComparison = firstMinutes.compareTo(secondMinutes);

        if (timeComparison != 0) {
          return timeComparison;
        }

        final typeComparison = first.type.index.compareTo(second.type.index);

        if (typeComparison != 0) {
          return typeComparison;
        }

        return first.id.compareTo(second.id);
      });

      return reminders;
    });
  }

  Future<String> addReminder({
    required ReminderType type,
    required int hour,
    required int minute,
    required List<int> weekdays,
    required String note,
    required bool isEnabled,
  }) async {
    final data = _validatedData(
      type: type,
      hour: hour,
      minute: minute,
      weekdays: weekdays,
      note: note,
      isEnabled: isEnabled,
    );

    final document = _collection.doc();

    await document.set({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return document.id;
  }

  Future<void> updateReminder({
    required String reminderId,
    required ReminderType type,
    required int hour,
    required int minute,
    required List<int> weekdays,
    required String note,
    required bool isEnabled,
  }) async {
    final data = _validatedData(
      type: type,
      hour: hour,
      minute: minute,
      weekdays: weekdays,
      note: note,
      isEnabled: isEnabled,
    );

    await _collection.doc(reminderId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setEnabled({
    required String reminderId,
    required bool isEnabled,
  }) {
    return _collection.doc(reminderId).update({
      'isEnabled': isEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteReminder(String reminderId) {
    return _collection.doc(reminderId).delete();
  }

  Map<String, dynamic> _validatedData({
    required ReminderType type,
    required int hour,
    required int minute,
    required List<int> weekdays,
    required String note,
    required bool isEnabled,
  }) {
    if (hour < 0 || hour > 23) {
      throw ArgumentError('Saat 0–23 arasında olmalıdır.');
    }

    if (minute < 0 || minute > 59) {
      throw ArgumentError('Dakika 0–59 arasında olmalıdır.');
    }

    if (weekdays.isEmpty || weekdays.any((day) => day < 1 || day > 7)) {
      throw ArgumentError('En az bir geçerli tekrar günü seçin.');
    }

    final normalizedDays = weekdays.toSet().toList()..sort();
    final normalizedNote = note.trim();

    if (normalizedNote.length > 200) {
      throw ArgumentError('Açıklama en fazla 200 karakter olabilir.');
    }

    return {
      'type': type.code,
      'hour': hour,
      'minute': minute,
      'weekdays': normalizedDays,
      'note': normalizedNote,
      'isEnabled': isEnabled,
    };
  }
}
