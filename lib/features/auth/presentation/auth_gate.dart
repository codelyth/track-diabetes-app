import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../home/presentation/main_screen.dart';
import '../data/account_deletion_service.dart';
import 'delete_account_screen.dart';
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
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Oturum bilgisi alınamadı. '
                    'Lütfen uygulamayı yeniden açın.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
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

        return _AccountAccessGate(
          key: ValueKey('account-access-${user.uid}'),
          userId: user.uid,
        );
      },
    );
  }
}

class _AccountAccessGate extends StatefulWidget {
  const _AccountAccessGate({super.key, required this.userId});

  final String userId;

  @override
  State<_AccountAccessGate> createState() => _AccountAccessGateState();
}

class _AccountAccessGateState extends State<_AccountAccessGate> {
  late Future<bool> _initialCheck;

  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _markerStream;

  @override
  void initState() {
    super.initState();

    _initialCheck = _checkServer();

    _markerStream = AccountDeletionService.instance
        .marker(widget.userId)
        .snapshots(includeMetadataChanges: true);
  }

  Future<bool> _checkServer() async {
    final document = await AccountDeletionService.instance
        .marker(widget.userId)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));

    return document.exists;
  }

  void _retry() {
    setState(() {
      _initialCheck = _checkServer();
    });
  }

  Widget _loading() {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text(
                  'Hesap durumu kontrol ediliyor…',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _error() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Hesap durumu doğrulanamadı. '
                  'İnternet bağlantınızı kontrol edip tekrar deneyin.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tekrar dene'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _initialCheck,
      builder: (context, initialSnapshot) {
        if (initialSnapshot.connectionState != ConnectionState.done) {
          return _loading();
        }

        if (initialSnapshot.hasError) {
          return _error();
        }

        if (initialSnapshot.data == true) {
          return DeleteAccountScreen(
            key: ValueKey('delete-recovery-${widget.userId}'),
            userId: widget.userId,
            resuming: true,
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _markerStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _error();
            }

            if (!snapshot.hasData) {
              return _loading();
            }

            if (snapshot.data!.exists) {
              return DeleteAccountScreen(
                key: ValueKey('delete-recovery-${widget.userId}'),
                userId: widget.userId,
                resuming: true,
              );
            }

            return MainScreen(key: ValueKey(widget.userId));
          },
        );
      },
    );
  }
}
