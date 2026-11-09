import 'package:cloud_firestore/cloud_firestore.dart';

enum InsulinKind {
  bolus('bolus', 'Bolus'),
  basal('basal', 'Bazal'),
  other('other', 'Diğer');

  const InsulinKind(this.code, this.label);

  final String code;
  final String label;

  static InsulinKind fromCode(String code) {
    return InsulinKind.values.firstWhere(
      (kind) => kind.code == code,
      orElse: () => throw FormatException('Bilinmeyen insülin türü: $code'),
    );
  }
}

class InsulinEntry {
  const InsulinEntry({
    required this.id,
    required this.insulinName,
    required this.kind,
    required this.doseUnits,
    required this.administeredAt,
    required this.note,
  });

  final String id;
  final String insulinName;
  final InsulinKind kind;
  final double doseUnits;
  final DateTime administeredAt;
  final String note;

  factory InsulinEntry.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    return InsulinEntry(
      id: document.id,
      insulinName: data['insulinName'] as String,
      kind: InsulinKind.fromCode(data['kind'] as String),
      doseUnits: (data['doseUnits'] as num).toDouble(),
      administeredAt: (data['administeredAt'] as Timestamp).toDate(),
      note: data['note'] as String,
    );
  }
}
