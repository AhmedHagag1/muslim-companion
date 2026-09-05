import '../../core/services/notification_service.dart';
import '../../core/services/prayer_times_service.dart';
import '../../data/models/app_settings.dart';
import '../daily/daily_islamic_controller.dart';
import '../memorization/memorization_controller.dart';
import '../khatma/khatma_controller.dart';

enum NotificationScheduleGroup {
  prayer,
  salawat,
  morning,
  evening,
  wird,
  memorization,
  review,
  khatma,
  dailyFasting,
  dailyNight,
  dailyDhuha,
}

class WorshipNotificationScheduler {
  WorshipNotificationScheduler(this.gateway);

  final NotificationGateway gateway;

  static final prayerIds = <int>[
    for (var day = 0; day < 2; day++)
      for (final name in AppSettings.defaultPrayers.keys) ...[
        NotificationIds.prayer(name, dayOffset: day),
        NotificationIds.prayer(name, before: true, dayOffset: day),
      ],
  ];

  static const salawatIds = [2000, 2001, 2002, 2003, 2004];
  static const allIds = [
    1001,
    1002,
    1003,
    1004,
    1005,
    1101,
    1102,
    1103,
    1104,
    1105,
    1021,
    1022,
    1023,
    1024,
    1025,
    1121,
    1122,
    1123,
    1124,
    1125,
    2000,
    2001,
    2002,
    2003,
    2004,
    3001,
    3002,
    4001,
    5001,
    5002,
    6001,
    7001,
    7002,
    7013,
    7014,
    7015,
    7101,
    7102,
  ];

  Future<void> reschedule(
    AppSettings settings, {
    required List<PrayerTimeItem> prayers,
    MemorizationController? memorization,
    KhatmaController? khatma,
    DailyIslamicController? daily,
    DateTime? now,
    Set<NotificationScheduleGroup>? groups,
    bool exactAvailable = true,
  }) async {
    final selected = groups ?? NotificationScheduleGroup.values.toSet();
    final current = now ?? DateTime.now();
    for (final group in selected) {
      await _cancelGroup(group);
    }

    if (selected.contains(NotificationScheduleGroup.prayer)) {
      await _schedulePrayers(
        settings,
        prayers,
        current,
        exactAvailable: exactAvailable,
      );
    }
    if (selected.contains(NotificationScheduleGroup.salawat) &&
        settings.salawat) {
      final times = salawatTimes(settings);
      for (var index = 0; index < times.length; index++) {
        await _daily(
          NotificationIds.salawat(index),
          'الصلاة على النبي ﷺ',
          index.isEven ? 'صلِّ على النبي ﷺ' : 'اللهم صل وسلم على نبينا محمد ﷺ',
          times[index],
          'salawat',
          current,
        );
      }
    }
    if (selected.contains(NotificationScheduleGroup.morning) &&
        settings.morningAdhkar) {
      await _daily(
        NotificationIds.morning,
        'أذكار الصباح',
        'حان وقت أذكار الصباح.',
        settings.morningTime,
        'adhkar:morning',
        current,
      );
    }
    if (selected.contains(NotificationScheduleGroup.evening) &&
        settings.eveningAdhkar) {
      await _daily(
        NotificationIds.evening,
        'أذكار المساء',
        'حان وقت أذكار المساء.',
        settings.eveningTime,
        'adhkar:evening',
        current,
      );
    }
    if (selected.contains(NotificationScheduleGroup.wird) && settings.wird) {
      await _daily(
        NotificationIds.wird,
        'ورد القرآن',
        'خصص وقتًا هادئًا لمتابعة قراءتك.',
        settings.wirdTime,
        'quran',
        current,
      );
    }
    final active = memorization?.activePlan;
    if (selected.contains(NotificationScheduleGroup.memorization) &&
        active != null &&
        settings.memorization) {
      await _daily(
        NotificationIds.memorization,
        'جلسة الحفظ',
        'تابع خطة ${active.title}.',
        settings.memorizationTime,
        'memorization',
        current,
      );
    }
    if (selected.contains(NotificationScheduleGroup.review) &&
        active != null &&
        settings.review &&
        memorization!.dueReviewAyahs.isNotEmpty) {
      await _daily(
        NotificationIds.review,
        'مراجعة الحفظ',
        'لديك ${memorization.dueReviewAyahs.length} مراجعات مستحقة.',
        settings.reviewTime,
        'memorization:review',
        current,
      );
    }
    final khatmaPlan = khatma?.activePlan;
    final khatmaDay = khatma?.today;
    if (selected.contains(NotificationScheduleGroup.khatma) &&
        khatmaPlan?.preferredReminderTime != null &&
        khatmaPlan!.status.name == 'active' &&
        khatmaDay?.isCompleted != true) {
      await _daily(
        NotificationIds.khatma,
        'ورد الختمة',
        'ورد اليوم جاهز: الصفحات ${khatmaDay?.plannedStartPage}–${khatmaDay?.plannedEndPage}.',
        khatmaPlan.preferredReminderTime!,
        'khatma',
        current,
      );
    }
    if (daily != null) {
      await _scheduleDailyLayer(daily, current, selected);
    }
  }

  Future<void> _schedulePrayers(
    AppSettings settings,
    List<PrayerTimeItem> prayers,
    DateTime current, {
    required bool exactAvailable,
  }) async {
    if (!settings.prayerNotifications) return;
    final start = DateTime(current.year, current.month, current.day);
    final exact = settings.exactPrayerAlarms && exactAvailable;
    for (final prayer in prayers) {
      if (prayer.name == 'الشروق' || !prayer.time.isAfter(current)) continue;
      final dayOffset = DateTime(
        prayer.time.year,
        prayer.time.month,
        prayer.time.day,
      ).difference(start).inDays;
      if (dayOffset < 0 || dayOffset > 1) continue;
      final config = settings.prayers[prayer.name];
      if (config == null || !config.enabled) continue;
      await gateway.schedule(
        ScheduledWorshipNotification(
          id: NotificationIds.prayer(prayer.name, dayOffset: dayOffset),
          title: 'حان وقت ${prayer.name}',
          body: 'حان وقت الصلاة.',
          at: prayer.time,
          payload: 'prayer:${prayer.name}',
          channel: config.adhan
              ? WorshipNotificationChannel.adhan
              : WorshipNotificationChannel.prayer,
        ),
        exact: exact,
      );
      if (config.beforeMinutes > 0) {
        final at = prayer.time.subtract(
          Duration(minutes: config.beforeMinutes),
        );
        if (at.isAfter(current)) {
          await gateway.schedule(
            ScheduledWorshipNotification(
              id: NotificationIds.prayer(
                prayer.name,
                before: true,
                dayOffset: dayOffset,
              ),
              title: 'اقتربت صلاة ${prayer.name}',
              body: 'باقي ${config.beforeMinutes} دقائق.',
              at: at,
              payload: 'prayer:${prayer.name}',
              channel: WorshipNotificationChannel.prayer,
            ),
            exact: exact,
          );
        }
      }
    }
  }

  List<ReminderTime> salawatTimes(AppSettings settings) =>
      switch (settings.salawatFrequency) {
        SalawatFrequency.once => const [ReminderTime(12, 0)],
        SalawatFrequency.three => const [
          ReminderTime(9, 0),
          ReminderTime(14, 0),
          ReminderTime(19, 0),
        ],
        SalawatFrequency.five => const [
          ReminderTime(8, 0),
          ReminderTime(11, 0),
          ReminderTime(14, 0),
          ReminderTime(17, 0),
          ReminderTime(20, 0),
        ],
        SalawatFrequency.custom => normalizeReminderTimes(
          settings.salawatTimes,
        ),
      };

  Future<void> _cancelGroup(NotificationScheduleGroup group) async {
    final ids = switch (group) {
      NotificationScheduleGroup.prayer => prayerIds,
      NotificationScheduleGroup.salawat => salawatIds,
      NotificationScheduleGroup.morning => const [NotificationIds.morning],
      NotificationScheduleGroup.evening => const [NotificationIds.evening],
      NotificationScheduleGroup.wird => const [NotificationIds.wird],
      NotificationScheduleGroup.memorization => const [
        NotificationIds.memorization,
      ],
      NotificationScheduleGroup.review => const [NotificationIds.review],
      NotificationScheduleGroup.khatma => const [NotificationIds.khatma],
      NotificationScheduleGroup.dailyFasting => const [
        NotificationIds.fastingMonday,
        NotificationIds.fastingThursday,
        7013,
        7014,
        7015,
      ],
      NotificationScheduleGroup.dailyNight => const [NotificationIds.lastThird],
      NotificationScheduleGroup.dailyDhuha => const [NotificationIds.dhuha],
    };
    for (final id in ids) {
      await gateway.cancel(id);
    }
  }

  Future<void> _daily(
    int id,
    String title,
    String body,
    ReminderTime time,
    String payload,
    DateTime now,
  ) {
    var at = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    return gateway.schedule(
      ScheduledWorshipNotification(
        id: id,
        title: title,
        body: body,
        at: at,
        payload: payload,
        daily: true,
      ),
      exact: false,
    );
  }

  Future<void> _scheduleDailyLayer(
    DailyIslamicController controller,
    DateTime now,
    Set<NotificationScheduleGroup> selected,
  ) async {
    final settings = controller.settings;
    if (selected.contains(NotificationScheduleGroup.dailyFasting)) {
      final foundWhiteDays = <int>{};
      var mondayDone = !settings.mondayReminder;
      var thursdayDone = !settings.thursdayReminder;
      for (var offset = 1; offset <= 45; offset++) {
        final fastingDay = DateTime(now.year, now.month, now.day + offset);
        final at = DateTime(
          fastingDay.year,
          fastingDay.month,
          fastingDay.day - 1,
          settings.fastingReminderTime.hour,
          settings.fastingReminderTime.minute,
        );
        if (!at.isAfter(now)) continue;
        if (!mondayDone && fastingDay.weekday == DateTime.monday) {
          await _oneOff(
            NotificationIds.fastingMonday,
            'تذكير بصيام الاثنين',
            'غدًا يوم الاثنين — تذكير اختياري.',
            at,
          );
          mondayDone = true;
        }
        if (!thursdayDone && fastingDay.weekday == DateTime.thursday) {
          await _oneOff(
            NotificationIds.fastingThursday,
            'تذكير بصيام الخميس',
            'غدًا يوم الخميس — تذكير اختياري.',
            at,
          );
          thursdayDone = true;
        }
        if (settings.whiteDaysReminder) {
          final hijri = controller.service.toHijri(
            fastingDay,
            adjustment: settings.hijriAdjustment,
          );
          if (hijri != null &&
              hijri.day >= 13 &&
              hijri.day <= 15 &&
              foundWhiteDays.add(hijri.day)) {
            await _oneOff(
              NotificationIds.whiteDay(hijri.day),
              'تذكير بالأيام البيض',
              'غدًا ${hijri.day} ${hijri.monthNameArabic} — تاريخ محسوب.',
              at,
            );
          }
        }
        if (mondayDone &&
            thursdayDone &&
            (!settings.whiteDaysReminder || foundWhiteDays.length == 3)) {
          break;
        }
      }
    }
    final state = controller.state;
    if (selected.contains(NotificationScheduleGroup.dailyNight) &&
        settings.lastThirdReminder &&
        state?.night?.lastThirdStart.isAfter(now) == true) {
      await _oneOff(
        NotificationIds.lastThird,
        'بداية الثلث الأخير المحسوبة',
        'بدأ الثلث الأخير تقريبًا وفق مواقيت الليلة.',
        state!.night!.lastThirdStart,
      );
    }
    if (selected.contains(NotificationScheduleGroup.dailyDhuha) &&
        settings.dhuhaReminder &&
        state?.dhuha?.start.isAfter(now) == true) {
      await _oneOff(
        NotificationIds.dhuha,
        'بداية نافذة الضحى المحسوبة',
        'بدأت نافذة الضحى الإرشادية المحسوبة.',
        state!.dhuha!.start,
      );
    }
  }

  Future<void> _oneOff(int id, String title, String body, DateTime at) =>
      gateway.schedule(
        ScheduledWorshipNotification(
          id: id,
          title: title,
          body: body,
          at: at,
          payload: 'daily',
        ),
        exact: false,
      );
}
