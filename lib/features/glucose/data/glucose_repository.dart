import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/glucose_reading.dart';

class GlucoseRepository {
  GlucoseRepository({required this.userId, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance {
    if (userId.trim().isEmpty) {
      throw ArgumentError('Kullanıcı kimliği boş olamaz.');
    }
  }

  final String userId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _readings {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('glucose_readings');
  }

  Stream<List<GlucoseReading>> watchReadings() {
    return _readings
        .orderBy('measuredAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(GlucoseReading.fromDocument)
              .toList(growable: false),
        );
  }

  Future<void> addReading({
    required int valueMgDl,
    required GlucoseType type,
    required DateTime measuredAt,
    String note = '',
  }) async {
    _validate(valueMgDl, note);

    await _readings.add({
      'valueMgDl': valueMgDl,
      'type': type.code,
      'measuredAt': Timestamp.fromDate(measuredAt),
      'note': note.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateReading({
    required String id,
    required int valueMgDl,
    required GlucoseType type,
    required DateTime measuredAt,
    String note = '',
  }) async {
    _validate(valueMgDl, note);

    await _readings.doc(id).update({
      'valueMgDl': valueMgDl,
      'type': type.code,
      'measuredAt': Timestamp.fromDate(measuredAt),
      'note': note.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteReading(String id) {
    return _readings.doc(id).delete();
  }

  void _validate(int valueMgDl, String note) {
    if (valueMgDl <= 0) {
      throw ArgumentError('Ölçüm değeri pozitif bir sayı olmalı.');
    }

    if (note.trim().length > 1000) {
      throw ArgumentError('Not en fazla 1000 karakter olabilir.');
    }
  }
}
