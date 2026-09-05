import 'package:flutter/foundation.dart';

import '../../core/services/notification_service.dart';
import '../../data/models/app_settings.dart';
import '../../data/repositories/app_settings_repository.dart';
import '../memorization/memorization_controller.dart';
import '../khatma/khatma_controller.dart';
import '../prayer/prayer_controller.dart';
import '../daily/daily_islamic_controller.dart';
import '../../data/models/islamic_daily.dart';
import 'notification_routing.dart';
import 'worship_notification_scheduler.dart';

class NotificationHealth {
  const NotificationHealth({
    required this.allowed,
    required this.exactAvailable,
    required this.enabledPrayerCount,
    required this.adhanInstalled,
    this.nextReminder,
  });

  final bool allowed;
  final bool exactAvailable;
  final int enabledPrayerCount;
  final bool adhanInstalled;
  final DateTime? nextReminder;
}

class SettingsController extends ChangeNotifier {
  SettingsController({
    AppSettingsRepository? repository,
    NotificationGateway? notifications,
    NotificationRouteCoordinator? routeCoordinator,
    required this.prayerController,
    required this.memorizationController,
    this.khatmaController,
    DailyIslamicController? dailyIslamicController,
  }) : dailyIslamicController =
           dailyIslamicController ??
           DailyIslamicController(prayerController: prayerController),
       _ownsDailyIslamicController = dailyIslamicController == null,
       _repository = repository ?? AppSettingsRepository(),
       notifications = notifications ?? LocalNotificationService(),
       routeCoordinator = routeCoordinator ?? NotificationRouteCoordinator() {
    scheduler = WorshipNotificationScheduler(this.notifications);
  }

  final AppSettingsRepository _repository;
  final NotificationGateway notifications;
  final NotificationRouteCoordinator routeCoordinator;
  final PrayerController prayerController;
  final MemorizationController memorizationController;
  final KhatmaController? khatmaController;
  final DailyIslamicController dailyIslamicController;
  final bool _ownsDailyIslamicController;
  late final WorshipNotificationScheduler scheduler;

  AppSettings settings = const AppSettings();
  bool loaded = false;
  bool notificationsAllowed = true;
  bool exactAvailable = false;
  String? message;

  NotificationHealth get health => NotificationHealth(
    allowed: notificationsAllowed,
    exactAvailable: exactAvailable,
    enabledPrayerCount: settings.prayerNotifications
        ? settings.prayers.values.where((value) => value.enabled).length
        : 0,
    adhanInstalled: LocalNotificationService.hasBundledAdhan,
    nextReminder: _nextReminder(),
  );

  Future<void> load() async {
    await notifications.initialize(routeCoordinator.receivePayload);
    settings = await _repository.load();
    loaded = true;
    await refreshHealth(rescheduleAfterExactGrant: false);
    await reschedule();
    notifyListeners();
  }

  Future<void> refreshHealth({bool rescheduleAfterExactGrant = true}) async {
    await notifications.refreshTimezone();
    final wasExactAvailable = exactAvailable;
    notificationsAllowed = await notifications.notificationsAllowed();
    exactAvailable = await notifications.canScheduleExact();
    if (rescheduleAfterExactGrant &&
        settings.exactPrayerAlarms &&
        !wasExactAvailable &&
        exactAvailable) {
      await reschedule(groups: {NotificationScheduleGroup.prayer});
    }
    notifyListeners();
  }

  Future<bool> update(
    AppSettings next, {
    bool explicitEnable = false,
    Set<NotificationScheduleGroup>? groups,
  }) async {
    final enabling =
        explicitEnable &&
        next.anyNotificationEnabled &&
        _enablesNotification(settings, next);
    if (enabling && !await notifications.requestPermission()) {
      notificationsAllowed = false;
      message =
          'الإشعارات محظورة. يمكنك السماح بها من إعدادات النظام ثم المحاولة مجددًا.';
      notifyListeners();
      return false;
    }
    settings = next;
    notificationsAllowed = await notifications.notificationsAllowed();
    await _repository.save(settings);
    await reschedule(groups: groups);
    message = null;
    notifyListeners();
    return true;
  }

  Future<void> reschedule({Set<NotificationScheduleGroup>? groups}) async {
    await scheduler.reschedule(
      settings,
      prayers: prayerController.notificationPrayers,
      memorization: memorizationController,
      khatma: khatmaController,
      daily: dailyIslamicController,
      groups: groups,
      exactAvailable: exactAvailable,
    );
  }

  Future<bool> requestExactAccess() async {
    settings = settings.copyWith(exactPrayerAlarms: true);
    await _repository.save(settings);
    if (!await notifications.canScheduleExact()) {
      final granted = await notifications.requestExactPermission();
      exactAvailable = granted || await notifications.canScheduleExact();
    } else {
      exactAvailable = true;
    }
    if (!exactAvailable) {
      await reschedule(groups: {NotificationScheduleGroup.prayer});
      message =
          'يحتاج التنبيه الدقيق إلى سماح خاص من النظام. يمكنك متابعة استخدام التوقيت التقريبي بأمان.';
      notifyListeners();
      return false;
    }
    await reschedule(groups: {NotificationScheduleGroup.prayer});
    message = null;
    notifyListeners();
    return true;
  }

  Future<void> useInexactPrayerTiming() => update(
    settings.copyWith(exactPrayerAlarms: false),
    groups: {NotificationScheduleGroup.prayer},
  );

  Future<void> openNotificationSettings() =>
      notifications.openNotificationSettings();

  Future<void> sendTest(NotificationTestKind kind) async {
    if (!await notifications.requestPermission()) {
      notificationsAllowed = false;
      message = 'اسمح بالإشعارات من إعدادات النظام لإرسال الاختبار.';
      notifyListeners();
      return;
    }
    notificationsAllowed = true;
    await notifications.showTest(kind);
    notifyListeners();
  }

  Future<void> scheduleNearFutureTest() async {
    if (!await notifications.requestPermission()) {
      notificationsAllowed = false;
      message = 'اسمح بالإشعارات من إعدادات النظام لجدولة الاختبار.';
      notifyListeners();
      return;
    }
    notificationsAllowed = true;
    await refreshHealth(rescheduleAfterExactGrant: false);
    final at = DateTime.now().add(const Duration(minutes: 1));
    await notifications.cancel(NotificationIds.testScheduled);
    await notifications.schedule(
      ScheduledWorshipNotification(
        id: NotificationIds.testScheduled,
        title: 'تذكير تجريبي مجدول',
        body: 'وصل الاختبار المجدول بنجاح.',
        at: at,
        payload: 'settings',
      ),
      exact: exactAvailable,
    );
    message = exactAvailable
        ? 'تمت جدولة اختبار دقيق بعد دقيقة.'
        : 'تمت جدولة اختبار تقريبي بعد دقيقة؛ قد يؤخره النظام قليلًا.';
    notifyListeners();
  }

  Future<bool> updateDailySettings(
    IslamicCalendarSettings next, {
    bool explicitEnable = false,
  }) async {
    final enabling =
        explicitEnable &&
        next.anyReminderEnabled &&
        !dailyIslamicController.settings.anyReminderEnabled;
    if (enabling && !await notifications.requestPermission()) {
      notificationsAllowed = false;
      message =
          'الإشعارات محظورة. يمكنك السماح بها من إعدادات النظام ثم المحاولة مجددًا.';
      notifyListeners();
      return false;
    }
    await dailyIslamicController.updateSettings(next);
    await reschedule(
      groups: {
        NotificationScheduleGroup.dailyFasting,
        NotificationScheduleGroup.dailyNight,
        NotificationScheduleGroup.dailyDhuha,
      },
    );
    notificationsAllowed = await notifications.notificationsAllowed();
    message = null;
    notifyListeners();
    return true;
  }

  static bool _enablesNotification(AppSettings old, AppSettings next) =>
      (!old.prayerNotifications && next.prayerNotifications) ||
      (!old.salawat && next.salawat) ||
      (!old.morningAdhkar && next.morningAdhkar) ||
      (!old.eveningAdhkar && next.eveningAdhkar) ||
      (!old.wird && next.wird) ||
      (!old.memorization && next.memorization) ||
      (!old.review && next.review);

  DateTime? _nextReminder() {
    if (!notificationsAllowed || !settings.anyNotificationEnabled) return null;
    final now = DateTime.now();
    final candidates = <DateTime>[];
    void addDaily(bool enabled, ReminderTime time) {
      if (!enabled) return;
      var value = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
      if (!value.isAfter(now)) value = value.add(const Duration(days: 1));
      candidates.add(value);
    }

    if (settings.prayerNotifications) {
      candidates.addAll(
        prayerController.notificationPrayers
            .where((prayer) {
              final config = settings.prayers[prayer.name];
              return prayer.time.isAfter(now) && config?.enabled == true;
            })
            .map((prayer) => prayer.time),
      );
    }
    if (settings.salawat) {
      for (final time in scheduler.salawatTimes(settings)) {
        addDaily(true, time);
      }
    }
    addDaily(settings.morningAdhkar, settings.morningTime);
    addDaily(settings.eveningAdhkar, settings.eveningTime);
    addDaily(settings.wird, settings.wirdTime);
    addDaily(
      settings.memorization && memorizationController.activePlan != null,
      settings.memorizationTime,
    );
    addDaily(
      settings.review && memorizationController.dueReviewAyahs.isNotEmpty,
      settings.reviewTime,
    );
    if (candidates.isEmpty) return null;
    candidates.sort();
    return candidates.first;
  }

  @override
  void dispose() {
    if (_ownsDailyIslamicController) dailyIslamicController.dispose();
    super.dispose();
  }
}
