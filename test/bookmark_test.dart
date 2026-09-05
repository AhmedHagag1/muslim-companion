import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/data/repositories/bookmark_repository.dart';
import 'package:quran_app/data/repositories/quran_repository.dart';
import 'package:quran_app/features/bookmarks/bookmark_controller.dart';
import 'package:quran_app/features/bookmarks/bookmarks_page.dart';
import 'package:quran_app/features/quran/quran_controller.dart';
import 'package:quran_app/features/reader/quran_reader_page.dart';
import 'package:quran_app/features/reader/reading_progress_controller.dart';
import 'package:quran_app/data/repositories/reading_progress_repository.dart';

void main() {
  group('BookmarkController', () {
    test(
      'starts empty and supports add, duplicate, remove, and toggle',
      () async {
        final controller = _bookmarkController(_BookmarkMemoryStore());
        await controller.load();
        expect(controller.bookmarks, isEmpty);
        expect(await controller.addBookmark(2, 10), isTrue);
        expect(await controller.addBookmark(2, 10), isFalse);
        expect(controller.isBookmarked(2, 10), isTrue);
        expect(await controller.removeBookmark(2, 10), isTrue);
        expect(await controller.toggleBookmark(2, 10), isTrue);
        expect(await controller.toggleBookmark(2, 10), isTrue);
        expect(controller.bookmarks, isEmpty);
      },
    );

    test('persists newest first and loads round trip', () async {
      final store = _BookmarkMemoryStore();
      final first = _bookmarkController(store);
      await first.addBookmark(1, 1, createdAt: DateTime.utc(2026, 1, 1));
      await first.addBookmark(2, 2, createdAt: DateTime.utc(2026, 2, 1));
      final second = _bookmarkController(store);
      await second.load();
      expect(second.bookmarks.map((b) => b.coordinateKey), ['2:2', '1:1']);
    });

    test('handles malformed and unsupported persistence safely', () async {
      final malformed = _bookmarkController(_BookmarkMemoryStore('{bad'));
      await malformed.load();
      expect(malformed.bookmarks, isEmpty);
      final unsupported = _bookmarkController(
        _BookmarkMemoryStore('{"version":99,"bookmarks":[]}'),
      );
      await unsupported.load();
      expect(unsupported.bookmarks, isEmpty);
    });

    test('rejects invalid Quran coordinates', () async {
      final controller = _bookmarkController(_BookmarkMemoryStore());
      expect(await controller.addBookmark(0, 1), isFalse);
      expect(await controller.addBookmark(115, 1), isFalse);
      expect(await controller.addBookmark(1, 0), isFalse);
      expect(await controller.addBookmark(1, 8), isFalse);
    });
  });

  testWidgets('BookmarksPage has an empty state', (tester) async {
    final bookmarkController = _bookmarkController(_BookmarkMemoryStore());
    await bookmarkController.load();
    await tester.pumpWidget(
      MaterialApp(
        home: BookmarksPage(
          bookmarkController: bookmarkController,
          quranController: QuranController(),
          readingProgressController: _progressController(),
        ),
      ),
    );
    expect(find.text('لا توجد آيات محفوظة بعد'), findsOneWidget);
  });

  testWidgets('ayah bookmark action reflects bookmarked state', (tester) async {
    final quran = QuranController(repository: QuranRepository());
    await tester.runAsync(quran.load);
    final bookmarks = _bookmarkController(_BookmarkMemoryStore());
    final progress = _progressController();
    await tester.pumpWidget(
      MaterialApp(
        home: QuranReaderPage(
          controller: quran,
          surahNumber: 1,
          readingProgressController: progress,
          bookmarkController: bookmarks,
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);
    await tester.tap(find.byKey(const ValueKey('ayah-tap-1-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final button = find.byKey(const ValueKey('ayah-action-bookmark'));
    expect(button, findsOneWidget);
    expect(
      find.descendant(
        of: button,
        matching: find.byIcon(Icons.bookmark_add_outlined),
      ),
      findsOneWidget,
    );
    await tester.tap(button);
    await tester.pump();
    expect(bookmarks.isBookmarked(1, 1), isTrue);
    expect(
      find.descendant(
        of: button,
        matching: find.byIcon(Icons.bookmark_remove_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('bookmark tile opens the exact ayah', (tester) async {
    final quran = QuranController(repository: QuranRepository());
    await tester.runAsync(quran.load);
    final bookmarks = _bookmarkController(_BookmarkMemoryStore());
    await bookmarks.addBookmark(2, 120);
    final progress = _progressController();
    final navigation = QuranReaderNavigationController();

    await tester.pumpWidget(
      MaterialApp(
        home: BookmarksPage(
          bookmarkController: bookmarks,
          quranController: quran,
          readingProgressController: progress,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('bookmark-tile-2:120')));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.pump();
    expect(find.byType(QuranReaderPage), findsOneWidget);
    expect(find.byKey(const ValueKey('ayah-2-120')), findsOneWidget);
    expect(navigation.isAttached, isFalse);
  });
}

BookmarkController _bookmarkController(BookmarkStore store) =>
    BookmarkController(repository: BookmarkRepository(store: store));

ReadingProgressController _progressController() => ReadingProgressController(
  repository: ReadingProgressRepository(store: _ProgressMemoryStore()),
);

class _BookmarkMemoryStore implements BookmarkStore {
  _BookmarkMemoryStore([this.value]);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

class _ProgressMemoryStore implements ReadingProgressStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}
