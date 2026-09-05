import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/religious_content.dart';
import 'religious_content_repository.dart';

abstract interface class DuaFavoritesStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesDuaFavoritesStore implements DuaFavoritesStore {
  static const key = 'dua.favorites.v1';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);
}

class DuaRepository {
  DuaRepository({
    ReligiousContentRepository? contentRepository,
    DuaFavoritesStore? store,
  }) : _contentRepository = contentRepository ?? ReligiousContentRepository(),
       _store = store ?? SharedPreferencesDuaFavoritesStore();

  final ReligiousContentRepository _contentRepository;
  final DuaFavoritesStore _store;

  Future<ReligiousContentPack> loadContent() => _contentRepository.load();

  Future<Set<String>> loadFavorites() async {
    try {
      final value = jsonDecode((await _store.read()) ?? '');
      if (value is! Map<String, dynamic> || value['version'] != 1) {
        return {};
      }
      final ids = value['ids'];
      if (ids is! List || ids.any((id) => id is! String)) return {};
      return ids.cast<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> saveFavorites(Set<String> ids) =>
      _store.write(jsonEncode({'version': 1, 'ids': ids.toList()..sort()}));
}
