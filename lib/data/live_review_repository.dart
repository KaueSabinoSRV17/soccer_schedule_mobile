import '../domain/schedule.dart';
import 'review_repository.dart';

enum ReviewSyncStatus { draft, pending, processing, synced, rejected, failed }

class ReviewSyncState {
  const ReviewSyncState(this.status, {this.choices});
  final ReviewSyncStatus status;
  final ReviewChoices? choices;
  bool get locked =>
      status == ReviewSyncStatus.pending ||
      status == ReviewSyncStatus.processing ||
      status == ReviewSyncStatus.synced ||
      status == ReviewSyncStatus.failed;
}

abstract interface class LiveReviewRepository implements ReviewRepository {
  Future<DailyReview> loadReviewById(String id);
  Stream<ReviewSyncState> watchSubmission(DailyReview review);
}

class ReviewUnavailable implements Exception {
  const ReviewUnavailable(this.message);
  final String message;
}
