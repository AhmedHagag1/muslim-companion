import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/ayah_audio_source.dart';
import '../../data/models/listening_history.dart';
import '../../data/models/reciter.dart';
import '../../data/models/surah.dart';
import '../../data/repositories/listening_history_repository.dart';
import '../../data/repositories/quran_audio_repository.dart';
import 'quran_audio_engine.dart';

enum QuranAudioStatus {
  idle,
  loading,
  buffering,
  playing,
  paused,
  completed,
  error,
}

enum QuranRepeatMode { off, ayah, surah }

class QuranAudioController extends ChangeNotifier {
  QuranAudioController({
    required this._repository,
    required this._engine,
    ListeningHistoryRepository? historyRepository,
    DateTime Function()? now,
  }) : _historyRepository = historyRepository ?? ListeningHistoryRepository(),
       _now = now ?? DateTime.now {
    _subscriptions = [
      _engine.processingStateStream.listen(_onProcessing),
      _engine.playingStream.listen(_onPlaying),
      _engine.positionStream.listen((value) {
        position = value;
        notifyListeners();
      }),
      _engine.durationStream.listen((value) {
        duration = value;
        notifyListeners();
      }),
      _engine.currentIndexStream.listen(_onIndex),
      _engine.errorStream.listen((value) {
        if (kDebugMode) debugPrint('Quran audio engine error: $value');
        _setError('حدث خلل أثناء تشغيل التلاوة. حاول مرة أخرى.');
      }),
    ];
  }

  final QuranAudioRepository _repository;
  final QuranAudioEngine _engine;
  final ListeningHistoryRepository _historyRepository;
  final DateTime Function() _now;
  late final List<StreamSubscription<Object?>> _subscriptions;

  QuranAudioStatus status = QuranAudioStatus.idle;
  List<Reciter> reciters = const [];
  Reciter? selectedReciter;
  int? currentSurahNumber;
  int? currentAyahNumber;
  int? currentQueueIndex;
  Duration position = Duration.zero;
  Duration? duration;
  double playbackSpeed = 1;
  QuranRepeatMode repeatMode = QuranRepeatMode.off;
  String? error;
  List<ListeningHistoryEntry> _history = const [];
  bool _lastQueueWasSurah = false;
  ({int surah, int ayah, bool surahQueue})? _lastRequest;

  List<ListeningHistoryEntry> get history => List.unmodifiable(_history);
  bool get hasActiveItem =>
      currentSurahNumber != null && currentAyahNumber != null;
  bool get isPlaying => status == QuranAudioStatus.playing;
  bool get isPlaybackSupported => true;
  bool get canPreviousAyah => (currentQueueIndex ?? 0) > 0;
  bool get canNextAyah =>
      currentQueueIndex != null &&
      currentQueueIndex! + 1 < _engine.queueSources.length;
  bool get canPreviousSurah =>
      currentSurahNumber != null && currentSurahNumber! > 1;
  bool get canNextSurah =>
      currentSurahNumber != null &&
      currentSurahNumber! < QuranMetadata.surahCount;
  int get currentAyahCount => currentSurahNumber == null
      ? 0
      : QuranMetadata.surah(currentSurahNumber!).ayahCount;
  bool get canSeek => duration != null && duration! > Duration.zero;
  double get positionFraction {
    if (!canSeek) return 0;
    return (position.inMilliseconds / duration!.inMilliseconds).clamp(0, 1);
  }

  Future<void> initialize() async {
    reciters = List.unmodifiable(await _repository.getReciters());
    final snapshot = await _historyRepository.load();
    _history = List.unmodifiable(snapshot.history);
    playbackSpeed = snapshot.playbackSpeed;
    repeatMode = switch (snapshot.repeatMode) {
      'ayah' => QuranRepeatMode.ayah,
      'surah' => QuranRepeatMode.surah,
      _ => QuranRepeatMode.off,
    };
    if (reciters.isNotEmpty) {
      selectedReciter = reciters.cast<Reciter?>().firstWhere(
        (reciter) => reciter?.id == snapshot.selectedReciterId,
        orElse: () => reciters.first,
      );
    }
    await _engine.setSpeed(playbackSpeed);
    await _engine.configureRepeatMode(_engineRepeatMode(repeatMode));
    notifyListeners();
    await _persist();
  }

  Future<List<Reciter>> loadReciters() async {
    reciters = List.unmodifiable(await _repository.getReciters());
    notifyListeners();
    return reciters;
  }

  bool setReciter(Reciter reciter) {
    if (reciter.id.trim().isEmpty) return false;
    selectedReciter = reciter;
    unawaited(_persist());
    notifyListeners();
    return true;
  }

  Future<bool> selectReciter(Reciter reciter) async {
    if (!setReciter(reciter)) return false;
    if (!hasActiveItem) return true;
    final surah = currentSurahNumber!;
    final ayah = currentAyahNumber!;
    final shouldPlay = isPlaying;
    return _lastQueueWasSurah
        ? playSurah(surah, initialAyah: ayah, autoPlay: shouldPlay)
        : _playSingleAyah(surah, ayah, autoPlay: shouldPlay);
  }

  Future<bool> playAyah(int surahNumber, int ayahNumber) =>
      _playSingleAyah(surahNumber, ayahNumber, autoPlay: true);

  Future<bool> _playSingleAyah(
    int surahNumber,
    int ayahNumber, {
    required bool autoPlay,
  }) async {
    if (!_valid(surahNumber, ayahNumber) || selectedReciter == null) {
      return false;
    }
    _lastRequest = (surah: surahNumber, ayah: ayahNumber, surahQueue: false);
    _lastQueueWasSurah = false;
    _setLoading();
    try {
      final source = await _repository.resolveAyah(
        reciterId: selectedReciter!.id,
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
      );
      if (source == null || source.uri == null) {
        return _fail('هذه التلاوة غير متاحة الآن. جرّب قارئًا آخر.');
      }
      return _load([
        source.withReciterName(selectedReciter!.displayNameArabic),
      ], autoPlay: autoPlay);
    } on QuranAudioResolutionException catch (exception) {
      return _fail(_resolutionMessage(exception.failure));
    } catch (exception) {
      if (kDebugMode) debugPrint('Quran ayah resolution error: $exception');
      return _fail('تعذر تجهيز التلاوة الآن. حاول مرة أخرى.');
    }
  }

  Future<bool> playSurah(
    int surahNumber, {
    int initialAyah = 1,
    bool autoPlay = true,
  }) async {
    if (!_valid(surahNumber, initialAyah) || selectedReciter == null) {
      return false;
    }
    _lastRequest = (surah: surahNumber, ayah: initialAyah, surahQueue: true);
    _lastQueueWasSurah = true;
    _setLoading();
    try {
      final resolved = await _repository.resolveSurah(
        reciterId: selectedReciter!.id,
        surahNumber: surahNumber,
      );
      if (resolved.isEmpty || resolved.any((source) => source.uri == null)) {
        return _fail('تلاوة السورة غير متاحة الآن. جرّب قارئًا آخر.');
      }
      final sources = resolved
          .map(
            (source) =>
                source.withReciterName(selectedReciter!.displayNameArabic),
          )
          .toList(growable: false);
      return _load(sources, initialIndex: initialAyah - 1, autoPlay: autoPlay);
    } on QuranAudioResolutionException catch (exception) {
      return _fail(_resolutionMessage(exception.failure));
    } catch (exception) {
      if (kDebugMode) debugPrint('Quran surah resolution error: $exception');
      return _fail('تعذر تجهيز السورة الآن. حاول مرة أخرى.');
    }
  }

  Future<bool> _load(
    List<AyahAudioSource> sources, {
    int initialIndex = 0,
    required bool autoPlay,
  }) async {
    try {
      await _engine.load(sources, initialIndex: initialIndex);
      await _engine.setSpeed(playbackSpeed);
      await _engine.configureRepeatMode(_engineRepeatMode(repeatMode));
      if (autoPlay) {
        await _engine.play();
      } else {
        status = QuranAudioStatus.paused;
        notifyListeners();
      }
      return true;
    } catch (exception) {
      if (kDebugMode) {
        debugPrint('Quran audio load/playback error: $exception');
      }
      return _fail('تعذر تشغيل التلاوة الآن. تحقق من الاتصال ثم أعد المحاولة.');
    }
  }

  Future<bool> retry() async {
    final request = _lastRequest;
    if (request == null) return false;
    return request.surahQueue
        ? playSurah(request.surah, initialAyah: request.ayah)
        : playAyah(request.surah, request.ayah);
  }

  Future<void> pause() => _engine.pause();
  Future<void> resume() => _engine.play();

  Future<bool> seek(Duration value) async {
    final limit = duration;
    if (limit == null || limit <= Duration.zero) return false;
    final milliseconds = value.inMilliseconds.clamp(0, limit.inMilliseconds);
    await _engine.seek(Duration(milliseconds: milliseconds));
    return true;
  }

  Future<bool> seekToFraction(double value) {
    if (!value.isFinite || !canSeek) return Future.value(false);
    return seek(
      Duration(
        milliseconds: (duration!.inMilliseconds * value.clamp(0, 1)).round(),
      ),
    );
  }

  Future<void> nextAyah() async {
    if (canNextAyah) await _engine.next();
  }

  Future<void> previousAyah() async {
    if (canPreviousAyah) await _engine.previous();
  }

  Future<bool> playNextSurah() {
    if (!canNextSurah) return Future.value(false);
    return playSurah(currentSurahNumber! + 1);
  }

  Future<bool> playPreviousSurah() {
    if (!canPreviousSurah) return Future.value(false);
    return playSurah(currentSurahNumber! - 1);
  }

  Future<bool> resumeHistory(ListeningHistoryEntry entry) async {
    final reciter = reciters.cast<Reciter?>().firstWhere(
      (item) => item?.id == entry.reciterId,
      orElse: () => selectedReciter,
    );
    if (reciter == null) return false;
    selectedReciter = reciter;
    await _persist();
    return playSurah(entry.surahNumber, initialAyah: entry.ayahNumber);
  }

  Future<void> stop() async {
    await _engine.stop();
    status = QuranAudioStatus.idle;
    position = Duration.zero;
    duration = null;
    currentSurahNumber = null;
    currentAyahNumber = null;
    currentQueueIndex = null;
    error = null;
    notifyListeners();
  }

  Future<bool> setPlaybackSpeed(double value) async {
    if (!value.isFinite || value < 0.5 || value > 2) return false;
    playbackSpeed = value;
    await _engine.setSpeed(value);
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> setRepeatMode(QuranRepeatMode value) async {
    repeatMode = value;
    await _engine.configureRepeatMode(_engineRepeatMode(value));
    await _persist();
    notifyListeners();
  }

  Future<void> cycleRepeatMode() => setRepeatMode(switch (repeatMode) {
    QuranRepeatMode.off => QuranRepeatMode.ayah,
    QuranRepeatMode.ayah => QuranRepeatMode.surah,
    QuranRepeatMode.surah => QuranRepeatMode.off,
  });

  ({int surahNumber, int ayahNumber})? nextCoordinate(
    int surahNumber,
    int ayahNumber,
  ) {
    if (!_valid(surahNumber, ayahNumber)) return null;
    final count = QuranMetadata.surah(surahNumber).ayahCount;
    if (ayahNumber < count) {
      return (surahNumber: surahNumber, ayahNumber: ayahNumber + 1);
    }
    if (surahNumber == QuranMetadata.surahCount) return null;
    return (surahNumber: surahNumber + 1, ayahNumber: 1);
  }

  ({int surahNumber, int ayahNumber})? previousCoordinate(
    int surahNumber,
    int ayahNumber,
  ) {
    if (!_valid(surahNumber, ayahNumber)) return null;
    if (ayahNumber > 1) {
      return (surahNumber: surahNumber, ayahNumber: ayahNumber - 1);
    }
    if (surahNumber == 1) return null;
    final previous = QuranMetadata.surah(surahNumber - 1);
    return (surahNumber: previous.number, ayahNumber: previous.ayahCount);
  }

  void _onProcessing(QuranEngineProcessingState value) {
    status = switch (value) {
      QuranEngineProcessingState.idle =>
        hasActiveItem ? QuranAudioStatus.paused : QuranAudioStatus.idle,
      QuranEngineProcessingState.loading => QuranAudioStatus.loading,
      QuranEngineProcessingState.buffering => QuranAudioStatus.buffering,
      QuranEngineProcessingState.ready =>
        status == QuranAudioStatus.playing
            ? QuranAudioStatus.playing
            : QuranAudioStatus.paused,
      QuranEngineProcessingState.completed => QuranAudioStatus.completed,
    };
    notifyListeners();
  }

  void _onPlaying(bool value) {
    if (status != QuranAudioStatus.loading &&
        status != QuranAudioStatus.buffering &&
        status != QuranAudioStatus.completed) {
      status = value
          ? QuranAudioStatus.playing
          : (hasActiveItem ? QuranAudioStatus.paused : QuranAudioStatus.idle);
    }
    notifyListeners();
  }

  void _onIndex(int? index) {
    currentQueueIndex = index;
    if (index != null && index >= 0 && index < _engine.queueSources.length) {
      final source = _engine.queueSources[index];
      currentSurahNumber = source.surahNumber;
      currentAyahNumber = source.ayahNumber;
      position = Duration.zero;
      unawaited(_recordHistory(source));
    }
    notifyListeners();
  }

  Future<void> _recordHistory(AyahAudioSource source) async {
    final entry = ListeningHistoryEntry(
      surahNumber: source.surahNumber,
      ayahNumber: source.ayahNumber,
      reciterId: source.reciterId,
      updatedAt: _now().toUtc(),
    );
    _history = [
      entry,
      ..._history.where((item) => item.surahNumber != entry.surahNumber),
    ].take(ListeningHistoryRepository.maxEntries).toList(growable: false);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() => _historyRepository.save(
    ListeningPreferencesSnapshot(
      selectedReciterId: selectedReciter?.id,
      repeatMode: repeatMode.name,
      playbackSpeed: playbackSpeed,
      history: _history,
    ),
  );

  QuranEngineRepeatMode _engineRepeatMode(QuranRepeatMode value) =>
      switch (value) {
        QuranRepeatMode.off => QuranEngineRepeatMode.off,
        QuranRepeatMode.ayah => QuranEngineRepeatMode.one,
        QuranRepeatMode.surah => QuranEngineRepeatMode.all,
      };

  String _resolutionMessage(QuranAudioResolutionFailure failure) =>
      switch (failure) {
        QuranAudioResolutionFailure.networkUnavailable =>
          'لا يتوفر اتصال بالشبكة الآن. تحقق من الاتصال ثم أعد المحاولة.',
        QuranAudioResolutionFailure.sourceUnavailable =>
          'هذه التلاوة غير متاحة حاليًا. جرّب قارئًا آخر.',
      };

  void _setLoading() {
    status = QuranAudioStatus.loading;
    error = null;
    notifyListeners();
  }

  void _setError(String message) {
    status = QuranAudioStatus.error;
    error = message;
    notifyListeners();
  }

  bool _fail(String message) {
    _setError(message);
    return false;
  }

  bool _valid(int surah, int ayah) =>
      surah >= 1 &&
      surah <= QuranMetadata.surahCount &&
      ayah >= 1 &&
      ayah <= QuranMetadata.surah(surah).ayahCount;

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    if (_repository case EveryAyahAudioRepository repository) {
      repository.dispose();
    }
    _engine.dispose();
    super.dispose();
  }
}
