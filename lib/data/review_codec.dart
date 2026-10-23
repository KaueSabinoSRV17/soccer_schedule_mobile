import '../domain/schedule.dart';

DailyReview decodeReview(String id, Map<String, dynamic> data) {
  if (data['schemaVersion'] != 1 ||
      data['status'] != 'ready' ||
      data['timezone'] != 'America/Sao_Paulo' ||
      data['revision'] is! int ||
      (data['revision'] as int) < 1) {
    throw const FormatException('Unsupported or unavailable review');
  }
  String requiredText(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid $key');
    }
    return value;
  }

  DateTime instant(String raw) {
    final parsed = DateTime.parse(raw);
    if (!parsed.isUtc) {
      throw const FormatException('An explicit timezone is required');
    }
    return parsed;
  }

  final fixtures = (data['fixtures'] as List<dynamic>).map((raw) {
    final item = Map<String, dynamic>.from(raw as Map);
    final id = item['fixtureId'];
    if (id is! int || id <= 0 || item['leagueId'] is! int) {
      throw const FormatException('Invalid fixture identifiers');
    }
    final rawBroadcast = item['broadcast'];
    Broadcast? broadcast;
    if (rawBroadcast != null) {
      final map = Map<String, dynamic>.from(rawBroadcast as Map);
      if (map['free'] is! bool) {
        throw const FormatException('Invalid broadcast');
      }
      final url = map['url'] is String
          ? Uri.tryParse(map['url'] as String)
          : null;
      broadcast = Broadcast(
        name: requiredText(map, 'name'),
        free: map['free'] as bool,
        url: url?.scheme == 'https' && url!.host.isNotEmpty ? url : null,
      );
    }
    return Fixture(
      fixtureId: id,
      leagueId: item['leagueId'] as int,
      competition: requiredText(item, 'competition'),
      kickoff: instant(requiredText(item, 'kickoff')),
      home: requiredText(item, 'home'),
      away: requiredText(item, 'away'),
      venue: item['venue'] as String?,
      status: item['status'] as String?,
      broadcast: broadcast,
    );
  }).toList();
  final review = DailyReview(
    id: id,
    revision: data['revision'] as int,
    generatedAt: instant(requiredText(data, 'generatedAt')),
    fixtures: fixtures,
  );
  final automatic = (data['automaticIds'] as List<dynamic>).cast<int>().toSet();
  final derived = review.automaticFixtures.map((f) => f.fixtureId).toSet();
  if (automatic.length != derived.length || !automatic.containsAll(derived)) {
    throw const FormatException('Incompatible overlap rules');
  }
  return review;
}
