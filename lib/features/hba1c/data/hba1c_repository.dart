import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/hba1c_result.dart';

class Hba1cRepository {
  Hba1cRepository({required this.userId, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance {
    if (userId.trim().isEmpty) {
      throw ArgumentError('Kullanıcı kimliği boş olamaz.');
    }
  }

  final String userId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _results {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('hba1c_results');
  }

  Stream<List<Hba1cResult>> watchResults() {
    return _results
        .orderBy('testDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(Hba1cResult.fromDocument)
              .toList(growable: false),
        );
  }

  Future<void> addResult({
    required double valuePercent,
    required DateTime testDate,
    String note = '',
  }) async {
    _validate(valuePercent, note);

    await _results.add({
      'valuePercent': valuePercent,
      'testDate': Timestamp.fromDate(testDate),
      'note': note.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateResult({
    required String id,
    required double valuePercent,
    required DateTime testDate,
    String note = '',
  }) async {
    _validate(valuePercent, note);

    await _results.doc(id).update({
      'valuePercent': valuePercent,
      'testDate': Timestamp.fromDate(testDate),
      'note': note.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteResult(String id) {
    return _results.doc(id).delete();
  }

  void _validate(double valuePercent, String note) {
    if (!valuePercent.isFinite || valuePercent <= 0 || valuePercent > 100) {
      throw ArgumentError(
        'Sonuç, sıfırdan büyük ve en fazla 100 olan bir yüzde olmalı.',
      );
    }

    if (note.trim().length > 1000) {
      throw ArgumentError('Not en fazla 1000 karakter olabilir.');
    }
  }
}
