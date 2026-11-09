import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../../../core/theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  bool _hidePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final nameSaved = await AuthService.register(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              nameSaved
                  ? 'Hesabınız oluşturuldu.'
                  : 'Hesabınız oluşturuldu ancak adınız kaydedilemedi.',
            ),
          ),
        );

      // Kayıt ekranını kapatır; AuthGate açık oturumu gösterecek.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(AuthService.errorMessage(error))),
        );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Hesap Oluştur'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.lavender,
                        child: Icon(
                          Icons.water_drop_outlined,
                          color: AppColors.primary,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Takibe İlk Adımı Atın',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppColors.text,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ölçümlerinizi ve kayıtlarınızı tek yerde toplayın.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, height: 1.5),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _label('Ad Soyad'),
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              decoration: const InputDecoration(
                                hintText: 'Adınız ve Soyadınız',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Adınızı ve soyadınızı girin.';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _label('E-posta Adresi'),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              enableSuggestions: false,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                hintText: 'ornek@eposta.com',
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                              validator: (value) {
                                final email = value?.trim() ?? '';

                                if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                    .hasMatch(email)) {
                                  return 'Geçerli bir e-posta adresi girin.';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _label('Şifre'),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _hidePassword,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              enableSuggestions: false,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: InputDecoration(
                                hintText: 'Şifre Oluşturun',
                                helperText: 'En az 8 karakter, bir büyük harf ve bir rakam.',
                                helperMaxLines: 2,
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _hidePassword
                                      ? 'Şifreyi Göster'
                                      : 'Şifreyi Gizle',
                                  onPressed: () {
                                    setState(() {
                                      _hidePassword = !_hidePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _hidePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                final password = value ?? '';

                                if (password.length < 8) {
                                  return 'Şifre en az 8 karakter olmalı.';
                                }

                                if (!RegExp(r'[A-ZÇĞİÖŞÜ]')
                                    .hasMatch(password)) {
                                  return 'En az bir büyük harf ekleyin.';
                                }

                                if (!RegExp(r'[0-9]').hasMatch(password)) {
                                  return 'En az bir rakam ekleyin.';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _label('Şifre Tekrarı'),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _hidePassword,
                              textInputAction: TextInputAction.done,
                              autocorrect: false,
                              enableSuggestions: false,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                hintText: 'Şifrenizi Tekrar Girin',
                                prefixIcon: Icon(Icons.lock_reset),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Şifrenizi tekrar girin.';
                                }

                                if (value != _passwordController.text) {
                                  return 'Şifreler Eşleşmiyor.';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 28),
                            FilledButton.icon(
                              onPressed: _isLoading ? null : _submit,
                              icon: const Icon(Icons.person_add_outlined),
                              label: Text(
                                _isLoading
                                    ? 'Hesap oluşturuluyor...'
                                    : 'Hesap oluştur',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('Zaten hesabınız var mı?'),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Giriş Yapın'),
                          ),
                        ],
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
