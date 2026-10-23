import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_schedule/domain/schedule.dart';
import 'package:timezone/data/latest.dart' as tz;

Fixture fixture(int id, int minute) => Fixture(
  fixtureId: id,
  leagueId: 1,
  competition: 'Test',
  kickoff: DateTime.utc(2026, 10, 23, 12).add(Duration(minutes: minute)),
  home: 'Home $id',
  away: 'Away $id',
);

DailyReview review(List<Fixture> fixtures) => DailyReview(
  id: 'test',
  revision: 1,
  generatedAt: DateTime.utc(2026),
  fixtures: fixtures,
);

void main() {
  setUpAll(tz.initializeTimeZones);

  test('135-minute windows exclude touching endpoints', () {
    expect(fixture(1, 0).overlaps(fixture(2, 134)), isTrue);
    expect(fixture(1, 0).overlaps(fixture(2, 135)), isFalse);
    expect(fixture(2, 134).overlaps(fixture(1, 0)), isTrue);
  });

  test('only fixtures with no overlapping neighbor are automatic', () {
    final daily = review([fixture(3, 400), fixture(2, 30), fixture(1, 0)]);
    expect(daily.automaticFixtures.map((f) => f.fixtureId), [3]);
    expect(daily.conflictGroups.single.fixtures.map((f) => f.fixtureId), [
      1,
      2,
    ]);
  });

  test('chain conflicts form one group without forcing one choice', () {
    final a = fixture(1, 0);
    final b = fixture(2, 100);
    final c = fixture(3, 200);
    final daily = review([c, a, b]);
    expect(daily.conflictGroups, hasLength(1));
    expect(daily.conflictGroups.single.fixtures, [a, b, c]);
    expect(a.overlaps(c), isFalse);
    expect(daily.automaticFixtures, isEmpty);
  });

  test('separate overlap components have distinct stable IDs', () {
    final daily = review([
      fixture(4, 510),
      fixture(1, 0),
      fixture(3, 500),
      fixture(2, 20),
    ]);
    expect(daily.conflictGroups.map((g) => g.id), ['1-2', '3-4']);
  });

  test('empty analysis and unique fixtures are supported', () {
    expect(review([]).conflictGroups, isEmpty);
    expect(review([fixture(1, 0)]).automaticFixtures, hasLength(1));
    expect(() => review([fixture(1, 0), fixture(1, 30)]), throwsArgumentError);
  });

  test('equal kickoff times produce stable group IDs in any input order', () {
    final a = fixture(1, 0);
    final b = fixture(2, 0);
    expect(review([a, b]).conflictGroups.single.id, '1-2');
    expect(review([b, a]).conflictGroups.single.id, '1-2');
  });

  test(
    'São Paulo formatting is independent of device timezone and crosses dates',
    () {
      final local = saoPaulo(DateTime.utc(2026, 10, 23, 1, 30));
      expect(local.day, 22);
      expect(local.hour, 22);
      expect(local.minute, 30);
    },
  );
}
