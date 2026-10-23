import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/review/review_controller.dart';
import 'features/review/review_screen.dart';
import 'notifications/review_notifications.dart';

const accent = Color(0xFFB8F568);
const surface = Color(0xFF171E1B);

class SoccerScheduleApp extends StatelessWidget {
  const SoccerScheduleApp({
    super.key,
    this.controller,
    this.notifications,
    this.home,
  });
  final ReviewController? controller;
  final ReviewNotifications? notifications;
  final Widget? home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Soccer Schedule',
    debugShowCheckedModeBanner: false,
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        primary: accent,
        surface: surface,
      ),
      scaffoldBackgroundColor: const Color(0xFF0C120F),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0C120F)),
      cardTheme: CardThemeData(
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ),
    home:
        home ??
        ReviewScreen(controller: controller!, notifications: notifications!),
  );
}
