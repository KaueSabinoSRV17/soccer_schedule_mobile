import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'review_notifications.dart';

class FcmReviewNotifications extends ReviewNotifications {
  FcmReviewNotifications(this.db, this.auth);
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  final _preferences = SharedPreferencesAsync();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  bool _started = false;
  bool _disposed = false;
  String? _installation;

  String? _reviewId(RemoteMessage message) =>
      message.data['type'] == 'daily_review' &&
          message.data['reviewId'] is String &&
          RegExp(r'^\d{4}-\d{2}-\d{2}$')
              .hasMatch(message.data['reviewId'] as String)
      ? message.data['reviewId'] as String
      : null;

  @override
  Future<void> initialize() async {
    if (_started || _disposed) return;
    await super.initialize();
    if (_disposed) return;
    _started = true;
    _subscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        final id = _reviewId(message);
        if (id != null && !_disposed) openReview(id);
      }),
    );
    _subscriptions.add(
      FirebaseMessaging.onMessage.listen((message) {
        final id = _reviewId(message);
        if (id != null && !_disposed) {
          unawaited(
            showIncoming(
              id,
              message.notification?.title ?? 'Sua análise está pronta',
              message.notification?.body ?? 'Abra para escolher seus jogos.',
            ).catchError((Object _) {
              debugPrint('Unable to display foreground review notification');
            }),
          );
        }
      }),
    );
    _subscriptions.add(
      FirebaseMessaging.instance.onRegistered.listen(
        (fid) {
          unawaited(
            _register(fid).catchError((Object _) {
              debugPrint('Unable to refresh review notification registration');
            }),
          );
        },
        onError: (Object _) {
          debugPrint('Daily notification registration is unavailable');
        },
      ),
    );
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null && !_disposed) {
      final id = _reviewId(initial);
      if (id != null) openReview(id);
    }
    unawaited(
      _activate().catchError((Object _) {
        debugPrint(
          'Unable to register daily notifications; use the notification test to retry.',
        );
      }),
    );
  }

  Future<void> _activate() async {
    if (_disposed || auth.currentUser == null) return;
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (_disposed || auth.currentUser == null) return;
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await FirebaseMessaging.instance.register().timeout(
        const Duration(seconds: 15),
      );
    }
  }

  Future<void> _register(String token) async {
    final user = auth.currentUser;
    if (_disposed || user?.email == null) return;
    _installation ??= await _preferences.getString('device.installation');
    _installation ??= List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await _preferences.setString('device.installation', _installation!);
    if (_disposed || auth.currentUser?.uid != user!.uid) return;
    await db
        .collection('devices')
        .doc(_installation)
        .set({
          'fid': token,
          'platform': 'android',
          'enabled': true,
          'ownerEmail': user.email!.toLowerCase(),
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(const Duration(seconds: 15));
  }

  @override
  Future<bool> showTest(
    String reviewId,
    int pendingGroups, {
    bool demo = false,
  }) async {
    final shown = await super.showTest(reviewId, pendingGroups, demo: false);
    if (shown) await _activate();
    return shown;
  }

  Future<void> unregister() async {
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    try {
      _installation ??= await _preferences.getString('device.installation');
      if (_installation != null) {
        await db
            .collection('devices')
            .doc(_installation)
            .delete()
            .timeout(const Duration(seconds: 10));
      }
    } catch (_) {
      debugPrint(
        'Device registration cleanup will complete when the stale token is rejected',
      );
    } finally {
      await FirebaseMessaging.instance.unregister().timeout(
        const Duration(seconds: 10),
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
