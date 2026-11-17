import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/insulin_occurrence.dart';

class InsulinPlanException implements Exception {
  const InsulinPlanException(this.message);

  final String message;

  @override
  String toString() => message;
}

class InsulinOccurrenceRepository {
  InsulinOccurrenceRepository({
    required this.userId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance {
    if (userId.trim().isEmpty) {
      throw ArgumentError('Kullanıcı kimliği boş olamaz.');
    }
  }

  final String userId;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _user {
    return _firestore.collection('users').doc(userId);
  }

  CollectionReference<Map<String, dynamic>> get _occurrences {
    return _user.collection('insulin_occurrences');
  }

  Stream<List<InsulinOccurrence>> watchDay(String dateKey) {
    return _occurrences
        .where('dateKey', isEqualTo: dateKey)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(InsulinOccurrence.fromDocument)
              .toList(growable: false),
        );
  }

  Future<void> _validatePlan(
    Transaction transaction,
    InsulinOccurrence occurrence,
  ) async {
    final document = await transaction.get(
      _user.collection('reminders').doc(occurrence.reminderId),
    );

    final data = document.data();

    if (!document.exists ||
        data == null ||
        data['type'] != 'insulin' ||
        data['isEnabled'] != true) {
      throw const InsulinPlanException(
        'Bu insülin hatırlatıcısı silinmiş veya kapatılmış.',
      );
    }

    final weekdays = List<int>.from(data['weekdays'] as List);

    if (data['hour'] != occurrence.hour ||
        data['minute'] != occurrence.minute ||
        !weekdays.contains(occurrence.weekday)) {
      throw const InsulinPlanException(
        'Hatırlatıcı değişmiş. Ekrana dönüp güncel planı açın.',
      );
    }

    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];

    if (createdAt is! Timestamp || updatedAt is! Timestamp) {
      throw const InsulinPlanException(
        'Hatırlatıcı henüz sunucuda doğrulanmadı.',
      );
    }

    if (createdAt.toDate().isAfter(occurrence.scheduledAt) ||
        updatedAt.toDate().isAfter(occurrence.scheduledAt)) {
      throw const InsulinPlanException(
        'Bu saatten sonra oluşturulan veya değiştirilen bir plan '
        'geriye dönük işaretlenemez.',
      );
    }

    if (occurrence.scheduledAt.isAfter(DateTime.now())) {
      throw const InsulinPlanException('Bu planın saati henüz gelmedi.');
    }

    final expectedId =
        '${occurrence.reminderId}_'
        '${occurrence.dateKey}_'
        '${occurrence.hour}_${occurrence.minute}';

    if (occurrence.id != expectedId) {
      throw const InsulinPlanException('Plan kimliği doğrulanamadı.');
    }
  }

  Future<void> complete({
    required InsulinOccurrence occurrence,
    required Map<String, dynamic> insulinData,
  }) async {
    final occurrenceRef = _occurrences.doc(occurrence.id);
    final entryRef = _user
        .collection('insulin_entries')
        .doc('planned_${occurrence.id}');

    await _firestore.runTransaction<void>((transaction) async {
      // Bütün okumalar yazmalardan önce yapılır.
      final existing = await transaction.get(occurrenceRef);
      final existingEntry = await transaction.get(entryRef);

      await _validatePlan(transaction, occurrence);

      if (existing.exists || existingEntry.exists) {
        throw const InsulinPlanException(
          'Bu plan için zaten bir işlem kaydedilmiş. '
          'Güncel durumu takip ekranından kontrol edin.',
        );
      }

      transaction.set(entryRef, {
        ...insulinData,
        'occurrenceId': occurrence.id,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(
        occurrenceRef,
        occurrence.toData(status: 'completed', insulinEntryId: entryRef.id),
      );
    });
  }

  Future<void> skip(InsulinOccurrence occurrence) async {
    final reference = _occurrences.doc(occurrence.id);

    await _firestore.runTransaction<void>((transaction) async {
      final existing = await transaction.get(reference);

      await _validatePlan(transaction, occurrence);

      if (existing.exists) {
        throw const InsulinPlanException(
          'Bu plan zaten işaretlenmiş. Güncel durumu kontrol edin.',
        );
      }

      transaction.set(
        reference,
        occurrence.toData(status: 'skipped', insulinEntryId: null),
      );
    });
  }

  Future<void> undoSkip(InsulinOccurrence occurrence) async {
    final reference = _occurrences.doc(occurrence.id);

    await _firestore.runTransaction<void>((transaction) async {
      final document = await transaction.get(reference);

      if (!document.exists) return;

      if (document.data()?['status'] != 'skipped') {
        throw const InsulinPlanException(
          'Bu planın durumu değişmiş. Ekranı kontrol edin.',
        );
      }

      transaction.delete(reference);
    });
  }
}
