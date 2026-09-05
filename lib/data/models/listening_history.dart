import 'surah.dart';

class ListeningHistoryEntry {
  const ListeningHistoryEntry({
    required this.surahNumber,
    required this.ayahNumber,
    required this.reciterId,
    required this.updatedAt,
  });

  final int surahNumber;
  final int ayahNumber;
  final String reciterId;
  final DateTime updatedAt;

  Map<String, Object> toJson() => {
    'surah': surahNumber,
    'ayah': ayahNumber,
    'reciter': reciterId,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  static ListeningHistoryEntry? tryParse(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final surah = value['surah'];
    final ayah = value['ayah'];
    final reciter = value['reciter'];
    final updatedAt = DateTime.tryParse(value['updatedAt']?.toString() ?? '');
    if (surah is! int ||
        ayah is! int ||
        reciter is! String ||
        reciter.trim().isEmpty ||
        updatedAt == null ||
        surah < 1 ||
        surah > QuranMetadata.surahCount ||
        ayah < 1 ||
        ayah > QuranMetadata.surah(surah).ayahCount) {
      return null;
    }
    return ListeningHistoryEntry(
      surahNumber: surah,
      ayahNumber: ayah,
      reciterId: reciter,
      updatedAt: updatedAt.toUtc(),
    );
  }
}

class ListeningPreferencesSnapshot {
  const ListeningPreferencesSnapshot({
    this.selectedReciterId,
    this.repeatMode = 'off',
    this.playbackSpeed = 1,
    this.history = const [],
  });

  final String? selectedReciterId;
  final String repeatMode;
  final double playbackSpeed;
  final List<ListeningHistoryEntry> history;
}
