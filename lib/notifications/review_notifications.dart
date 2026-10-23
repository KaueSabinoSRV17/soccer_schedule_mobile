import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Exercises Android permission, notification display and tap routing locally.
/// Remote FCM registration/delivery is deliberately not configured in demo mode.
class ReviewNotifications {
  final _plugin = FlutterLocalNotificationsPlugin();
  final openedReview = ValueNotifier<String?>(null);
  bool _initialized = false;
  bool _closed = false;

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize() async {
    if (!supported || _initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_soccer'),
      ),
      onDidReceiveNotificationResponse: (response) =>
          openReview(response.payload),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'daily_review',
            'Análise diária',
            description: 'Sua análise diária de jogos.',
          ),
        );
    _initialized = true;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      openReview(launch?.notificationResponse?.payload);
    }
  }

  void openReview(String? payload) {
    if (_closed ||
        payload == null ||
        !RegExp(r'^(demo-)?\d{4}-\d{2}-\d{2}$').hasMatch(payload)) {
      return;
    }
    // Reset first so repeated taps for the same review still notify listeners.
    openedReview.value = null;
    openedReview.value = payload;
  }

  void dispose() {
    _closed = true;
    openedReview.dispose();
  }

  Future<void> showIncoming(String reviewId, String title, String body) =>
      _plugin.show(
        id: 1,
        title: title,
        body: body,
        payload: reviewId,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_review',
            'Análise diária',
            icon: 'ic_stat_soccer',
          ),
        ),
      );

  Future<bool> showTest(
    String reviewId,
    int pendingGroups, {
    bool demo = true,
  }) async {
    if (!supported) return false;
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final allowed = await android?.requestNotificationsPermission() ?? false;
    if (!allowed) return false;
    await _plugin.show(
      id: 1,
      title: demo
          ? 'Soccer Schedule · Demonstração'
          : 'Soccer Schedule · Teste',
      body: pendingGroups > 0
          ? '$pendingGroups grupos de jogos precisam da sua escolha.'
          : demo
          ? 'Sua análise de demonstração está pronta.'
          : 'Sua análise diária está pronta.',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          demo ? 'daily_review_demo' : 'daily_review',
          demo ? 'Análise diária · demonstração' : 'Análise diária',
          channelDescription: 'Teste local da análise diária de jogos.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      payload: reviewId,
    );
    return true;
  }
}
