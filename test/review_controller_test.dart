import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_schedule/data/review_repository.dart';
import 'package:soccer_schedule/domain/schedule.dart';
import 'package:soccer_schedule/features/review/review_controller.dart';

import 'schedule_test.dart' as fixtures;

class FakeReviewRepository implements ReviewRepository {
  FakeReviewRepository(this.review);
  DailyReview review;
  ReviewChoices? stored;
  bool failLoad = false;
  bool failSave = false;
  Completer<void>? saveGate;
  int writes = 0;

  @override
  Future<DailyReview> loadReview() async {
    if (failLoad) throw StateError('offline');
    return review;
  }

  @override
  Future<ReviewChoices?> loadChoices(DailyReview review) async => stored;

  @override
  Future<void> saveChoices(DailyReview review, ReviewChoices choices) async {
    writes++;
    if (saveGate != null) await saveGate!.future;
    if (failSave) throw StateError('disk unavailable');
    stored = choices;
  }

  @override
  Future<void> clearChoices(DailyReview review) async => stored = null;
}

void main() {
  late FakeReviewRepository repository;
  late ReviewController controller;
  late List<Fixture> matches;

  setUp(() async {
    matches = [
      fixtures.fixture(1, 0),
      fixtures.fixture(2, 100),
      fixtures.fixture(3, 200),
      fixtures.fixture(4, 600),
    ];
    repository = FakeReviewRepository(fixtures.review(matches));
    controller = ReviewController(repository);
    await controller.load();
  });

  tearDown(() => controller.dispose());

  test('requires an explicit group decision before saving', () async {
    expect(controller.canSave, isFalse);
    expect(controller.agenda.map((f) => f.fixtureId), [4]);
    await controller.save();
    expect(repository.writes, 0);
    controller.skip(controller.groups.single);
    expect(controller.canSave, isTrue);
    await controller.save();
    expect(repository.stored!.selectedIds, isEmpty);
    expect(controller.saved, isTrue);
  });

  test('accepts A and C in a chain but rejects B', () {
    controller.toggle(matches[0]);
    expect(controller.canSelect(matches[1]), isFalse);
    controller.toggle(matches[1]);
    controller.toggle(matches[2]);
    expect(controller.selectedIds, {1, 3});
    expect(controller.agenda.map((f) => f.fixtureId), [1, 3, 4]);
  });

  test('unselecting allows another conflicting match', () {
    controller.toggle(matches[0]);
    controller.toggle(matches[0]);
    controller.toggle(matches[1]);
    expect(controller.selectedIds, {2});
  });

  test('skip clears choices and selecting clears skip', () {
    controller.toggle(matches[0]);
    controller.skip(controller.groups.single);
    expect(controller.selectedIds, isEmpty);
    expect(controller.isSkipped(controller.groups.single), isTrue);
    controller.toggle(matches[2]);
    expect(controller.isSkipped(controller.groups.single), isFalse);
    expect(controller.selectedIds, {3});
  });

  test('saved choices reload and editing marks them unconfirmed', () async {
    controller.toggle(matches[0]);
    await controller.save();
    await controller.load();
    expect(controller.saved, isTrue);
    expect(controller.selectedIds, {1});
    controller.toggle(matches[2]);
    expect(controller.saved, isFalse);
    expect(controller.canSave, isTrue);
  });

  test(
    'rejects stale IDs, incompatible and contradictory persisted choices',
    () async {
      for (final choices in [
        const ReviewChoices(selectedIds: {99}, skippedGroups: {}),
        const ReviewChoices(selectedIds: {1, 2}, skippedGroups: {}),
        const ReviewChoices(selectedIds: {4}, skippedGroups: {}),
        const ReviewChoices(selectedIds: {1}, skippedGroups: {'1-2-3'}),
      ]) {
        repository.stored = choices;
        await controller.load();
        expect(controller.selectedIds, isEmpty);
        expect(controller.saved, isFalse);
      }
    },
  );

  test('save failure retains choices and allows retry', () async {
    controller.toggle(matches[0]);
    repository.failSave = true;
    await controller.save();
    expect(controller.error, isNotNull);
    expect(controller.saved, isFalse);
    expect(controller.selectedIds, {1});
    expect(controller.canSave, isTrue);
    repository.failSave = false;
    await controller.save();
    expect(controller.saved, isTrue);
    expect(controller.error, isNull);
  });

  test('save is atomic against editing and repeated submission', () async {
    controller.toggle(matches[0]);
    repository.saveGate = Completer<void>();
    final pending = controller.save();
    controller.toggle(matches[2]);
    controller.skip(controller.groups.single);
    await controller.save();
    expect(controller.selectedIds, {1});
    expect(repository.writes, 1);
    repository.saveGate!.complete();
    await pending;
    expect(repository.stored!.selectedIds, {1});
  });

  test('reset removes persisted and in-memory decisions', () async {
    controller.toggle(matches[0]);
    await controller.save();
    await controller.reset();
    expect(repository.stored, isNull);
    expect(controller.selectedIds, isEmpty);
    expect(controller.pendingGroups, 1);
  });

  test('load failure can be retried', () async {
    repository.failLoad = true;
    await controller.load();
    expect(controller.error, isNotNull);
    expect(controller.loading, isFalse);
    repository.failLoad = false;
    await controller.load();
    expect(controller.error, isNull);
  });
}
