import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/data/models/ayah_audio_source.dart';
import 'package:quran_app/data/models/listening_history.dart';
import 'package:quran_app/data/models/quran_verse.dart';
import 'package:quran_app/data/models/reciter.dart';
import 'package:quran_app/data/models/surah.dart';
import 'package:quran_app/data/repositories/listening_history_repository.dart';
import 'package:quran_app/data/repositories/quran_audio_repository.dart';
import 'package:quran_app/features/audio/audio_mini_player.dart';
import 'package:quran_app/features/audio/listening_page.dart';
import 'package:quran_app/features/audio/quran_audio_controller.dart';
import 'package:quran_app/features/audio/quran_audio_engine.dart';
import 'package:quran_app/features/reader/quran_reader_page.dart';

void main() {
  late _FakeEngine engine;
  late _FakeRepository repository;
  late _MemoryListeningStore store;
  late QuranAudioController controller;

  setUp(() async {
    engine = _FakeEngine();
    repository = _FakeRepository();
    store = _MemoryListeningStore();
    controller = QuranAudioController(
      repository: repository,
      engine: engine,
      historyRepository: ListeningHistoryRepository(store: store),
      now: () => DateTime.utc(2026, 8, 14, 12),
    );
    await controller.initialize();
  });

  test('starts idle and plays an ayah through repository and engine', () async {
    expect(controller.status, QuranAudioStatus.idle);
    expect(await controller.playAyah(1, 1), isTrue);
    expect(engine.loaded, hasLength(1));
    expect(controller.currentSurahNumber, 1);
    expect(controller.currentAyahNumber, 1);
    expect(controller.status, QuranAudioStatus.playing);
  });

  test('maps resolution and engine failures without raw exceptions', () async {
    repository.failure = QuranAudioResolutionFailure.networkUnavailable;
    expect(await controller.playAyah(1, 1), isFalse);
    expect(controller.error, contains('الاتصال'));
    repository.failure = null;
    engine.failLoad = true;
    expect(await controller.playAyah(1, 1), isFalse);
    expect(controller.error, isNot(contains('SECRET_ENGINE_FAILURE')));
    engine.errors.add(Exception('SECRET_STREAM_FAILURE'));
    expect(controller.error, isNot(contains('SECRET_STREAM_FAILURE')));
  });

  test('tracks buffering playing pause resume stop and completion', () async {
    await controller.playAyah(1, 1);
    engine.processing.add(QuranEngineProcessingState.buffering);
    expect(controller.status, QuranAudioStatus.buffering);
    engine.processing.add(QuranEngineProcessingState.ready);
    await controller.pause();
    expect(controller.status, QuranAudioStatus.paused);
    await controller.resume();
    expect(controller.status, QuranAudioStatus.playing);
    engine.processing.add(QuranEngineProcessingState.completed);
    expect(controller.status, QuranAudioStatus.completed);
    await controller.stop();
    expect(controller.status, QuranAudioStatus.idle);
    expect(controller.hasActiveItem, isFalse);
  });

  test('supports queue coordinates, speed, and invalid coordinates', () async {
    expect(await controller.playSurah(1, initialAyah: 6), isTrue);
    expect(controller.currentAyahNumber, 6);
    await controller.nextAyah();
    expect(controller.currentAyahNumber, 7);
    await controller.previousAyah();
    expect(controller.currentAyahNumber, 6);
    expect(controller.nextCoordinate(114, 6), isNull);
    expect(controller.previousCoordinate(1, 1), isNull);
    expect(await controller.playAyah(1, 8), isFalse);
    expect(await controller.setPlaybackSpeed(1.5), isTrue);
    expect(engine.speed, 1.5);
    expect(await controller.setPlaybackSpeed(3), isFalse);
  });

  test(
    'selected reciter persists and active change keeps coordinate',
    () async {
      await controller.playSurah(2, initialAyah: 42);
      await controller.pause();
      expect(await controller.selectReciter(repository.reciters.last), isTrue);
      expect(controller.currentSurahNumber, 2);
      expect(controller.currentAyahNumber, 42);
      expect(controller.isPlaying, isFalse);

      final restored = QuranAudioController(
        repository: repository,
        engine: _FakeEngine(),
        historyRepository: ListeningHistoryRepository(store: store),
      );
      await restored.initialize();
      expect(restored.selectedReciter?.id, repository.reciters.last.id);
    },
  );

  test(
    'next and previous Surah rebuild canonical queues without wrap',
    () async {
      await controller.playSurah(2, initialAyah: 20);
      expect(await controller.playNextSurah(), isTrue);
      expect(
        (controller.currentSurahNumber, controller.currentAyahNumber),
        (3, 1),
      );
      expect(await controller.playPreviousSurah(), isTrue);
      expect(
        (controller.currentSurahNumber, controller.currentAyahNumber),
        (2, 1),
      );
      await controller.playSurah(1);
      expect(await controller.playPreviousSurah(), isFalse);
      await controller.playSurah(114);
      expect(await controller.playNextSurah(), isFalse);
    },
  );

  test(
    'interactive seek clamps safely and is disabled without duration',
    () async {
      await controller.playAyah(1, 1);
      expect(await controller.seekToFraction(0.5), isFalse);
      engine.durations.add(const Duration(seconds: 100));
      expect(await controller.seekToFraction(1.5), isTrue);
      expect(engine.lastSeek, const Duration(seconds: 100));
      expect(await controller.seek(const Duration(seconds: -5)), isTrue);
      expect(engine.lastSeek, Duration.zero);
    },
  );

  test('repeat current ayah configures real one-track looping', () async {
    await controller.playSurah(1, initialAyah: 3);
    await controller.setRepeatMode(QuranRepeatMode.ayah);
    expect(engine.repeatMode, QuranEngineRepeatMode.one);
    engine.simulateTrackEnd();
    expect(controller.currentAyahNumber, 3);
  });

  test('repeat Surah configures queue looping back to ayah one', () async {
    await controller.playSurah(1, initialAyah: 7);
    await controller.setRepeatMode(QuranRepeatMode.surah);
    expect(engine.repeatMode, QuranEngineRepeatMode.all);
    engine.simulateTrackEnd();
    expect(controller.currentAyahNumber, 1);
    await controller.setRepeatMode(QuranRepeatMode.off);
    expect(engine.repeatMode, QuranEngineRepeatMode.off);
  });

  test(
    'history persists coordinates with schema and recovers malformed data',
    () async {
      final historyRepository = ListeningHistoryRepository(store: store);
      final entries = List.generate(
        15,
        (index) => ListeningHistoryEntry(
          surahNumber: index + 1,
          ayahNumber: 1,
          reciterId: 'r1',
          updatedAt: DateTime.utc(2026, 8, 14, 12, index),
        ),
      );
      await historyRepository.save(
        ListeningPreferencesSnapshot(history: entries),
      );
      final restored = await historyRepository.load();
      expect(
        restored.history,
        hasLength(ListeningHistoryRepository.maxEntries),
      );
      final document = jsonDecode(store.value!) as Map<String, dynamic>;
      expect(document['version'], ListeningHistoryRepository.schemaVersion);
      expect((document['history'] as List).first['surah'], 1);

      store.value = '{malformed';
      expect((await historyRepository.load()).history, isEmpty);
      store.value = '{"version":99,"history":[]}';
      expect((await historyRepository.load()).history, isEmpty);
    },
  );

  test('playback records bounded recent Surahs and supports resume', () async {
    await controller.playSurah(2, initialAyah: 255);
    await Future<void>.delayed(Duration.zero);
    expect(controller.history.first.surahNumber, 2);
    expect(controller.history.first.ayahNumber, 255);
    await controller.resumeHistory(controller.history.first);
    expect(
      (controller.currentSurahNumber, controller.currentAyahNumber),
      (2, 255),
    );
  });

  testWidgets('library exposes all 114 Surahs and live search', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ListeningPage(controller: controller)),
    );
    expect(find.byKey(const ValueKey('listening-library')), findsOneWidget);
    expect(find.text('114 سورة'), findsOneWidget);
    expect(find.byKey(const ValueKey('listening-surah-1')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('listening-surah-search')),
      'البقرة',
    );
    await tester.pump();
    expect(find.text('1 سورة'), findsOneWidget);
    expect(find.byKey(const ValueKey('listening-surah-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('listening-surah-1')), findsNothing);
  });

  testWidgets('library reciter selector comes from repository', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ListeningPage(controller: controller)),
    );
    await tester.tap(find.byKey(const ValueKey('reciter-selector')));
    await tester.pumpAndSettle();
    expect(
      find.text(repository.reciters.last.displayNameArabic),
      findsOneWidget,
    );
    await tester.tap(find.text(repository.reciters.last.displayNameArabic));
    await tester.pumpAndSettle();
    expect(controller.selectedReciter?.id, repository.reciters.last.id);
  });

  testWidgets('full player reflects Surah state and seek availability', (
    tester,
  ) async {
    await controller.playSurah(2, initialAyah: 255);
    engine.durations.add(const Duration(minutes: 3));
    await tester.pumpWidget(
      MaterialApp(home: ListeningPlayerPage(controller: controller)),
    );
    expect(find.byKey(const ValueKey('listening-full-player')), findsOneWidget);
    expect(find.text('سورة البقرة'), findsOneWidget);
    expect(find.text('الآية 255 من 286'), findsOneWidget);
    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('listening-seek')),
    );
    expect(slider.onChanged, isNotNull);
  });

  testWidgets('mini player opens full player and close clears state', (
    tester,
  ) async {
    await controller.playSurah(1);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            bottomSheet: AudioMiniPlayer(
              controller: controller,
              onOpen: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ListeningPlayerPage(controller: controller),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('audio-mini-player')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('audio-mini-player-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('listening-full-player')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('audio-mini-player-close')));
    await tester.pumpAndSettle();
    expect(engine.loaded, isEmpty);
    expect(find.byKey(const ValueKey('audio-mini-player')), findsNothing);
  });

  test('background MediaItem contains canonical Surah, ayah, and reciter', () {
    final item = quranMediaItemForSource(
      const AyahAudioSource(
        surahNumber: 2,
        ayahNumber: 255,
        reciterId: 'r1',
        reciterName: 'القارئ الأول',
        sourceId: 'https://example.test/002255.mp3',
        duration: Duration(minutes: 2),
      ),
    );
    expect(item.title, 'سورة البقرة');
    expect(item.artist, 'القارئ الأول');
    expect(item.duration, const Duration(minutes: 2));
    expect(item.extras?['surahNumber'], 2);
    expect(item.extras?['ayahNumber'], 255);
    expect(item.extras?['reciterId'], 'r1');
  });

  testWidgets('active ayah renders subtle highlight and real pause action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuranAyahItem(
            verse: const QuranVerse(surahNumber: 1, ayahNumber: 1, text: 'آية'),
            fontSize: 30,
            isActive: true,
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.pause_rounded), findsNothing);
    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer).last,
    );
    final color = (container.decoration! as BoxDecoration).color!;
    expect(color, isNot(Colors.transparent));
    expect(color.a, lessThan(0.2));
  });
}

class _FakeRepository implements QuranAudioRepository {
  final reciters = const [
    Reciter(id: 'r1', displayNameArabic: 'القارئ الأول'),
    Reciter(id: 'r2', displayNameArabic: 'القارئ الثاني'),
  ];
  QuranAudioResolutionFailure? failure;

  @override
  Future<List<Reciter>> getReciters() async => reciters;

  @override
  Future<AyahAudioSource?> resolveAyah({
    required String reciterId,
    required int surahNumber,
    required int ayahNumber,
  }) async {
    if (failure != null) throw QuranAudioResolutionException(failure!);
    return _source(reciterId, surahNumber, ayahNumber);
  }

  @override
  Future<List<AyahAudioSource>> resolveSurah({
    required String reciterId,
    required int surahNumber,
  }) async {
    if (failure != null) throw QuranAudioResolutionException(failure!);
    return List.generate(
      QuranMetadata.surah(surahNumber).ayahCount,
      (index) => _source(reciterId, surahNumber, index + 1),
    );
  }

  AyahAudioSource _source(String reciter, int surah, int ayah) =>
      AyahAudioSource(
        surahNumber: surah,
        ayahNumber: ayah,
        reciterId: reciter,
        sourceId: 'https://example.test/$surah/$ayah.mp3',
      );
}

class _FakeEngine implements QuranAudioEngine {
  final processing = StreamController<QuranEngineProcessingState>.broadcast(
    sync: true,
  );
  final playing = StreamController<bool>.broadcast(sync: true);
  final positions = StreamController<Duration>.broadcast(sync: true);
  final durations = StreamController<Duration?>.broadcast(sync: true);
  final indices = StreamController<int?>.broadcast(sync: true);
  final errors = StreamController<Object>.broadcast(sync: true);
  List<AyahAudioSource> loaded = [];
  int? index;
  bool failLoad = false;
  double speed = 1;
  Duration? lastSeek;
  QuranEngineRepeatMode repeatMode = QuranEngineRepeatMode.off;

  @override
  List<AyahAudioSource> get queueSources => loaded;
  @override
  Stream<QuranEngineProcessingState> get processingStateStream =>
      processing.stream;
  @override
  Stream<bool> get playingStream => playing.stream;
  @override
  Stream<Duration> get positionStream => positions.stream;
  @override
  Stream<Duration?> get durationStream => durations.stream;
  @override
  Stream<int?> get currentIndexStream => indices.stream;
  @override
  Stream<Object> get errorStream => errors.stream;

  @override
  Future<void> load(
    List<AyahAudioSource> sources, {
    int initialIndex = 0,
  }) async {
    if (failLoad) throw Exception('SECRET_ENGINE_FAILURE');
    loaded = sources;
    index = initialIndex;
    processing.add(QuranEngineProcessingState.ready);
    indices.add(index);
  }

  @override
  Future<void> play() async => playing.add(true);
  @override
  Future<void> pause() async => playing.add(false);
  @override
  Future<void> stop() async {
    loaded = [];
    index = null;
    playing.add(false);
    processing.add(QuranEngineProcessingState.idle);
  }

  @override
  Future<void> seek(Duration position) async {
    lastSeek = position;
    positions.add(position);
  }

  @override
  Future<void> setSpeed(double value) async => speed = value;
  @override
  Future<void> configureRepeatMode(QuranEngineRepeatMode value) async =>
      repeatMode = value;
  @override
  Future<void> next() async {
    if (index != null && index! + 1 < loaded.length) {
      index = index! + 1;
      indices.add(index);
    }
  }

  @override
  Future<void> previous() async {
    if (index != null && index! > 0) {
      index = index! - 1;
      indices.add(index);
    }
  }

  void simulateTrackEnd() {
    if (index == null) return;
    switch (repeatMode) {
      case QuranEngineRepeatMode.one:
        indices.add(index);
      case QuranEngineRepeatMode.all:
        index = index! + 1 < loaded.length ? index! + 1 : 0;
        indices.add(index);
      case QuranEngineRepeatMode.off:
        processing.add(QuranEngineProcessingState.completed);
    }
  }

  @override
  Future<void> dispose() async {
    await processing.close();
    await playing.close();
    await positions.close();
    await durations.close();
    await indices.close();
    await errors.close();
  }
}

class _MemoryListeningStore implements ListeningHistoryStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}
