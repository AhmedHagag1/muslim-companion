import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/navigation/internal_destination.dart';
import 'package:quran_app/data/models/app_settings.dart';
import 'package:quran_app/data/models/memorization.dart';
import 'package:quran_app/data/models/quran_verse.dart';
import 'package:quran_app/data/repositories/app_settings_repository.dart';
import 'package:quran_app/data/repositories/bookmark_repository.dart';
import 'package:quran_app/data/repositories/khatma_repository.dart';
import 'package:quran_app/data/repositories/memorization_repository.dart';
import 'package:quran_app/data/repositories/quran_repository.dart';
import 'package:quran_app/data/repositories/reading_progress_repository.dart';
import 'package:quran_app/data/services/user_data_backup_service.dart';
import 'package:quran_app/features/memorization/memorization_controller.dart';
import 'package:quran_app/features/memorization/memorization_page.dart';
import 'package:quran_app/features/memorization/memorization_review_scheduler.dart';
import 'package:quran_app/features/mushaf/data/mushaf_preferences.dart';
import 'package:quran_app/features/quran/quran_controller.dart';
import 'package:quran_app/features/reader/ayah_share_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime.utc(2026, 8, 14, 10);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('protected canonical Quran remains unchanged', () async {
    final bytes = await File('assets/quran/quran-uthmani.txt').readAsBytes();
    expect(bytes, isNotEmpty);
    expect(
      sha256.convert(bytes).toString().toUpperCase(),
      '829083F684ECB5C71853029CA1970946A12C2DC90528D6E0E3CD6DBC41204B7C',
    );
  });

  test('ambiguous corpus terms leave Word Study content unbundled', () async {
    final documentation = await File('docs/QURAN_WORD_STUDY.md').readAsString();
    expect(documentation, contains('BLOCKED — no corpus content imported'));
    final corpusAssets = Directory('assets')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.toLowerCase().contains('corpus'));
    expect(corpusAssets, isEmpty);
  });

  test('three self-ratings update review schedule deterministically', () {
    final scheduler = MemorizationReviewScheduler();
    final ayah = _memorized(now, level: 3);
    expect(
      scheduler.rate(ayah, MemorizationSessionResult.mastered, now).reviewLevel,
      4,
    );
    expect(
      scheduler
          .rate(ayah, MemorizationSessionResult.needsReview, now)
          .reviewLevel,
      2,
    );
    final difficult = scheduler.rate(
      ayah,
      MemorizationSessionResult.notMastered,
      now,
    );
    expect(difficult.reviewLevel, 0);
    expect(difficult.failedReviews, 1);
    expect(difficult.nextReviewAt, DateTime.utc(2026, 8, 15));
  });

  test('session modes, weak queue, and resume persist', () async {
    var clock = now;
    final store = _MemStore();
    final controller = MemorizationController(
      repository: MemorizationRepository(store: store),
      clock: () => clock,
    );
    await controller.load();
    await controller.createPlan(
      title: 'الملك',
      start: const QuranCoordinate(67, 1),
      end: const QuranCoordinate(67, 4),
      dailyNewAyahTarget: 2,
    );
    final newSession = await controller.generateSession(
      MemorizationSessionMode.newMemorization,
      testMode: MemorizationTestMode.progressiveReveal,
    );
    expect(newSession!.newAyahs, hasLength(2));
    expect(newSession.testMode, MemorizationTestMode.progressiveReveal);
    await controller.markAyahMemorized(newSession.newAyahs.first);
    await controller.completeSession();
    clock = now.add(const Duration(days: 1));
    final review = await controller.generateSession(
      MemorizationSessionMode.nearReview,
    );
    expect(review!.reviewAyahs.single.key, '67:1');
    await controller.recordReviewRating(
      const QuranCoordinate(67, 1),
      MemorizationSessionResult.needsReview,
    );
    expect(controller.weakReviewAyahs.single.coordinate.key, '67:1');
    final resumed = MemorizationController(
      repository: MemorizationRepository(store: store),
      clock: () => clock,
    );
    await resumed.load();
    expect(resumed.todaySession!.mode, MemorizationSessionMode.nearReview);
    expect(
      resumed.todaySession!.results['67:1'],
      MemorizationSessionResult.needsReview,
    );
  });

  testWidgets('hide/reveal and next-ayah test use canonical verses', (
    tester,
  ) async {
    final quran = QuranController(repository: QuranRepository());
    await tester.runAsync(quran.load);
    final controller = MemorizationController(
      repository: MemorizationRepository(store: _MemStore()),
      clock: () => now,
    );
    await controller.load();
    final session = MemorizationSession(
      id: 's',
      planId: 'p',
      startedAt: now,
      newAyahs: const [QuranCoordinate(2, 2)],
      reviewAyahs: const [],
      results: const {},
      mode: MemorizationSessionMode.selfTest,
      testMode: MemorizationTestMode.nextAyah,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MemorizationSessionPage(
          controller: controller,
          quranController: quran,
          session: session,
        ),
      ),
    );
    expect(find.byKey(const ValueKey('session-next-prompt')), findsOneWidget);
    expect(find.byKey(const ValueKey('session-ayah-text')), findsNothing);
    final reveal = find.byKey(const ValueKey('memorization-reveal'));
    expect(
      find.ancestor(of: reveal, matching: find.byType(SafeArea)),
      findsWidgets,
    );
    await tester.tap(reveal);
    await tester.pump();
    expect(find.byKey(const ValueKey('session-ayah-text')), findsOneWidget);
    expect(find.text('ثابت'), findsOneWidget);
  });

  test('memorization v1 migrates without losing data', () async {
    final store = _MemStore()
      ..value = jsonEncode({
        'version': 1,
        'plans': [_plan(now).toJson()],
        'ayahs': <Object>[],
        'sessions': <Object>[],
      });
    final loaded = await MemorizationRepository(store: store).load();
    expect(loaded.plans.single.id, 'p');
    expect(jsonDecode(store.value!)['version'], 2);
  });

  test('priority v1 documents migrate to v2', () async {
    final bookmarkStore = _BookmarkStore('{"version":1,"bookmarks":[]}');
    await BookmarkRepository(store: bookmarkStore).load();
    expect(jsonDecode(bookmarkStore.value!)['version'], 2);

    final progressStore = _ProgressStore(
      jsonEncode({
        'version': 1,
        'progress': {
          'surahNumber': 2,
          'ayahNumber': 255,
          'updatedAt': now.toIso8601String(),
        },
      }),
    );
    await ReadingProgressRepository(store: progressStore).load();
    expect(jsonDecode(progressStore.value!)['version'], 2);

    final khatmaStore = _KhatmaStore('{"version":1,"plans":[]}');
    await KhatmaRepository(store: khatmaStore).load();
    expect(jsonDecode(khatmaStore.value!)['version'], 2);

    final settingsStore = _SettingsStore(
      jsonEncode({'version': 1, 'settings': const AppSettings().toJson()}),
    );
    await AppSettingsRepository(store: settingsStore).load();
    expect(jsonDecode(settingsStore.value!)['version'], 2);

    SharedPreferences.setMockInitialValues({
      SharedPreferencesMushafPreferences.displayKey: jsonEncode({
        'schemaVersion': 1,
        'settings': const MushafDisplaySettings().toJson(),
      }),
    });
    await SharedPreferencesMushafPreferences().loadDisplaySettings();
    final prefs = await SharedPreferences.getInstance();
    expect(
      jsonDecode(
        prefs.getString(SharedPreferencesMushafPreferences.displayKey)!,
      )['schemaVersion'],
      2,
    );
  });

  test('backup exports only whitelisted user state and round trips', () async {
    SharedPreferences.setMockInitialValues({
      'quran.bookmarks': '{"version":2,"bookmarks":[]}',
      'quran.reader_mode.v1': 'study',
      'assets.quran.text': 'must-not-export',
      'quran.study.pack': 'must-not-export',
    });
    final service = const UserDataBackupService();
    final raw = await service.exportJson(clock: () => now);
    expect(raw, isNot(contains('must-not-export')));
    final preview = service.preview(raw);
    expect(preview.sections.keys, containsAll(['المحفوظات', 'نمط القراءة']));

    SharedPreferences.setMockInitialValues({});
    await service.replaceFromPreview(preview, confirmed: true);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('quran.reader_mode.v1'), 'study');
    expect(jsonDecode(prefs.getString('quran.bookmarks')!)['version'], 2);
  });

  test(
    'backup rejects malformed, unsupported, invalid and unconfirmed input',
    () async {
      const service = UserDataBackupService();
      expect(
        () => service.preview('{bad'),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        () => service.preview('{"appBackupVersion":99,"sections":{}}'),
        throwsA(isA<BackupFormatException>()),
      );
      final invalid = jsonEncode({
        'appBackupVersion': 1,
        'createdAt': now.toIso8601String(),
        'sourceAppVersion': '1.0.0+1',
        'sections': {
          'readingProgress': {
            'version': 2,
            'progress': {'surahNumber': 1, 'ayahNumber': 8},
          },
        },
      });
      expect(
        () => service.preview(invalid),
        throwsA(isA<BackupFormatException>()),
      );
      final empty = service.preview(
        jsonEncode({
          'appBackupVersion': 1,
          'createdAt': now.toIso8601String(),
          'sourceAppVersion': '1.0.0+1',
          'sections': <String, Object>{},
        }),
      );
      expect(
        service.replaceFromPreview(empty, confirmed: false),
        throwsA(isA<BackupFormatException>()),
      );
    },
  );

  test('internal destinations round trip and reject invalid routes', () {
    final values = <InternalDestination>[
      const InternalDestination.ayah(QuranCoordinate(2, 255)),
      const InternalDestination.study(
        QuranCoordinate(2, 255),
        VerseStudySection.tafsir,
      ),
      const InternalDestination.simple(InternalDestinationType.khatma),
      const InternalDestination.simple(InternalDestinationType.memorization),
      const InternalDestination.item(InternalDestinationType.dua, 'dua-1'),
      const InternalDestination.item(InternalDestinationType.adhkar, 'morning'),
      const InternalDestination.simple(InternalDestinationType.prayer),
      const InternalDestination.simple(InternalDestinationType.qibla),
    ];
    for (final value in values) {
      expect(InternalDestination.parse(value.path)?.type, value.type);
    }
    expect(InternalDestination.parse('/quran/1/8'), isNull);
    expect(InternalDestination.parse('/study/2/255?tab=unknown'), isNull);
    expect(
      InternalDestination.parse('https://example.com/quran/2/255'),
      isNull,
    );
  });

  test('ayah share uses canonical text without study content', () {
    const verse = QuranVerse(
      surahNumber: 1,
      ayahNumber: 1,
      text: 'بِسْمِ اللَّهِ',
    );
    final shared = const AyahShareService().canonicalText(verse);
    expect(shared, startsWith(verse.text));
    expect(shared, contains('سورة الفاتحة — الآية 1'));
    expect(shared, isNot(contains('تفسير')));
    expect(shared, isNot(contains('Translation')));
  });
}

MemorizationPlan _plan(DateTime now) => MemorizationPlan(
  id: 'p',
  title: 'test',
  start: const QuranCoordinate(67, 1),
  end: const QuranCoordinate(67, 4),
  createdAt: now,
  preferredStudyDays: const {1, 2, 3, 4, 5, 6, 7},
  status: MemorizationPlanStatus.active,
  dailyNewAyahTarget: 2,
);

MemorizedAyah _memorized(DateTime now, {int level = 0}) => MemorizedAyah(
  coordinate: const QuranCoordinate(67, 1),
  planId: 'p',
  firstMemorizedAt: now,
  lastReviewedAt: now,
  nextReviewAt: now,
  reviewLevel: level,
  successfulReviews: 1,
  failedReviews: 0,
);

class _MemStore implements MemorizationStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

class _BookmarkStore implements BookmarkStore {
  _BookmarkStore(this.value);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

class _ProgressStore implements ReadingProgressStore {
  _ProgressStore(this.value);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

class _KhatmaStore implements KhatmaStore {
  _KhatmaStore(this.value);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

class _SettingsStore implements AppSettingsStore {
  _SettingsStore(this.value);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}
