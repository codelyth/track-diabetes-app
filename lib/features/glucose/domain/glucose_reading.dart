import 'package:cloud_firestore/cloud_firestore.dart';

enum GlucoseType {
  fasting('fasting', 'Açlık'),
  postMeal('postMeal', 'Tokluk');

  const GlucoseType(this.code, this.label);

  final String code;
  final String label;

  static GlucoseType fromCode(String code) {
    return GlucoseType.values.firstWhere(
      (type) => type.code == code,
      orElse: () => throw FormatException('Bilinmeyen ölçüm türü: $code'),
    );
  }
}

class GlucoseReading {
  const GlucoseReading({
    required this.id,
    required this.valueMgDl,
    required this.type,
    required this.measuredAt,
    required this.note,
  });

  final String id;
  final int valueMgDl;
  final GlucoseType type;
  final DateTime measuredAt;
  final String note;

  factory GlucoseReading.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    return GlucoseReading(
      id: document.id,
      valueMgDl: data['valueMgDl'] as int,
      type: GlucoseType.fromCode(data['type'] as String),
      measuredAt: (data['measuredAt'] as Timestamp).toDate(),
      note: data['note'] as String,
    );
  }
}
