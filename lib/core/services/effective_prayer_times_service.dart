import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'prayer_api_service.dart';
import 'prayer_times_service.dart';

abstract interface class DeviceTimezoneProvider {
  Future<String> currentTimezone();
}

class FlutterDeviceTimezoneProvider implements DeviceTimezoneProvider {
  @override
  Future<String> currentTimezone() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;
}

class EffectivePrayerTimesService {
  EffectivePrayerTimesService({
    PrayerApiService? remote,
    PrayerTimesService? local,
    DeviceTimezoneProvider? timezoneProvider,
  }) : remote = remote ?? PrayerApiService(),
       local = local ?? PrayerTimesService(),
       timezoneProvider = timezoneProvider ?? FlutterDeviceTimezoneProvider() {
    tz_data.initializeTimeZones();
  }

  final PrayerApiService remote;
  final PrayerTimesService local;
  final DeviceTimezoneProvider timezoneProvider;

  Future<EffectivePrayerTimes> resolve({
    required double latitude,
    required double longitude,
    required PrayerSettings settings,
    required DateTime date,
  }) async {
    try {
      final result = await remote.getTodayPrayerTimes(
        latitude: latitude,
        longitude: longitude,
        settings: settings,
        date: date,
      );
      return EffectivePrayerTimes(
        source: PrayerTimesSource.remote,
        settings: settings,
        date: date,
        timezone: result.timezone,
        times: result.times,
      ).applyAdjustments();
    } on PrayerFetchFailure {
      return _local(
        latitude: latitude,
        longitude: longitude,
        settings: settings,
        date: date,
      );
    }
  }

  Future<EffectivePrayerTimes> _local({
    required double latitude,
    required double longitude,
    required PrayerSettings settings,
    required DateTime date,
  }) async {
    String identifier;
    try {
      identifier = await timezoneProvider.currentTimezone();
      tz.getLocation(identifier);
    } catch (_) {
      identifier = tz.local.name;
    }
    final times = local.getTodayPrayerTimes(
      latitude: latitude,
      longitude: longitude,
      date: date,
      timezone: identifier,
      settings: settings,
    );
    return EffectivePrayerTimes(
      source: PrayerTimesSource.local,
      settings: settings,
      date: date,
      timezone: identifier,
      times: times,
    ).applyAdjustments();
  }

  void dispose() => remote.dispose();
}
