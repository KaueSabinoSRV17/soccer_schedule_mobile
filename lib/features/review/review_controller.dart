import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/review_repository.dart';
import '../../data/live_review_repository.dart';
import '../../domain/schedule.dart';

class ReviewController extends ChangeNotifier {
  ReviewController(this.repository);
  final ReviewRepository repository;
  DailyReview? review;
  bool get isLive => repository is LiveReviewRepository;
  ReviewSyncStatus syncStatus = ReviewSyncStatus.draft;
  StreamSubscription<ReviewSyncState>? _syncSubscription;
  bool _disposed = false;
  String? _queuedReviewId;

  Future<void> _loadQueuedReview() async {
    final id = _queuedReviewId;
    _queuedReviewId = null;
    if (id != null && !_disposed) await load(reviewId: id);
  }

  bool get locked =>
      isLive &&
      (saved && syncStatus != ReviewSyncStatus.rejected ||
          const [
            ReviewSyncStatus.pending,
            ReviewSyncStatus.processing,
            ReviewSyncStatus.synced,
            ReviewSyncStatus.failed,
          ].contains(syncStatus));
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_syncSubscription?.cancel());
    super.dispose();
  }

  bool loading = false;
  bool saving = false;
  bool saved = false;
  String? error;
  final Set<int> _selected = {};
  final Set<String> _skipped = {};

  Set<int> get selectedIds => Set.unmodifiable(_selected);
  List<ConflictGroup> get groups => review?.conflictGroups ?? [];
  bool isSkipped(ConflictGroup group) => _skipped.contains(group.id);
  bool isResolved(ConflictGroup group) =>
      isSkipped(group) ||
      group.fixtures.any((f) => _selected.contains(f.fixtureId));
  int get pendingGroups => groups.where((g) => !isResolved(g)).length;
  bool get canSave =>
      review != null &&
      !loading &&
      !saving &&
      !saved &&
      !locked &&
      pendingGroups == 0 &&
      (!isLive ||
          !review!.fixtures.any(
            (f) =>
                _selected.contains(f.fixtureId) &&
                !f.kickoff.isAfter(DateTime.now()),
          ));

  List<Fixture> get agenda => [
    ...?review?.automaticFixtures,
    ...?review?.fixtures.where((f) => _selected.contains(f.fixtureId)),
  ]..sort(compareFixtures);

  bool canSelect(Fixture fixture) =>
      !saving &&
      !loading &&
      !locked &&
      (!isLive ||
          fixture.kickoff.isAfter(DateTime.now()) ||
          _selected.contains(fixture.fixtureId)) &&
      (_selected.contains(fixture.fixtureId) ||
          !(review?.fixtures.any(
                (f) =>
                    f.fixtureId != fixture.fixtureId &&
                    _selected.contains(f.fixtureId) &&
                    fixture.overlaps(f),
              ) ??
              false));

  Future<void> load({String? reviewId}) async {
    if (_disposed) return;
    if (loading || saving) {
      if (reviewId != null) _queuedReviewId = reviewId;
      return;
    }
    loading = true;
    error = null;
    _changed();
    try {
      await _syncSubscription?.cancel();
      final loaded = isLive && reviewId != null
          ? await (repository as LiveReviewRepository).loadReviewById(reviewId)
          : await repository.loadReview();
      final choices = await repository.loadChoices(loaded);
      review = loaded;
      syncStatus = ReviewSyncStatus.draft;
      _selected.clear();
      _skipped.clear();
      saved = false;
      if (choices != null) {
        final conflictIds = groups
            .expand((g) => g.fixtures)
            .map((f) => f.fixtureId)
            .toSet();
        if (choices.selectedIds.every(conflictIds.contains) &&
            choices.skippedGroups.every(
              (id) => groups.any((g) => g.id == id),
            )) {
          final chosen = loaded.fixtures
              .where((f) => choices.selectedIds.contains(f.fixtureId))
              .toList();
          final overlaps = chosen.any(
            (a) => chosen.any((b) => a != b && a.overlaps(b)),
          );
          final contradictory = groups.any(
            (g) =>
                choices.skippedGroups.contains(g.id) &&
                g.fixtures.any(
                  (f) => choices.selectedIds.contains(f.fixtureId),
                ),
          );
          if (!overlaps && !contradictory) {
            _selected.addAll(choices.selectedIds);
            _skipped.addAll(choices.skippedGroups);
            saved = pendingGroups == 0;
          }
        }
      }
      if (isLive && !_disposed) {
        _syncSubscription = (repository as LiveReviewRepository)
            .watchSubmission(loaded)
            .listen(
              (state) {
                if (_disposed) return;
                syncStatus = state.status;
                saved = state.locked;
                if (state.choices != null &&
                    state.status != ReviewSyncStatus.draft) {
                  _selected
                    ..clear()
                    ..addAll(
                      state.choices!.selectedIds.where(
                        (id) => review!.fixtures.any((f) => f.fixtureId == id),
                      ),
                    );
                  _skipped
                    ..clear()
                    ..addAll(
                      state.choices!.skippedGroups.where(
                        (id) => groups.any((g) => g.id == id),
                      ),
                    );
                }
                error = state.status == ReviewSyncStatus.rejected
                    ? 'Escolhas rejeitadas. Confira os horários, corrija os jogos e envie novamente.'
                    : null;
                _changed();
              },
              onError: (Object _) {
                error = 'A conexão com o servidor foi interrompida. Atualize para conferir o envio.';
                _changed();
              },
            );
      }
    } catch (exception) {
      error = exception is ReviewUnavailable
          ? exception.message
          : 'Não foi possível carregar a análise. Tente novamente.';
    } finally {
      loading = false;
      _changed();
      await _loadQueuedReview();
    }
  }

  void toggle(Fixture fixture) {
    if (saving ||
        loading ||
        locked ||
        !groups.any((g) => g.fixtures.contains(fixture))) {
      return;
    }
    if (_selected.contains(fixture.fixtureId)) {
      _selected.remove(fixture.fixtureId);
    } else {
      if (!canSelect(fixture)) return;
      _selected.add(fixture.fixtureId);
    }
    for (final group in groups.where((g) => g.fixtures.contains(fixture))) {
      _skipped.remove(group.id);
    }
    saved = false;
    error = null;
    _changed();
  }

  void skip(ConflictGroup group) {
    if (saving || loading || locked || !groups.any((g) => g.id == group.id)) {
      return;
    }
    _selected.removeAll(group.fixtures.map((f) => f.fixtureId));
    if (!_skipped.add(group.id)) _skipped.remove(group.id);
    saved = false;
    error = null;
    _changed();
  }

  Future<void> save() async {
    if (!canSave) return;
    saving = true;
    error = null;
    _changed();
    try {
      await repository.saveChoices(
        review!,
        ReviewChoices(
          selectedIds: Set.of(_selected),
          skippedGroups: Set.of(_skipped),
        ),
      );
      if (isLive && syncStatus == ReviewSyncStatus.draft) {
        syncStatus = ReviewSyncStatus.pending;
      }
      saved = !isLive || syncStatus != ReviewSyncStatus.rejected;
    } catch (_) {
      error = 'Não foi possível salvar. Suas escolhas continuam nesta tela.';
    } finally {
      saving = false;
      _changed();
      await _loadQueuedReview();
    }
  }

  Future<void> reset() async {
    if (isLive || review == null || saving || loading) return;
    saving = true;
    error = null;
    _changed();
    try {
      await repository.clearChoices(review!);
      _selected.clear();
      _skipped.clear();
      saved = false;
    } catch (_) {
      error = 'Não foi possível limpar as escolhas.';
    } finally {
      saving = false;
      _changed();
    }
  }
}
