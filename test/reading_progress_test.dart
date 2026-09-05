import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/app/theme/app_colors.dart';
import 'package:quran_app/data/repositories/reading_progress_repository.dart';
import 'package:quran_app/data/repositories/bookmark_repository.dart';
import 'package:quran_app/features/bookmarks/bookmark_controller.dart';
import 'package:quran_app/data/repositories/quran_repository.dart';
import 'package:quran_app/data/models/surah.dart';
import 'package:quran_app/features/quran/quran_controller.dart';
import 'package:quran_app/features/reader/quran_reader_page.dart';
import 'package:quran_app/features/reader/reading_progress_controller.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  group('ReadingProgressController', () {
    test('has a clean default when no progress exists', () async {
      final controller = _controllerWith(_MemoryStore());

      await controller.load();

      expect(controller.isLoaded, isTrue);
      expect(controller.progress, isNull);
    });

    test('saves and loads progress round trip', () async {
      final store = _MemoryStore();
      final first = _controllerWith(store);
      final updatedAt = DateTime.utc(2026, 8, 12, 10, 30);

      expect(
        await first.update(
          surahNumber: 2,
          ayahNumber: 120,
          updatedAt: updatedAt,
        ),
        isTrue,
      );

      final second = _controllerWith(store);
      await second.load();

      expect(second.progress?.surahNumber, 2);
      expect(second.progress?.ayahNumber, 120);
      expect(second.progress?.updatedAt, updatedAt);
    });

    test('notifies and exposes a valid progress update', () async {
      final controller = _controllerWith(_MemoryStore());
      var notifications = 0;
      controller.addListener(() => notifications++);

      final accepted = await controller.update(surahNumber: 9, ayahNumber: 1);

      expect(accepted, isTrue);
      expect(controller.progress?.surahNumber, 9);
      expect(controller.progress?.ayahNumber, 1);
      expect(notifications, 2);
    });

    test('rejects invalid surah and ayah values', () async {
      final store = _MemoryStore();
      final controller = _controllerWith(store);

      expect(await controller.update(surahNumber: 0, ayahNumber: 1), isFalse);
      expect(await controller.update(surahNumber: 115, ayahNumber: 1), isFalse);
      expect(await controller.update(surahNumber: 1, ayahNumber: 0), isFalse);
      expect(await controller.update(surahNumber: 1, ayahNumber: 8), isFalse);
      expect(controller.progress, isNull);
      expect(store.value, isNull);
    });

    test('safely ignores malformed or unsupported saved data', () async {
      final malformed = _controllerWith(_MemoryStore('{bad json'));
      await malformed.load();
      expect(malformed.progress, isNull);

      final unsupported = _controllerWith(
        _MemoryStore('{"version":99,"progress":{}}'),
      );
      await unsupported.load();
      expect(unsupported.progress, isNull);
    });
  });

  testWidgets('reader records ayah 1 when a different surah is opened', (
    tester,
  ) async {
    final progressController = _controllerWith(_MemoryStore());

    await tester.pumpWidget(
      MaterialApp(
        home: QuranReaderPage(
          controller: QuranController(),
          surahNumber: 2,
          readingProgressController: progressController,
          bookmarkController: _bookmarkController(),
        ),
      ),
    );
    await tester.pump();

    expect(progressController.progress?.surahNumber, 2);
    expect(progressController.progress?.ayahNumber, 1);
  });

  group('Per-ayah reader', () {
    late QuranController quranController;

    setUp(() async {
      quranController = QuranController(repository: QuranRepository());
      await quranController.load();
    });

    tearDown(() => quranController.dispose());

    testWidgets('uses a dedicated ivory Mushaf surface and ornament', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QuranReaderPage(
            controller: quranController,
            surahNumber: 1,
            readingProgressController: _controllerWith(_MemoryStore()),
            bookmarkController: _bookmarkController(),
          ),
        ),
      );
      await tester.pump();

      final surface = tester.widget<Container>(
        find.byKey(const ValueKey('mushaf-surface')),
      );
      final decoration = surface.decoration! as BoxDecoration;

      expect(decoration.color, AppColors.mushafBackground);
      expect(find.byKey(const ValueKey('mushaf-ornament')), findsOneWidget);
    });

    testWidgets('renders one addressable item per ayah in Al-Fatiha', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final progressController = _controllerWith(_MemoryStore());

      await tester.pumpWidget(
        MaterialApp(
          home: QuranReaderPage(
            controller: quranController,
            surahNumber: 1,
            readingProgressController: progressController,
            bookmarkController: _bookmarkController(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(QuranAyahItem), findsNWidgets(7));
      for (var ayah = 1; ayah <= 7; ayah++) {
        expect(find.byKey(ValueKey('ayah-1-$ayah')), findsOneWidget);
      }
    });

    testWidgets(
      'font size slider updates and persists without pinch gestures',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: QuranReaderPage(
              controller: quranController,
              surahNumber: 1,
              readingProgressController: _controllerWith(_MemoryStore()),
              bookmarkController: _bookmarkController(),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const ValueKey('reader-overflow')));
        await tester.pumpAndSettle();
        final slider = find.byKey(const ValueKey('reader-font-size-slider'));
        expect(slider, findsOneWidget);
        await tester.drag(slider, const Offset(180, 0));
        await tester.pump();
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        final ayah = find.byKey(const ValueKey('ayah-tap-1-1'));
        final text = tester.widget<Text>(
          find.descendant(of: ayah, matching: find.byType(Text)).first,
        );
        expect(text.style?.fontSize, greaterThan(30));
        expect(text.style?.fontSize, lessThanOrEqualTo(42));
        expect(find.byKey(const ValueKey('ayah-actions-1-1')), findsNothing);
        final preferences = await SharedPreferences.getInstance();
        expect(
          preferences.getDouble('quran.reader_font_size'),
          text.style?.fontSize,
        );
      },
    );

    testWidgets('normal ayahs use a flat transparent reading surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QuranReaderPage(
            controller: quranController,
            surahNumber: 1,
            readingProgressController: _controllerWith(_MemoryStore()),
            bookmarkController: _bookmarkController(),
          ),
        ),
      );
      await tester.pump();
      final surface = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('ayah-surface-1-1')),
      );
      final decoration = surface.decoration! as BoxDecoration;
      expect(decoration.color, Colors.transparent);
      expect(decoration.border, isNull);
      expect(decoration.boxShadow, isNull);
    });

    testWidgets(
      'selected ayah keeps contextual actions without permanent controls',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: QuranReaderPage(
              controller: quranController,
              surahNumber: 1,
              readingProgressController: _controllerWith(_MemoryStore()),
              bookmarkController: _bookmarkController(),
            ),
          ),
        );
        await tester.pump();
        expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);
        expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
        await tester.tap(find.byKey(const ValueKey('ayah-tap-1-1')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byKey(const ValueKey('ayah-actions-1-1')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('ayah-action-bookmark')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('ayah-action-copy')), findsOneWidget);
        expect(find.byKey(const ValueKey('ayah-action-study')), findsOneWidget);
        final selected = tester.widget<AnimatedContainer>(
          find.byKey(const ValueKey('ayah-surface-1-1')),
        );
        expect(
          (selected.decoration! as BoxDecoration).color,
          isNot(Colors.transparent),
        );
      },
    );

    testWidgets('restores a saved ayah and supports indexed navigation', (
      tester,
    ) async {
      final progressController = _controllerWith(_MemoryStore());
      await progressController.update(surahNumber: 2, ayahNumber: 120);
      final navigationController = QuranReaderNavigationController();

      await tester.pumpWidget(
        MaterialApp(
          home: QuranReaderPage(
            controller: quranController,
            surahNumber: 2,
            readingProgressController: progressController,
            bookmarkController: _bookmarkController(),
            navigationController: navigationController,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('ayah-2-120')), findsOneWidget);

      final navigation = navigationController.scrollToAyah(125);
      await tester.pumpAndSettle();
      await navigation;
      expect(find.byKey(const ValueKey('ayah-2-125')), findsOneWidget);
    });

    testWidgets('updates progress after the visible ayah settles', (
      tester,
    ) async {
      final progressController = _controllerWith(_MemoryStore());
      final navigationController = QuranReaderNavigationController();

      await tester.pumpWidget(
        MaterialApp(
          home: QuranReaderPage(
            controller: quranController,
            surahNumber: 2,
            readingProgressController: progressController,
            bookmarkController: _bookmarkController(),
            navigationController: navigationController,
          ),
        ),
      );
      await tester.pump();
      final navigation = navigationController.scrollToAyah(20);
      await tester.pumpAndSettle();
      await navigation;
      await tester.pump(const Duration(milliseconds: 401));

      expect(progressController.progress?.surahNumber, 2);
      expect(progressController.progress?.ayahNumber, 20);
    });

    testWidgets('renders Surah 1 basmala once as its first ayah', (
      tester,
    ) async {
      final progressController = _controllerWith(_MemoryStore());

      await tester.pumpWidget(
        MaterialApp(
          home: QuranReaderPage(
            controller: quranController,
            surahNumber: 1,
            readingProgressController: progressController,
            bookmarkController: _bookmarkController(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('reader-basmala')), findsNothing);
      expect(find.textContaining(QuranMetadata.basmala), findsOneWidget);
    });

    testWidgets('renders no separate basmala for Surah 9', (tester) async {
      final progressController = _controllerWith(_MemoryStore());

      await tester.pumpWidget(
        MaterialApp(
          home: QuranReaderPage(
            controller: quranController,
            surahNumber: 9,
            readingProgressController: progressController,
            bookmarkController: _bookmarkController(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('reader-basmala')), findsNothing);
      expect(find.textContaining(QuranMetadata.basmala), findsNothing);
    });

    testWidgets('renders exactly one separate basmala for Surah 2', (
      tester,
    ) async {
      final progressController = _controllerWith(_MemoryStore());

      await tester.pumpWidget(
        MaterialApp(
          home: QuranReaderPage(
            controller: quranController,
            surahNumber: 2,
            readingProgressController: progressController,
            bookmarkController: _bookmarkController(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('reader-basmala')), findsOneWidget);
      expect(find.textContaining(QuranMetadata.basmala), findsOneWidget);
    });
  });

  test('most visible ayah wins over a barely visible previous ayah', () {
    final index = mostVisibleAyahIndex([
      const ItemPosition(
        index: 4,
        itemLeadingEdge: -0.95,
        itemTrailingEdge: 0.05,
      ),
      const ItemPosition(
        index: 5,
        itemLeadingEdge: 0.05,
        itemTrailingEdge: 0.85,
      ),
      const ItemPosition(
        index: 6,
        itemLeadingEdge: 0.85,
        itemTrailingEdge: 1.20,
      ),
    ]);

    expect(index, 5);
  });
}

ReadingProgressController _controllerWith(ReadingProgressStore store) {
  return ReadingProgressController(
    repository: ReadingProgressRepository(store: store),
  );
}

class _MemoryStore implements ReadingProgressStore {
  _MemoryStore([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}

BookmarkController _bookmarkController() => BookmarkController(
  repository: BookmarkRepository(store: _BookmarkMemoryStore()),
);

class _BookmarkMemoryStore implements BookmarkStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}
