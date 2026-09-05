import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class QuranSearchHistoryRepository {
  static const _key = 'quran.search.recent.v1';

  Future<List<String>> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      final decoded = jsonDecode(raw ?? '[]');
      if (decoded is! List) return const [];
      return decoded
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .take(8)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<String>> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return load();
    final recent = await load();
    final next = [
      trimmed,
      ...recent.where((value) => value != trimmed),
    ].take(8).toList();
    await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(next),
    );
    return next;
  }

  Future<void> clear() async {
    await (await SharedPreferences.getInstance()).remove(_key);
  }
}
