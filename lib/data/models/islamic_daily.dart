import 'package:flutter/foundation.dart';

import 'app_settings.dart';

const hijriMonthNamesArabic = <String>[
  'محرم',
  'صفر',
  'ربيع الأول',
  'ربيع الآخر',
  'جمادى الأولى',
  'جمادى الآخرة',
  'رجب',
  'شعبان',
  'رمضان',
  'شوال',
  'ذو القعدة',
  'ذو الحجة',
];

@immutable
class HijriDate {
  const HijriDate({required this.year, required this.month, required this.day});

  final int year;
  final int month;
  final int day;

  String get monthNameArabic => hijriMonthNamesArabic[month - 1];
  String get formattedArabic => '$day $monthNameArabic $year هـ';

  @override
  bool operator ==(Object other) =>
      other is HijriDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

enum FastingDayType { monday, thursday, whiteDay }

@immutable
class IslamicOccasion {
  const IslamicOccasion({
    required this.id,
    required this.month,
    required this.day,
    required this.titleArabic,
  });

  final String id;
  final int month;
  final int day;
  final String titleArabic;

  bool occursOn(HijriDate date) => date.month == month && date.day == day;
}

@immutable
class NightTimeWindow {
  const NightTimeWindow({
    required this.maghrib,
    required this.nextFajr,
    required this.midpoint,
    required this.lastThirdStart,
  });

  final DateTime maghrib;
  final DateTime nextFajr;
  final DateTime midpoint;
  final DateTime lastThirdStart;
  Duration get duration => nextFajr.difference(maghrib);
}

@immutable
class DhuhaWindow {
  const DhuhaWindow({required this.start, required this.end});
  final DateTime start;
  final DateTime end;
}

@immutable
class IslamicCalendarSettings {
  const IslamicCalendarSettings({
    this.hijriAdjustment = 0,
    this.mondayReminder = false,
    this.thursdayReminder = false,
    this.whiteDaysReminder = false,
    this.lastThirdReminder = false,
    this.dhuhaReminder = false,
    this.fastingReminderTime = const ReminderTime(20, 0),
  });

  final int hijriAdjustment;
  final bool mondayReminder;
  final bool thursdayReminder;
  final bool whiteDaysReminder;
  final bool lastThirdReminder;
  final bool dhuhaReminder;
  final ReminderTime fastingReminderTime;

  bool get anyReminderEnabled =>
      mondayReminder ||
      thursdayReminder ||
      whiteDaysReminder ||
      lastThirdReminder ||
      dhuhaReminder;

  IslamicCalendarSettings copyWith({
    int? hijriAdjustment,
    bool? mondayReminder,
    bool? thursdayReminder,
    bool? whiteDaysReminder,
    bool? lastThirdReminder,
    bool? dhuhaReminder,
    ReminderTime? fastingReminderTime,
  }) => IslamicCalendarSettings(
    hijriAdjustment: (hijriAdjustment ?? this.hijriAdjustment).clamp(-1, 1),
    mondayReminder: mondayReminder ?? this.mondayReminder,
    thursdayReminder: thursdayReminder ?? this.thursdayReminder,
    whiteDaysReminder: whiteDaysReminder ?? this.whiteDaysReminder,
    lastThirdReminder: lastThirdReminder ?? this.lastThirdReminder,
    dhuhaReminder: dhuhaReminder ?? this.dhuhaReminder,
    fastingReminderTime: fastingReminderTime ?? this.fastingReminderTime,
  );

  Map<String, Object> toJson() => {
    'hijriAdjustment': hijriAdjustment,
    'mondayReminder': mondayReminder,
    'thursdayReminder': thursdayReminder,
    'whiteDaysReminder': whiteDaysReminder,
    'lastThirdReminder': lastThirdReminder,
    'dhuhaReminder': dhuhaReminder,
    'fastingReminderTime': fastingReminderTime.toJson(),
  };

  static IslamicCalendarSettings fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      return const IslamicCalendarSettings();
    }
    final adjustment = value['hijriAdjustment'];
    return IslamicCalendarSettings(
      hijriAdjustment: adjustment is int && adjustment >= -1 && adjustment <= 1
          ? adjustment
          : 0,
      mondayReminder: value['mondayReminder'] == true,
      thursdayReminder: value['thursdayReminder'] == true,
      whiteDaysReminder: value['whiteDaysReminder'] == true,
      lastThirdReminder: value['lastThirdReminder'] == true,
      dhuhaReminder: value['dhuhaReminder'] == true,
      fastingReminderTime:
          ReminderTime.fromJson(value['fastingReminderTime']) ??
          const ReminderTime(20, 0),
    );
  }
}

@immutable
class DailyIslamicState {
  const DailyIslamicState({
    required this.gregorianDate,
    required this.hijriDate,
    required this.fastingDays,
    required this.moonSightingDisclaimer,
    this.todayOccasion,
    this.upcomingOccasion,
    this.upcomingOccasionDate,
    this.night,
    this.dhuha,
  });

  final DateTime gregorianDate;
  final HijriDate hijriDate;
  final Set<FastingDayType> fastingDays;
  final bool moonSightingDisclaimer;
  final IslamicOccasion? todayOccasion;
  final IslamicOccasion? upcomingOccasion;
  final DateTime? upcomingOccasionDate;
  final NightTimeWindow? night;
  final DhuhaWindow? dhuha;
}
