import 'package:flutter/foundation.dart';

enum PrayerCalculationMethod {
  muslimWorldLeague,
  egyptian,
  ummAlQura,
  karachi,
  isna,
}

enum PrayerMadhab { standard, hanafi }

enum PrayerHighLatitudeRule { middleOfNight, seventhOfNight, twilightAngle }

enum PrayerTimesSource { remote, local }

extension PrayerCalculationMethodInfo on PrayerCalculationMethod {
  int get alAdhanId => switch (this) {
    PrayerCalculationMethod.muslimWorldLeague => 3,
    PrayerCalculationMethod.egyptian => 5,
    PrayerCalculationMethod.ummAlQura => 4,
    PrayerCalculationMethod.karachi => 1,
    PrayerCalculationMethod.isna => 2,
  };

  String get arabicName => switch (this) {
    PrayerCalculationMethod.muslimWorldLeague => 'رابطة العالم الإسلامي',
    PrayerCalculationMethod.egyptian => 'الهيئة المصرية العامة للمساحة',
    PrayerCalculationMethod.ummAlQura => 'أم القرى',
    PrayerCalculationMethod.karachi => 'جامعة العلوم الإسلامية - كراتشي',
    PrayerCalculationMethod.isna => 'الجمعية الإسلامية لأمريكا الشمالية',
  };
}

extension PrayerMadhabInfo on PrayerMadhab {
  int get alAdhanSchool => this == PrayerMadhab.hanafi ? 1 : 0;
  String get arabicName => this == PrayerMadhab.hanafi ? 'حنفي' : 'قياسي';
}

extension PrayerHighLatitudeRuleInfo on PrayerHighLatitudeRule {
  int get alAdhanId => switch (this) {
    PrayerHighLatitudeRule.middleOfNight => 1,
    PrayerHighLatitudeRule.seventhOfNight => 2,
    PrayerHighLatitudeRule.twilightAngle => 3,
  };

  String get arabicName => switch (this) {
    PrayerHighLatitudeRule.middleOfNight => 'منتصف الليل',
    PrayerHighLatitudeRule.seventhOfNight => 'سُبع الليل',
    PrayerHighLatitudeRule.twilightAngle => 'زاوية الشفق',
  };
}

@immutable
class PrayerSettings {
  const PrayerSettings({
    this.method = PrayerCalculationMethod.muslimWorldLeague,
    this.madhab = PrayerMadhab.standard,
    this.highLatitudeRule = PrayerHighLatitudeRule.middleOfNight,
    this.adjustments = const {},
  });

  final PrayerCalculationMethod method;
  final PrayerMadhab madhab;
  final PrayerHighLatitudeRule highLatitudeRule;
  final Map<String, int> adjustments;

  int adjustmentFor(String name) => adjustments[name]?.clamp(-30, 30) ?? 0;

  PrayerSettings copyWith({
    PrayerCalculationMethod? method,
    PrayerMadhab? madhab,
    PrayerHighLatitudeRule? highLatitudeRule,
    Map<String, int>? adjustments,
  }) => PrayerSettings(
    method: method ?? this.method,
    madhab: madhab ?? this.madhab,
    highLatitudeRule: highLatitudeRule ?? this.highLatitudeRule,
    adjustments: Map.unmodifiable(adjustments ?? this.adjustments),
  );

  Map<String, Object> toJson() => {
    'method': method.name,
    'madhab': madhab.name,
    'highLatitudeRule': highLatitudeRule.name,
    'adjustments': adjustments,
  };

  static PrayerSettings fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return const PrayerSettings();
    T valueOf<T extends Enum>(List<T> values, Object? raw, T fallback) =>
        values.where((item) => item.name == raw).firstOrNull ?? fallback;
    final rawAdjustments = value['adjustments'];
    final adjustments = <String, int>{};
    if (rawAdjustments is Map) {
      for (final name in adjustablePrayerNames) {
        final raw = rawAdjustments[name];
        if (raw is int && raw >= -30 && raw <= 30) adjustments[name] = raw;
      }
    }
    return PrayerSettings(
      method: valueOf(
        PrayerCalculationMethod.values,
        value['method'],
        PrayerCalculationMethod.muslimWorldLeague,
      ),
      madhab: valueOf(
        PrayerMadhab.values,
        value['madhab'],
        PrayerMadhab.standard,
      ),
      highLatitudeRule: valueOf(
        PrayerHighLatitudeRule.values,
        value['highLatitudeRule'],
        PrayerHighLatitudeRule.middleOfNight,
      ),
      adjustments: Map.unmodifiable(adjustments),
    );
  }
}

const adjustablePrayerNames = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];

@immutable
class PrayerTimeItem {
  const PrayerTimeItem({required this.name, required this.time});
  final String name;
  final DateTime time;

  PrayerTimeItem adjusted(int minutes) => PrayerTimeItem(
    name: name,
    time: time.add(Duration(minutes: minutes.clamp(-30, 30))),
  );
}

@immutable
class EffectivePrayerTimes {
  const EffectivePrayerTimes({
    required this.source,
    required this.settings,
    required this.date,
    required this.timezone,
    required this.times,
  });
  final PrayerTimesSource source;
  final PrayerSettings settings;
  final DateTime date;
  final String timezone;
  final List<PrayerTimeItem> times;

  PrayerTimeItem? named(String name) =>
      times.where((item) => item.name == name).firstOrNull;

  EffectivePrayerTimes applyAdjustments() => EffectivePrayerTimes(
    source: source,
    settings: settings,
    date: date,
    timezone: timezone,
    times: List.unmodifiable(
      times.map((item) => item.adjusted(settings.adjustmentFor(item.name))),
    ),
  );
}
