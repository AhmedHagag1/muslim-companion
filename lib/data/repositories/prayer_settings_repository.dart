import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/prayer_models.dart';

abstract interface class PrayerSettingsStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesPrayerSettingsStore implements PrayerSettingsStore {
  static const key = 'prayer.settings.v2';
  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);
}

class PrayerSettingsRepository {
  PrayerSettingsRepository({PrayerSettingsStore? store})
    : _store = store ?? SharedPreferencesPrayerSettingsStore();
  final PrayerSettingsStore _store;
  static const schemaVersion = 1;

  Future<PrayerSettings> load() async {
    try {
      final value = jsonDecode((await _store.read()) ?? '');
      if (value is! Map<String, dynamic> || value['version'] != schemaVersion) {
        return const PrayerSettings();
      }
      return PrayerSettings.fromJson(value['settings']);
    } catch (_) {
      return const PrayerSettings();
    }
  }

  Future<void> save(PrayerSettings settings) => _store.write(
    jsonEncode({'version': schemaVersion, 'settings': settings.toJson()}),
  );
}
