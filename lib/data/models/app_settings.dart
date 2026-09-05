enum SalawatFrequency { once, three, five, custom }

class ReminderTime {
  const ReminderTime(this.hour, this.minute);
  final int hour, minute;
  bool get isValid => hour >= 0 && hour < 24 && minute >= 0 && minute < 60;
  Map<String, int> toJson() => {'hour': hour, 'minute': minute};

  int get minutesSinceMidnight => hour * 60 + minute;

  @override
  bool operator ==(Object other) =>
      other is ReminderTime && hour == other.hour && minute == other.minute;

  @override
  int get hashCode => Object.hash(hour, minute);
  static ReminderTime? fromJson(Object? v) {
    if (v is! Map<String, dynamic>) return null;
    final t = ReminderTime(v['hour'] as int? ?? -1, v['minute'] as int? ?? -1);
    return t.isValid ? t : null;
  }
}

List<ReminderTime> normalizeReminderTimes(Iterable<ReminderTime> values) {
  final unique = values.where((time) => time.isValid).toSet().toList()
    ..sort(
      (first, second) =>
          first.minutesSinceMidnight.compareTo(second.minutesSinceMidnight),
    );
  return List.unmodifiable(unique);
}

class PrayerReminderSettings {
  const PrayerReminderSettings({
    this.enabled = true,
    this.adhan = false,
    this.beforeMinutes = 0,
  });
  final bool enabled, adhan;
  final int beforeMinutes;
  PrayerReminderSettings copyWith({
    bool? enabled,
    bool? adhan,
    int? beforeMinutes,
  }) => PrayerReminderSettings(
    enabled: enabled ?? this.enabled,
    adhan: adhan ?? this.adhan,
    beforeMinutes: beforeMinutes ?? this.beforeMinutes,
  );
  Map<String, Object> toJson() => {
    'enabled': enabled,
    'adhan': adhan,
    'beforeMinutes': beforeMinutes,
  };
  static PrayerReminderSettings fromJson(Object? v) {
    if (v is! Map<String, dynamic>) return const PrayerReminderSettings();
    final before = v['beforeMinutes'] as int? ?? 0;
    return PrayerReminderSettings(
      enabled: v['enabled'] == true,
      adhan: v['adhan'] == true,
      beforeMinutes: {0, 5, 10, 15, 30}.contains(before) ? before : 0,
    );
  }
}

class AppSettings {
  const AppSettings({
    this.prayerNotifications = false,
    this.prayers = defaultPrayers,
    this.salawat = false,
    this.salawatFrequency = SalawatFrequency.once,
    this.salawatTimes = const [ReminderTime(12, 0)],
    this.morningAdhkar = false,
    this.morningTime = const ReminderTime(7, 0),
    this.eveningAdhkar = false,
    this.eveningTime = const ReminderTime(18, 0),
    this.wird = false,
    this.wirdTime = const ReminderTime(20, 0),
    this.memorization = false,
    this.memorizationTime = const ReminderTime(17, 0),
    this.review = false,
    this.reviewTime = const ReminderTime(19, 0),
    this.exactPrayerAlarms = false,
  });
  final bool prayerNotifications,
      salawat,
      morningAdhkar,
      eveningAdhkar,
      wird,
      memorization,
      review,
      exactPrayerAlarms;
  final Map<String, PrayerReminderSettings> prayers;
  final SalawatFrequency salawatFrequency;
  final List<ReminderTime> salawatTimes;
  final ReminderTime morningTime,
      eveningTime,
      wirdTime,
      memorizationTime,
      reviewTime;
  static const defaultPrayers = {
    'الفجر': PrayerReminderSettings(),
    'الظهر': PrayerReminderSettings(),
    'العصر': PrayerReminderSettings(),
    'المغرب': PrayerReminderSettings(),
    'العشاء': PrayerReminderSettings(),
  };
  bool get anyNotificationEnabled =>
      prayerNotifications ||
      salawat ||
      morningAdhkar ||
      eveningAdhkar ||
      wird ||
      memorization ||
      review;
  AppSettings copyWith({
    bool? prayerNotifications,
    Map<String, PrayerReminderSettings>? prayers,
    bool? salawat,
    SalawatFrequency? salawatFrequency,
    List<ReminderTime>? salawatTimes,
    bool? morningAdhkar,
    ReminderTime? morningTime,
    bool? eveningAdhkar,
    ReminderTime? eveningTime,
    bool? wird,
    ReminderTime? wirdTime,
    bool? memorization,
    ReminderTime? memorizationTime,
    bool? review,
    ReminderTime? reviewTime,
    bool? exactPrayerAlarms,
  }) => AppSettings(
    prayerNotifications: prayerNotifications ?? this.prayerNotifications,
    prayers: prayers ?? this.prayers,
    salawat: salawat ?? this.salawat,
    salawatFrequency: salawatFrequency ?? this.salawatFrequency,
    salawatTimes: salawatTimes == null
        ? this.salawatTimes
        : normalizeReminderTimes(salawatTimes),
    morningAdhkar: morningAdhkar ?? this.morningAdhkar,
    morningTime: morningTime ?? this.morningTime,
    eveningAdhkar: eveningAdhkar ?? this.eveningAdhkar,
    eveningTime: eveningTime ?? this.eveningTime,
    wird: wird ?? this.wird,
    wirdTime: wirdTime ?? this.wirdTime,
    memorization: memorization ?? this.memorization,
    memorizationTime: memorizationTime ?? this.memorizationTime,
    review: review ?? this.review,
    reviewTime: reviewTime ?? this.reviewTime,
    exactPrayerAlarms: exactPrayerAlarms ?? this.exactPrayerAlarms,
  );
  Map<String, Object> toJson() => {
    'prayerNotifications': prayerNotifications,
    'prayers': prayers.map((k, v) => MapEntry(k, v.toJson())),
    'salawat': salawat,
    'salawatFrequency': salawatFrequency.name,
    'salawatTimes': salawatTimes.map((e) => e.toJson()).toList(),
    'morningAdhkar': morningAdhkar,
    'morningTime': morningTime.toJson(),
    'eveningAdhkar': eveningAdhkar,
    'eveningTime': eveningTime.toJson(),
    'wird': wird,
    'wirdTime': wirdTime.toJson(),
    'memorization': memorization,
    'memorizationTime': memorizationTime.toJson(),
    'review': review,
    'reviewTime': reviewTime.toJson(),
    'exactPrayerAlarms': exactPrayerAlarms,
  };
  static AppSettings fromJson(Object? v) {
    if (v is! Map<String, dynamic>) return const AppSettings();
    final raw = v['prayers'];
    final prayers = {
      for (final e in defaultPrayers.entries)
        e.key: PrayerReminderSettings.fromJson(raw is Map ? raw[e.key] : null),
    };
    ReminderTime time(String k, ReminderTime fallback) =>
        ReminderTime.fromJson(v[k]) ?? fallback;
    final freq =
        SalawatFrequency.values
            .where((e) => e.name == v['salawatFrequency'])
            .firstOrNull ??
        SalawatFrequency.once;
    final custom = normalizeReminderTimes(
      (v['salawatTimes'] as List?)
              ?.map(ReminderTime.fromJson)
              .whereType<ReminderTime>() ??
          const <ReminderTime>[],
    );
    return AppSettings(
      prayerNotifications: v['prayerNotifications'] == true,
      prayers: prayers,
      salawat: v['salawat'] == true,
      salawatFrequency: freq,
      salawatTimes: custom.isEmpty ? const [ReminderTime(12, 0)] : custom,
      morningAdhkar: v['morningAdhkar'] == true,
      morningTime: time('morningTime', const ReminderTime(7, 0)),
      eveningAdhkar: v['eveningAdhkar'] == true,
      eveningTime: time('eveningTime', const ReminderTime(18, 0)),
      wird: v['wird'] == true,
      wirdTime: time('wirdTime', const ReminderTime(20, 0)),
      memorization: v['memorization'] == true,
      memorizationTime: time('memorizationTime', const ReminderTime(17, 0)),
      review: v['review'] == true,
      reviewTime: time('reviewTime', const ReminderTime(19, 0)),
      exactPrayerAlarms: v['exactPrayerAlarms'] == true,
    );
  }
}
