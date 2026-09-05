import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/data/models/adhkar.dart';
import 'package:quran_app/data/models/khatma.dart';
import 'package:quran_app/data/models/memorization.dart';
import 'package:quran_app/data/models/quran_bookmark.dart';
import 'package:quran_app/data/models/quran_verse.dart';
import 'package:quran_app/data/models/religious_content.dart';
import 'package:quran_app/data/models/surah.dart';
import 'package:quran_app/data/repositories/quran_knowledge_repositories.dart';
import 'package:quran_app/data/repositories/quran_repository.dart';
import 'package:quran_app/features/search/universal_search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<QuranVerse> verses;
  late BundledQuranStudyData study;
  late int studyLoadMilliseconds;

  setUpAll(() async {
    verses = await QuranRepository().loadQuran();
    final stopwatch = Stopwatch()..start();
    study = await BundledQuranStudyRepository.load();
    stopwatch.stop();
    studyLoadMilliseconds = stopwatch.elapsedMilliseconds;
  });

  test('protected Quran hash remains unchanged', () async {
    final bytes = await File('assets/quran/quran-uthmani.txt').readAsBytes();
    expect(
      sha256.convert(bytes).toString().toUpperCase(),
      '829083F684ECB5C71853029CA1970946A12C2DC90528D6E0E3CD6DBC41204B7C',
    );
  });

  test('QuranEnc manifest is pinned, offline, and remotely inert', () async {
    final manifest =
        jsonDecode(
              await File('assets/quran_study/manifest.json').readAsString(),
            )
            as Map<String, dynamic>;
    expect(manifest['schemaVersion'], 1);
    expect(manifest['provider'], 'QuranEnc.com');
    expect(manifest['canonicalQuranIncluded'], isFalse);
    expect(
      (manifest['remoteActivation'] as Map<String, dynamic>)['enabled'],
      isFalse,
    );
    expect((manifest['resources'] as List), hasLength(3));
  });

  test(
    'every study asset matches size, SHA-256 and Quran coordinates',
    () async {
      final manifest =
          jsonDecode(
                await File('assets/quran_study/manifest.json').readAsString(),
              )
              as Map<String, dynamic>;
      for (final raw in manifest['resources'] as List) {
        final resource = raw as Map<String, dynamic>;
        final bytes = await File(resource['asset'] as String).readAsBytes();
        expect(bytes.length, resource['size']);
        expect(
          sha256.convert(bytes).toString().toUpperCase(),
          resource['sha256'],
        );
        final payload = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final entries = payload['entries'] as List;
        expect(entries, hasLength(6236));
        expect(payload.containsKey('arabic_text'), isFalse);
        final seen = <String>{};
        for (final rawEntry in entries) {
          final entry = rawEntry as Map<String, dynamic>;
          expect(entry.containsKey('arabic_text'), isFalse);
          final surah = entry['surahNumber'] as int;
          final ayah = entry['ayahNumber'] as int;
          expect(surah, inInclusiveRange(1, 114));
          expect(
            ayah,
            inInclusiveRange(1, QuranMetadata.surah(surah).ayahCount),
          );
          expect(seen.add('$surah:$ayah'), isTrue);
        }
      }
    },
  );

  test('study repositories expose all three verified resources offline', () {
    expect(study.manifests, hasLength(3));
    expect(study.translations.single.version, '1.0.19');
    expect(study.tafsirs.single.version, '1.0.0');
    expect(study.wordMeaningSources.single.version, '1.0.0');
    expect(study.translationsByCoordinate.values.single, hasLength(6236));
    expect(study.tafsirsByCoordinate.values.single, hasLength(6236));
    expect(study.wordMeaningsByCoordinate.values.single, hasLength(6236));
    expect(study.searchDocuments.length, 6236 + 6236 + 3648);
  });

  test('known verse has translation, tafsir and word meanings', () async {
    const translation = BundledTranslationRepository();
    const tafsir = BundledTafsirRepository();
    const words = BundledWordMeaningRepository();
    final translated = await translation.getAyah(
      'quranenc-english-rwwad',
      2,
      255,
    );
    final interpreted = await tafsir.getEntry(
      'quranenc-arabic-moyassar',
      2,
      255,
    );
    final meanings = await words.getEntry('quranenc-arabic-seraj', 2, 255);
    expect(translated?.text, isNotEmpty);
    expect(interpreted?.text, isNotEmpty);
    expect(meanings?.text, isNotEmpty);
  });

  test('universal normalization supports Arabic variants and English case', () {
    expect(normalizeUniversalSearch(' إِلَى '), 'الي');
    expect(normalizeUniversalSearch('THRONE'), 'throne');
  });

  test('exact Quran coordinate ranks first and routes to the exact ayah', () {
    final results = _service(verses, study).search('2:255');
    final ayah = results.groups
        .firstWhere((group) => group.type == UniversalSearchType.ayah)
        .results
        .first;
    expect((ayah.surahNumber, ayah.ayahNumber), (2, 255));
    expect(ayah.rank, -100);
  });

  test('study search covers tafsir, word meanings and English translation', () {
    final service = _service(verses, study);
    expect(
      service
          .search('الكرسي')
          .groups
          .any((group) => group.type == UniversalSearchType.tafsir),
      isTrue,
    );
    expect(
      service
          .search('القيوم')
          .groups
          .any((group) => group.type == UniversalSearchType.wordMeaning),
      isTrue,
    );
    expect(
      service
          .search('Throne')
          .groups
          .any((group) => group.type == UniversalSearchType.translation),
      isTrue,
    );
  });

  test('worship and personal results have exact stable identifiers', () {
    final service = _service(verses, study);
    final dhikr = service
        .search('سبحان الله')
        .groups
        .firstWhere((group) => group.type == UniversalSearchType.dhikr)
        .results
        .single;
    expect((dhikr.categoryId, dhikr.itemId), ('morning', 'dhikr-1'));

    final dua = service
        .search('العفو')
        .groups
        .firstWhere((group) => group.type == UniversalSearchType.dua)
        .results
        .single;
    expect(dua.itemId, 'dua-1');

    expect(
      service
          .search('المحفوظات')
          .groups
          .singleWhere((group) => group.type == UniversalSearchType.bookmark)
          .results
          .single
          .ayahNumber,
      255,
    );
    expect(
      service
          .search('خطة البقرة')
          .groups
          .any((group) => group.type == UniversalSearchType.memorizationPlan),
      isTrue,
    );
    expect(
      service
          .search('ختمة رمضان')
          .groups
          .singleWhere((group) => group.type == UniversalSearchType.khatma)
          .results
          .single
          .pageNumber,
      42,
    );
    expect(
      service
          .search('القبلة')
          .groups
          .singleWhere((group) => group.type == UniversalSearchType.destination)
          .results
          .single
          .itemId,
      'qibla',
    );
  });

  test('ranking, grouping and limits are deterministic', () {
    final service = _service(verses, study);
    final first = service.search('الله');
    final second = service.search('الله');
    expect(
      first.groups.map((group) => group.type),
      orderedEquals(second.groups.map((group) => group.type)),
    );
    for (var index = 0; index < first.groups.length; index++) {
      expect(
        first.groups[index].results.map((result) => result.title),
        orderedEquals(
          second.groups[index].results.map((result) => result.title),
        ),
      );
      expect(first.groups[index].results.length, lessThanOrEqualTo(16));
    }
  });

  test('full offline universal query remains responsive', () {
    final indexStopwatch = Stopwatch()..start();
    final service = _service(verses, study);
    indexStopwatch.stop();
    final queryStopwatch = Stopwatch()..start();
    final results = service.search('الرحمن');
    queryStopwatch.stop();
    expect(results.total, greaterThan(0));
    expect(indexStopwatch.elapsedMilliseconds, lessThan(3000));
    expect(queryStopwatch.elapsedMilliseconds, lessThan(700));
    // Printed only as benchmark evidence; pass/fail uses generous CI bounds.
    // ignore: avoid_print
    print(
      'Study/search benchmark: studyLoad=${studyLoadMilliseconds}ms '
      'index=${indexStopwatch.elapsedMilliseconds}ms '
      'quranQuery=${queryStopwatch.elapsedMilliseconds}ms',
    );
  });

  test('typical study queries remain local and responsive', () {
    final service = _service(verses, study);
    int query(String value) {
      final stopwatch = Stopwatch()..start();
      final results = service.search(value);
      stopwatch.stop();
      expect(results.total, greaterThan(0));
      return stopwatch.elapsedMilliseconds;
    }

    final tafsir = query('الكرسي');
    final translation = query('Throne');
    expect(studyLoadMilliseconds, lessThan(3000));
    expect(tafsir, lessThan(700));
    expect(translation, lessThan(700));
    // ignore: avoid_print
    print(
      'Study query benchmark: tafsir=${tafsir}ms translation=${translation}ms',
    );
  });
}

UniversalSearchService _service(
  List<QuranVerse> verses,
  BundledQuranStudyData study,
) {
  final now = DateTime.utc(2026, 8, 14);
  final memorized = MemorizedAyah(
    coordinate: const QuranCoordinate(2, 255),
    planId: 'plan-1',
    firstMemorizedAt: now,
    lastReviewedAt: now,
    nextReviewAt: now,
    reviewLevel: 1,
    successfulReviews: 1,
    failedReviews: 0,
  );
  return UniversalSearchService(
    UniversalSearchCorpus(
      verses: verses,
      studyDocuments: study.searchDocuments,
      dhikrCategories: const [
        DhikrCategory(
          id: 'morning',
          title: 'أذكار الصباح',
          semanticType: 'morning',
          sortOrder: 1,
        ),
      ],
      dhikrItems: const [
        DhikrItem(
          id: 'dhikr-1',
          categoryId: 'morning',
          arabicText: 'سبحان الله وبحمده',
          repeatCount: 100,
          sourceText: 'صحيح مسلم',
          reference: '2692',
          provenanceId: 'fixture',
        ),
      ],
      duaCategories: const [
        DuaCategory(id: 'night', title: 'أدعية الليل', sortOrder: 1),
      ],
      duaItems: const [
        DuaItem(
          id: 'dua-1',
          categoryId: 'night',
          title: 'دعاء العفو',
          arabicText: 'اللهم إنك عفو تحب العفو فاعف عني',
          sourceText: 'سنن الترمذي',
          reference: '3513',
          provenanceId: 'fixture',
        ),
      ],
      bookmarks: [
        QuranBookmark(surahNumber: 2, ayahNumber: 255, createdAt: now),
      ],
      memorizationPlans: [
        MemorizationPlan(
          id: 'plan-1',
          title: 'خطة البقرة',
          start: const QuranCoordinate(2, 255),
          end: const QuranCoordinate(2, 257),
          createdAt: now,
          preferredStudyDays: const {1, 2, 3},
          status: MemorizationPlanStatus.active,
          dailyNewAyahTarget: 1,
        ),
      ],
      memorizedAyahs: [memorized],
      dueReviewAyahs: [memorized],
      khatmaPlans: [
        KhatmaPlan(
          id: 'khatma-1',
          title: 'ختمة رمضان',
          createdAt: now,
          startDate: now,
          targetDate: now.add(const Duration(days: 30)),
          status: KhatmaPlanStatus.active,
          startPage: 1,
          endPage: 604,
          currentPage: 42,
          planType: KhatmaPlanType.thirtyDays,
          days: const [],
        ),
      ],
      destinations: const [
        UniversalSearchDestination(
          id: 'qibla',
          title: 'القبلة',
          subtitle: 'اتجاه القبلة',
        ),
      ],
    ),
  );
}
