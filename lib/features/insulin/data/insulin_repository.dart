import 'package:cloud_firestore/cloud_firestore.dart';

import '../../reminders/data/insulin_occurrence_repository.dart';
import '../../reminders/domain/insulin_occurrence.dart';
import '../domain/insulin_entry.dart';

class InsulinRepository {
  InsulinRepository({required this.userId, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance {
    if (userId.trim().isEmpty) {
      throw ArgumentError('Kullanıcı kimliği boş olamaz.');
    }
  }

  final String userId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _entries {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('insulin_entries');
  }

  Stream<List<InsulinEntry>> watchEntries() {
    return _entries
        .orderBy('administeredAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(InsulinEntry.fromDocument)
              .toList(growable: false),
        );
  }

  Future<void> addEntry({
    required String insulinName,
    required InsulinKind kind,
    required double doseUnits,
    required DateTime administeredAt,
    String note = '',
    InsulinOccurrence? occurrence,
  }) async {
    _validate(
      insulinName: insulinName,
      doseUnits: doseUnits,
      administeredAt: administeredAt,
      note: note,
    );

    final data = <String, dynamic>{
      'insulinName': insulinName.trim(),
      'kind': kind.code,
      'doseUnits': doseUnits,
      'administeredAt': Timestamp.fromDate(administeredAt),
      'note': note.trim(),
    };

    if (occurrence != null) {
      await InsulinOccurrenceRepository(
        userId: userId,
        firestore: _firestore,
      ).complete(occurrence: occurrence, insulinData: data);

      return;
    }

    await _entries.add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateEntry({
    required String id,
    required String insulinName,
    required InsulinKind kind,
    required double doseUnits,
    required DateTime administeredAt,
    String note = '',
  }) async {
    _validate(
      insulinName: insulinName,
      doseUnits: doseUnits,
      administeredAt: administeredAt,
      note: note,
    );

    // Varsa occurrenceId alanı korunur.
    await _entries.doc(id).update({
      'insulinName': insulinName.trim(),
      'kind': kind.code,
      'doseUnits': doseUnits,
      'administeredAt': Timestamp.fromDate(administeredAt),
      'note': note.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteEntry(String id) async {
    final reference = _entries.doc(id);

    await _firestore.runTransaction<void>((transaction) async {
      final entry = await transaction.get(reference);

      if (!entry.exists) return;

      final occurrenceId = entry.data()?['occurrenceId'];

      DocumentReference<Map<String, dynamic>>? occurrenceRef;

      if (occurrenceId is String) {
        occurrenceRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('insulin_occurrences')
            .doc(occurrenceId);

        final occurrence = await transaction.get(occurrenceRef);

        if (occurrence.exists) {
          final data = occurrence.data();

          if (data?['status'] != 'completed' || data?['insulinEntryId'] != id) {
            throw const InsulinPlanException(
              'Bağlı plan doğrulanamadı. Ekranı yenileyin.',
            );
          }
        }
      }

      if (occurrenceRef != null) {
        transaction.delete(occurrenceRef);
      }

      transaction.delete(reference);
    });
  }

  void _validate({
    required String insulinName,
    required double doseUnits,
    required DateTime administeredAt,
    required String note,
  }) {
    if (insulinName.trim().isEmpty || insulinName.trim().length > 100) {
      throw ArgumentError('İnsülin adı 1–100 karakter olmalı.');
    }

    if (!doseUnits.isFinite || doseUnits <= 0) {
      throw ArgumentError('Uygulanan miktar sıfırdan büyük olmalı.');
    }

    if (administeredAt.isAfter(DateTime.now())) {
      throw ArgumentError('Uygulama zamanı gelecekte olamaz.');
    }

    if (note.trim().length > 1000) {
      throw ArgumentError('Not en fazla 1000 karakter olabilir.');
    }
  }
}
