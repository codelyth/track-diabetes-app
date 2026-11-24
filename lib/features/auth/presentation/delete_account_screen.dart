import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/account_deletion_service.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({
    super.key,
    required this.userId,
    this.resuming = false,
  });

  final String userId;
  final bool resuming;

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _service = AccountDeletionService.instance;
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  bool _confirmed = false;
  bool _showPassword = false;
  bool _preparing = false;
  bool _submitting = false;

  String? _error;

  @override
  void initState() {
    super.initState();

    if (widget.resuming) {
      _confirmed = true;
      _preparing = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_prepareRecovery());
        }
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _prepareRecovery() async {
    try {
      // İlk ekrandaki silme işlemi zaten çalışıyorsa
      // yerel temizliği ikinci kez başlatma.
      if (!_service.running.value) {
        await _service.freezeLocalData(widget.userId);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = AccountDeletionService.errorMessage(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _preparing = false);
      }
    }
  }

  Future<void> _delete() async {
    if (_submitting || _preparing || _service.running.value) return;
    if (!_formKey.currentState!.validate()) return;

    if (!_confirmed) {
      setState(() {
        _error = 'Devam etmek için silme onayını işaretleyin.';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    final password = _passwordController.text;
    _passwordController.clear();

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _service.deleteAccount(userId: widget.userId, password: password);

      if (!mounted) return;

      // AuthGate giriş ekranını gösterir.
      // Üstte açık kalmış form rotalarını kapat.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = AccountDeletionService.errorMessage(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _signOut() async {
    if (_submitting || _preparing || _service.running.value) return;

    setState(() {
      _preparing = true;
      _error = null;
    });

    try {
      await _service.freezeLocalData(widget.userId);

      if (FirebaseAuth.instance.currentUser?.uid != widget.userId) {
        throw StateError('Oturum değişti.');
      }

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = AccountDeletionService.errorMessage(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _preparing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _service.running,
      builder: (context, running, _) {
        final busy = running || _submitting || _preparing;

        return PopScope(
          canPop: !busy && !widget.resuming,
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: !busy && !widget.resuming,
              title: Text(
                widget.resuming ? 'Hesap Silmeyi Tamamla' : 'Hesabımı Sil',
              ),
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
                          Icon(
                            Icons.delete_forever_outlined,
                            size: 56,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            widget.resuming
                                ? 'Hesap silme işleminiz bekliyor.'
                                : 'Bu işlem geri alınamaz',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            widget.resuming
                                ? 'Daha önce başlattığınız silme işlemi '
                                      'henüz tamamlanmadı. Silinen kayıtlar '
                                      'geri getirilemez. Kalan kayıtları ve '
                                      'hesabınızı silmek için şifrenizi girin.'
                                : 'Şeker ölçümleriniz, HbA1c sonuçlarınız, '
                                      'insülin kayıtlarınız, hatırlatıcılarınız '
                                      've giriş hesabınız silinecek.',
                            style: const TextStyle(
                              color: AppColors.muted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'İşlem boyunca internet bağlantınızı ve '
                            'uygulamayı açık tutun. Kesinti olursa '
                            'tekrar giriş yaparak devam edebilirsiniz.',
                            style: TextStyle(
                              color: AppColors.muted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _passwordController,
                            enabled: !busy,
                            obscureText: !_showPassword,
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: 'Mevcut Şifreniz',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: busy
                                    ? null
                                    : () {
                                        setState(() {
                                          _showPassword = !_showPassword;
                                        });
                                      },
                                tooltip: _showPassword
                                    ? 'Şifreyi Gizle'
                                    : 'Şifreyi Göster',
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Şifrenizi girin.';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _delete(),
                          ),
                          if (!widget.resuming) ...[
                            const SizedBox(height: 16),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: _confirmed,
                              onChanged: busy
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _confirmed = value ?? false;
                                      });
                                    },
                              title: const Text(
                                'Kayıtlarımın ve hesabımın kalıcı olarak '
                                'silinmesini onaylıyorum.',
                              ),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                          if (busy) ...[
                            const SizedBox(height: 20),
                            const LinearProgressIndicator(),
                            const SizedBox(height: 10),
                            ValueListenableBuilder<String>(
                              valueListenable: _service.progress,
                              builder: (context, message, _) {
                                return Text(
                                  message.isEmpty
                                      ? 'İşlem hazırlanıyor…'
                                      : message,
                                  textAlign: TextAlign.center,
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .error,
                              foregroundColor: Theme.of(context)
                                  .colorScheme
                                  .onError,
                            ),
                            onPressed: busy ? null : _delete,
                            icon: const Icon(Icons.delete_forever),
                            label: Text(
                              widget.resuming
                                  ? 'Silmeyi Tamamla'
                                  : 'Hesabımı Kalıcı Olarak Sil',
                            ),
                          ),
                          if (widget.resuming)
                            TextButton(
                              onPressed: busy ? null : _signOut,
                              child: const Text('Şimdilik Çıkış Yap'),
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
      },
    );
  }
}
