import 'package:adhan_dart/adhan_dart.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'prayer_models.dart';
export 'prayer_models.dart';

class PrayerTimesService {
  PrayerTimesService() {
    tz_data.initializeTimeZones();
  }

  List<PrayerTimeItem> getTodayPrayerTimes({
    required double latitude,
    required double longitude,
    required DateTime date,
    required String timezone,
    required PrayerSettings settings,
  }) {
    final location = tz.getLocation(timezone);
    final calculationDate = tz.TZDateTime(
      location,
      date.year,
      date.month,
      date.day,
    );

    final coordinates = Coordinates(latitude, longitude);

    final parameters =
        switch (settings.method) {
            PrayerCalculationMethod.muslimWorldLeague =>
              CalculationMethodParameters.muslimWorldLeague(),
            PrayerCalculationMethod.egyptian =>
              CalculationMethodParameters.egyptian(),
            PrayerCalculationMethod.ummAlQura =>
              CalculationMethodParameters.ummAlQura(),
            PrayerCalculationMethod.karachi =>
              CalculationMethodParameters.karachi(),
            PrayerCalculationMethod.isna =>
              CalculationMethodParameters.northAmerica(),
          }
          ..madhab = settings.madhab == PrayerMadhab.hanafi
              ? Madhab.hanafi
              : Madhab.shafi
          ..highLatitudeRule = switch (settings.highLatitudeRule) {
            PrayerHighLatitudeRule.middleOfNight =>
              HighLatitudeRule.middleOfTheNight,
            PrayerHighLatitudeRule.seventhOfNight =>
              HighLatitudeRule.seventhOfTheNight,
            PrayerHighLatitudeRule.twilightAngle =>
              HighLatitudeRule.twilightAngle,
          };

    final prayerTimes = PrayerTimes(
      coordinates: coordinates,
      date: calculationDate,
      calculationParameters: parameters,
    );

    return [
      PrayerTimeItem(
        name: 'الفجر',
        time: tz.TZDateTime.from(prayerTimes.fajr, location),
      ),
      PrayerTimeItem(
        name: 'الشروق',
        time: tz.TZDateTime.from(prayerTimes.sunrise, location),
      ),
      PrayerTimeItem(
        name: 'الظهر',
        time: tz.TZDateTime.from(prayerTimes.dhuhr, location),
      ),
      PrayerTimeItem(
        name: 'العصر',
        time: tz.TZDateTime.from(prayerTimes.asr, location),
      ),
      PrayerTimeItem(
        name: 'المغرب',
        time: tz.TZDateTime.from(prayerTimes.maghrib, location),
      ),
      PrayerTimeItem(
        name: 'العشاء',
        time: tz.TZDateTime.from(prayerTimes.isha, location),
      ),
    ];
  }
}
