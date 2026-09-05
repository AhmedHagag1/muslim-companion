import 'surah.dart';

enum MemorizationPlanStatus { active, paused, completed, archived }

enum MemorizationReviewStrategy { spaced }

enum MemorizationSessionResult { mastered, needsReview, notMastered }

enum MemorizationSessionMode {
  newMemorization,
  nearReview,
  oldReview,
  selfTest,
}

enum MemorizationTestMode { fullAyah, firstWords, progressiveReveal, nextAyah }

class QuranCoordinate implements Comparable<QuranCoordinate> {
  const QuranCoordinate(this.surahNumber, this.ayahNumber);
  final int surahNumber;
  final int ayahNumber;

  bool get isValid =>
      surahNumber >= 1 &&
      surahNumber <= QuranMetadata.surahCount &&
      ayahNumber >= 1 &&
      ayahNumber <= QuranMetadata.surah(surahNumber).ayahCount;
  String get key => '$surahNumber:$ayahNumber';
  Map<String, Object> toJson() => {'surah': surahNumber, 'ayah': ayahNumber};
  static QuranCoordinate? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final coordinate = QuranCoordinate(
      value['surah'] as int? ?? 0,
      value['ayah'] as int? ?? 0,
    );
    return coordinate.isValid ? coordinate : null;
  }

  @override
  int compareTo(QuranCoordinate other) => surahNumber != other.surahNumber
      ? surahNumber.compareTo(other.surahNumber)
      : ayahNumber.compareTo(other.ayahNumber);
  @override
  bool operator ==(Object other) =>
      other is QuranCoordinate && key == other.key;
  @override
  int get hashCode => Object.hash(surahNumber, ayahNumber);
}

abstract final class QuranRange {
  static bool valid(QuranCoordinate start, QuranCoordinate end) =>
      start.isValid && end.isValid && start.compareTo(end) <= 0;
  static List<QuranCoordinate> coordinates(
    QuranCoordinate start,
    QuranCoordinate end,
  ) {
    if (!valid(start, end)) return const [];
    final result = <QuranCoordinate>[];
    for (var surah = start.surahNumber; surah <= end.surahNumber; surah++) {
      final first = surah == start.surahNumber ? start.ayahNumber : 1;
      final last = surah == end.surahNumber
          ? end.ayahNumber
          : QuranMetadata.surah(surah).ayahCount;
      for (var ayah = first; ayah <= last; ayah++) {
        result.add(QuranCoordinate(surah, ayah));
      }
    }
    return result;
  }
}

class MemorizationPlan {
  const MemorizationPlan({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.createdAt,
    this.targetDate,
    required this.preferredStudyDays,
    required this.status,
    required this.dailyNewAyahTarget,
    this.reviewStrategy = MemorizationReviewStrategy.spaced,
  });
  final String id;
  final String title;
  final QuranCoordinate start;
  final QuranCoordinate end;
  final DateTime createdAt;
  final DateTime? targetDate;
  final Set<int> preferredStudyDays;
  final MemorizationPlanStatus status;
  final int dailyNewAyahTarget;
  final MemorizationReviewStrategy reviewStrategy;
  int get totalAyahs => QuranRange.coordinates(start, end).length;
  DateTime estimatedCompletion(DateTime from, {int completed = 0}) {
    var remaining = (totalAyahs - completed).clamp(0, totalAyahs);
    var date = DateTime.utc(from.year, from.month, from.day);
    while (remaining > 0) {
      if (preferredStudyDays.isEmpty ||
          preferredStudyDays.contains(date.weekday)) {
        remaining -= dailyNewAyahTarget;
      }
      if (remaining > 0) date = date.add(const Duration(days: 1));
    }
    return date;
  }

  MemorizationPlan copyWith({
    MemorizationPlanStatus? status,
    String? title,
    DateTime? targetDate,
    bool clearTargetDate = false,
    Set<int>? preferredStudyDays,
    int? dailyNewAyahTarget,
  }) => MemorizationPlan(
    id: id,
    title: title ?? this.title,
    start: start,
    end: end,
    createdAt: createdAt,
    targetDate: clearTargetDate ? null : targetDate ?? this.targetDate,
    preferredStudyDays: preferredStudyDays ?? this.preferredStudyDays,
    status: status ?? this.status,
    dailyNewAyahTarget: dailyNewAyahTarget ?? this.dailyNewAyahTarget,
    reviewStrategy: reviewStrategy,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'start': start.toJson(),
    'end': end.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'targetDate': targetDate?.toUtc().toIso8601String(),
    'days': preferredStudyDays.toList()..sort(),
    'status': status.name,
    'dailyTarget': dailyNewAyahTarget,
    'reviewStrategy': reviewStrategy.name,
  };
  static MemorizationPlan? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final start = QuranCoordinate.fromJson(value['start']);
    final end = QuranCoordinate.fromJson(value['end']);
    final created = DateTime.tryParse('${value['createdAt']}');
    final target = value['targetDate'] == null
        ? null
        : DateTime.tryParse('${value['targetDate']}');
    final status = MemorizationPlanStatus.values
        .where((e) => e.name == value['status'])
        .firstOrNull;
    final strategy = MemorizationReviewStrategy.values
        .where((e) => e.name == value['reviewStrategy'])
        .firstOrNull;
    final days =
        (value['days'] as List?)
            ?.whereType<int>()
            .where((d) => d >= 1 && d <= 7)
            .toSet() ??
        <int>{};
    if (value['id'] is! String ||
        (value['id'] as String).isEmpty ||
        value['title'] is! String ||
        start == null ||
        end == null ||
        !QuranRange.valid(start, end) ||
        created == null ||
        status == null ||
        strategy == null ||
        value['dailyTarget'] is! int ||
        (value['dailyTarget'] as int) < 1 ||
        (value['targetDate'] != null && target == null)) {
      return null;
    }
    return MemorizationPlan(
      id: value['id'] as String,
      title: value['title'] as String,
      start: start,
      end: end,
      createdAt: created.toUtc(),
      targetDate: target?.toUtc(),
      preferredStudyDays: days,
      status: status,
      dailyNewAyahTarget: value['dailyTarget'] as int,
      reviewStrategy: strategy,
    );
  }
}

class MemorizedAyah {
  const MemorizedAyah({
    required this.coordinate,
    required this.planId,
    required this.firstMemorizedAt,
    required this.lastReviewedAt,
    required this.nextReviewAt,
    required this.reviewLevel,
    required this.successfulReviews,
    required this.failedReviews,
  });
  final QuranCoordinate coordinate;
  final String planId;
  final DateTime firstMemorizedAt;
  final DateTime lastReviewedAt;
  final DateTime nextReviewAt;
  final int reviewLevel;
  final int successfulReviews;
  final int failedReviews;
  MemorizedAyah copyWith({
    DateTime? lastReviewedAt,
    DateTime? nextReviewAt,
    int? reviewLevel,
    int? successfulReviews,
    int? failedReviews,
  }) => MemorizedAyah(
    coordinate: coordinate,
    planId: planId,
    firstMemorizedAt: firstMemorizedAt,
    lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    nextReviewAt: nextReviewAt ?? this.nextReviewAt,
    reviewLevel: reviewLevel ?? this.reviewLevel,
    successfulReviews: successfulReviews ?? this.successfulReviews,
    failedReviews: failedReviews ?? this.failedReviews,
  );
  Map<String, Object> toJson() => {
    'coordinate': coordinate.toJson(),
    'planId': planId,
    'firstMemorizedAt': firstMemorizedAt.toUtc().toIso8601String(),
    'lastReviewedAt': lastReviewedAt.toUtc().toIso8601String(),
    'nextReviewAt': nextReviewAt.toUtc().toIso8601String(),
    'reviewLevel': reviewLevel,
    'successfulReviews': successfulReviews,
    'failedReviews': failedReviews,
  };
  static MemorizedAyah? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final c = QuranCoordinate.fromJson(value['coordinate']);
    final first = DateTime.tryParse('${value['firstMemorizedAt']}');
    final last = DateTime.tryParse('${value['lastReviewedAt']}');
    final next = DateTime.tryParse('${value['nextReviewAt']}');
    if (c == null ||
        value['planId'] is! String ||
        first == null ||
        last == null ||
        next == null ||
        value['reviewLevel'] is! int ||
        value['successfulReviews'] is! int ||
        value['failedReviews'] is! int) {
      return null;
    }
    final level = value['reviewLevel'] as int;
    if (level < 0 || level > 5) return null;
    return MemorizedAyah(
      coordinate: c,
      planId: value['planId'] as String,
      firstMemorizedAt: first.toUtc(),
      lastReviewedAt: last.toUtc(),
      nextReviewAt: next.toUtc(),
      reviewLevel: level,
      successfulReviews: value['successfulReviews'] as int,
      failedReviews: value['failedReviews'] as int,
    );
  }
}

class MemorizationSession {
  const MemorizationSession({
    required this.id,
    required this.planId,
    required this.startedAt,
    this.completedAt,
    required this.newAyahs,
    required this.reviewAyahs,
    required this.results,
    this.mode = MemorizationSessionMode.newMemorization,
    this.testMode = MemorizationTestMode.fullAyah,
  });
  final String id;
  final String planId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final List<QuranCoordinate> newAyahs;
  final List<QuranCoordinate> reviewAyahs;
  final Map<String, MemorizationSessionResult> results;
  final MemorizationSessionMode mode;
  final MemorizationTestMode testMode;
  bool get isCompleted => completedAt != null;
  MemorizationSession copyWith({
    DateTime? completedAt,
    Map<String, MemorizationSessionResult>? results,
    MemorizationSessionMode? mode,
    MemorizationTestMode? testMode,
  }) => MemorizationSession(
    id: id,
    planId: planId,
    startedAt: startedAt,
    completedAt: completedAt ?? this.completedAt,
    newAyahs: newAyahs,
    reviewAyahs: reviewAyahs,
    results: results ?? this.results,
    mode: mode ?? this.mode,
    testMode: testMode ?? this.testMode,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'planId': planId,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'completedAt': completedAt?.toUtc().toIso8601String(),
    'newAyahs': newAyahs.map((e) => e.toJson()).toList(),
    'reviewAyahs': reviewAyahs.map((e) => e.toJson()).toList(),
    'results': {for (final e in results.entries) e.key: e.value.name},
    'mode': mode.name,
    'testMode': testMode.name,
  };
  static MemorizationSession? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final started = DateTime.tryParse('${value['startedAt']}');
    final completed = value['completedAt'] == null
        ? null
        : DateTime.tryParse('${value['completedAt']}');
    final newAyahs = (value['newAyahs'] as List?)
        ?.map(QuranCoordinate.fromJson)
        .toList();
    final reviews = (value['reviewAyahs'] as List?)
        ?.map(QuranCoordinate.fromJson)
        .toList();
    if (value['id'] is! String ||
        value['planId'] is! String ||
        started == null ||
        newAyahs == null ||
        reviews == null ||
        newAyahs.any((e) => e == null) ||
        reviews.any((e) => e == null) ||
        (value['completedAt'] != null && completed == null)) {
      return null;
    }
    final results = <String, MemorizationSessionResult>{};
    final raw = value['results'];
    if (raw is Map<String, dynamic>) {
      for (final e in raw.entries) {
        final result = MemorizationSessionResult.values
            .where((v) => v.name == e.value)
            .firstOrNull;
        if (result != null) results[e.key] = result;
      }
    }
    final mode = MemorizationSessionMode.values
        .where((e) => e.name == value['mode'])
        .firstOrNull;
    final testMode = MemorizationTestMode.values
        .where((e) => e.name == value['testMode'])
        .firstOrNull;
    return MemorizationSession(
      id: value['id'] as String,
      planId: value['planId'] as String,
      startedAt: started.toUtc(),
      completedAt: completed?.toUtc(),
      newAyahs: newAyahs.cast<QuranCoordinate>(),
      reviewAyahs: reviews.cast<QuranCoordinate>(),
      results: results,
      mode: mode ?? MemorizationSessionMode.newMemorization,
      testMode: testMode ?? MemorizationTestMode.fullAyah,
    );
  }
}

class MemorizationProgress {
  const MemorizationProgress({
    required this.planId,
    required this.completedNewAyahs,
    required this.reviewedAyahs,
    this.lastSessionAt,
    this.currentCoordinate,
  });
  final String planId;
  final int completedNewAyahs;
  final int reviewedAyahs;
  final DateTime? lastSessionAt;
  final QuranCoordinate? currentCoordinate;
}
