import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/data/models/memorization.dart';
import 'package:quran_app/data/repositories/memorization_repository.dart';
import 'package:quran_app/features/memorization/memorization_controller.dart';
import 'package:quran_app/features/memorization/memorization_review_scheduler.dart';

void main() {
  final now = DateTime.utc(2026, 8, 13, 9);
  test('whole-surah and cross-surah ranges use canonical coordinates', () {
    expect(
      QuranRange.coordinates(
        const QuranCoordinate(67, 1),
        const QuranCoordinate(67, 30),
      ).length,
      30,
    );
    expect(
      QuranRange.coordinates(
        const QuranCoordinate(1, 6),
        const QuranCoordinate(2, 2),
      ).map((e) => e.key),
      ['1:6', '1:7', '2:1', '2:2'],
    );
    expect(
      QuranRange.valid(
        const QuranCoordinate(2, 2),
        const QuranCoordinate(1, 7),
      ),
      isFalse,
    );
    expect(const QuranCoordinate(1, 8).isValid, isFalse);
  });

  test('review scheduler covers intervals, success, and failure', () {
    final scheduler = MemorizationReviewScheduler();
    expect(
      List.generate(
        6,
        (i) => scheduler
            .dueAt(i, now)
            .difference(DateTime.utc(2026, 8, 13))
            .inDays,
      ),
      [1, 2, 4, 7, 14, 30],
    );
    final ayah = MemorizedAyah(
      coordinate: const QuranCoordinate(67, 1),
      planId: 'p',
      firstMemorizedAt: now,
      lastReviewedAt: now,
      nextReviewAt: now,
      reviewLevel: 2,
      successfulReviews: 1,
      failedReviews: 0,
    );
    expect(scheduler.success(ayah, now).reviewLevel, 3);
    expect(
      scheduler.success(ayah, now).nextReviewAt,
      DateTime.utc(2026, 8, 20),
    );
    expect(scheduler.failure(ayah, now).reviewLevel, 1);
    expect(
      scheduler.failure(ayah, now).nextReviewAt,
      DateTime.utc(2026, 8, 14),
    );
  });

  test(
    'repository round trip is versioned and rejects malformed data',
    () async {
      final store = _Store();
      final repository = MemorizationRepository(store: store);
      final plan = _plan(now);
      await repository.createPlan(plan);
      final loaded = await MemorizationRepository(store: store).load();
      expect(loaded.plans.single.id, plan.id);
      expect(store.value, contains('"version":2'));
      store.value = '{bad';
      expect(
        (await MemorizationRepository(store: store).load()).plans,
        isEmpty,
      );
      store.value = '{"version":99,"plans":[]}';
      expect(
        (await MemorizationRepository(store: store).load()).plans,
        isEmpty,
      );
    },
  );

  test(
    'controller creates real workload, session, progress and review due state',
    () async {
      var clock = now;
      final store = _Store();
      final controller = MemorizationController(
        repository: MemorizationRepository(store: store),
        clock: () => clock,
      );
      await controller.load();
      final plan = await controller.createPlan(
        title: 'الملك',
        start: const QuranCoordinate(67, 1),
        end: const QuranCoordinate(67, 30),
        dailyNewAyahTarget: 5,
      );
      expect(plan.totalAyahs, 30);
      expect(plan.estimatedCompletion(now), DateTime.utc(2026, 8, 18));
      final session = await controller.generateTodaySession();
      expect(session!.newAyahs.length, 5);
      expect(session.reviewAyahs, isEmpty);
      await controller.markAyahMemorized(const QuranCoordinate(67, 1));
      expect(controller.completedFor(plan), 1);
      expect(controller.progressFor(plan), closeTo(1 / 30, .0001));
      await controller.completeSession();
      expect(controller.todaySession, isNull);
      clock = DateTime.utc(2026, 8, 14, 10);
      expect(controller.dueReviewAyahs.single.coordinate.key, '67:1');
      final review = await controller.generateTodaySession();
      expect(review!.reviewAyahs.single.key, '67:1');
      await controller.recordReviewSuccess(const QuranCoordinate(67, 1));
      expect(controller.memorizedAyahs.single.reviewLevel, 1);
    },
  );

  test(
    'controller rejects invalid ranges and derives daily target from date',
    () async {
      final c = MemorizationController(
        repository: MemorizationRepository(store: _Store()),
        clock: () => now,
      );
      await c.load();
      expect(
        () => c.createPlan(
          title: 'bad',
          start: const QuranCoordinate(2, 2),
          end: const QuranCoordinate(1, 1),
          dailyNewAyahTarget: 1,
        ),
        throwsArgumentError,
      );
      final plan = await c.createPlan(
        title: 'dated',
        start: const QuranCoordinate(67, 1),
        end: const QuranCoordinate(67, 30),
        targetDate: now.add(const Duration(days: 14)),
      );
      expect(plan.dailyNewAyahTarget, 3);
    },
  );

  test('failed first attempt is recorded without fake progress', () async {
    final controller = MemorizationController(
      repository: MemorizationRepository(store: _Store()),
      clock: () => now,
    );
    await controller.load();
    final plan = await controller.createPlan(
      title: 'honest',
      start: const QuranCoordinate(67, 1),
      end: const QuranCoordinate(67, 2),
      dailyNewAyahTarget: 1,
    );
    await controller.generateTodaySession();
    await controller.markAyahMemorized(
      const QuranCoordinate(67, 1),
      result: MemorizationSessionResult.notMastered,
    );
    expect(controller.completedFor(plan), 0);
    expect(controller.progressFor(plan), 0);
    expect(
      controller.todaySession!.results['67:1'],
      MemorizationSessionResult.notMastered,
    );
  });

  test('plan editing preserves range and recalculates schedule', () async {
    final c = MemorizationController(
      repository: MemorizationRepository(store: _Store()),
      clock: () => now,
    );
    await c.load();
    final p = await c.createPlan(
      title: 'old',
      start: const QuranCoordinate(67, 1),
      end: const QuranCoordinate(67, 30),
      dailyNewAyahTarget: 5,
    );
    await c.editPlan(
      p.id,
      title: 'new',
      preferredStudyDays: {1, 3, 5},
      dailyNewAyahTarget: 3,
    );
    final edited = c.activePlan!;
    expect(edited.title, 'new');
    expect(edited.start, p.start);
    expect(edited.end, p.end);
    expect(edited.preferredStudyDays, {1, 3, 5});
    expect(
      edited.estimatedCompletion(now).isAfter(p.estimatedCompletion(now)),
      isTrue,
    );
  });
  test('session is resumable and abandon removes only open session', () async {
    final store = _Store();
    final c = MemorizationController(
      repository: MemorizationRepository(store: store),
      clock: () => now,
    );
    await c.load();
    await c.createPlan(
      title: 'p',
      start: const QuranCoordinate(67, 1),
      end: const QuranCoordinate(67, 5),
      dailyNewAyahTarget: 2,
    );
    final s = await c.generateTodaySession();
    await c.markAyahMemorized(s!.newAyahs.first);
    final resumed = MemorizationController(
      repository: MemorizationRepository(store: store),
      clock: () => now,
    );
    await resumed.load();
    expect(resumed.todaySession!.results.containsKey('67:1'), isTrue);
    expect(resumed.completedFor(resumed.activePlan!), 1);
    await resumed.abandonSession();
    expect(resumed.todaySession, isNull);
    expect(resumed.completedFor(resumed.activePlan!), 1);
  });
  test('completed sessions appear in real history', () async {
    final c = MemorizationController(
      repository: MemorizationRepository(store: _Store()),
      clock: () => now,
    );
    await c.load();
    final p = await c.createPlan(
      title: 'p',
      start: const QuranCoordinate(67, 1),
      end: const QuranCoordinate(67, 2),
      dailyNewAyahTarget: 1,
    );
    await c.generateTodaySession();
    await c.markAyahMemorized(const QuranCoordinate(67, 1));
    await c.completeSession();
    expect(c.historyFor(p.id).single.isCompleted, isTrue);
  });
}

MemorizationPlan _plan(DateTime now) => MemorizationPlan(
  id: 'p',
  title: 'test',
  start: const QuranCoordinate(67, 1),
  end: const QuranCoordinate(67, 30),
  createdAt: now,
  preferredStudyDays: const {1, 2, 3, 4, 5, 6, 7},
  status: MemorizationPlanStatus.active,
  dailyNewAyahTarget: 5,
);

class _Store implements MemorizationStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}
