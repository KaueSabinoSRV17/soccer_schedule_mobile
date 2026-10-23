import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'app.dart';
import 'config/live_config.dart';
import 'features/auth/owner_gate.dart';
import 'data/demo_review_repository.dart';
import 'features/review/review_controller.dart';
import 'notifications/review_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  const mode = String.fromEnvironment('APP_MODE', defaultValue: 'demo');
  if (mode != 'demo') {
    try {
      if (mode != 'live' ||
          kIsWeb ||
          defaultTargetPlatform != TargetPlatform.android) {
        throw const FormatException(
          'A versão conectada está disponível no Android. Use APP_MODE=demo na prévia web.',
        );
      }
      const config = LiveConfig();
      config.validate();
      await Firebase.initializeApp(options: config.firebase);
      await GoogleSignIn.instance.initialize(
        serverClientId: config.webClientId,
      );
      runApp(const SoccerScheduleApp(home: OwnerGate(config: config)));
    } catch (_) {
      runApp(
        const SoccerScheduleApp(
          home: Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Configuração de acesso incompleta. Exporte a configuração Android pelo repositório de infraestrutura e inicie com --dart-define-from-file.',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return;
  }
  runApp(
    SoccerScheduleApp(
      controller: ReviewController(
        DemoReviewRepository(SharedPreferencesAsync()),
      ),
      notifications: ReviewNotifications(),
    ),
  );
}
