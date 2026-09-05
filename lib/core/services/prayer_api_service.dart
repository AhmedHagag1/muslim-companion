import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'prayer_models.dart';

enum PrayerFetchFailureType { timeout, network, service, malformed }

class PrayerFetchFailure implements Exception {
  const PrayerFetchFailure(this.type);
  final PrayerFetchFailureType type;
}

class RemotePrayerTimes {
  const RemotePrayerTimes({required this.times, required this.timezone});
  final List<PrayerTimeItem> times;
  final String timezone;
}

class PrayerApiService {
  PrayerApiService({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client() {
    tz_data.initializeTimeZones();
  }

  final http.Client _client;
  final Duration timeout;
  static const String _baseUrl = 'https://api.aladhan.com/v1';

  Future<RemotePrayerTimes> getTodayPrayerTimes({
    required double latitude,
    required double longitude,
    required PrayerSettings settings,
    DateTime? date,
  }) async {
    final value = date ?? DateTime.now();
    final dateParameter =
        '${value.day.toString().padLeft(2, '0')}-${value.month.toString().padLeft(2, '0')}-${value.year}';
    final uri = Uri.parse('$_baseUrl/timings/$dateParameter').replace(
      queryParameters: {
        'latitude': '$latitude',
        'longitude': '$longitude',
        'method': '${settings.method.alAdhanId}',
        'school': '${settings.madhab.alAdhanSchool}',
        'latitudeAdjustmentMethod': '${settings.highLatitudeRule.alAdhanId}',
      },
    );

    http.Response response;
    try {
      response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(timeout);
    } on TimeoutException {
      throw const PrayerFetchFailure(PrayerFetchFailureType.timeout);
    } catch (_) {
      throw const PrayerFetchFailure(PrayerFetchFailureType.network);
    }
    if (response.statusCode != 200) {
      throw const PrayerFetchFailure(PrayerFetchFailureType.service);
    }

    try {
      final root = jsonDecode(response.body);
      if (root is! Map<String, dynamic> ||
          root['code'] != 200 ||
          root['data'] is! Map<String, dynamic>) {
        throw const PrayerFetchFailure(PrayerFetchFailureType.malformed);
      }
      final data = root['data'] as Map<String, dynamic>;
      final timings = data['timings'];
      final meta = data['meta'];
      if (timings is! Map<String, dynamic> || meta is! Map<String, dynamic>) {
        throw const PrayerFetchFailure(PrayerFetchFailureType.malformed);
      }
      final timezone = meta['timezone']?.toString();
      if (timezone == null || timezone.isEmpty) {
        throw const PrayerFetchFailure(PrayerFetchFailureType.malformed);
      }
      final location = tz.getLocation(timezone);
      final times = <PrayerTimeItem>[
        PrayerTimeItem(
          name: 'الفجر',
          time: _parseTime(timings['Fajr'], value, location),
        ),
        PrayerTimeItem(
          name: 'الشروق',
          time: _parseTime(timings['Sunrise'], value, location),
        ),
        PrayerTimeItem(
          name: 'الظهر',
          time: _parseTime(timings['Dhuhr'], value, location),
        ),
        PrayerTimeItem(
          name: 'العصر',
          time: _parseTime(timings['Asr'], value, location),
        ),
        PrayerTimeItem(
          name: 'المغرب',
          time: _parseTime(timings['Maghrib'], value, location),
        ),
        PrayerTimeItem(
          name: 'العشاء',
          time: _parseTime(timings['Isha'], value, location),
        ),
      ];
      _validate(times);
      return RemotePrayerTimes(
        times: List.unmodifiable(times),
        timezone: timezone,
      );
    } on PrayerFetchFailure {
      rethrow;
    } catch (_) {
      throw const PrayerFetchFailure(PrayerFetchFailureType.malformed);
    }
  }

  DateTime _parseTime(Object? value, DateTime date, tz.Location location) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})',
    ).firstMatch(value?.toString() ?? '');
    if (match == null) {
      throw const PrayerFetchFailure(PrayerFetchFailureType.malformed);
    }
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      throw const PrayerFetchFailure(PrayerFetchFailureType.malformed);
    }
    return tz.TZDateTime(
      location,
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
  }

  void _validate(List<PrayerTimeItem> times) {
    if (times.length != 6) {
      throw const PrayerFetchFailure(PrayerFetchFailureType.malformed);
    }
    for (var index = 1; index < times.length; index++) {
      if (!times[index].time.isAfter(times[index - 1].time)) {
        throw const PrayerFetchFailure(PrayerFetchFailureType.malformed);
      }
    }
  }

  void dispose() => _client.close();
}
