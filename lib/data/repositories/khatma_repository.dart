import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/khatma.dart';

abstract interface class KhatmaStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesKhatmaStore implements KhatmaStore {
  static const key = 'quran.khatma.v1';
  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);
}

class KhatmaRepository {
  KhatmaRepository({KhatmaStore? store})
    : _store = store ?? SharedPreferencesKhatmaStore();
  final KhatmaStore _store;
  static const schemaVersion = 2;
  Future<List<KhatmaPlan>> load() async {
    try {
      final root = jsonDecode((await _store.read()) ?? '');
      if (root is! Map<String, dynamic> ||
          (root['version'] != 1 && root['version'] != schemaVersion) ||
          root['plans'] is! List) {
        return const [];
      }
      final plans = List<KhatmaPlan>.unmodifiable(
        (root['plans'] as List)
            .map(KhatmaPlan.fromJson)
            .whereType<KhatmaPlan>(),
      );
      if (root['version'] == 1) await save(plans);
      return plans;
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<KhatmaPlan> plans) => _store.write(
    jsonEncode({
      'version': schemaVersion,
      'plans': plans.map((e) => e.toJson()).toList(),
    }),
  );
}
