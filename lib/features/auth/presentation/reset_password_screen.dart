import 'package:flutter/material.dart';

import '../data/auth_service.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_theme.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _requestCompleted = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading || _requestCompleted) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AuthService.resetPassword(_emailController.text);

      if (!mounted) return;

      setState(() => _requestCompleted = true);
    } catch (error) {
      if (!mounted) return;

      // Hesabın var olup olmadığını açıklamayan ortak sonuç.
      if (error is FirebaseAuthException && error.code == 'user-not-found') {
        setState(() => _requestCompleted = true);
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(AuthService.errorMessage(error))),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Şifre Sıfırlama'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        color: AppColors.lavender,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_reset_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Şifrenizi mi unuttunuz?',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Hesabınıza ait e-posta adresini girin. '
                    'Şifrenizi yenilemek için bir sıfırlama '
                    'bağlantısı isteyebilirsiniz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'E-posta Adresi',
                              style: textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              autocorrect: false,
                              enableSuggestions: false,
                              autofillHints: const [AutofillHints.email],
                              onFieldSubmitted: (_) => _submit(),
                              enabled: !_isLoading && !_requestCompleted,
                              decoration: const InputDecoration(
                                hintText: 'ornek@eposta.com',
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                              validator: (value) {
                                final email = value?.trim() ?? '';

                                if (email.isEmpty) {
                                  return 'E-posta adresinizi girin.';
                                }

                                if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                    .hasMatch(email)) {
                                  return 'Geçerli bir e-posta adresi girin.';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _isLoading || _requestCompleted
                                  ? null
                                  : _submit,
                              icon: Icon(
                                _requestCompleted
                                    ? Icons.mark_email_read_outlined
                                    : Icons.send_outlined,
                              ),
                              label: Text(
                                _isLoading
                                    ? 'Gönderiliyor...'
                                    : _requestCompleted
                                    ? 'İstek tamamlandı'
                                    : 'Sıfırlama bağlantısı gönder',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            if (_requestCompleted) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Bu adresle kayıtlı bir hesap varsa sıfırlama e-postası '
                                'gönderilir. Gelen kutunuzu ve spam klasörünü kontrol edin.',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  height: 1.5,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() => _requestCompleted = false);
                                },
                                child: const Text('Başka bir adres kullan'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.field,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primary),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Şifrenizi e-posta ile gelen bağlantıdan '
                            'yenileyebilirsiniz. Şifrenizi '
                            'kimseyle paylaşmayın.',
                            style: TextStyle(
                              color: AppColors.muted,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Giriş Ekranına Dön'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
