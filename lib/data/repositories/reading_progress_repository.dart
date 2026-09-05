import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/reading_progress.dart';
import '../models/surah.dart';

abstract interface class ReadingProgressStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesReadingProgressStore implements ReadingProgressStore {
  static const String _key = 'quran.reading_progress';

  @override
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_key);
  }

  @override
  Future<void> write(String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, value);
  }
}

class ReadingProgressRepository {
  ReadingProgressRepository({ReadingProgressStore? store})
    : _store = store ?? SharedPreferencesReadingProgressStore();

  static const int schemaVersion = 2;

  final ReadingProgressStore _store;

  Future<ReadingProgress?> load() async {
    final value = await _store.read();
    if (value == null) return null;

    try {
      final document = jsonDecode(value);
      if (document is! Map<String, dynamic> ||
          (document['version'] != 1 && document['version'] != schemaVersion) ||
          document['progress'] is! Map<String, dynamic>) {
        return null;
      }
      final progress = ReadingProgress.fromJson(
        document['progress'] as Map<String, dynamic>,
      );
      if (progress == null ||
          progress.surahNumber < 1 ||
          progress.surahNumber > QuranMetadata.surahCount ||
          progress.ayahNumber < 1 ||
          progress.ayahNumber >
              QuranMetadata.surah(progress.surahNumber).ayahCount) {
        return null;
      }
      if (document['version'] == 1) await save(progress);
      return progress;
    } on FormatException {
      return null;
    }
  }

  Future<void> save(ReadingProgress progress) {
    return _store.write(
      jsonEncode({'version': schemaVersion, 'progress': progress.toJson()}),
    );
  }
}
