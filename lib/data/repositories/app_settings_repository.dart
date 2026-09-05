import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

abstract interface class AppSettingsStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesAppSettingsStore implements AppSettingsStore {
  static const key = 'app.settings.v1';
  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);
}

class AppSettingsRepository {
  AppSettingsRepository({AppSettingsStore? store})
    : _store = store ?? SharedPreferencesAppSettingsStore();
  final AppSettingsStore _store;
  static const version = 2;
  Future<AppSettings> load() async {
    try {
      final d = jsonDecode((await _store.read()) ?? '');
      if (d is! Map<String, dynamic> ||
          (d['version'] != 1 && d['version'] != version)) {
        return const AppSettings();
      }
      final settings = AppSettings.fromJson(d['settings']);
      if (d['version'] == 1) await save(settings);
      return settings;
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings s) =>
      _store.write(jsonEncode({'version': version, 'settings': s.toJson()}));
}
