import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Hesap açıldıktan sonra adın kaydedilip kaydedilemediğini döndürür.
  static Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );

    try {
      await credential.user!.updateDisplayName(name.trim());
      return true;
    } catch (_) {
      // Ad güncellenemese bile hesap oluşturulmuş durumdadır.
      return false;
    }
  }

  static Future<void> resetPassword(String email) async {
    await FirebaseAuth.instance.setLanguageCode('tr');
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
  }

  static Future<void> signOut() {
    return FirebaseAuth.instance.signOut();
  }

  static String errorMessage(Object error) {
    if (error is! FirebaseAuthException) {
      return 'İşlem tamamlanamadı. Lütfen tekrar deneyin.';
    }

    switch (error.code) {
      case 'invalid-email':
        return 'Geçerli bir e-posta adresi girin.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'E-posta adresi veya şifre hatalı.';
      case 'email-already-in-use':
        return 'Bu e-posta adresiyle bir hesap zaten var.';
      case 'weak-password':
        return 'Şifreniz güvenlik koşullarını karşılamıyor.';
      case 'network-request-failed':
        return 'İnternet bağlantınızı kontrol edip tekrar deneyin.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Bir süre sonra tekrar deneyin.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış.';
      case 'operation-not-allowed':
        return 'E-posta ve şifre ile giriş şu anda etkin değil.';
      default:
        return 'İşlem tamamlanamadı. Lütfen tekrar deneyin.';
    }
  }
}
