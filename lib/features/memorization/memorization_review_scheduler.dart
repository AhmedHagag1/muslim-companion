import '../../data/models/memorization.dart';

class MemorizationReviewScheduler {
  static const intervals = [1, 2, 4, 7, 14, 30];
  DateTime dueAt(int stage, DateTime from) => DateTime.utc(
    from.year,
    from.month,
    from.day,
  ).add(Duration(days: intervals[stage.clamp(0, 5)]));
  MemorizedAyah success(MemorizedAyah ayah, DateTime at) {
    final stage = (ayah.reviewLevel + 1).clamp(0, 5);
    return ayah.copyWith(
      lastReviewedAt: at.toUtc(),
      nextReviewAt: dueAt(stage, at),
      reviewLevel: stage,
      successfulReviews: ayah.successfulReviews + 1,
    );
  }

  MemorizedAyah failure(MemorizedAyah ayah, DateTime at) {
    final stage = (ayah.reviewLevel - 1).clamp(0, 5);
    return ayah.copyWith(
      lastReviewedAt: at.toUtc(),
      nextReviewAt: dueAt(0, at),
      reviewLevel: stage,
      failedReviews: ayah.failedReviews + 1,
    );
  }

  MemorizedAyah rate(
    MemorizedAyah ayah,
    MemorizationSessionResult result,
    DateTime at,
  ) {
    switch (result) {
      case MemorizationSessionResult.mastered:
        return success(ayah, at);
      case MemorizationSessionResult.needsReview:
        return failure(ayah, at);
      case MemorizationSessionResult.notMastered:
        return ayah.copyWith(
          lastReviewedAt: at.toUtc(),
          nextReviewAt: dueAt(0, at),
          reviewLevel: 0,
          failedReviews: ayah.failedReviews + 1,
        );
    }
  }
}
