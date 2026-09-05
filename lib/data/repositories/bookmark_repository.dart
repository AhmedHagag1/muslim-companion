import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/quran_bookmark.dart';

abstract interface class BookmarkStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesBookmarkStore implements BookmarkStore {
  static const _key = 'quran.bookmarks';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String value) async {
    await (await SharedPreferences.getInstance()).setString(_key, value);
  }
}

class BookmarkRepository {
  BookmarkRepository({BookmarkStore? store})
    : _store = store ?? SharedPreferencesBookmarkStore();

  static const schemaVersion = 2;
  final BookmarkStore _store;

  Future<List<QuranBookmark>> load() async {
    final raw = await _store.read();
    if (raw == null) return const [];
    try {
      final document = jsonDecode(raw);
      if (document is! Map<String, dynamic> ||
          (document['version'] != 1 && document['version'] != schemaVersion) ||
          document['bookmarks'] is! List) {
        return const [];
      }
      final bookmarks = (document['bookmarks'] as List)
          .whereType<Map<String, dynamic>>()
          .map(QuranBookmark.fromJson)
          .whereType<QuranBookmark>()
          .toList();
      if (document['version'] == 1) await save(bookmarks);
      return bookmarks;
    } on FormatException {
      return const [];
    }
  }

  Future<void> save(List<QuranBookmark> bookmarks) {
    return _store.write(
      jsonEncode({
        'version': schemaVersion,
        'bookmarks': bookmarks.map((bookmark) => bookmark.toJson()).toList(),
      }),
    );
  }
}
