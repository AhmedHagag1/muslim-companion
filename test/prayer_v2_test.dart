import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran_app/core/services/effective_prayer_times_service.dart';
import 'package:quran_app/core/services/prayer_api_service.dart';
import 'package:quran_app/core/services/prayer_times_service.dart';
import 'package:quran_app/data/repositories/prayer_settings_repository.dart';

void main() {
  group('Prayer V2', () {
    test('all exposed methods map to implemented AlAdhan IDs', () {
      expect(PrayerCalculationMethod.values.map((e) => e.alAdhanId).toSet(), {
        1,
        2,
        3,
        4,
        5,
      });
    });

    test(
      'calculation settings persist with madhab, rule and adjustments',
      () async {
        final store = _MemoryPrayerSettingsStore();
        final repository = PrayerSettingsRepository(store: store);
        const settings = PrayerSettings(
          method: PrayerCalculationMethod.egyptian,
          madhab: PrayerMadhab.hanafi,
          highLatitudeRule: PrayerHighLatitudeRule.twilightAngle,
          adjustments: {'الفجر': 5},
        );
        await repository.save(settings);
        final loaded = await repository.load();
        expect(loaded.method, settings.method);
        expect(loaded.madhab, settings.madhab);
        expect(loaded.highLatitudeRule, settings.highLatitudeRule);
        expect(loaded.adjustmentFor('الفجر'), 5);
      },
    );

    test(
      'malformed settings recover and adjustment values are bounded',
      () async {
        final store = _MemoryPrayerSettingsStore()..value = '{bad';
        expect(
          (await PrayerSettingsRepository(store: store).load()).method,
          PrayerCalculationMethod.muslimWorldLeague,
        );
        expect(
          const PrayerSettings(
            adjustments: {'الفجر': 99},
          ).adjustmentFor('الفجر'),
          30,
        );
      },
    );

    test('local calculation uses configured timezone, method and madhab', () {
      final values = PrayerTimesService().getTodayPrayerTimes(
        latitude: 40.7128,
        longitude: -74.0060,
        date: DateTime(2026, 8, 14),
        timezone: 'America/New_York',
        settings: const PrayerSettings(
          method: PrayerCalculationMethod.isna,
          madhab: PrayerMadhab.standard,
        ),
      );
      expect(values, hasLength(6));
      expect(values.first.time.timeZoneOffset, const Duration(hours: -4));
      expect(
        values.map((e) => e.time).toList(),
        orderedEquals(values.map((e) => e.time).toList()..sort()),
      );
    });

    test('remote parsing is safe and honors response timezone', () async {
      final client = MockClient(
        (request) async => http.Response(jsonEncode(_response()), 200),
      );
      final result = await PrayerApiService(client: client).getTodayPrayerTimes(
        latitude: 30,
        longitude: 31,
        settings: const PrayerSettings(),
        date: DateTime(2026, 8, 14),
      );
      expect(result.timezone, 'Africa/Cairo');
      expect(result.times, hasLength(6));
      expect(result.times.first.time.hour, 4);
    });

    test('invalid remote response becomes typed malformed failure', () async {
      final service = PrayerApiService(
        client: MockClient(
          (_) async => http.Response('{"code":200,"data":{}}', 200),
        ),
      );
      expect(
        () => service.getTodayPrayerTimes(
          latitude: 1,
          longitude: 1,
          settings: const PrayerSettings(),
        ),
        throwsA(
          isA<PrayerFetchFailure>().having(
            (e) => e.type,
            'type',
            PrayerFetchFailureType.malformed,
          ),
        ),
      );
    });

    test('remote timeout becomes typed timeout failure', () async {
      final service = PrayerApiService(
        client: MockClient((_) => Completer<http.Response>().future),
        timeout: const Duration(milliseconds: 2),
      );
      expect(
        () => service.getTodayPrayerTimes(
          latitude: 1,
          longitude: 1,
          settings: const PrayerSettings(),
        ),
        throwsA(
          isA<PrayerFetchFailure>().having(
            (e) => e.type,
            'type',
            PrayerFetchFailureType.timeout,
          ),
        ),
      );
    });

    test(
      'service failure falls back locally and applies adjustment once',
      () async {
        final remote = PrayerApiService(
          client: MockClient((_) async => http.Response('unavailable', 503)),
        );
        final service = EffectivePrayerTimesService(
          remote: remote,
          timezoneProvider: _Timezone('Europe/London'),
        );
        final result = await service.resolve(
          latitude: 51.5,
          longitude: -.12,
          settings: const PrayerSettings(adjustments: {'الفجر': 5}),
          date: DateTime(2026, 8, 14),
        );
        final raw = PrayerTimesService().getTodayPrayerTimes(
          latitude: 51.5,
          longitude: -.12,
          date: DateTime(2026, 8, 14),
          timezone: 'Europe/London',
          settings: const PrayerSettings(adjustments: {'الفجر': 5}),
        );
        expect(result.source, PrayerTimesSource.local);
        expect(result.timezone, 'Europe/London');
        expect(
          result.named('الفجر')!.time.difference(raw.first.time),
          const Duration(minutes: 5),
        );
      },
    );
  });
}

Map<String, Object> _response() => {
  'code': 200,
  'data': {
    'timings': {
      'Fajr': '04:10 (EEST)',
      'Sunrise': '05:40',
      'Dhuhr': '12:10',
      'Asr': '15:40',
      'Maghrib': '18:35',
      'Isha': '20:00',
    },
    'meta': {'timezone': 'Africa/Cairo'},
  },
};

class _Timezone implements DeviceTimezoneProvider {
  const _Timezone(this.value);
  final String value;
  @override
  Future<String> currentTimezone() async => value;
}

class _MemoryPrayerSettingsStore implements PrayerSettingsStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}
