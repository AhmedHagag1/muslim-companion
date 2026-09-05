import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/religious_content.dart';
import '../models/tasbeeh.dart';
import 'religious_content_repository.dart';

abstract interface class TasbeehStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesTasbeehStore implements TasbeehStore {
  static const key = 'tasbeeh.state.v1';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);
}

class TasbeehRepository {
  TasbeehRepository({
    ReligiousContentRepository? contentRepository,
    TasbeehStore? store,
  }) : _contentRepository = contentRepository ?? ReligiousContentRepository(),
       _store = store ?? SharedPreferencesTasbeehStore();

  final ReligiousContentRepository _contentRepository;
  final TasbeehStore _store;

  Future<ReligiousContentPack> loadContent() => _contentRepository.load();

  Future<TasbeehState?> loadState() async {
    try {
      final value = jsonDecode((await _store.read()) ?? '');
      if (value is! Map<String, dynamic> || value['version'] != 1) return null;
      return TasbeehState.fromJson(value['state']);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveState(TasbeehState state) =>
      _store.write(jsonEncode({'version': 1, 'state': state.toJson()}));
}
