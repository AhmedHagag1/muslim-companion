import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/islamic_daily.dart';

class IslamicCalendarSettingsRepository {
  static const storageKey = 'islamic.daily.settings.v1';

  Future<IslamicCalendarSettings> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(storageKey);
    if (raw == null) return const IslamicCalendarSettings();
    try {
      final root = jsonDecode(raw);
      if (root is! Map<String, dynamic> || root['schemaVersion'] != 1) {
        return const IslamicCalendarSettings();
      }
      return IslamicCalendarSettings.fromJson(root['settings']);
    } catch (_) {
      return const IslamicCalendarSettings();
    }
  }

  Future<void> save(IslamicCalendarSettings settings) async {
    await (await SharedPreferences.getInstance()).setString(
      storageKey,
      jsonEncode({'schemaVersion': 1, 'settings': settings.toJson()}),
    );
  }
}
