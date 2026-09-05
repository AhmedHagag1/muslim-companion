import 'package:flutter/foundation.dart';
import '../../data/models/memorization.dart';
import '../../data/repositories/memorization_repository.dart';
import 'memorization_review_scheduler.dart';

class MemorizationController extends ChangeNotifier {
  MemorizationController({
    MemorizationRepository? repository,
    MemorizationReviewScheduler? scheduler,
    DateTime Function()? clock,
  }) : _repository = repository ?? MemorizationRepository(),
       _scheduler = scheduler ?? MemorizationReviewScheduler(),
       _clock = clock ?? DateTime.now;
  final MemorizationRepository _repository;
  final MemorizationReviewScheduler _scheduler;
  final DateTime Function() _clock;
  List<MemorizationPlan> _plans = [];
  List<MemorizedAyah> _ayahs = [];
  List<MemorizationSession> _sessions = [];
  bool isLoaded = false;
  List<MemorizationPlan> get plans => List.unmodifiable(_plans);
  List<MemorizationSession> get sessions => List.unmodifiable(_sessions);
  List<MemorizedAyah> get memorizedAyahs => List.unmodifiable(_ayahs);
  MemorizationPlan? get activePlan => _plans
      .where((e) => e.status == MemorizationPlanStatus.active)
      .firstOrNull;
  MemorizationSession? get todaySession {
    final p = activePlan;
    if (p == null) return null;
    final now = _clock().toUtc();
    return _sessions
        .where(
          (e) =>
              e.planId == p.id && !e.isCompleted && _sameDay(e.startedAt, now),
        )
        .firstOrNull;
  }

  List<MemorizedAyah> get dueReviewAyahs {
    final p = activePlan;
    if (p == null) return const [];
    final now = _clock().toUtc();
    return _ayahs
        .where((e) => e.planId == p.id && !e.nextReviewAt.isAfter(now))
        .toList()
      ..sort((a, b) => a.nextReviewAt.compareTo(b.nextReviewAt));
  }

  List<MemorizedAyah> get weakReviewAyahs {
    final p = activePlan;
    if (p == null) return const [];
    final now = _clock().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    return _ayahs
        .where(
          (e) =>
              e.planId == p.id &&
              (e.failedReviews > 0 || e.nextReviewAt.isBefore(today)),
        )
        .toList()
      ..sort((a, b) {
        final failures = b.failedReviews.compareTo(a.failedReviews);
        return failures != 0
            ? failures
            : a.nextReviewAt.compareTo(b.nextReviewAt);
      });
  }

  int completedFor(MemorizationPlan plan) => _ayahs
      .where((e) => e.planId == plan.id)
      .map((e) => e.coordinate)
      .toSet()
      .length;
  double progressFor(MemorizationPlan plan) =>
      plan.totalAyahs == 0 ? 0 : completedFor(plan) / plan.totalAyahs;
  int get todayRemainingNew =>
      todaySession?.newAyahs
          .where((e) => !todaySession!.results.containsKey(e.key))
          .length ??
      activePlan?.dailyNewAyahTarget ??
      0;
  List<MemorizationSession> historyFor(String planId) =>
      _sessions.where((e) => e.planId == planId && e.isCompleted).toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  Future<void> load() async {
    final d = await _repository.load();
    _plans = [...d.plans];
    _ayahs = [...d.ayahs];
    _sessions = [...d.sessions];
    isLoaded = true;
    notifyListeners();
  }

  Future<MemorizationPlan> createPlan({
    required String title,
    required QuranCoordinate start,
    required QuranCoordinate end,
    DateTime? targetDate,
    int? dailyNewAyahTarget,
    Set<int> preferredStudyDays = const {1, 2, 3, 4, 5, 6, 7},
  }) async {
    if (title.trim().isEmpty || !QuranRange.valid(start, end)) {
      throw ArgumentError('Invalid plan');
    }
    final now = _clock().toUtc();
    final total = QuranRange.coordinates(start, end).length;
    final target = targetDate?.toUtc();
    if (target != null && !target.isAfter(now)) {
      throw ArgumentError('Target date must be future');
    }
    final targetDays = target
        ?.difference(DateTime.utc(now.year, now.month, now.day))
        .inDays
        .clamp(1, 99999);
    final daily = dailyNewAyahTarget ?? ((total / (targetDays!)).ceil());
    if (daily < 1) throw ArgumentError('Daily target must be positive');
    final plan = MemorizationPlan(
      id: 'plan-${now.microsecondsSinceEpoch}',
      title: title.trim(),
      start: start,
      end: end,
      createdAt: now,
      targetDate: target,
      preferredStudyDays: preferredStudyDays,
      status: _plans.any((e) => e.status == MemorizationPlanStatus.active)
          ? MemorizationPlanStatus.paused
          : MemorizationPlanStatus.active,
      dailyNewAyahTarget: daily,
    );
    await _repository.createPlan(plan);
    _plans.add(plan);
    notifyListeners();
    return plan;
  }

  Future<void> activatePlan(String id) async {
    for (var i = 0; i < _plans.length; i++) {
      final next = _plans[i].copyWith(
        status: _plans[i].id == id
            ? MemorizationPlanStatus.active
            : (_plans[i].status == MemorizationPlanStatus.active
                  ? MemorizationPlanStatus.paused
                  : _plans[i].status),
      );
      _plans[i] = next;
      await _repository.updatePlan(next);
    }
    notifyListeners();
  }

  Future<void> editPlan(
    String id, {
    required String title,
    required Set<int> preferredStudyDays,
    required int dailyNewAyahTarget,
    DateTime? targetDate,
  }) async {
    final i = _plans.indexWhere((e) => e.id == id);
    if (i < 0 ||
        title.trim().isEmpty ||
        dailyNewAyahTarget < 1 ||
        preferredStudyDays.any((d) => d < 1 || d > 7)) {
      throw ArgumentError('Invalid plan update');
    }
    final next = _plans[i].copyWith(
      title: title.trim(),
      preferredStudyDays: preferredStudyDays,
      dailyNewAyahTarget: dailyNewAyahTarget,
      targetDate: targetDate,
      clearTargetDate: targetDate == null,
    );
    _plans[i] = next;
    await _repository.updatePlan(next);
    notifyListeners();
  }

  Future<void> abandonSession() async {
    final s = todaySession;
    if (s == null) return;
    await _repository.deleteSession(s.id);
    _sessions.removeWhere((e) => e.id == s.id);
    notifyListeners();
  }

  Future<MemorizationSession?> generateTodaySession() async {
    final existing = todaySession;
    if (existing != null) return existing;
    final plan = activePlan;
    if (plan == null) return null;
    final memorized = _ayahs
        .where((e) => e.planId == plan.id)
        .map((e) => e.coordinate)
        .toSet();
    final isStudyDay =
        plan.preferredStudyDays.isEmpty ||
        plan.preferredStudyDays.contains(_clock().toUtc().weekday);
    final fresh = isStudyDay
        ? QuranRange.coordinates(plan.start, plan.end)
              .where((e) => !memorized.contains(e))
              .take(plan.dailyNewAyahTarget)
              .toList()
        : <QuranCoordinate>[];
    final due = dueReviewAyahs.map((e) => e.coordinate).toList();
    if (fresh.isEmpty && due.isEmpty) return null;
    final now = _clock().toUtc();
    final session = MemorizationSession(
      id: 'session-${now.microsecondsSinceEpoch}',
      planId: plan.id,
      startedAt: now,
      newAyahs: fresh,
      reviewAyahs: due,
      results: const {},
      mode: fresh.isNotEmpty
          ? MemorizationSessionMode.newMemorization
          : MemorizationSessionMode.nearReview,
    );
    await _repository.saveSession(session);
    _sessions.add(session);
    notifyListeners();
    return session;
  }

  Future<MemorizationSession?> generateSession(
    MemorizationSessionMode mode, {
    MemorizationTestMode testMode = MemorizationTestMode.fullAyah,
  }) async {
    final existing = todaySession;
    if (existing != null) return existing;
    final plan = activePlan;
    if (plan == null) return null;
    final memorized = _ayahs.where((e) => e.planId == plan.id).toList();
    final known = memorized.map((e) => e.coordinate).toSet();
    final due = dueReviewAyahs;
    List<QuranCoordinate> fresh = const [];
    List<QuranCoordinate> review = const [];
    switch (mode) {
      case MemorizationSessionMode.newMemorization:
        fresh = QuranRange.coordinates(plan.start, plan.end)
            .where((e) => !known.contains(e))
            .take(plan.dailyNewAyahTarget)
            .toList();
      case MemorizationSessionMode.nearReview:
        review = due
            .where((e) => e.reviewLevel <= 2)
            .map((e) => e.coordinate)
            .toList();
      case MemorizationSessionMode.oldReview:
        review = due
            .where((e) => e.reviewLevel > 2)
            .map((e) => e.coordinate)
            .toList();
      case MemorizationSessionMode.selfTest:
        final candidates = [...weakReviewAyahs, ...memorized];
        review = candidates.map((e) => e.coordinate).toSet().take(10).toList();
    }
    if (fresh.isEmpty && review.isEmpty) return null;
    final now = _clock().toUtc();
    final session = MemorizationSession(
      id: 'session-${now.microsecondsSinceEpoch}',
      planId: plan.id,
      startedAt: now,
      newAyahs: fresh,
      reviewAyahs: review,
      results: const {},
      mode: mode,
      testMode: testMode,
    );
    await _repository.saveSession(session);
    _sessions.add(session);
    notifyListeners();
    return session;
  }

  Future<void> markAyahMemorized(
    QuranCoordinate c, {
    MemorizationSessionResult result = MemorizationSessionResult.mastered,
  }) async {
    final p = activePlan;
    if (p == null || !QuranRange.coordinates(p.start, p.end).contains(c)) {
      throw ArgumentError('Coordinate outside active plan');
    }
    final now = _clock().toUtc();
    var ayah = _ayahs
        .where((e) => e.planId == p.id && e.coordinate == c)
        .firstOrNull;
    if (ayah == null && result == MemorizationSessionResult.mastered) {
      ayah = MemorizedAyah(
        coordinate: c,
        planId: p.id,
        firstMemorizedAt: now,
        lastReviewedAt: now,
        nextReviewAt: _scheduler.dueAt(0, now),
        reviewLevel: 0,
        successfulReviews: 1,
        failedReviews: 0,
      );
      _ayahs.add(ayah);
    }
    if (ayah != null) await _repository.saveMemorizedAyah(ayah);
    await _recordResult(c, result);
    notifyListeners();
  }

  Future<void> recordReviewSuccess(QuranCoordinate c) => _review(c, true);
  Future<void> recordReviewFailure(QuranCoordinate c) => _review(c, false);
  Future<void> _review(QuranCoordinate c, bool success) async {
    final i = _ayahs.indexWhere(
      (e) => e.coordinate == c && e.planId == activePlan?.id,
    );
    if (i < 0) throw ArgumentError('Ayah not memorized');
    final next = success
        ? _scheduler.success(_ayahs[i], _clock())
        : _scheduler.failure(_ayahs[i], _clock());
    _ayahs[i] = next;
    await _repository.saveMemorizedAyah(next);
    await _recordResult(
      c,
      success
          ? MemorizationSessionResult.mastered
          : MemorizationSessionResult.needsReview,
    );
    notifyListeners();
  }

  Future<void> recordReviewRating(
    QuranCoordinate c,
    MemorizationSessionResult result,
  ) async {
    final i = _ayahs.indexWhere(
      (e) => e.coordinate == c && e.planId == activePlan?.id,
    );
    if (i < 0) throw ArgumentError('Ayah not memorized');
    final next = _scheduler.rate(_ayahs[i], result, _clock());
    _ayahs[i] = next;
    await _repository.saveMemorizedAyah(next);
    await _recordResult(c, result);
    notifyListeners();
  }

  DateTime? get nextScheduledReview {
    final values =
        _ayahs
            .where((e) => e.planId == activePlan?.id)
            .map((e) => e.nextReviewAt)
            .toList()
          ..sort();
    return values.firstOrNull;
  }

  Future<void> _recordResult(
    QuranCoordinate c,
    MemorizationSessionResult result,
  ) async {
    final s = todaySession;
    if (s == null) return;
    final updated = s.copyWith(results: {...s.results, c.key: result});
    final i = _sessions.indexWhere((e) => e.id == s.id);
    _sessions[i] = updated;
    await _repository.saveSession(updated);
  }

  Future<void> completeSession() async {
    final s = todaySession;
    if (s == null) return;
    final updated = s.copyWith(completedAt: _clock().toUtc());
    final i = _sessions.indexWhere((e) => e.id == s.id);
    _sessions[i] = updated;
    await _repository.saveSession(updated);
    notifyListeners();
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.toUtc().year == b.toUtc().year &&
      a.toUtc().month == b.toUtc().month &&
      a.toUtc().day == b.toUtc().day;
}
