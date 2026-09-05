import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/services/notification_service.dart';
import 'package:quran_app/data/models/app_settings.dart';
import 'package:quran_app/data/models/khatma.dart';
import 'package:quran_app/data/repositories/khatma_repository.dart';
import 'package:quran_app/features/khatma/khatma_controller.dart';
import 'package:quran_app/features/settings/worship_notification_scheduler.dart';

void main() {
  group('Khatma Planner V1', () {
    test('30/60/90-day quick plans have correct inclusive targets', () async {
      final controller = _controller(DateTime(2026, 8, 14));
      await controller.load();
      expect(
        controller
            .preview(type: KhatmaPlanType.thirtyDays, startPage: 1)
            .targetDate,
        DateTime(2026, 9, 12),
      );
      expect(
        controller
            .preview(type: KhatmaPlanType.sixtyDays, startPage: 1)
            .targetDate,
        DateTime(2026, 10, 12),
      );
      expect(
        controller
            .preview(type: KhatmaPlanType.ninetyDays, startPage: 1)
            .targetDate,
        DateTime(2026, 11, 11),
      );
    });

    test('custom target and current-page start are respected', () async {
      final controller = _controller(DateTime(2026, 8, 14));
      await controller.load();
      final plan = await controller.create(
        title: 'من موضعي',
        type: KhatmaPlanType.custom,
        startPage: 42,
        customTarget: DateTime(2026, 8, 23),
      );
      expect(plan.startPage, 42);
      expect(plan.targetDate, DateTime(2026, 8, 23));
      expect(plan.days.first.plannedStartPage, 42);
    });

    test('distribution covers each page exactly once with fair remainder', () {
      final days = distributeKhatmaPages(
        startPage: 1,
        startDate: DateTime(2026, 1, 1),
        targetDate: DateTime(2026, 1, 30),
      );
      final pages = [
        for (final day in days)
          for (
            var page = day.plannedStartPage;
            page <= day.plannedEndPage;
            page++
          )
            page,
      ];
      expect(pages, List.generate(604, (i) => i + 1));
      expect(pages.toSet(), hasLength(604));
      final sizes = days
          .map((d) => d.plannedEndPage - d.plannedStartPage + 1)
          .toSet();
      expect(sizes.difference({20, 21}), isEmpty);
    });

    test(
      'missed days redistribute remaining pages and preserve completion',
      () async {
        var now = DateTime(2026, 8, 14);
        final store = _MemoryKhatmaStore();
        final controller = KhatmaController(
          repository: KhatmaRepository(store: store),
          clock: () => now,
        );
        await controller.load();
        await controller.create(
          title: 'ختمة',
          type: KhatmaPlanType.thirtyDays,
          startPage: 1,
        );
        await controller.confirmTodayCompleted();
        final completedEnd = controller.activePlan!.days.first.plannedEndPage;
        now = DateTime(2026, 8, 17);
        expect(await controller.redistributeMissedDays(), isTrue);
        expect(controller.message, 'تم تحديث وردك اليومي');
        expect(
          controller.activePlan!.days.first.completedThroughPage,
          completedEnd,
        );
        expect(controller.today!.plannedStartPage, completedEnd + 1);
      },
    );

    test(
      'progress only advances within today range and can complete plan',
      () async {
        final controller = _controller(DateTime(2026, 8, 14));
        await controller.load();
        await controller.create(
          title: 'قصيرة',
          type: KhatmaPlanType.custom,
          startPage: 600,
          customTarget: DateTime(2026, 8, 14),
        );
        await controller.recordReachedPage(599);
        expect(controller.today!.completedThroughPage, isNull);
        await controller.recordReachedPage(604);
        expect(
          calculateKhatmaProgress(
            controller.history.single,
            DateTime(2026, 8, 14),
          ).remainingPages,
          0,
        );
        expect(controller.history.single.status, KhatmaPlanStatus.completed);
        expect(controller.activePlan, isNull);
      },
    );

    test(
      'versioned persistence round trips and malformed data recovers',
      () async {
        final store = _MemoryKhatmaStore();
        final first = KhatmaController(
          repository: KhatmaRepository(store: store),
          clock: () => DateTime(2026, 8, 14),
        );
        await first.load();
        await first.create(
          title: 'محفوظة',
          type: KhatmaPlanType.sixtyDays,
          startPage: 12,
        );
        final second = KhatmaController(
          repository: KhatmaRepository(store: store),
          clock: () => DateTime(2026, 8, 14),
        );
        await second.load();
        expect(second.activePlan?.title, 'محفوظة');
        expect(second.activePlan?.startPage, 12);
        store.value = '{broken';
        expect(await KhatmaRepository(store: store).load(), isEmpty);
      },
    );

    test(
      'optional reminder is deterministic and suppressed after completion',
      () async {
        final controller = _controller(DateTime(2026, 8, 14, 10));
        await controller.load();
        await controller.create(
          title: 'ختمة',
          type: KhatmaPlanType.thirtyDays,
          startPage: 1,
          reminder: const ReminderTime(20, 0),
        );
        final gateway = FakeNotificationService();
        await WorshipNotificationScheduler(gateway).reschedule(
          const AppSettings(),
          prayers: const [],
          khatma: controller,
          now: DateTime(2026, 8, 14, 10),
          groups: {NotificationScheduleGroup.khatma},
        );
        expect(gateway.scheduled.keys, {NotificationIds.khatma});
        await controller.confirmTodayCompleted();
        await WorshipNotificationScheduler(gateway).reschedule(
          const AppSettings(),
          prayers: const [],
          khatma: controller,
          now: DateTime(2026, 8, 14, 10),
          groups: {NotificationScheduleGroup.khatma},
        );
        expect(gateway.scheduled, isEmpty);
      },
    );
  });
}

KhatmaController _controller(DateTime now) => KhatmaController(
  repository: KhatmaRepository(store: _MemoryKhatmaStore()),
  clock: () => now,
);

class _MemoryKhatmaStore implements KhatmaStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}
