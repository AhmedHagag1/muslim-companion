import 'package:flutter/foundation.dart';

import '../../data/models/quran_verse.dart';
import '../../data/models/surah.dart';

enum QuranSearchFilter { all, surahs, ayahs }

@immutable
class QuranSearchResult {
  const QuranSearchResult({
    required this.surah,
    this.ayahNumber,
    this.canonicalText,
    this.matchFragment,
  });

  final Surah surah;
  final int? ayahNumber;
  final String? canonicalText;
  final String? matchFragment;

  bool get isSurah => ayahNumber == null;
  (int, int) get navigationCoordinate => (surah.number, ayahNumber ?? 1);
}

@immutable
class QuranSearchResults {
  const QuranSearchResults({required this.surahs, required this.ayahs});

  final List<QuranSearchResult> surahs;
  final List<QuranSearchResult> ayahs;
  int get total => surahs.length + ayahs.length;
}

@visibleForTesting
String normalizeQuranSearch(String value) => value
    // Uthmani superscript alef is a written alef for the primary index.
    .replaceAll('\u0670', 'ا')
    .replaceAll(RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]'), '')
    .replaceAll('\u0640', '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ؤ', 'و')
    .replaceAll('ئ', 'ي')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .toLowerCase();

class QuranSearchService {
  QuranSearchService(List<QuranVerse> verses)
    : assert(verses.length == 6236),
      _ayahIndex = List.unmodifiable(
        verses.map(
          (verse) => _IndexedAyah(
            verse,
            normalizeQuranSearch(verse.text),
            QuranMetadata.surah(verse.surahNumber),
          ),
        ),
      ),
      _surahIndex = List.unmodifiable(
        QuranMetadata.surahs.map(
          (surah) => _IndexedSurah(surah, normalizeQuranSearch(surah.name)),
        ),
      );

  final List<_IndexedAyah> _ayahIndex;
  final List<_IndexedSurah> _surahIndex;

  int get indexedAyahCount => _ayahIndex.length;

  QuranSearchResults search(
    String rawQuery, {
    QuranSearchFilter filter = QuranSearchFilter.all,
    int ayahLimit = 6236,
  }) {
    final query = normalizeQuranSearch(rawQuery);
    if (query.isEmpty) {
      return const QuranSearchResults(surahs: [], ayahs: []);
    }
    final coordinate = _coordinate(rawQuery);
    final surahNumberQuery = int.tryParse(query);
    final surahMatches = filter == QuranSearchFilter.ayahs
        ? const <QuranSearchResult>[]
        : _surahIndex
              .where(
                (entry) =>
                    entry.normalizedName.contains(query) ||
                    entry.surah.number == surahNumberQuery ||
                    entry.surah.number == coordinate?.$1,
              )
              .map((entry) => QuranSearchResult(surah: entry.surah))
              .toList(growable: false);

    if (filter == QuranSearchFilter.surahs) {
      return QuranSearchResults(surahs: surahMatches, ayahs: const []);
    }
    final nameAndAyah = _surahNameAndAyah(query);
    final ayahMatches = <QuranSearchResult>[];
    for (final entry in _ayahIndex) {
      final matchesCoordinate =
          coordinate != null &&
          entry.verse.surahNumber == coordinate.$1 &&
          entry.verse.ayahNumber == coordinate.$2;
      final matchesNameCoordinate =
          nameAndAyah != null &&
          entry.surah.ayahCount >= nameAndAyah.$2 &&
          entry.verse.ayahNumber == nameAndAyah.$2 &&
          normalizeQuranSearch(entry.surah.name).contains(nameAndAyah.$1);
      final matchesText = _matchesText(entry.normalizedText, query);
      final matchesAyahNumber =
          surahNumberQuery != null &&
          entry.verse.ayahNumber == surahNumberQuery;
      if (!matchesCoordinate &&
          !matchesNameCoordinate &&
          !matchesText &&
          !matchesAyahNumber) {
        continue;
      }
      ayahMatches.add(
        QuranSearchResult(
          surah: entry.surah,
          ayahNumber: entry.verse.ayahNumber,
          canonicalText: entry.verse.text,
          matchFragment: _canonicalFragment(entry.verse.text, query),
        ),
      );
      if (ayahMatches.length >= ayahLimit) break;
    }
    return QuranSearchResults(surahs: surahMatches, ayahs: ayahMatches);
  }

  bool _matchesText(String normalizedText, String query) {
    if (normalizedText.contains(query)) return true;
    // Some common keyboard spellings omit the Uthmani superscript alif while
    // others type it as a regular alif. This fallback folds both forms only
    // for comparison and is never exposed or persisted.
    final foldedText = normalizedText.replaceAll('ا', '');
    final foldedQuery = query.replaceAll('ا', '');
    return foldedQuery.isNotEmpty && foldedText.contains(foldedQuery);
  }

  (int, int)? _coordinate(String query) {
    final match = RegExp(
      r'^\s*(\d{1,3})\s*[:：]\s*(\d{1,3})\s*$',
    ).firstMatch(query);
    if (match == null) return null;
    final surah = int.parse(match.group(1)!);
    final ayah = int.parse(match.group(2)!);
    if (surah < 1 || surah > QuranMetadata.surahCount) return null;
    if (ayah < 1 || ayah > QuranMetadata.surah(surah).ayahCount) return null;
    return (surah, ayah);
  }

  (String, int)? _surahNameAndAyah(String query) {
    final match = RegExp(r'^(.+?)\s+(\d{1,3})$').firstMatch(query);
    if (match == null) return null;
    final name = match.group(1)!.trim();
    final ayah = int.parse(match.group(2)!);
    return name.isEmpty ? null : (name, ayah);
  }

  String? _canonicalFragment(String canonicalText, String normalizedQuery) {
    if (normalizedQuery.isEmpty || normalizedQuery.contains(RegExp(r'\d'))) {
      return null;
    }
    final words = canonicalText.split(RegExp(r'\s+'));
    final index = words.indexWhere(
      (word) => _matchesText(normalizeQuranSearch(word), normalizedQuery),
    );
    if (index < 0) return null;
    final start = (index - 2).clamp(0, words.length);
    final end = (index + 3).clamp(0, words.length);
    return words.sublist(start, end).join(' ');
  }
}

class _IndexedAyah {
  const _IndexedAyah(this.verse, this.normalizedText, this.surah);
  final QuranVerse verse;
  final String normalizedText;
  final Surah surah;
}

class _IndexedSurah {
  const _IndexedSurah(this.surah, this.normalizedName);
  final Surah surah;
  final String normalizedName;
}
