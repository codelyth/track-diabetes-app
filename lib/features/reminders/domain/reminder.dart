import 'package:cloud_firestore/cloud_firestore.dart';

enum ReminderType {
  fasting('fasting', 'Açlık ölçümü'),
  postMeal('postMeal', 'Tokluk ölçümü'),
  insulin('insulin', 'İnsülin');

  const ReminderType(this.code, this.label);

  final String code;
  final String label;

  static ReminderType fromCode(String code) {
    return values.firstWhere(
      (type) => type.code == code,
      orElse: () => throw FormatException('Bilinmeyen hatırlatıcı türü: $code'),
    );
  }
}

class Reminder {
  Reminder({
    required this.id,
    required this.type,
    required this.hour,
    required this.minute,
    required List<int> weekdays,
    required this.note,
    required this.isEnabled,
  }) : weekdays = List.unmodifiable(weekdays);

  final String id;
  final ReminderType type;
  final int hour;
  final int minute;

  /// Pazartesi: 1, Salı: 2, ... Pazar: 7.
  final List<int> weekdays;

  final String note;
  final bool isEnabled;

  String get timeLabel {
    final hourText = hour.toString().padLeft(2, '0');
    final minuteText = minute.toString().padLeft(2, '0');

    return '$hourText:$minuteText';
  }

  String get repeatLabel {
    final daySet = weekdays.toSet();
    final sortedDays = daySet.toList()..sort();

    if (daySet.length == 7) {
      return 'Her gün';
    }

    if (daySet.length == 5 && daySet.containsAll([1, 2, 3, 4, 5])) {
      return 'Hafta içi';
    }

    if (daySet.length == 2 && daySet.containsAll([6, 7])) {
      return 'Hafta sonu';
    }

    const names = {
      1: 'Pzt',
      2: 'Sal',
      3: 'Çar',
      4: 'Per',
      5: 'Cum',
      6: 'Cmt',
      7: 'Paz',
    };

    return sortedDays.map((day) => names[day]!).join(', ');
  }

  factory Reminder.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    return Reminder(
      id: document.id,
      type: ReminderType.fromCode(data['type'] as String),
      hour: data['hour'] as int,
      minute: data['minute'] as int,
      weekdays: List<int>.from(data['weekdays'] as List),
      note: data['note'] as String,
      isEnabled: data['isEnabled'] as bool,
    );
  }
}
