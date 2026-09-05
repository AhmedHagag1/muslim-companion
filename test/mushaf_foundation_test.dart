import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/data/models/quran_verse.dart';
import 'package:quran_app/features/mushaf/data/mushaf_preferences.dart';
import 'package:quran_app/features/mushaf/data/mushaf_repository.dart';
import 'package:quran_app/features/mushaf/domain/mushaf_models.dart';
import 'package:quran_app/features/mushaf/presentation/mushaf_page_view.dart';
import 'package:quran_app/features/quran/quran_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Madina Mushaf layout contract', () {
    late MadinaMushafRepository repository;

    setUp(() async {
      repository = MadinaMushafRepository();
      await repository.load();
    });

    test('contains exactly 604 continuous pages and all canonical ayahs', () {
      final validation = repository.validate();
      expect(repository.totalPages, 604);
      expect(validation.pageCount, 604);
      expect(validation.mappedAyahCount, 6236);
      expect(validation.representedSurahs, hasLength(114));
      for (var page = 1; page <= 604; page++) {
        expect(repository.page(page).pageNumber, page);
      }
    });

    test('first and last page ranges are canonical', () {
      final first = repository.page(1);
      final last = repository.page(604);
      expect(first.firstCoordinate, const MushafCoordinate(1, 1));
      expect(first.lastCoordinate, const MushafCoordinate(1, 7));
      expect(last.firstCoordinate, const MushafCoordinate(112, 1));
      expect(last.lastCoordinate, const MushafCoordinate(114, 6));
    });

    test('coordinate and Surah page lookups are deterministic', () {
      expect(repository.pageForCoordinate(2, 255), 42);
      expect(repository.firstPageForSurah(1), 1);
      expect(repository.firstPageForSurah(2), 2);
      expect(repository.firstPageForSurah(9), 187);
      expect(repository.firstPageForSurah(114), 604);
      expect(repository.pageForCoordinate(2, 255), 42);
    });

    test('page ranges exactly cover every ayah once', () {
      final coordinates = <MushafCoordinate>[];
      for (var page = 1; page <= repository.totalPages; page++) {
        coordinates.addAll(repository.page(page).coordinates);
      }
      expect(coordinates, hasLength(6236));
      expect(coordinates.toSet(), hasLength(6236));
      expect(coordinates.first, const MushafCoordinate(1, 1));
      expect(coordinates.last, const MushafCoordinate(114, 6));
    });

    test('invalid page and coordinate values are rejected', () {
      expect(() => repository.page(0), throwsRangeError);
      expect(() => repository.page(605), throwsRangeError);
      expect(() => repository.pageForCoordinate(2, 287), throwsRangeError);
      expect(() => repository.firstPageForSurah(115), throwsRangeError);
    });
  });

  test(
    'Mushaf progress restores separately and reader mode persists',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = SharedPreferencesMushafPreferences();
      const progress = MushafReadingProgress(
        pageNumber: 42,
        coordinate: MushafCoordinate(2, 253),
      );
      await preferences.saveProgress(progress);
      await preferences.saveMode(QuranReaderMode.study);

      final restored = await preferences.loadProgress();
      expect(restored?.pageNumber, 42);
      expect(restored?.coordinate, const MushafCoordinate(2, 253));
      expect(await preferences.loadMode(), QuranReaderMode.study);
    },
  );

  testWidgets('production identity stays dark under light system brightness', (
    tester,
  ) async {
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.light;
    addTearDown(
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );
    await tester.pumpWidget(const QuranApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(app.theme?.brightness, Brightness.dark);
    expect(app.darkTheme?.brightness, Brightness.dark);
  });

  test('rendered text offsets resolve only to their canonical ayah span', () {
    const first = QuranVerse(surahNumber: 2, ayahNumber: 255, text: 'first');
    const second = QuranVerse(surahNumber: 2, ayahNumber: 256, text: 'second');
    final ranges = [
      (start: 10, end: 20, verse: first),
      (start: 20, end: 31, verse: second),
    ];

    expect(mushafVerseForTextOffset(ranges, 9), isNull);
    expect(mushafVerseForTextOffset(ranges, 10), same(first));
    expect(mushafVerseForTextOffset(ranges, 19), same(first));
    expect(mushafVerseForTextOffset(ranges, 20), same(second));
    expect(mushafVerseForTextOffset(ranges, 31), isNull);
  });

  testWidgets('page jump dialog tears down safely across repeated jumps', (
    tester,
  ) async {
    final selectedPages = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              key: const ValueKey('open-page-jump'),
              onPressed: () async {
                final page = await showMushafPageJumpDialog(context);
                if (page != null) selectedPages.add(page);
              },
              child: const Text('فتح'),
            ),
          ),
        ),
      ),
    );

    for (final page in const [42, 1, 604]) {
      await tester.tap(find.byKey(const ValueKey('open-page-jump')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('mushaf-page-input')),
        '$page',
      );
      await tester.tap(find.text('انتقل'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byKey(const ValueKey('open-page-jump')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(selectedPages, const [42, 1, 604]);
  });
}
