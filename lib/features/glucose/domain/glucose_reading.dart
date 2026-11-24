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

enum GlucoseSeverity { target, caution, alert }

enum GlucoseLevel {
  veryLow('veryLow', 'Çok düşük'),
  low('low', 'Düşük'),
  belowTarget('belowTarget', 'Hedefin altında'),
  inTarget('inTarget', 'Hedef aralıkta'),
  high('high', 'Yüksek'),
  veryHigh('veryHigh', 'Çok yüksek');

  const GlucoseLevel(this.code, this.label);

  final String code;
  final String label;

  GlucoseSeverity get severity {
    return switch (this) {
      GlucoseLevel.inTarget => GlucoseSeverity.target,
      GlucoseLevel.belowTarget || GlucoseLevel.high => GlucoseSeverity.caution,
      GlucoseLevel.veryLow ||
      GlucoseLevel.low ||
      GlucoseLevel.veryHigh => GlucoseSeverity.alert,
    };
  }

  static GlucoseLevel evaluate({
    required int valueMgDl,
    required GlucoseType type,
  }) {
    if (valueMgDl <= 0) {
      throw ArgumentError.value(
        valueMgDl,
        'valueMgDl',
        'Ölçüm değeri pozitif olmalıdır.',
      );
    }

    if (valueMgDl < 54) return GlucoseLevel.veryLow;
    if (valueMgDl < 70) return GlucoseLevel.low;
    if (valueMgDl > 250) return GlucoseLevel.veryHigh;

    return switch (type) {
      GlucoseType.fasting =>
        valueMgDl < 80
            ? GlucoseLevel.belowTarget
            : valueMgDl <= 130
            ? GlucoseLevel.inTarget
            : GlucoseLevel.high,
      GlucoseType.postMeal =>
        valueMgDl < 180 ? GlucoseLevel.inTarget : GlucoseLevel.high,
    };
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

  GlucoseLevel get level {
    return GlucoseLevel.evaluate(valueMgDl: valueMgDl, type: type);
  }

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
