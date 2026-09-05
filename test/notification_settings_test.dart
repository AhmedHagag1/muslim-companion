import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/services/notification_service.dart';
import 'package:quran_app/core/services/prayer_times_service.dart';
import 'package:quran_app/data/models/app_settings.dart';
import 'package:quran_app/data/models/memorization.dart';
import 'package:quran_app/data/repositories/app_settings_repository.dart';
import 'package:quran_app/data/repositories/memorization_repository.dart';
import 'package:quran_app/features/memorization/memorization_controller.dart';
import 'package:quran_app/features/prayer/prayer_controller.dart';
import 'package:quran_app/features/settings/notification_routing.dart';
import 'package:quran_app/features/settings/settings_controller.dart';
import 'package:quran_app/features/settings/worship_notification_scheduler.dart';

void main() {
  final now = DateTime(2026, 8, 13, 6);
  test('notification defaults are all off and persist round trip', () async {
    const s = AppSettings();
    expect(s.anyNotificationEnabled, isFalse);
    expect(s.prayerNotifications, isFalse);
    expect(s.prayers.values.every((e) => !e.adhan), isTrue);
    final store = _SettingsStore();
    await AppSettingsRepository(
      store: store,
    ).save(s.copyWith(wird: true, morningAdhkar: true));
    final loaded = await AppSettingsRepository(store: store).load();
    expect(loaded.wird, isTrue);
    expect(loaded.morningAdhkar, isTrue);
  });
  test('deterministic ids remain stable', () {
    expect(NotificationIds.prayer('الفجر'), 1001);
    expect(NotificationIds.prayer('الفجر', before: true), 1101);
    expect(NotificationIds.salawat(2), 2002);
  });
  test(
    'prayer scheduler skips sunrise and disabled prayer and calculates before time',
    () async {
      final fake = FakeNotificationService();
      final prayers = [
        PrayerTimeItem(name: 'الفجر', time: DateTime(2026, 8, 13, 7)),
        PrayerTimeItem(name: 'الشروق', time: DateTime(2026, 8, 13, 8)),
        PrayerTimeItem(name: 'الظهر', time: DateTime(2026, 8, 13, 12)),
      ];
      final settings = AppSettings(
        prayerNotifications: true,
        prayers: {
          ...AppSettings.defaultPrayers,
          'الفجر': const PrayerReminderSettings(beforeMinutes: 15),
          'الظهر': const PrayerReminderSettings(enabled: false),
        },
      );
      await WorshipNotificationScheduler(
        fake,
      ).reschedule(settings, prayers: prayers, now: now);
      expect(fake.scheduled.keys, {1001, 1101});
      expect(fake.scheduled[1101]!.at, DateTime(2026, 8, 13, 6, 45));
      expect(fake.cancelled.length, WorshipNotificationScheduler.allIds.length);
    },
  );
  test(
    'salawat 1 3 5 custom, adhkar and wird schedule without duplicates',
    () async {
      for (final pair in [
        (SalawatFrequency.once, 1),
        (SalawatFrequency.three, 3),
        (SalawatFrequency.five, 5),
      ]) {
        final fake = FakeNotificationService();
        await WorshipNotificationScheduler(fake).reschedule(
          AppSettings(
            salawat: true,
            salawatFrequency: pair.$1,
            morningAdhkar: true,
            eveningAdhkar: true,
            wird: true,
          ),
          prayers: const [],
          now: now,
        );
        expect(
          fake.scheduled.values.where((e) => e.payload == 'salawat').length,
          pair.$2,
        );
        expect(fake.scheduled.keys.toSet().length, fake.scheduled.length);
        expect(fake.scheduled.containsKey(NotificationIds.morning), isTrue);
        expect(fake.scheduled.containsKey(NotificationIds.evening), isTrue);
        expect(fake.scheduled.containsKey(NotificationIds.wird), isTrue);
      }
      final custom = FakeNotificationService();
      await WorshipNotificationScheduler(custom).reschedule(
        const AppSettings(
          salawat: true,
          salawatFrequency: SalawatFrequency.custom,
          salawatTimes: [ReminderTime(10, 5), ReminderTime(16, 10)],
        ),
        prayers: const [],
        now: now,
      );
      expect(custom.scheduled.length, 2);
    },
  );
  test(
    'memorization reminders require an active plan and test notification works',
    () async {
      final fake = FakeNotificationService();
      final scheduler = WorshipNotificationScheduler(fake);
      await scheduler.reschedule(
        const AppSettings(memorization: true, review: true),
        prayers: const [],
        now: now,
      );
      expect(fake.scheduled.containsKey(NotificationIds.memorization), isFalse);
      final memory = _MemStore();
      final c = MemorizationController(
        repository: MemorizationRepository(store: memory),
        clock: () => now,
      );
      await c.load();
      await c.createPlan(
        title: 'خطة',
        start: const QuranCoordinate(67, 1),
        end: const QuranCoordinate(67, 2),
        dailyNewAyahTarget: 1,
      );
      await scheduler.reschedule(
        const AppSettings(memorization: true),
        prayers: const [],
        memorization: c,
        now: now,
      );
      expect(fake.scheduled.containsKey(NotificationIds.memorization), isTrue);
      await fake.showTest(NotificationTestKind.normal);
      expect(fake.testsShown, [NotificationTestKind.normal]);
    },
  );
  test('permission gateway is never invoked by scheduling alone', () async {
    final fake = FakeNotificationService();
    await WorshipNotificationScheduler(
      fake,
    ).reschedule(const AppSettings(wird: true), prayers: const [], now: now);
    expect(fake.permissionRequests, 0);
    expect(await fake.canScheduleExact(), isFalse);
  });

  test(
    'all custom picker times persist and invalid duplicates normalize',
    () async {
      final store = _SettingsStore();
      const settings = AppSettings(
        salawatFrequency: SalawatFrequency.custom,
        salawatTimes: [
          ReminderTime(18, 30),
          ReminderTime(7, 5),
          ReminderTime(18, 30),
        ],
        morningTime: ReminderTime(6, 15),
        eveningTime: ReminderTime(19, 45),
        wirdTime: ReminderTime(20, 20),
        memorizationTime: ReminderTime(16, 10),
        reviewTime: ReminderTime(21, 25),
      );
      await AppSettingsRepository(store: store).save(settings);
      final loaded = await AppSettingsRepository(store: store).load();
      expect(loaded.morningTime, const ReminderTime(6, 15));
      expect(loaded.eveningTime, const ReminderTime(19, 45));
      expect(loaded.wirdTime, const ReminderTime(20, 20));
      expect(loaded.memorizationTime, const ReminderTime(16, 10));
      expect(loaded.reviewTime, const ReminderTime(21, 25));
      expect(loaded.salawatTimes, [
        const ReminderTime(7, 5),
        const ReminderTime(18, 30),
      ]);
    },
  );

  test(
    'cold-start and background payloads use one queued routing abstraction',
    () {
      final routes = NotificationRouteCoordinator();
      routes.receivePayload('adhkar:morning');
      expect(routes.pending, NotificationDestination.morningAdhkar);
      final received = <NotificationDestination>[];
      routes.attach(received.add);
      expect(received, [NotificationDestination.morningAdhkar]);
      routes.receivePayload('memorization:review');
      routes.receivePayload('prayer:الفجر');
      expect(received, [
        NotificationDestination.morningAdhkar,
        NotificationDestination.review,
        NotificationDestination.prayer,
      ]);
      expect(destinationForNotificationPayload('unknown'), isNull);
    },
  );

  test(
    'prayer horizon schedules today and tomorrow with distinct ids',
    () async {
      final fake = FakeNotificationService();
      await WorshipNotificationScheduler(fake).reschedule(
        const AppSettings(prayerNotifications: true),
        prayers: [
          PrayerTimeItem(name: 'الفجر', time: DateTime(2026, 8, 13, 7)),
          PrayerTimeItem(name: 'الفجر', time: DateTime(2026, 8, 14, 7)),
        ],
        now: now,
      );
      expect(fake.scheduled.keys, {1001, 1021});
      expect(fake.scheduled.values.map((value) => value.at.day), {13, 14});
    },
  );

  test('selective time change only reconciles affected group', () async {
    final fake = FakeNotificationService();
    await WorshipNotificationScheduler(fake).reschedule(
      const AppSettings(morningAdhkar: true, eveningAdhkar: true),
      prayers: const [],
      now: now,
    );
    fake.cancelled.clear();
    await WorshipNotificationScheduler(fake).reschedule(
      const AppSettings(
        morningAdhkar: true,
        eveningAdhkar: true,
        morningTime: ReminderTime(8, 30),
      ),
      prayers: const [],
      now: now,
      groups: {NotificationScheduleGroup.morning},
    );
    expect(fake.cancelled, [NotificationIds.morning]);
    expect(fake.scheduled[NotificationIds.evening], isNotNull);
    expect(fake.scheduled[NotificationIds.morning]!.at.hour, 8);
  });

  test(
    'exact unavailable falls back inexact and grant reschedules exact',
    () async {
      final fake = FakeNotificationService();
      final prayers = [
        PrayerTimeItem(name: 'الفجر', time: DateTime(2026, 8, 13, 7)),
      ];
      await WorshipNotificationScheduler(fake).reschedule(
        const AppSettings(prayerNotifications: true, exactPrayerAlarms: true),
        prayers: prayers,
        now: now,
        exactAvailable: false,
      );
      expect(fake.scheduledExact[1001], isFalse);
      await WorshipNotificationScheduler(fake).reschedule(
        const AppSettings(prayerNotifications: true, exactPrayerAlarms: true),
        prayers: prayers,
        now: now,
        exactAvailable: true,
        groups: {NotificationScheduleGroup.prayer},
      );
      expect(fake.scheduledExact[1001], isTrue);
    },
  );

  test(
    'bundled Adhan is honest and uses dedicated versioned channel',
    () async {
      expect(LocalNotificationService.hasBundledAdhan, isTrue);
      expect(LocalNotificationService.adhanChannelId, 'adhan_v1');
      final fake = FakeNotificationService();
      await WorshipNotificationScheduler(fake).reschedule(
        AppSettings(
          prayerNotifications: true,
          prayers: {
            ...AppSettings.defaultPrayers,
            'الفجر': const PrayerReminderSettings(adhan: true),
          },
        ),
        prayers: [
          PrayerTimeItem(name: 'الفجر', time: DateTime(2026, 8, 13, 7)),
        ],
        now: now,
      );
      expect(fake.scheduled[1001]!.channel, WorshipNotificationChannel.adhan);
    },
  );

  test(
    'settings permission grant, health, and startup reconcile with fakes',
    () async {
      final fake = FakeNotificationService();
      final store = _SettingsStore();
      final memory = MemorizationController(
        repository: MemorizationRepository(store: _MemStore()),
        clock: () => now,
      );
      await memory.load();
      final controller = SettingsController(
        repository: AppSettingsRepository(store: store),
        notifications: fake,
        routeCoordinator: NotificationRouteCoordinator(),
        prayerController: PrayerController(),
        memorizationController: memory,
      );
      await controller.load();
      expect(fake.cancelled, isNotEmpty);
      expect(controller.health.allowed, isTrue);
      expect(controller.health.adhanInstalled, isTrue);
      fake.cancelled.clear();
      await controller.update(
        controller.settings.copyWith(wird: true),
        explicitEnable: true,
        groups: {NotificationScheduleGroup.wird},
      );
      expect(fake.permissionRequests, 1);
      expect(fake.scheduled.containsKey(NotificationIds.wird), isTrue);
      expect(controller.health.nextReminder, isNotNull);
      final before = DateTime.now();
      await controller.scheduleNearFutureTest();
      final scheduled = fake.scheduled[NotificationIds.testScheduled]!;
      expect(scheduled.at.isAfter(before), isTrue);
      expect(
        scheduled.at.difference(before).inSeconds,
        inInclusiveRange(59, 61),
      );
      expect(scheduled.payload, 'settings');
      expect(fake.scheduledExact[NotificationIds.testScheduled], isFalse);
      controller.dispose();
    },
  );

  test(
    'exact access is explicit and grant triggers prayer reconciliation',
    () async {
      final fake = FakeNotificationService()..exactRequestResult = true;
      final memory = MemorizationController(
        repository: MemorizationRepository(store: _MemStore()),
        clock: () => now,
      );
      await memory.load();
      final controller = SettingsController(
        repository: AppSettingsRepository(store: _SettingsStore()),
        notifications: fake,
        prayerController: PrayerController(),
        memorizationController: memory,
      );
      await controller.load();
      fake.cancelled.clear();
      expect(await controller.requestExactAccess(), isTrue);
      expect(fake.exactPermissionRequests, 1);
      expect(controller.settings.exactPrayerAlarms, isTrue);
      expect(
        fake.cancelled,
        containsAll(WorshipNotificationScheduler.prayerIds),
      );
      controller.dispose();
    },
  );

  test(
    'denied exact access persists intent and safely uses fallback',
    () async {
      final fake = FakeNotificationService();
      final memory = MemorizationController(
        repository: MemorizationRepository(store: _MemStore()),
        clock: () => now,
      );
      await memory.load();
      final controller = SettingsController(
        repository: AppSettingsRepository(store: _SettingsStore()),
        notifications: fake,
        prayerController: PrayerController(),
        memorizationController: memory,
      );
      await controller.load();
      expect(await controller.requestExactAccess(), isFalse);
      expect(fake.exactPermissionRequests, 1);
      expect(controller.settings.exactPrayerAlarms, isTrue);
      expect(controller.exactAvailable, isFalse);
      expect(controller.message, contains('التوقيت التقريبي'));
      controller.dispose();
    },
  );
}

class _SettingsStore implements AppSettingsStore {
  String? v;
  @override
  Future<String?> read() async => v;
  @override
  Future<void> write(String value) async => v = value;
}

class _MemStore implements MemorizationStore {
  String? v;
  @override
  Future<String?> read() async => v;
  @override
  Future<void> write(String value) async => v = value;
}
