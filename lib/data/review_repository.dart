import '../domain/schedule.dart';

class ReviewChoices {
  const ReviewChoices({required this.selectedIds, required this.skippedGroups});
  final Set<int> selectedIds;
  final Set<String> skippedGroups;
}

abstract interface class ReviewRepository {
  Future<DailyReview> loadReview();
  Future<ReviewChoices?> loadChoices(DailyReview review);
  Future<void> saveChoices(DailyReview review, ReviewChoices choices);
  Future<void> clearChoices(DailyReview review);
}
