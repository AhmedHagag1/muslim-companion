import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/listening_history.dart';

abstract interface class ListeningHistoryStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesListeningHistoryStore implements ListeningHistoryStore {
  static const _key = 'quran.listening.v1';

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

class ListeningHistoryRepository {
  ListeningHistoryRepository({ListeningHistoryStore? store})
    : _store = store ?? SharedPreferencesListeningHistoryStore();

  static const schemaVersion = 1;
  static const maxEntries = 12;

  final ListeningHistoryStore _store;

  Future<ListeningPreferencesSnapshot> load() async {
    final raw = await _store.read();
    if (raw == null) return const ListeningPreferencesSnapshot();
    try {
      final document = jsonDecode(raw);
      if (document is! Map<String, dynamic> ||
          document['version'] != schemaVersion) {
        return const ListeningPreferencesSnapshot();
      }
      final reciter = document['selectedReciter'];
      final repeat = document['repeatMode'];
      final speedValue = document['playbackSpeed'];
      final speed = speedValue is num ? speedValue.toDouble() : 1.0;
      final historyValue = document['history'];
      final history = historyValue is List
          ? historyValue
                .map(ListeningHistoryEntry.tryParse)
                .whereType<ListeningHistoryEntry>()
                .take(maxEntries)
                .toList(growable: false)
          : const <ListeningHistoryEntry>[];
      return ListeningPreferencesSnapshot(
        selectedReciterId: reciter is String && reciter.trim().isNotEmpty
            ? reciter
            : null,
        repeatMode: repeat == 'ayah' || repeat == 'surah' ? repeat : 'off',
        playbackSpeed: speed.isFinite && speed >= 0.5 && speed <= 2 ? speed : 1,
        history: history,
      );
    } on FormatException {
      return const ListeningPreferencesSnapshot();
    }
  }

  Future<void> save(ListeningPreferencesSnapshot snapshot) {
    return _store.write(
      jsonEncode({
        'version': schemaVersion,
        'selectedReciter': snapshot.selectedReciterId,
        'repeatMode': snapshot.repeatMode,
        'playbackSpeed': snapshot.playbackSpeed,
        'history': snapshot.history
            .take(maxEntries)
            .map((entry) => entry.toJson())
            .toList(growable: false),
      }),
    );
  }
}
