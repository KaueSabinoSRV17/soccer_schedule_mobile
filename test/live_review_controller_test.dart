import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_schedule/data/live_review_repository.dart';
import 'package:soccer_schedule/data/review_repository.dart';
import 'package:soccer_schedule/domain/schedule.dart';
import 'package:soccer_schedule/features/review/review_controller.dart';
import 'package:soccer_schedule/notifications/review_notifications.dart';

class FakeLiveRepository implements LiveReviewRepository {
  final stream = StreamController<ReviewSyncState>.broadcast();
  String? loadedId;
  int saves = 0;
  bool rejectOnSave = false;
  @override
  Future<DailyReview> loadReview() async => DailyReview(
    id: '2099-01-01',
    revision: 1,
    generatedAt: DateTime.utc(2099),
    fixtures: List.generate(
      2,
      (i) => Fixture(
        fixtureId: i + 1,
        leagueId: 1,
        competition: 'Test',
        kickoff: DateTime.utc(2099, 1, 1, 12, i * 30),
        home: 'A',
        away: 'B',
      ),
    ),
  );
  @override
  Future<DailyReview> loadReviewById(String id) async {
    loadedId = id;
    return loadReview();
  }

  @override
  Future<ReviewChoices?> loadChoices(DailyReview review) async => null;
  @override
  Future<void> saveChoices(DailyReview review, ReviewChoices choices) async {
    saves++;
    if (rejectOnSave) {
      stream.add(const ReviewSyncState(ReviewSyncStatus.rejected));
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  Stream<ReviewSyncState> watchSubmission(DailyReview review) => stream.stream;
  @override
  Future<void> clearChoices(DailyReview review) async =>
      throw StateError('Cannot reset live data');
}

class DelayedLiveRepository extends FakeLiveRepository {
  final started = Completer<void>();
  final resume = Completer<void>();
  bool delayed = false;
  @override
  Future<DailyReview> loadReview() async {
    if (!delayed) {
      delayed = true;
      started.complete();
      await resume.future;
    }
    return super.loadReview();
  }
}

void main() {
  test(
    'a notification during loading opens its target after the current request',
    () async {
      final repository = DelayedLiveRepository();
      final controller = ReviewController(repository);
      final initial = controller.load();
      await repository.started.future;
      await controller.load(reviewId: '2099-01-02');
      repository.resume.complete();
      await initial;
      expect(repository.loadedId, '2099-01-02');
      controller.dispose();
      await repository.stream.close();
    },
  );
  test(
    'a new review does not inherit the previous synchronization lock',
    () async {
      final repository = FakeLiveRepository();
      final controller = ReviewController(repository);
      await controller.load();
      repository.stream.add(const ReviewSyncState(ReviewSyncStatus.synced));
      await Future<void>.delayed(Duration.zero);
      expect(controller.locked, isTrue);
      await controller.load(reviewId: '2099-01-02');
      expect(controller.syncStatus, ReviewSyncStatus.draft);
      expect(controller.locked, isFalse);
      controller.dispose();
      await repository.stream.close();
    },
  );
  test(
    'a rejection arriving before save acknowledgement remains editable',
    () async {
      final repository = FakeLiveRepository()..rejectOnSave = true;
      final controller = ReviewController(repository);
      await controller.load();
      controller.toggle(controller.review!.fixtures.first);
      await controller.save();
      expect(controller.syncStatus, ReviewSyncStatus.rejected);
      expect(controller.saved, isFalse);
      expect(controller.canSave, isTrue);
      controller.dispose();
      await repository.stream.close();
    },
  );
  test('submission acknowledgement locks choices without claiming Calendar success', () async {
    final repository = FakeLiveRepository();
    final controller = ReviewController(repository);
    await controller.load();
    controller.toggle(controller.review!.fixtures.first);
    await controller.save();
    expect(controller.locked, isTrue);
    expect(controller.syncStatus, ReviewSyncStatus.pending);
    controller.toggle(controller.review!.fixtures.first);
    expect(controller.selectedIds, {1});
    repository.stream.add(
      const ReviewSyncState(
        ReviewSyncStatus.synced,
        choices: ReviewChoices(selectedIds: {1}, skippedGroups: {}),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.syncStatus, ReviewSyncStatus.synced);
    await controller.reset();
    expect(controller.selectedIds, {1});
    controller.dispose();
    await repository.stream.close();
  });
  test('rejected choices can be corrected while failed Calendar sync stays locked for retry', () async {
    final repository = FakeLiveRepository();
    final controller = ReviewController(repository);
    await controller.load();
    repository.stream.add(
      const ReviewSyncState(
        ReviewSyncStatus.rejected,
        choices: ReviewChoices(selectedIds: {1}, skippedGroups: {}),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.locked, isFalse);
    controller.toggle(controller.review!.fixtures.first);
    controller.toggle(controller.review!.fixtures.last);
    expect(controller.selectedIds, {2});
    repository.stream.add(
      const ReviewSyncState(
        ReviewSyncStatus.failed,
        choices: ReviewChoices(selectedIds: {2}, skippedGroups: {}),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.locked, isTrue);
    expect(controller.canSave, isFalse);
    controller.dispose();
    await repository.stream.close();
  });
  test('notification target can load a specific review; stale streams stop on dispose', () async {
    final repository = FakeLiveRepository();
    final controller = ReviewController(repository);
    await controller.load(reviewId: '2099-01-01');
    expect(repository.loadedId, '2099-01-01');
    controller.dispose();
    repository.stream.add(const ReviewSyncState(ReviewSyncStatus.synced));
    await repository.stream.close();
  });
  test(
    'notification routing accepts protocol IDs and ignores malformed payloads',
    () {
      final notifications = ReviewNotifications();
      notifications.openReview('2099-01-01');
      expect(notifications.openedReview.value, '2099-01-01');
      notifications.openReview('../../config/access');
      expect(notifications.openedReview.value, '2099-01-01');
      notifications.openReview('demo-2099-01-01');
      expect(notifications.openedReview.value, 'demo-2099-01-01');
      notifications.dispose();
      notifications.openReview('2099-01-02');
    },
  );
}
