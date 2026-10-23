import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../config/live_config.dart';
import '../../data/firestore_review_repository.dart';
import '../../notifications/fcm_review_notifications.dart';
import '../review/review_controller.dart';
import '../review/review_screen.dart';

class OwnerGate extends StatefulWidget {
  const OwnerGate({super.key, required this.config});
  final LiveConfig config;
  @override
  State<OwnerGate> createState() => _OwnerGateState();
}

class _OwnerGateState extends State<OwnerGate> {
  late final _authChanges = FirebaseAuth.instance.authStateChanges();
  bool busy = false;
  String? error;
  Future<void> _signIn() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final google = await GoogleSignIn.instance.authenticate();
      final credential = GoogleAuthProvider.credential(
        idToken: google.authentication.idToken,
      );
      final result = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      if (result.user?.email?.toLowerCase() != widget.config.ownerEmail ||
          result.user?.emailVerified != true) {
        await FirebaseAuth.instance.signOut();
        await GoogleSignIn.instance.signOut();
        if (mounted) {
          setState(
            () => error =
                'Esta conta não tem acesso. Use a conta do proprietário.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Não foi possível entrar. Confira a conexão e a configuração de acesso.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: _authChanges,
    builder: (context, snapshot) {
      final user = snapshot.data;
      if (user != null &&
          user.emailVerified &&
          user.email?.toLowerCase() == widget.config.ownerEmail &&
          user.providerData.any((p) => p.providerId == 'google.com')) {
        return _OwnerSession(key: ValueKey(user.uid));
      }
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sports_soccer, size: 64),
                    const SizedBox(height: 24),
                    Text(
                      'Seu dia de futebol.',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Entre com a conta do proprietário para receber a análise diária e escolher os jogos com conflito.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.orangeAccent),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: busy ? null : _signIn,
                      icon: const Icon(Icons.login),
                      label: Text(busy ? 'Entrando…' : 'Entrar com Google'),
                    ),
                    if (user != null)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                await FirebaseAuth.instance.signOut();
                                await GoogleSignIn.instance.signOut();
                              },
                        child: const Text('Trocar conta'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _OwnerSession extends StatefulWidget {
  const _OwnerSession({super.key});
  @override
  State<_OwnerSession> createState() => _OwnerSessionState();
}

class _OwnerSessionState extends State<_OwnerSession> {
  late final ReviewController controller;
  late final FcmReviewNotifications notifications;
  @override
  void initState() {
    super.initState();
    controller = ReviewController(
      FirestoreReviewRepository(
        FirebaseFirestore.instance,
        FirebaseAuth.instance,
      ),
    );
    notifications = FcmReviewNotifications(
      FirebaseFirestore.instance,
      FirebaseAuth.instance,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    notifications.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ReviewScreen(
    controller: controller,
    notifications: notifications,
    onSignOut: () async {
      try {
        await notifications.unregister();
      } finally {
        await FirebaseAuth.instance.signOut();
        await GoogleSignIn.instance.signOut();
      }
    },
  );
}
