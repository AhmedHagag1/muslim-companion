import 'package:flutter/foundation.dart';

import '../../core/utils/arabic_search.dart';
import '../../data/models/adhkar.dart';
import '../../data/models/khatma.dart';
import '../../data/models/memorization.dart';
import '../../data/models/quran_bookmark.dart';
import '../../data/models/quran_knowledge.dart';
import '../../data/models/quran_verse.dart';
import '../../data/models/religious_content.dart';
import '../../data/models/surah.dart';
import '../../data/repositories/quran_knowledge_repositories.dart';
import 'quran_search_service.dart';

enum UniversalSearchType {
  surah,
  ayah,
  translation,
  tafsir,
  wordMeaning,
  dhikr,
  dua,
  bookmark,
  memorizationPlan,
  memorizationAyah,
  khatma,
  destination,
}

@immutable
class UniversalSearchResult {
  const UniversalSearchResult({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.searchText,
    required this.rank,
    this.excerpt,
    this.surahNumber,
    this.ayahNumber,
    this.itemId,
    this.categoryId,
    this.pageNumber,
  });

  final UniversalSearchType type;
  final String title;
  final String subtitle;
  final String searchText;
  final int rank;
  final String? excerpt;
  final int? surahNumber;
  final int? ayahNumber;
  final String? itemId;
  final String? categoryId;
  final int? pageNumber;
}

@immutable
class UniversalSearchGroup {
  const UniversalSearchGroup({
    required this.type,
    required this.title,
    required this.results,
  });

  final UniversalSearchType type;
  final String title;
  final List<UniversalSearchResult> results;
}

@immutable
class UniversalSearchResults {
  const UniversalSearchResults(this.groups);

  final List<UniversalSearchGroup> groups;
  int get total => groups.fold(0, (sum, group) => sum + group.results.length);
}

class UniversalSearchCorpus {
  const UniversalSearchCorpus({
    required this.verses,
    this.studyDocuments = const [],
    this.dhikrCategories = const [],
    this.dhikrItems = const [],
    this.duaCategories = const [],
    this.duaItems = const [],
    this.bookmarks = const [],
    this.memorizationPlans = const [],
    this.memorizedAyahs = const [],
    this.dueReviewAyahs = const [],
    this.khatmaPlans = const [],
    this.destinations = const [],
  });

  final List<QuranVerse> verses;
  final List<QuranStudySearchDocument> studyDocuments;
  final List<DhikrCategory> dhikrCategories;
  final List<DhikrItem> dhikrItems;
  final List<DuaCategory> duaCategories;
  final List<DuaItem> duaItems;
  final List<QuranBookmark> bookmarks;
  final List<MemorizationPlan> memorizationPlans;
  final List<MemorizedAyah> memorizedAyahs;
  final List<MemorizedAyah> dueReviewAyahs;
  final List<KhatmaPlan> khatmaPlans;
  final List<UniversalSearchDestination> destinations;
}

@immutable
class UniversalSearchDestination {
  const UniversalSearchDestination({
    required this.id,
    required this.title,
    required this.subtitle,
    this.aliases = const [],
  });

  final String id;
  final String title;
  final String subtitle;
  final List<String> aliases;
}

@visibleForTesting
String normalizeUniversalSearch(String value) =>
    normalizeArabicSearch(value).toLowerCase().replaceAll('ـ', '');

class UniversalSearchService {
  UniversalSearchService(UniversalSearchCorpus corpus)
    : _corpus = corpus,
      _quranSearch = QuranSearchService(corpus.verses),
      _studyIndex = List.unmodifiable(
        corpus.studyDocuments.map(
          (document) => _IndexedStudyDocument(
            document,
            normalizeUniversalSearch(document.text),
          ),
        ),
      ),
      _verseByCoordinate = {
        for (final verse in corpus.verses)
          '${verse.surahNumber}:${verse.ayahNumber}': verse,
      };

  final UniversalSearchCorpus _corpus;
  final QuranSearchService _quranSearch;
  final List<_IndexedStudyDocument> _studyIndex;
  final Map<String, QuranVerse> _verseByCoordinate;

  UniversalSearchResults search(String rawQuery) {
    final query = normalizeUniversalSearch(rawQuery);
    if (query.isEmpty) return const UniversalSearchResults([]);
    final buckets = <UniversalSearchType, List<UniversalSearchResult>>{};
    void add(UniversalSearchResult result) =>
        buckets.putIfAbsent(result.type, () => []).add(result);

    final quran = _quranSearch.search(rawQuery, ayahLimit: 40);
    for (final result in quran.surahs) {
      add(
        UniversalSearchResult(
          type: UniversalSearchType.surah,
          title: 'سورة ${result.surah.name}',
          subtitle: '${result.surah.ayahCount} آية',
          searchText: result.surah.name,
          rank: _rank(result.surah.name, query),
          surahNumber: result.surah.number,
          ayahNumber: 1,
        ),
      );
    }
    for (final result in quran.ayahs) {
      add(
        UniversalSearchResult(
          type: UniversalSearchType.ayah,
          title: 'سورة ${result.surah.name} • الآية ${result.ayahNumber}',
          subtitle: 'نص القرآن الكريم',
          searchText: result.canonicalText!,
          excerpt: result.matchFragment ?? result.canonicalText,
          rank:
              _coordinateRank(rawQuery, result) ??
              _rank(result.canonicalText!, query),
          surahNumber: result.surah.number,
          ayahNumber: result.ayahNumber,
        ),
      );
    }

    for (final indexed in _studyIndex) {
      if (!indexed.normalizedText.contains(query)) continue;
      final document = indexed.document;
      final type = switch (document.resourceType) {
        QuranResourceType.translation => UniversalSearchType.translation,
        QuranResourceType.tafsir => UniversalSearchType.tafsir,
        QuranResourceType.wordMeanings => UniversalSearchType.wordMeaning,
        _ => null,
      };
      if (type == null) continue;
      final surah = QuranMetadata.surah(document.surahNumber);
      add(
        UniversalSearchResult(
          type: type,
          title: 'سورة ${surah.name} • الآية ${document.ayahNumber}',
          subtitle: _studyLabel(type),
          searchText: document.text,
          excerpt: _excerpt(document.text, query),
          rank: _rankNormalized(indexed.normalizedText, query),
          surahNumber: document.surahNumber,
          ayahNumber: document.ayahNumber,
          itemId: document.resourceId,
        ),
      );
    }

    final dhikrCategories = {
      for (final category in _corpus.dhikrCategories)
        category.id: category.title,
    };
    for (final item in _corpus.dhikrItems) {
      final category = dhikrCategories[item.categoryId] ?? 'الأذكار';
      final searchable = '$category ${item.arabicText} ${item.reference}';
      if (!_matches(searchable, query)) continue;
      add(
        UniversalSearchResult(
          type: UniversalSearchType.dhikr,
          title: category,
          subtitle: '${item.repeatCount} مرات • ${item.sourceText}',
          searchText: searchable,
          excerpt: _excerpt(item.arabicText, query),
          rank: _rank(searchable, query),
          itemId: item.id,
          categoryId: item.categoryId,
        ),
      );
    }

    final duaCategories = {
      for (final category in _corpus.duaCategories) category.id: category.title,
    };
    for (final item in _corpus.duaItems) {
      final searchable =
          '${item.title} ${duaCategories[item.categoryId] ?? ''} ${item.arabicText} ${item.reference}';
      if (!_matches(searchable, query)) continue;
      add(
        UniversalSearchResult(
          type: UniversalSearchType.dua,
          title: item.title,
          subtitle: item.sourceText,
          searchText: searchable,
          excerpt: _excerpt(item.arabicText, query),
          rank: _rank(searchable, query),
          itemId: item.id,
          categoryId: item.categoryId,
        ),
      );
    }

    for (final bookmark in _corpus.bookmarks) {
      final verse = _verse(bookmark.surahNumber, bookmark.ayahNumber);
      if (verse == null) continue;
      final surah = QuranMetadata.surah(bookmark.surahNumber);
      final searchable =
          'المحفوظات محفوظة علامة سورة ${surah.name} ${verse.text} ${bookmark.coordinateKey}';
      if (!_matches(searchable, query)) continue;
      add(
        UniversalSearchResult(
          type: UniversalSearchType.bookmark,
          title: 'سورة ${surah.name} • الآية ${bookmark.ayahNumber}',
          subtitle: 'محفوظة',
          searchText: searchable,
          excerpt: _excerpt(verse.text, query),
          rank: _rank(searchable, query),
          surahNumber: bookmark.surahNumber,
          ayahNumber: bookmark.ayahNumber,
        ),
      );
    }

    for (final plan in _corpus.memorizationPlans) {
      final searchable =
          'حفظ خطة ${plan.title} ${_coordinateLabel(plan.start)} ${_coordinateLabel(plan.end)}';
      if (!_matches(searchable, query)) continue;
      add(
        UniversalSearchResult(
          type: UniversalSearchType.memorizationPlan,
          title: plan.title,
          subtitle: 'خطة حفظ • ${plan.totalAyahs} آية',
          searchText: searchable,
          rank: _rank(searchable, query),
          itemId: plan.id,
        ),
      );
    }
    final due = _corpus.dueReviewAyahs
        .map((item) => item.coordinate.key)
        .toSet();
    for (final item in _corpus.memorizedAyahs) {
      final verse = _verse(
        item.coordinate.surahNumber,
        item.coordinate.ayahNumber,
      );
      if (verse == null) continue;
      final surah = QuranMetadata.surah(item.coordinate.surahNumber);
      final isDue = due.contains(item.coordinate.key);
      final searchable =
          'حفظ ${isDue ? 'مراجعة مستحقة' : 'محفوظ'} سورة ${surah.name} ${verse.text}';
      if (!_matches(searchable, query)) continue;
      add(
        UniversalSearchResult(
          type: UniversalSearchType.memorizationAyah,
          title: 'سورة ${surah.name} • الآية ${item.coordinate.ayahNumber}',
          subtitle: isDue ? 'مراجعة مستحقة' : 'محفوظة ضمن خطة',
          searchText: searchable,
          excerpt: _excerpt(verse.text, query),
          rank: _rank(searchable, query),
          surahNumber: item.coordinate.surahNumber,
          ayahNumber: item.coordinate.ayahNumber,
        ),
      );
    }

    for (final plan in _corpus.khatmaPlans) {
      final searchable =
          'ختمة ورد ${plan.title} صفحة ${plan.currentPage} ${plan.startPage} ${plan.endPage}';
      if (!_matches(searchable, query)) continue;
      add(
        UniversalSearchResult(
          type: UniversalSearchType.khatma,
          title: plan.title,
          subtitle: 'خطة ختمة • الصفحة ${plan.currentPage}',
          searchText: searchable,
          rank: _rank(searchable, query),
          itemId: plan.id,
          pageNumber: plan.currentPage,
        ),
      );
    }

    for (final destination in _corpus.destinations) {
      final searchable =
          '${destination.title} ${destination.aliases.join(' ')}';
      if (!_matches(searchable, query)) continue;
      add(
        UniversalSearchResult(
          type: UniversalSearchType.destination,
          title: destination.title,
          subtitle: destination.subtitle,
          searchText: searchable,
          rank: _rank(destination.title, query),
          itemId: destination.id,
        ),
      );
    }

    final groups = <UniversalSearchGroup>[];
    for (final groupType in _groupOrder) {
      final results = buckets[groupType];
      if (results == null || results.isEmpty) continue;
      results.sort(_compare);
      groups.add(
        UniversalSearchGroup(
          type: groupType,
          title: _groupTitle(groupType),
          results: List.unmodifiable(results.take(_limit(groupType))),
        ),
      );
    }
    return UniversalSearchResults(List.unmodifiable(groups));
  }

  QuranVerse? _verse(int surah, int ayah) => _verseByCoordinate['$surah:$ayah'];

  static bool _matches(String value, String query) =>
      normalizeUniversalSearch(value).contains(query);

  static int _rank(String value, String query) {
    return _rankNormalized(normalizeUniversalSearch(value), query);
  }

  static int _rankNormalized(String normalized, String query) {
    if (normalized == query) return 0;
    if (normalized.startsWith(query)) return 10;
    if (normalized.split(' ').any((word) => word.startsWith(query))) return 20;
    final index = normalized.indexOf(query);
    return index < 0 ? 1000 : 30 + index.clamp(0, 200);
  }

  static int? _coordinateRank(String rawQuery, QuranSearchResult result) {
    final coordinate = '${result.surah.number}:${result.ayahNumber}';
    return rawQuery.trim() == coordinate ? -100 : null;
  }

  static int _compare(
    UniversalSearchResult first,
    UniversalSearchResult second,
  ) {
    final rank = first.rank.compareTo(second.rank);
    if (rank != 0) return rank;
    final surah = (first.surahNumber ?? 999).compareTo(
      second.surahNumber ?? 999,
    );
    if (surah != 0) return surah;
    final ayah = (first.ayahNumber ?? 999).compareTo(second.ayahNumber ?? 999);
    if (ayah != 0) return ayah;
    return first.title.compareTo(second.title);
  }

  static String _excerpt(String text, String query) {
    if (text.length <= 180) return text;
    final normalized = normalizeUniversalSearch(text);
    final index = normalized.indexOf(query);
    if (index < 0 || index < 70) return '${text.substring(0, 177)}…';
    final start = (index - 60).clamp(0, text.length);
    final end = (start + 177).clamp(0, text.length);
    return '…${text.substring(start, end)}…';
  }

  static String _coordinateLabel(QuranCoordinate coordinate) =>
      '${coordinate.surahNumber}:${coordinate.ayahNumber}';

  static String _studyLabel(UniversalSearchType type) => switch (type) {
    UniversalSearchType.translation => 'الترجمة الإنجليزية',
    UniversalSearchType.tafsir => 'التفسير الميسر',
    UniversalSearchType.wordMeaning => 'معاني الكلمات',
    _ => '',
  };

  static String _groupTitle(UniversalSearchType type) => switch (type) {
    UniversalSearchType.surah => 'السور',
    UniversalSearchType.ayah => 'آيات القرآن',
    UniversalSearchType.translation => 'الترجمة الإنجليزية',
    UniversalSearchType.tafsir => 'التفسير الميسر',
    UniversalSearchType.wordMeaning => 'معاني الكلمات',
    UniversalSearchType.dhikr => 'الأذكار',
    UniversalSearchType.dua => 'الأدعية',
    UniversalSearchType.bookmark => 'المحفوظات',
    UniversalSearchType.memorizationPlan => 'خطط الحفظ',
    UniversalSearchType.memorizationAyah => 'الحفظ والمراجعة',
    UniversalSearchType.khatma => 'الختمة',
    UniversalSearchType.destination => 'داخل التطبيق',
  };

  static int _limit(UniversalSearchType type) => switch (type) {
    UniversalSearchType.surah => 8,
    UniversalSearchType.ayah => 16,
    UniversalSearchType.translation ||
    UniversalSearchType.tafsir ||
    UniversalSearchType.wordMeaning => 10,
    _ => 8,
  };

  static const _groupOrder = [
    UniversalSearchType.surah,
    UniversalSearchType.ayah,
    UniversalSearchType.tafsir,
    UniversalSearchType.wordMeaning,
    UniversalSearchType.translation,
    UniversalSearchType.dhikr,
    UniversalSearchType.dua,
    UniversalSearchType.bookmark,
    UniversalSearchType.memorizationPlan,
    UniversalSearchType.memorizationAyah,
    UniversalSearchType.khatma,
    UniversalSearchType.destination,
  ];
}

class _IndexedStudyDocument {
  const _IndexedStudyDocument(this.document, this.normalizedText);

  final QuranStudySearchDocument document;
  final String normalizedText;
}
