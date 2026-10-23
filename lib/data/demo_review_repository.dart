import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/schedule.dart';
import 'review_repository.dart';

/// Offline demo only. Never performs Calendar or Firebase operations.
class DemoReviewRepository implements ReviewRepository {
  DemoReviewRepository(this.preferences, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  final SharedPreferencesAsync preferences;
  final DateTime Function() clock;

  String _key(DailyReview review) =>
      'demo.choices.${review.id}.${review.revision}';

  @override
  Future<DailyReview> loadReview() async {
    final now = saoPaulo(clock());
    // Tomorrow keeps demo choices actionable regardless of the current hour.
    final day = tz.TZDateTime(now.location, now.year, now.month, now.day + 1);
    Fixture fixture(
      int id,
      String home,
      String away,
      String competition,
      int hour,
      int minute, {
      bool free = false,
      String provider = 'Disney+',
    }) => Fixture(
      fixtureId: id,
      leagueId: competition == 'Brasileirão Série A' ? 4351 : 4480,
      competition: competition,
      kickoff: tz.TZDateTime(
        day.location,
        day.year,
        day.month,
        day.day,
        hour,
        minute,
      ).toUtc(),
      home: home,
      away: away,
      status: 'NS',
      broadcast: Broadcast(
        name: provider,
        free: free,
        url: Uri.parse(
          free
              ? 'https://www.youtube.com/@CazeTV'
              : 'https://www.disneyplus.com/',
        ),
      ),
    );
    return DailyReview(
      id: 'demo-${DateFormat('yyyy-MM-dd').format(day)}',
      revision: 1,
      generatedAt: now.toUtc(),
      fixtures: [
        fixture(1001, 'Arsenal', 'Liverpool', 'Premier League', 10, 0),
        fixture(1002, 'Real Madrid', 'Barcelona', 'LaLiga', 14, 0),
        fixture(
          1003,
          'Bayern München',
          'Dortmund',
          'Bundesliga',
          14,
          30,
          free: true,
          provider: 'CazéTV',
        ),
        fixture(1004, 'Inter', 'Juventus', 'Serie A', 17, 0),
        fixture(
          1005,
          'Flamengo',
          'Palmeiras',
          'Brasileirão Série A',
          19,
          30,
          free: true,
          provider: 'CazéTV',
        ),
        fixture(1006, 'Corinthians', 'Santos', 'Brasileirão Série A', 20, 0),
        fixture(1007, 'Grêmio', 'Internacional', 'Brasileirão Série A', 22, 0),
      ],
    );
  }

  @override
  Future<ReviewChoices?> loadChoices(DailyReview review) async {
    final raw = await preferences.getString(_key(review));
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return ReviewChoices(
        selectedIds: (data['selectedIds'] as List<dynamic>).cast<int>().toSet(),
        skippedGroups: (data['skippedGroups'] as List<dynamic>)
            .cast<String>()
            .toSet(),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> saveChoices(DailyReview review, ReviewChoices choices) =>
      preferences.setString(
        _key(review),
        jsonEncode({
          'selectedIds': choices.selectedIds.toList()..sort(),
          'skippedGroups': choices.skippedGroups.toList()..sort(),
        }),
      );

  @override
  Future<void> clearChoices(DailyReview review) =>
      preferences.remove(_key(review));
}
