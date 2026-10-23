import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_schedule/app.dart';
import 'package:soccer_schedule/data/live_review_repository.dart';
import 'package:soccer_schedule/features/review/review_controller.dart';
import 'package:soccer_schedule/notifications/review_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'review_controller_test.dart' show FakeReviewRepository;
import 'live_review_controller_test.dart' show FakeLiveRepository;
import 'schedule_test.dart' as fixtures;

class FakeReviewNotifications extends ReviewNotifications {
  @override
  Future<void> initialize() async {}
}

void main() {
  setUpAll(tz.initializeTimeZones);

  testWidgets(
    'live review distinguishes queued choices from confirmed Calendar success',
    (tester) async {
      final repository = FakeLiveRepository();
      final controller = ReviewController(repository);
      final notifications = FakeReviewNotifications();
      addTearDown(() async {
        controller.dispose();
        notifications.dispose();
        await repository.stream.close();
      });
      await tester.pumpWidget(
        SoccerScheduleApp(controller: controller, notifications: notifications),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('DEMONSTRAÇÃO'), findsNothing);
      controller.toggle(controller.review!.fixtures.first);
      await controller.save();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Escolhas recebidas pelo servidor.'),
        200,
      );
      expect(find.text('Google Calendar atualizado.'), findsNothing);
      repository.stream.add(const ReviewSyncState(ReviewSyncStatus.synced));
      await tester.pumpAndSettle();
      expect(find.text('Google Calendar atualizado.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('review, select, save and view local agenda', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeReviewRepository(
      fixtures.review([
        fixtures.fixture(1, 0),
        fixtures.fixture(2, 30),
        fixtures.fixture(3, 400),
      ]),
    );
    final controller = ReviewController(repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      SoccerScheduleApp(
        controller: controller,
        notifications: FakeReviewNotifications(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('DEMONSTRAÇÃO'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('select-1')),
      200,
    );
    await tester.tap(find.byKey(const ValueKey('select-1')));
    await tester.pumpAndSettle();
    expect(controller.selectedIds, {1});
    await tester.scrollUntilVisible(
      find.text('Salvar escolhas no aparelho'),
      200,
    );
    await tester.tap(find.text('Salvar escolhas no aparelho'));
    await tester.pumpAndSettle();
    expect(find.text('Escolhas salvas neste aparelho.'), findsOneWidget);
    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    expect(find.text('Sua agenda de jogos.'), findsOneWidget);
    expect(controller.agenda.map((f) => f.fixtureId), [1, 3]);
    expect(tester.takeException(), isNull);
  });
}
