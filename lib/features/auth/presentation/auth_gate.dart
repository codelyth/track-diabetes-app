import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<User?> _userStream;

  @override
  void initState() {
    super.initState();
    _userStream = FirebaseAuth.instance.userChanges();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _userStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('Oturum bilgisi alınamadı. Uygulamayı yeniden açın.'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginScreen();
        }

        return _AccountScreen(user: user);
      },
    );
  }
}

// Dashboard tamamlanana kadar kullanılacak geçici ekran.
class _AccountScreen extends StatefulWidget {
  const _AccountScreen({required this.user});

  final User user;

  @override
  State<_AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<_AccountScreen> {
  bool _isLoading = false;

  Future<void> _signOut() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await AuthService.signOut();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AuthService.errorMessage(error))));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user.displayName?.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Şeker Takibi')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    name == null || name.isEmpty
                        ? 'Hoş Geldiniz'
                        : 'Hoş Geldiniz, $name',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(widget.user.email ?? '', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  const Text(
                    'Oturumunuz açık. Özet ekranını sonraki adımda ekleyeceğiz.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _signOut,
                    icon: const Icon(Icons.logout),
                    label: Text(
                      _isLoading ? 'Çıkış yapılıyor...' : 'Çıkış Yap',
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
