import 'package:timezone/timezone.dart' as tz;

const matchWindow = Duration(minutes: 135);

class Broadcast {
  const Broadcast({required this.name, required this.free, this.url});
  final String name;
  final bool free;
  final Uri? url;
}

class Fixture {
  const Fixture({
    required this.fixtureId,
    required this.leagueId,
    required this.competition,
    required this.kickoff,
    required this.home,
    required this.away,
    this.venue,
    this.status,
    this.broadcast,
  });

  final int fixtureId;
  final int leagueId;
  final String competition;
  final DateTime kickoff;
  final String home;
  final String away;
  final String? venue;
  final String? status;
  final Broadcast? broadcast;

  DateTime get endsAt => kickoff.add(matchWindow);
  bool overlaps(Fixture other) =>
      kickoff.isBefore(other.endsAt) && other.kickoff.isBefore(endsAt);
}

class ConflictGroup {
  ConflictGroup(List<Fixture> fixtures)
    : fixtures = List.unmodifiable(fixtures);
  final List<Fixture> fixtures;
  String get id => fixtures.map((f) => f.fixtureId).join('-');
}

int compareFixtures(Fixture left, Fixture right) {
  final timeOrder = left.kickoff.compareTo(right.kickoff);
  return timeOrder != 0 ? timeOrder : left.fixtureId.compareTo(right.fixtureId);
}

class DailyReview {
  DailyReview({
    required this.id,
    required this.revision,
    required this.generatedAt,
    required List<Fixture> fixtures,
  }) : fixtures = List<Fixture>.unmodifiable(
         <Fixture>[...fixtures]..sort(compareFixtures),
       ) {
    if (fixtures.map((f) => f.fixtureId).toSet().length != fixtures.length) {
      throw ArgumentError('Fixture IDs must be unique.');
    }
  }

  final String id;
  final int revision;
  final DateTime generatedAt;
  final List<Fixture> fixtures;

  List<Fixture> get automaticFixtures => fixtures
      .where((f) => !fixtures.any((other) => other != f && f.overlaps(other)))
      .toList();

  // Connected components preserve chain conflicts: A overlaps B, B overlaps C,
  // but A and C may both be selected when their match windows do not overlap.
  List<ConflictGroup> get conflictGroups {
    final remaining = fixtures.toSet();
    final groups = <ConflictGroup>[];
    while (remaining.isNotEmpty) {
      final component = <Fixture>[remaining.first];
      remaining.remove(component.first);
      for (var i = 0; i < component.length; i++) {
        final neighbors = remaining.where(component[i].overlaps).toList();
        component.addAll(neighbors);
        remaining.removeAll(neighbors);
      }
      if (component.length > 1) {
        component.sort(compareFixtures);
        groups.add(ConflictGroup(component));
      }
    }
    return groups;
  }
}

tz.TZDateTime saoPaulo(DateTime instant) =>
    tz.TZDateTime.from(instant, tz.getLocation('America/Sao_Paulo'));
