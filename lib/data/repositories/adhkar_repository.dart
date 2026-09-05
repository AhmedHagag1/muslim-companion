import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/adhkar.dart';
import '../models/religious_content.dart';
import 'religious_content_repository.dart';

class AdhkarData {
  const AdhkarData(this.categories, this.items, this.manifest);
  final List<DhikrCategory> categories;
  final List<DhikrItem> items;
  final ReligiousContentManifest? manifest;
}

abstract interface class AdhkarSessionStore {
  Future<String?> read();
  Future<void> write(String? value);
}

class SharedPreferencesAdhkarStore implements AdhkarSessionStore {
  static const key = 'adhkar.session.v1';
  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String? value) async {
    final p = await SharedPreferences.getInstance();
    value == null ? await p.remove(key) : await p.setString(key, value);
  }
}

class AdhkarRepository {
  AdhkarRepository({
    ReligiousContentRepository? contentRepository,
    AdhkarSessionStore? store,
  }) : _contentRepository = contentRepository ?? ReligiousContentRepository(),
       _store = store ?? SharedPreferencesAdhkarStore();
  final ReligiousContentRepository _contentRepository;
  final AdhkarSessionStore _store;
  Future<AdhkarData> loadData() async {
    try {
      final pack = await _contentRepository.load();
      return AdhkarData(pack.adhkarCategories, pack.adhkarItems, pack.manifest);
    } catch (_) {
      return const AdhkarData([], [], null);
    }
  }

  Future<DhikrSession?> loadSession() async {
    try {
      final d = jsonDecode((await _store.read()) ?? '');
      if (d is! Map<String, dynamic> || d['version'] != 1) return null;
      return DhikrSession.fromJson(d['session']);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession(DhikrSession? s) => _store.write(
    s == null ? null : jsonEncode({'version': 1, 'session': s.toJson()}),
  );
}
