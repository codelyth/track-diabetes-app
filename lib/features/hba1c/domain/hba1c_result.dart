import 'package:cloud_firestore/cloud_firestore.dart';

class Hba1cResult {
  const Hba1cResult({
    required this.id,
    required this.valuePercent,
    required this.testDate,
    required this.note,
  });

  final String id;
  final double valuePercent;
  final DateTime testDate;
  final String note;

  factory Hba1cResult.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    return Hba1cResult(
      id: document.id,
      valuePercent: (data['valuePercent'] as num).toDouble(),
      testDate: (data['testDate'] as Timestamp).toDate(),
      note: data['note'] as String,
    );
  }
}
