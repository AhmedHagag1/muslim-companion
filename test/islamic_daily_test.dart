import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quran_app/core/services/islamic_daily_service.dart';
import 'package:quran_app/core/services/notification_service.dart';
import 'package:quran_app/data/models/app_settings.dart';
import 'package:quran_app/data/models/islamic_daily.dart';
import 'package:quran_app/data/repositories/islamic_calendar_settings_repository.dart';
import 'package:quran_app/features/daily/daily_islamic_controller.dart';
import 'package:quran_app/features/daily/daily_islamic_page.dart';
import 'package:quran_app/features/prayer/prayer_controller.dart';
import 'package:quran_app/features/settings/worship_notification_scheduler.dart';

void main() {
  const service = IslamicDailyService();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('known Gregorian date converts to Umm al-Qura Hijri date', () {
    expect(
      service.toHijri(DateTime(2025, 3, 1)),
      const HijriDate(year: 1446, month: 9, day: 1),
    );
  });

  test('Hijri to Gregorian conversion round trips', () {
    expect(
      service.toGregorian(const HijriDate(year: 1446, month: 9, day: 1)),
      DateTime(2025, 3, 1),
    );
  });

  test('Hijri adjustment is bounded and changes civil input by one day', () {
    final base = service.toHijri(DateTime(2025, 3, 1))!;
    final minus = service.toHijri(DateTime(2025, 3, 1), adjustment: -1)!;
    final plus = service.toHijri(DateTime(2025, 3, 1), adjustment: 1)!;
    expect(minus, isNot(base));
    expect(plus, isNot(base));
    expect(service.toGregorian(minus, adjustment: -1), DateTime(2025, 3, 1));
    expect(service.toGregorian(plus, adjustment: 1), DateTime(2025, 3, 1));
    expect(service.toHijri(DateTime(2025, 3, 1), adjustment: 99), plus);
  });

  test('Hijri month rollover converts without gaps', () {
    final length = service.daysInMonth(1446, 9);
    final last = service.toGregorian(
      HijriDate(year: 1446, month: 9, day: length),
    )!;
    expect(
      service.toHijri(last.add(const Duration(days: 1))),
      const HijriDate(year: 1446, month: 10, day: 1),
    );
  });

  test('Hijri year rollover converts without gaps', () {
    final length = service.daysInMonth(1446, 12);
    final last = service.toGregorian(
      HijriDate(year: 1446, month: 12, day: length),
    )!;
    expect(
      service.toHijri(last.add(const Duration(days: 1))),
      const HijriDate(year: 1447, month: 1, day: 1),
    );
  });

  test('Monday and Thursday indicators use Gregorian weekday', () {
    final hijri = const HijriDate(year: 1446, month: 8, day: 3);
    expect(
      service.fastingIndicators(DateTime(2025, 2, 3), hijri),
      contains(FastingDayType.monday),
    );
    expect(
      service.fastingIndicators(DateTime(2025, 2, 6), hijri),
      contains(FastingDayType.thursday),
    );
  });

  test('white-day indicator is present only for Hijri 13, 14 and 15', () {
    for (final day in [13, 14, 15]) {
      expect(
        service.fastingIndicators(
          DateTime(2025, 2, 1),
          HijriDate(year: 1446, month: 8, day: day),
        ),
        contains(FastingDayType.whiteDay),
      );
    }
    expect(
      service.fastingIndicators(
        DateTime(2025, 2, 1),
        const HijriDate(year: 1446, month: 8, day: 12),
      ),
      isNot(contains(FastingDayType.whiteDay)),
    );
  });

  test('night calculations cross midnight and use exact fractions', () {
    final maghrib = DateTime(2025, 2, 1, 18);
    final fajr = DateTime(2025, 2, 2, 6);
    final night = service.nightWindow(maghrib, fajr)!;
    expect(night.duration, const Duration(hours: 12));
    expect(night.midpoint, DateTime(2025, 2, 2));
    expect(night.lastThirdStart, DateTime(2025, 2, 2, 2));
  });

  test('invalid night ordering and invalid Dhuha interval are rejected', () {
    final now = DateTime(2025, 2, 1, 10);
    expect(service.nightWindow(now, now), isNull);
    expect(service.dhuhaWindow(now, now), isNull);
  });

  test('Dhuha guidance uses sunrise plus 20 and Dhuhr minus 10', () {
    final window = service.dhuhaWindow(
      DateTime(2025, 2, 1, 7),
      DateTime(2025, 2, 1, 12, 30),
    )!;
    expect(window.start, DateTime(2025, 2, 1, 7, 20));
    expect(window.end, DateTime(2025, 2, 1, 12, 20));
  });

  test('occasion rules include only documented calculated dates', () {
    expect(
      service.occasionFor(const HijriDate(year: 1446, month: 1, day: 10))?.id,
      'ashura',
    );
    expect(
      service.occasionFor(const HijriDate(year: 1446, month: 9, day: 1))?.id,
      'ramadan-start',
    );
    expect(
      IslamicDailyService.occasions.any(
        (item) => item.titleArabic.contains('ليلة القدر'),
      ),
      isFalse,
    );
  });

  test('state always exposes moon-sighting disclaimer flag', () {
    final state = service.buildState(
      now: DateTime(2025, 3, 1),
      settings: const IslamicCalendarSettings(),
    )!;
    expect(state.moonSightingDisclaimer, isTrue);
    expect(IslamicDailyService.moonSightingDisclaimerArabic, contains('محسوب'));
  });

  test('reminder defaults are all off and adjustment is clamped', () {
    const defaults = IslamicCalendarSettings();
    expect(defaults.anyReminderEnabled, isFalse);
    expect(defaults.copyWith(hijriAdjustment: 8).hijriAdjustment, 1);
    expect(defaults.copyWith(hijriAdjustment: -8).hijriAdjustment, -1);
  });

  test('daily notification IDs are deterministic and isolated', () {
    expect(NotificationIds.fastingMonday, 7001);
    expect(NotificationIds.fastingThursday, 7002);
    expect(NotificationIds.whiteDay(13), 7013);
    expect(NotificationIds.whiteDay(15), 7015);
    expect(NotificationIds.lastThird, 7101);
    expect(NotificationIds.dhuha, 7102);
  });

  test('settings persist and malformed values recover safely', () async {
    final repository = IslamicCalendarSettingsRepository();
    const value = IslamicCalendarSettings(
      hijriAdjustment: 1,
      mondayReminder: true,
      dhuhaReminder: true,
      fastingReminderTime: ReminderTime(19, 45),
    );
    await repository.save(value);
    final loaded = await repository.load();
    expect(loaded.hijriAdjustment, 1);
    expect(loaded.mondayReminder, isTrue);
    expect(loaded.dhuhaReminder, isTrue);
    expect(loaded.fastingReminderTime, const ReminderTime(19, 45));

    SharedPreferences.setMockInitialValues({
      IslamicCalendarSettingsRepository.storageKey: '{broken',
    });
    expect((await repository.load()).anyReminderEnabled, isFalse);
  });

  test('basic Daily state calculates fully offline', () {
    final state = service.buildState(
      now: DateTime(2025, 3, 1),
      settings: const IslamicCalendarSettings(),
      maghrib: DateTime(2025, 3, 1, 18),
      nextFajr: DateTime(2025, 3, 2, 6),
      sunrise: DateTime(2025, 3, 1, 7),
      dhuhr: DateTime(2025, 3, 1, 12, 30),
    )!;
    expect(state.hijriDate, const HijriDate(year: 1446, month: 9, day: 1));
    expect(state.night, isNotNull);
    expect(state.dhuha, isNotNull);
  });

  test('Home summary prioritizes white day then night guidance', () {
    final white = service.buildState(
      now: service.toGregorian(const HijriDate(year: 1446, month: 9, day: 13))!,
      settings: const IslamicCalendarSettings(),
    )!;
    expect(dailyHomeSummary(white), 'اليوم من الأيام البيض');

    final normal = DailyIslamicState(
      gregorianDate: DateTime(2025, 2, 1),
      hijriDate: const HijriDate(year: 1446, month: 8, day: 2),
      fastingDays: const {},
      moonSightingDisclaimer: true,
      night: NightTimeWindow(
        maghrib: DateTime(2025, 2, 1, 18),
        nextFajr: DateTime(2025, 2, 2, 6),
        midpoint: DateTime(2025, 2, 2),
        lastThirdStart: DateTime(2025, 2, 2, 2),
      ),
    );
    expect(dailyHomeSummary(normal), contains('الثلث الأخير'));
  });

  test(
    'fasting scheduler creates only enabled deterministic reminders',
    () async {
      final prayer = PrayerController();
      final daily = DailyIslamicController(
        prayerController: prayer,
        clock: () => DateTime(2025, 2, 1, 12),
      );
      await daily.load();
      await daily.updateSettings(
        const IslamicCalendarSettings(
          mondayReminder: true,
          thursdayReminder: true,
          whiteDaysReminder: true,
        ),
      );
      final gateway = FakeNotificationService();
      await WorshipNotificationScheduler(gateway).reschedule(
        const AppSettings(),
        prayers: const [],
        daily: daily,
        now: DateTime(2025, 2, 1, 12),
        groups: {NotificationScheduleGroup.dailyFasting},
      );
      expect(
        gateway.scheduled.keys,
        containsAll([7001, 7002, 7013, 7014, 7015]),
      );
      expect(
        gateway.scheduled.values.every((item) => item.payload == 'daily'),
        isTrue,
      );
      daily.dispose();
      prayer.dispose();
    },
  );

  testWidgets('Daily page and calendar render calculated state', (
    tester,
  ) async {
    final prayer = PrayerController();
    final controller = DailyIslamicController(
      prayerController: prayer,
      clock: () => DateTime(2025, 3, 1),
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(home: DailyIslamicPage(controller: controller)),
    );
    expect(find.byKey(const ValueKey('daily-islamic-page')), findsOneWidget);
    expect(find.textContaining('رمضان'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('open-hijri-calendar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hijri-calendar-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('hijri-day-1')), findsOneWidget);
    controller.dispose();
    prayer.dispose();
  });
}
