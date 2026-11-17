import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class UpdateAccountScreen extends StatefulWidget {
  const UpdateAccountScreen({
    super.key,
    required this.userId,
    required this.changePassword,
  });

  final String userId;
  final bool changePassword;

  @override
  State<UpdateAccountScreen> createState() => _UpdateAccountScreenState();
}

class _UpdateAccountScreenState extends State<UpdateAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _saving = false;
  bool _showPasswords = false;

  String? _error;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    if (user?.uid == widget.userId) {
      _nameController.text = user?.displayName ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  User _requireCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.uid != widget.userId) {
      throw StateError('Oturum değişti.');
    }

    return user;
  }

  String _authErrorMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'wrong-password' ||
      'invalid-credential' ||
      'invalid-login-credentials' => 'Mevcut şifreniz doğrulanamadı.',
      'weak-password' || 'password-does-not-meet-requirements' =>
        'Yeni şifre güvenlik koşullarını karşılamıyor. '
            'Daha güçlü bir şifre deneyin.',
      'network-request-failed' =>
        'Bağlantı kurulamadı. İnternetinizi kontrol edin.',
      'too-many-requests' =>
        'Çok fazla deneme yapıldı. Bir süre sonra tekrar deneyin.',
      'requires-recent-login' || 'user-token-expired' || 'invalid-user-token' =>
        'Oturumunuzu yenilemek için çıkış yapıp tekrar giriş yapın.',
      'user-disabled' => 'Bu hesap devre dışı bırakılmış.',
      _ => 'İşlem tamamlanamadı. Tekrar deneyin.',
    };
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final user = _requireCurrentUser();

      if (widget.changePassword) {
        final email = user.email;

        final usesPassword = user.providerData.any(
          (provider) => provider.providerId == 'password',
        );

        if (email == null || !usesPassword) {
          throw UnsupportedError(
            'Bu hesap e-posta ve şifre ile giriş kullanmıyor.',
          );
        }

        final credential = EmailAuthProvider.credential(
          email: email,
          password: _currentPasswordController.text,
        );

        await user.reauthenticateWithCredential(credential);

        if (!mounted) return;

        final currentUser = _requireCurrentUser();

        await currentUser.updatePassword(_newPasswordController.text);
      } else {
        await user.updateDisplayName(_nameController.text.trim());
      }

      if (!mounted) return;

      _requireCurrentUser();

      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() => _error = _authErrorMessage(error));
      }
    } on UnsupportedError {
      if (mounted) {
        setState(() {
          _error = 'Bu hesap için şifre değiştirme desteklenmiyor.';
        });
      }
    } on StateError {
      if (mounted) {
        setState(() {
          _error = 'Oturumunuz değişti. Bu ekranı kapatıp tekrar açın.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'İşlem tamamlanamadı. Tekrar deneyin.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    TextInputAction action = TextInputAction.next,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_saving,
      obscureText: !_showPasswords,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: action,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        helperMaxLines: 2,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _showPasswords ? 'Şifreleri gizle' : 'Şifreleri göster',
          onPressed: _saving
              ? null
              : () {
                  setState(() => _showPasswords = !_showPasswords);
                },
          icon: Icon(
            _showPasswords
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
      validator: validator,
      onFieldSubmitted: action == TextInputAction.done ? (_) => _save() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final changingPassword = widget.changePassword;

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(changingPassword ? 'Şifre değiştir' : 'Profili düzenle'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        changingPassword
                            ? 'Yeni şifrenizi belirleyin'
                            : 'Profil bilgilerinizi güncelleyin',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        changingPassword
                            ? 'Güvenliğiniz için önce mevcut '
                                  'şifrenizi doğrulayacağız.'
                            : 'Adınız uygulamadaki profil '
                                  'bilgilerinize yansır.',
                        style: const TextStyle(
                          color: AppColors.muted,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (!changingPassword)
                        TextFormField(
                          controller: _nameController,
                          enabled: !_saving,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.name],
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Ad soyad',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            final name = value?.trim() ?? '';

                            if (name.isEmpty) {
                              return 'Adınızı ve soyadınızı girin.';
                            }

                            if (name.length > 100) {
                              return 'En fazla 100 karakter girin.';
                            }

                            return null;
                          },
                          onFieldSubmitted: (_) => _save(),
                        )
                      else ...[
                        _passwordField(
                          controller: _currentPasswordController,
                          label: 'Mevcut şifre',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Mevcut şifrenizi girin.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        _passwordField(
                          controller: _newPasswordController,
                          label: 'Yeni şifre',
                          helperText:
                              'En az 8 karakter, bir büyük harf ve bir rakam.',
                          validator: (value) {
                            final password = value ?? '';

                            if (password.length < 8) {
                              return 'En az 8 karakter kullanın.';
                            }

                            if (!RegExp(r'[A-ZÇĞİÖŞÜ]').hasMatch(password)) {
                              return 'En az bir büyük harf kullanın.';
                            }

                            if (!RegExp(r'[0-9]').hasMatch(password)) {
                              return 'En az bir rakam kullanın.';
                            }

                            if (password == _currentPasswordController.text) {
                              return 'Yeni şifre mevcut şifreden '
                                  'farklı olmalı.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        _passwordField(
                          controller: _confirmPasswordController,
                          label: 'Yeni şifre tekrar',
                          action: TextInputAction.done,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Yeni şifrenizi tekrar girin.';
                            }

                            if (value != _newPasswordController.text) {
                              return 'Şifreler eşleşmiyor.';
                            }

                            return null;
                          },
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 18),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
