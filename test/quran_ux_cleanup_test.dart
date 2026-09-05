import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quran_app/core/services/location_service.dart';
import 'package:quran_app/core/services/prayer_api_service.dart';
import 'package:quran_app/data/models/surah.dart';
import 'package:quran_app/data/repositories/bookmark_repository.dart';
import 'package:quran_app/data/repositories/reading_progress_repository.dart';
import 'package:quran_app/features/bookmarks/bookmark_controller.dart';
import 'package:quran_app/features/prayer/prayer_controller.dart';
import 'package:quran_app/features/prayer/prayer_page.dart';
import 'package:quran_app/features/quran/quran_controller.dart';
import 'package:quran_app/features/quran/quran_page.dart';
import 'package:quran_app/features/reader/reading_progress_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('surah filtering is spacing and Arabic-form tolerant', () {
    final name = QuranMetadata.surahs.first.name;
    expect(filterSurahs('  $name  ').first.number, 1);
    expect(normalizeSurahSearch('أ إ آ ى ة'), 'ااايه');
    expect(filterSurahs('اسم غير موجود'), isEmpty);
  });

  testWidgets('Quran search updates immediately and has clear/empty states', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'quran.reader_mode.v1': 'study'});
    final quran = QuranController();
    await tester.pumpWidget(
      MaterialApp(
        home: QuranPage(
          controller: quran,
          readingProgressController: _progress(),
          bookmarkController: _bookmarks(),
        ),
      ),
    );
    await tester.pump();
    expect(
      (await SharedPreferences.getInstance()).getString('quran.reader_mode.v1'),
      'study',
    );

    final target = QuranMetadata.surah(112);
    await tester.enterText(
      find.byKey(const ValueKey('surah-search-field')),
      target.name,
    );
    await tester.pump();
    expect(find.text('سورة ${target.name}'), findsOneWidget);
    expect(find.byKey(const ValueKey('clear-surah-search')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('surah-search-field')),
      'اسم غير موجود',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('surah-search-empty')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('clear-surah-search')));
    await tester.pump();
    expect(find.byKey(const ValueKey('surah-search-empty')), findsNothing);

    await tester.tap(find.text('المصحف'));
    await tester.pump();
    expect(
      (await SharedPreferences.getInstance()).getString('quran.reader_mode.v1'),
      'mushaf',
    );
  });

  testWidgets(
    'location-disabled and permanently-denied states offer settings',
    (tester) async {
      for (final type in [
        LocationFailureType.serviceDisabled,
        LocationFailureType.permissionDeniedForever,
      ]) {
        final location = _FailingLocationService(type);
        final controller = PrayerController(
          prayerApiService: PrayerApiService(),
          locationService: location,
        );
        await controller.load();
        await tester.pumpWidget(
          MaterialApp(home: PrayerPage(controller: controller)),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('prayer-open-settings')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('prayer-retry')), findsOneWidget);
        expect(find.textContaining('Exception:'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('prayer-open-settings')));
        await tester.pump();
        expect(location.settingsOpened, isTrue);
        controller.dispose();
      }
    },
  );
}

ReadingProgressController _progress() => ReadingProgressController(
  repository: ReadingProgressRepository(store: _MemoryProgressStore()),
);

BookmarkController _bookmarks() => BookmarkController(
  repository: BookmarkRepository(store: _MemoryBookmarkStore()),
);

class _MemoryProgressStore implements ReadingProgressStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

class _MemoryBookmarkStore implements BookmarkStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

class _FailingLocationService extends LocationService {
  _FailingLocationService(this.type);
  final LocationFailureType type;
  bool settingsOpened = false;

  @override
  Future<Position> getCurrentPosition() async => throw LocationFailure(type);

  @override
  Future<bool> openLocationSettings() async => settingsOpened = true;

  @override
  Future<bool> openAppSettings() async => settingsOpened = true;
}
