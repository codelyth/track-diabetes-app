import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/notifications/notification_service.dart';
import '../../home/data/home_widget_service.dart';
import '../../reminders/data/reminder_scheduler.dart';

class AccountDeletionService {
  AccountDeletionService._();

  static final AccountDeletionService instance = AccountDeletionService._();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final ValueNotifier<bool> running = ValueNotifier(false);
  final ValueNotifier<String> progress = ValueNotifier('');

  DocumentReference<Map<String, dynamic>> marker(String userId) {
    return _firestore.collection('account_deletions').doc(userId);
  }

  User _requireUser(String userId) {
    final user = _auth.currentUser;

    if (user == null || user.uid != userId) {
      throw StateError('Oturum değişti.');
    }

    return user;
  }

  Future<void> _reauthenticate(String userId, String password) async {
    final user = _requireUser(userId);
    final email = user.email;

    final usesPassword = user.providerData.any(
      (provider) => provider.providerId == 'password',
    );

    if (email == null || !usesPassword) {
      throw UnsupportedError(
        'Bu hesap e-posta ve şifre ile giriş kullanmıyor.',
      );
    }

    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );

    _requireUser(userId);

    // Firestore kuralları güncel auth_time bilgisini görsün.
    await user.getIdToken(true);

    _requireUser(userId);
  }

  Future<void> freezeLocalData(String userId) async {
    _requireUser(userId);

    await ReminderScheduler.instance.stopSession();

    _requireUser(userId);

    NotificationService.instance.clearPendingPayload();

    await HomeWidgetService.instance.suspendAndClear();

    _requireUser(userId);
  }

  Future<void> deleteAccount({
    required String userId,
    required String password,
  }) async {
    if (running.value) {
      throw StateError('Bir silme işlemi zaten çalışıyor.');
    }

    running.value = true;

    try {
      progress.value = 'Şifreniz doğrulanıyor…';

      await _reauthenticate(userId, password);

      progress.value = 'Hesap silme işlemi başlatılıyor…';

      final markerRef = marker(userId);

      await _firestore.runTransaction<void>((transaction) async {
        _requireUser(userId);

        final document = await transaction.get(markerRef);

        if (!document.exists) {
          transaction.set(markerRef, {
            'version': 1,
            'requestedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      _requireUser(userId);

      progress.value = 'Bildirimler ve widget temizleniyor…';

      await freezeLocalData(userId);

      const collections = <String, String>{
        'reminders': 'Hatırlatıcılar',
        'glucose_readings': 'Şeker Ölçümleri',
        'hba1c_results': 'HbA1c Sonuçları',
        'insulin_entries': 'İnsülin Kayıtları',
        'insulin_occurrences': 'İnsülin Takip Durumları',
      };

      for (final entry in collections.entries) {
        progress.value = '${entry.value} siliniyor…';

        await _deleteCollection(userId: userId, collectionName: entry.key);
      }

      // Kilit yeni yazmaları engelliyor. Hesabı silmeden önce
      // dört koleksiyonun da sunucuda boş olduğunu doğrula.
      progress.value = 'Kayıtların temizlendiği doğrulanıyor…';

      for (final collectionName in collections.keys) {
        _requireUser(userId);

        final remaining = await _firestore
            .collection('users')
            .doc(userId)
            .collection(collectionName)
            .limit(1)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 15));

        _requireUser(userId);

        if (remaining.docs.isNotEmpty) {
          throw StateError('Henüz silinmemiş kayıtlar var.');
        }
      }

      // Çok kayıt varsa işlem uzamış olabilir.
      // Authentication hesabını silmeden önce yeniden doğrula.
      progress.value = 'Giriş hesabınız siliniyor…';

      await _reauthenticate(userId, password);

      await _requireUser(userId).delete();

      progress.value = 'Hesabınız silindi.';
    } finally {
      running.value = false;
    }
  }

  Future<void> _deleteCollection({
    required String userId,
    required String collectionName,
  }) async {
    final collection = _firestore
        .collection('users')
        .doc(userId)
        .collection(collectionName);

    while (true) {
      _requireUser(userId);

      final snapshot = await collection
          .limit(100)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));

      _requireUser(userId);

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();

      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }

      // Sunucu onayı alınmadan sonraki gruba geçilmez.
      await batch.commit();

      _requireUser(userId);
    }
  }

  static String errorMessage(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'wrong-password' ||
        'invalid-credential' ||
        'invalid-login-credentials' =>
          'Şifreniz doğrulanamadı. Kontrol edip tekrar deneyin.',
        'network-request-failed' => 'İnternet bağlantısı kurulamadı.',
        'too-many-requests' =>
          'Çok fazla deneme yapıldı. Bir süre sonra tekrar deneyin.',
        'requires-recent-login' =>
          'Şifrenizi tekrar girerek işlemi yeniden deneyin.',
        'user-disabled' || 'user-token-expired' || 'invalid-user-token' =>
          'Oturumunuz doğrulanamadı. Çıkış yapıp tekrar giriş yapın.',
        _ => 'Hesap silme işlemi tamamlanamadı.',
      };
    }

    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Silme yetkisi doğrulanamadı. Firestore kurallarının '
              'yayımlandığını kontrol edin.',
        'resource-exhausted' =>
          'Firebase işlem kotasına ulaşıldı. Daha sonra tekrar deneyin.',
        'unavailable' || 'deadline-exceeded' =>
          'Sunucuya ulaşılamadı. Bağlantınızı kontrol edin.',
        _ => 'Kayıtlar temizlenemedi. Tekrar deneyin.',
      };
    }

    if (error is UnsupportedError) {
      return 'Bu giriş yöntemi için hesap silme desteklenmiyor.';
    }

    if (error is StateError) {
      return 'Oturum veya silme durumu değişti. '
          'Çıkış yapıp tekrar giriş yaparak devam edin.';
    }

    return 'İşlem tamamlanamadı. Bağlantınızı kontrol edip tekrar deneyin.';
  }
}
