import 'package:hijri_core/hijri_core.dart' as hijri_core;

import '../../data/models/islamic_daily.dart';

/// Offline Umm al-Qura conversion backed by hijri_core's KACST-derived table.
/// Results are calculated civil dates and may differ from local moon sighting.
class IslamicDailyService {
  const IslamicDailyService();

  static const moonSightingDisclaimerArabic =
      'تاريخ هجري محسوب وفق تقويم أم القرى، وقد يختلف عن الإعلان الرسمي حسب رؤية الهلال في بلدك.';

  static const occasions = <IslamicOccasion>[
    IslamicOccasion(
      id: 'muharram-start',
      month: 1,
      day: 1,
      titleArabic: 'بداية شهر المحرم — تاريخ محسوب',
    ),
    IslamicOccasion(
      id: 'ashura',
      month: 1,
      day: 10,
      titleArabic: 'يوم عاشوراء — تاريخ محسوب',
    ),
    IslamicOccasion(
      id: 'ramadan-start',
      month: 9,
      day: 1,
      titleArabic: 'بداية شهر رمضان — تاريخ محسوب',
    ),
    IslamicOccasion(
      id: 'shawwal-start',
      month: 10,
      day: 1,
      titleArabic: 'أول شوال — تاريخ محسوب',
    ),
    IslamicOccasion(
      id: 'arafah',
      month: 12,
      day: 9,
      titleArabic: 'يوم عرفة — تاريخ محسوب',
    ),
    IslamicOccasion(
      id: 'dhul-hijjah-ten',
      month: 12,
      day: 10,
      titleArabic: 'العاشر من ذي الحجة — تاريخ محسوب',
    ),
  ];

  HijriDate? toHijri(DateTime date, {int adjustment = 0}) {
    final safeAdjustment = adjustment.clamp(-1, 1);
    final civil = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).add(Duration(days: safeAdjustment));
    final converted = hijri_core.toHijri(civil);
    if (converted == null) return null;
    return HijriDate(
      year: converted.hy,
      month: converted.hm,
      day: converted.hd,
    );
  }

  DateTime? toGregorian(HijriDate date, {int adjustment = 0}) {
    final converted = hijri_core.toGregorian(date.year, date.month, date.day);
    if (converted == null) return null;
    return DateTime(
      converted.year,
      converted.month,
      converted.day,
    ).subtract(Duration(days: adjustment.clamp(-1, 1)));
  }

  int daysInMonth(int year, int month) =>
      hijri_core.daysInHijriMonth(year, month);

  Set<FastingDayType> fastingIndicators(DateTime gregorian, HijriDate hijri) {
    final result = <FastingDayType>{};
    if (gregorian.weekday == DateTime.monday) {
      result.add(FastingDayType.monday);
    }
    if (gregorian.weekday == DateTime.thursday) {
      result.add(FastingDayType.thursday);
    }
    if (hijri.day >= 13 && hijri.day <= 15) {
      result.add(FastingDayType.whiteDay);
    }
    return Set.unmodifiable(result);
  }

  NightTimeWindow? nightWindow(DateTime? maghrib, DateTime? nextFajr) {
    if (maghrib == null || nextFajr == null || !nextFajr.isAfter(maghrib)) {
      return null;
    }
    final seconds = nextFajr.difference(maghrib).inSeconds;
    return NightTimeWindow(
      maghrib: maghrib,
      nextFajr: nextFajr,
      midpoint: maghrib.add(Duration(seconds: seconds ~/ 2)),
      lastThirdStart: maghrib.add(Duration(seconds: seconds * 2 ~/ 3)),
    );
  }

  /// Conservative product guidance: sunrise +20m through Dhuhr -10m.
  /// It is deliberately labelled calculated guidance, not an optimum ruling.
  DhuhaWindow? dhuhaWindow(DateTime? sunrise, DateTime? dhuhr) {
    if (sunrise == null || dhuhr == null) return null;
    final start = sunrise.add(const Duration(minutes: 20));
    final end = dhuhr.subtract(const Duration(minutes: 10));
    return end.isAfter(start) ? DhuhaWindow(start: start, end: end) : null;
  }

  IslamicOccasion? occasionFor(HijriDate date) =>
      occasions.where((item) => item.occursOn(date)).firstOrNull;

  ({IslamicOccasion occasion, DateTime date})? nextOccasion(
    DateTime from, {
    required int adjustment,
  }) {
    for (var offset = 0; offset <= 370; offset++) {
      final date = DateTime(from.year, from.month, from.day + offset);
      final hijri = toHijri(date, adjustment: adjustment);
      if (hijri == null) continue;
      final occasion = occasionFor(hijri);
      if (occasion != null) return (occasion: occasion, date: date);
    }
    return null;
  }

  DailyIslamicState? buildState({
    required DateTime now,
    required IslamicCalendarSettings settings,
    DateTime? maghrib,
    DateTime? nextFajr,
    DateTime? sunrise,
    DateTime? dhuhr,
  }) {
    final day = DateTime(now.year, now.month, now.day);
    final hijri = toHijri(day, adjustment: settings.hijriAdjustment);
    if (hijri == null) return null;
    final upcoming = nextOccasion(day, adjustment: settings.hijriAdjustment);
    return DailyIslamicState(
      gregorianDate: day,
      hijriDate: hijri,
      fastingDays: fastingIndicators(day, hijri),
      moonSightingDisclaimer: true,
      todayOccasion: occasionFor(hijri),
      upcomingOccasion: upcoming?.occasion,
      upcomingOccasionDate: upcoming?.date,
      night: nightWindow(maghrib, nextFajr),
      dhuha: dhuhaWindow(sunrise, dhuhr),
    );
  }
}
