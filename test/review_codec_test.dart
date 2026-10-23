import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_schedule/data/review_codec.dart';

Map<String, dynamic> document() => {
  'schemaVersion': 1,
  'revision': 1,
  'status': 'ready',
  'timezone': 'America/Sao_Paulo',
  'generatedAt': '2099-01-01T06:00:00Z',
  'automaticIds': [1],
  'fixtures': [
    {
      'fixtureId': 1,
      'leagueId': 4351,
      'competition': 'League',
      'home': 'A',
      'away': 'B',
      'kickoff': '2099-01-01T12:00:00Z',
      'broadcast': {
        'name': 'Provider',
        'free': true,
        'url': 'https://www.youtube.com/watch?v=example',
      },
    },
  ],
};

void main() {
  test(
    'reads the server schema and preserves UTC instants and viewing links',
    () {
      final review = decodeReview('2099-01-01', document());
      expect(review.id, '2099-01-01');
      expect(review.fixtures.single.kickoff.isUtc, isTrue);
      expect(review.fixtures.single.broadcast!.url!.scheme, 'https');
    },
  );
  test('rejects unavailable schemas, naive timestamps, duplicates and inconsistent automatic fixtures', () {
    for (final changes in <Map<String, dynamic>>[
      {'schemaVersion': 2},
      {'status': 'preparing'},
      {'revision': 0},
      {'timezone': 'UTC'},
      {'generatedAt': '2099-01-01T06:00:00'},
      {'automaticIds': <int>[]},
    ]) {
      expect(
        () => decodeReview('2099-01-01', {...document(), ...changes}),
        throwsFormatException,
      );
    }
    final data = document();
    data['fixtures'] = [data['fixtures'][0], data['fixtures'][0]];
    expect(() => decodeReview('2099-01-01', data), throwsArgumentError);
  });
  test('does not expose unsafe viewing URLs to the launcher', () {
    final data = document();
    data['fixtures'][0]['broadcast']['url'] = 'javascript:alert(1)';
    expect(
      decodeReview('2099-01-01', data).fixtures.single.broadcast!.url,
      isNull,
    );
  });
}
