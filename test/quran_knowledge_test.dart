import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/data/models/quran_knowledge.dart';
import 'package:quran_app/data/models/quran_verse.dart';
import 'package:quran_app/data/repositories/quran_knowledge_repositories.dart';
import 'package:quran_app/data/repositories/quran_repository.dart';
import 'package:quran_app/data/repositories/bookmark_repository.dart';
import 'package:quran_app/data/repositories/quran_search_history_repository.dart';
import 'package:quran_app/features/bookmarks/bookmark_controller.dart';
import 'package:quran_app/features/quran/quran_controller.dart';
import 'package:quran_app/features/search/quran_search_service.dart';
import 'package:quran_app/features/study/verse_study_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<QuranVerse> verses;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  setUpAll(() async {
    final assets = <String, Uint8List>{};
    for (final path in [
      'assets/quran/quran-uthmani.txt',
      'assets/quran_study/manifest.json',
      'assets/quran_study/english_rwwad.json',
      'assets/quran_study/arabic_moyassar.json',
      'assets/quran_study/arabic_seraj.json',
    ]) {
      assets[path] = Uint8List.fromList(await File(path).readAsBytes());
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = const StringCodec().decodeMessage(message);
          final data = assets[key];
          return data == null ? null : ByteData.sublistView(data);
        });
    verses = await QuranRepository().loadQuran();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  test('search index covers all 6236 canonical ayahs and is offline', () {
    final stopwatch = Stopwatch()..start();
    final service = QuranSearchService(verses);
    final indexDuration = stopwatch.elapsed;
    expect(service.indexedAyahCount, 6236);
    expect(service.search('الصابرين').ayahs, isNotEmpty);
    stopwatch
      ..reset()
      ..start();
    service.search('الرحمن');
    debugPrint(
      'Quran search benchmark: index=${indexDuration.inMicroseconds}us, '
      'query=${stopwatch.elapsedMicroseconds}us',
    );
  });

  test(
    'normalization tolerates diacritics, tatweel, whitespace, alef and ya',
    () {
      expect(normalizeQuranSearch('  إِنَّــا  أَعْطَيْنَاكَ '), 'انا اعطيناك');
      expect(normalizeQuranSearch('إلى'), normalizeQuranSearch('الي'));
      final service = QuranSearchService(verses);
      expect(service.search('الرحمن').ayahs, isNotEmpty);
      expect(service.search('الصابرين').ayahs, isNotEmpty);
    },
  );

  test('coordinate and Surah-name coordinate resolve exact navigation', () {
    final service = QuranSearchService(verses);
    final coordinate = service.search('2:255').ayahs.single;
    expect((coordinate.surah.number, coordinate.ayahNumber), (2, 255));
    final named = service.search('البقرة 255').ayahs.single;
    expect((named.surah.number, named.ayahNumber), (2, 255));
    expect(named.navigationCoordinate, (2, 255));
    expect(service.search('999:1').ayahs, isEmpty);
    expect(service.search('2:999').ayahs, isEmpty);
  });

  test(
    'search results retain canonical text and never expose normalized text',
    () {
      final service = QuranSearchService(verses);
      final original = verses.firstWhere(
        (verse) => verse.surahNumber == 2 && verse.ayahNumber == 255,
      );
      final result = service.search('2:255').ayahs.single;
      expect(result.canonicalText, same(original.text));
      expect(result.canonicalText, isNot(normalizeQuranSearch(original.text)));
    },
  );

  test(
    'translation parsing rejects invalid values and missing data is safe',
    () async {
      final parsed = TranslatedAyah.fromJson({
        'surahNumber': 2,
        'ayahNumber': 255,
        'text': 'Verified fixture text',
      }, translationId: 'fixture');
      expect(parsed?.surahNumber, 2);
      expect(TranslatedAyah.fromJson({'text': ''}, translationId: 'x'), isNull);
      expect(
        TranslatedAyah.fromJson({
          'surahNumber': 999,
          'ayahNumber': 1,
          'text': 'invalid coordinate',
        }, translationId: 'x'),
        isNull,
      );
      const repository = BundledTranslationRepository();
      expect(await repository.installedTranslations(), hasLength(1));
      expect(await repository.getAyah('missing', 2, 255), isNull);
      expect(await repository.getAyah('missing', 999, 1), isNull);
    },
  );

  test('recent search persistence stores the query, not index text', () async {
    final repository = QuranSearchHistoryRepository();
    const query = '  إِنَّا أعطيناك  ';
    await repository.add(query);
    final saved = await repository.load();
    expect(saved, ['إِنَّا أعطيناك']);
    expect(saved.single, isNot(normalizeQuranSearch(saved.single)));
  });

  test('manifest parsing and checksum validation are strict', () {
    final parsed = QuranResourceManifest.fromJson({
      'id': 'fixture',
      'type': 'translation',
      'language': 'en',
      'version': '1',
      'size': 10,
      'checksum': 'ABC',
      'source': 'fixture',
      'license': 'fixture',
      'installed': true,
    });
    expect(parsed?.type, QuranResourceType.translation);
    expect(QuranResourceManifest.fromJson({'type': 'unknown'}), isNull);
    expect(
      const QuranResourceRepository().checksumMatches(parsed!, 'abc'),
      isTrue,
    );
  });

  test('Tafsir range model supports single and cross-verse coverage', () {
    const entry = TafsirEntry(
      sourceId: 'fixture',
      startSurahNumber: 2,
      startAyahNumber: 255,
      endSurahNumber: 2,
      endAyahNumber: 257,
      text: 'Verified fixture only',
    );
    expect(entry.covers(2, 255), isTrue);
    expect(entry.covers(2, 256), isTrue);
    expect(entry.covers(2, 258), isFalse);
  });

  testWidgets(
    'VerseStudyPage separates canonical Quran from verified study resources',
    (tester) async {
      final canonical = verses.firstWhere(
        (verse) => verse.surahNumber == 2 && verse.ayahNumber == 255,
      );
      final controller = _StudyQuranController(canonical);
      final bookmarks = BookmarkController(
        repository: BookmarkRepository(store: _EmptyBookmarkStore()),
      );
      await bookmarks.load();
      await tester.pumpWidget(
        MaterialApp(
          home: VerseStudyPage(
            quranController: controller,
            surahNumber: 2,
            ayahNumber: 255,
            bookmarkController: bookmarks,
            translationRepository: const _TranslationRepo(),
            tafsirRepository: const _TafsirRepo(),
            wordMeaningRepository: const _WordsRepo(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byKey(const ValueKey('study-canonical-ayah')),
        findsOneWidget,
      );
      expect(find.textContaining('Allah'), findsWidgets);
      expect(find.text(canonical.text), findsOneWidget);
      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      DefaultTabController.of(tester.element(find.byType(TabBar))).animateTo(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tabBar.tabs.length, 3);
      expect(find.textContaining('التفسير الميسر'), findsWidgets);
    },
  );

  test(
    'source tree contains no LLM integration or generated Quran resource',
    () {
      final dart = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync().toLowerCase())
          .join('\n');
      expect(dart, isNot(contains('openai')));
      expect(dart, isNot(contains('chatgpt')));
      expect(BundledQuranResources.installed.length, 1);
    },
  );
}

class _EmptyBookmarkStore implements BookmarkStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String value) async {}
}

class _StudyQuranController extends QuranController {
  _StudyQuranController(this.verse);

  final QuranVerse verse;

  @override
  QuranVerse? getVerse(int surahNumber, int ayahNumber) =>
      surahNumber == verse.surahNumber && ayahNumber == verse.ayahNumber
      ? verse
      : null;
}

class _TranslationRepo implements TranslationRepository {
  const _TranslationRepo();

  @override
  Future<List<QuranTranslation>> installedTranslations() async => const [
    QuranTranslation(
      id: 'translation',
      name: 'English Translation',
      languageCode: 'en',
      author: 'Verified publisher',
      provider: 'QuranEnc.com',
      source: 'fixture',
      license: 'fixture',
      version: '1',
    ),
  ];

  @override
  Future<TranslatedAyah?> getAyah(
    String translationId,
    int surahNumber,
    int ayahNumber,
  ) async => TranslatedAyah(
    translationId: translationId,
    surahNumber: surahNumber,
    ayahNumber: ayahNumber,
    text: 'Allah fixture translation',
  );
}

class _TafsirRepo implements TafsirRepository {
  const _TafsirRepo();

  @override
  Future<List<TafsirSource>> installedSources() async => const [
    TafsirSource(
      id: 'tafsir',
      title: 'التفسير الميسر',
      author: 'ناشر موثق',
      languageCode: 'ar',
      source: 'fixture',
      license: 'fixture',
      version: '1',
    ),
  ];

  @override
  Future<TafsirEntry?> getEntry(
    String sourceId,
    int surahNumber,
    int ayahNumber,
  ) async => TafsirEntry(
    sourceId: sourceId,
    startSurahNumber: surahNumber,
    startAyahNumber: ayahNumber,
    endSurahNumber: surahNumber,
    endAyahNumber: ayahNumber,
    text: 'تفسير موثق للاختبار',
  );
}

class _WordsRepo implements WordMeaningRepository {
  const _WordsRepo();

  @override
  Future<List<WordMeaningSource>> installedSources() async => const [
    WordMeaningSource(
      id: 'words',
      title: 'معاني الكلمات',
      publisher: 'ناشر موثق',
      source: 'fixture',
      license: 'fixture',
      version: '1',
    ),
  ];

  @override
  Future<WordMeaningEntry?> getEntry(
    String sourceId,
    int surahNumber,
    int ayahNumber,
  ) async => WordMeaningEntry(
    sourceId: sourceId,
    surahNumber: surahNumber,
    ayahNumber: ayahNumber,
    text: 'معنى موثق',
  );
}
