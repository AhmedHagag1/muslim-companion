import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

enum WorshipNotificationChannel { general, prayer, adhan }

enum NotificationTestKind { normal, prayer, adhan }

class ScheduledWorshipNotification {
  const ScheduledWorshipNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    required this.payload,
    this.daily = false,
    this.channel = WorshipNotificationChannel.general,
  });

  final int id;
  final String title;
  final String body;
  final DateTime at;
  final String payload;
  final WorshipNotificationChannel channel;
  final bool daily;
}

abstract interface class NotificationGateway {
  Future<void> initialize(void Function(String payload) onTap);
  Future<void> refreshTimezone();
  Future<bool> requestPermission();
  Future<bool> notificationsAllowed();
  Future<void> openNotificationSettings();
  Future<bool> canScheduleExact();
  Future<bool> requestExactPermission();
  Future<void> schedule(
    ScheduledWorshipNotification value, {
    required bool exact,
  });
  Future<void> cancel(int id);
  Future<void> showTest(NotificationTestKind kind);
}

class LocalNotificationService implements NotificationGateway {
  static const generalChannelId = 'worship_general_v1';
  static const prayerChannelId = 'prayer_reminders_v1';
  static const adhanChannelId = 'adhan_v1';
  static const adhanSoundResource = 'adhan_cc0';
  static const hasBundledAdhan = true;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> initialize(void Function(String payload) onTap) async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    await refreshTimezone();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) onTap(payload);
      },
    );
    _initialized = true;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true &&
        payload != null &&
        payload.isNotEmpty) {
      onTap(payload);
    }
  }

  @override
  Future<void> refreshTimezone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // The timezone package's local fallback remains usable.
    }
  }

  @override
  Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? true;

  @override
  Future<bool> notificationsAllowed() async =>
      await _android?.areNotificationsEnabled() ?? true;

  @override
  Future<void> openNotificationSettings() async {
    await _plugin.openAppNotificationSettings();
  }

  @override
  Future<bool> canScheduleExact() async =>
      await _android?.canScheduleExactNotifications() ?? true;

  @override
  Future<bool> requestExactPermission() async =>
      await _android?.requestExactAlarmsPermission() ?? true;

  NotificationDetails _details(WorshipNotificationChannel channel) {
    final (id, name, description, sound) = switch (channel) {
      WorshipNotificationChannel.general => (
        generalChannelId,
        'تذكيرات العبادة',
        'تذكيرات الأذكار والورد والحفظ',
        null,
      ),
      WorshipNotificationChannel.prayer => (
        prayerChannelId,
        'تذكيرات الصلاة',
        'تنبيهات مواقيت الصلاة',
        null,
      ),
      WorshipNotificationChannel.adhan => (
        adhanChannelId,
        'الأذان',
        'تنبيه وقت الصلاة بصوت الأذان',
        const RawResourceAndroidNotificationSound(adhanSoundResource),
      ),
    };
    return NotificationDetails(
      android: AndroidNotificationDetails(
        id,
        name,
        channelDescription: description,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: sound,
        enableVibration: channel != WorshipNotificationChannel.adhan,
        channelBypassDnd: false,
        fullScreenIntent: false,
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  @override
  Future<void> schedule(
    ScheduledWorshipNotification value, {
    required bool exact,
  }) async {
    await _plugin.zonedSchedule(
      id: value.id,
      title: value.title,
      body: value.body,
      scheduledDate: tz.TZDateTime.from(value.at, tz.local),
      notificationDetails: _details(value.channel),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: value.daily ? DateTimeComponents.time : null,
      payload: value.payload,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> showTest(NotificationTestKind kind) {
    final (id, title, body, payload, channel) = switch (kind) {
      NotificationTestKind.normal => (
        NotificationIds.testNormal,
        'إشعار تجريبي',
        'التذكيرات المحلية تعمل.',
        'settings',
        WorshipNotificationChannel.general,
      ),
      NotificationTestKind.prayer => (
        NotificationIds.testPrayer,
        'اختبار تنبيه الصلاة',
        'هذا مثال لتنبيه وقت الصلاة.',
        'prayer:اختبار',
        WorshipNotificationChannel.prayer,
      ),
      NotificationTestKind.adhan => (
        NotificationIds.testAdhan,
        'اختبار صوت الأذان',
        'اختبار الصوت المثبت داخل التطبيق.',
        'prayer:اختبار',
        WorshipNotificationChannel.adhan,
      ),
    };
    return _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details(channel),
      payload: payload,
    );
  }
}

abstract final class NotificationIds {
  static const testScheduled = 9996;
  static const testNormal = 9997;
  static const testPrayer = 9998;
  static const testAdhan = 9999;

  static int prayer(String name, {bool before = false, int dayOffset = 0}) =>
      1000 +
      const {
        'الفجر': 1,
        'الظهر': 2,
        'العصر': 3,
        'المغرب': 4,
        'العشاء': 5,
      }[name]! +
      (dayOffset * 20) +
      (before ? 100 : 0);

  static int salawat(int index) => 2000 + index;
  static const morning = 3001;
  static const evening = 3002;
  static const wird = 4001;
  static const khatma = 6001;
  static const memorization = 5001;
  static const review = 5002;
  static const fastingMonday = 7001;
  static const fastingThursday = 7002;
  static int whiteDay(int hijriDay) => 7000 + hijriDay;
  static const lastThird = 7101;
  static const dhuha = 7102;
}

@visibleForTesting
class FakeNotificationService implements NotificationGateway {
  final scheduled = <int, ScheduledWorshipNotification>{};
  final scheduledExact = <int, bool>{};
  final cancelled = <int>[];
  final testsShown = <NotificationTestKind>[];
  var permissionRequests = 0;
  var exactPermissionRequests = 0;
  var settingsOpenCount = 0;
  bool permission = true;
  bool exact = false;
  bool exactRequestResult = false;
  String? launchPayload;
  void Function(String payload)? onTap;

  @override
  Future<void> initialize(void Function(String payload) handler) async {
    onTap = handler;
    if (launchPayload != null) handler(launchPayload!);
  }

  @override
  Future<void> refreshTimezone() async {}

  void tap(String payload) => onTap?.call(payload);

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<bool> notificationsAllowed() async => permission;

  @override
  Future<void> openNotificationSettings() async {
    settingsOpenCount++;
  }

  @override
  Future<bool> canScheduleExact() async => exact;

  @override
  Future<bool> requestExactPermission() async {
    exactPermissionRequests++;
    exact = exactRequestResult;
    return exact;
  }

  @override
  Future<void> schedule(
    ScheduledWorshipNotification value, {
    required bool exact,
  }) async {
    scheduled[value.id] = value;
    scheduledExact[value.id] = exact;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
    scheduledExact.remove(id);
  }

  @override
  Future<void> showTest(NotificationTestKind kind) async {
    testsShown.add(kind);
  }
}
