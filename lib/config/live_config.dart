import 'package:firebase_core/firebase_core.dart';

class LiveConfig {
  const LiveConfig();
  String get ownerEmail =>
      const String.fromEnvironment('OWNER_EMAIL').trim().toLowerCase();
  String get webClientId =>
      const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  FirebaseOptions get firebase => const FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
  );
  void validate() {
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(ownerEmail) ||
        webClientId.isEmpty ||
        firebase.apiKey.isEmpty ||
        firebase.appId.isEmpty ||
        firebase.messagingSenderId.isEmpty ||
        firebase.projectId.isEmpty) {
      throw const FormatException(
        'Exporte a configuração Android pelo repositório de infraestrutura e use --dart-define-from-file.',
      );
    }
  }
}
