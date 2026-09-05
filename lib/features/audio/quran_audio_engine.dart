import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../../data/models/ayah_audio_source.dart';
import '../../data/models/surah.dart';

enum QuranEngineProcessingState { idle, loading, buffering, ready, completed }

enum QuranEngineRepeatMode { off, one, all }

abstract interface class QuranAudioEngine {
  Stream<QuranEngineProcessingState> get processingStateStream;
  Stream<bool> get playingStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<int?> get currentIndexStream;
  Stream<Object> get errorStream;
  List<AyahAudioSource> get queueSources;
  Future<void> load(List<AyahAudioSource> sources, {int initialIndex = 0});
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> configureRepeatMode(QuranEngineRepeatMode mode);
  Future<void> next();
  Future<void> previous();
  Future<void> dispose();
}

class JustAudioQuranEngine extends BaseAudioHandler
    implements QuranAudioEngine {
  JustAudioQuranEngine() {
    _bind();
  }

  final AudioPlayer _player = AudioPlayer();
  final _errors = StreamController<Object>.broadcast();
  List<AyahAudioSource> _sources = const [];

  static Future<JustAudioQuranEngine> create() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    return AudioService.init(
      builder: JustAudioQuranEngine.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.ahmedhaggag.muslimcompanion.audio',
        androidNotificationChannelName: 'Quran recitation',
        androidNotificationOngoing: true,
      ),
    );
  }

  void _bind() {
    _player.playbackEventStream.listen((event) {
      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            _player.playing ? MediaControl.pause : MediaControl.play,
            MediaControl.stop,
            MediaControl.skipToNext,
          ],
          systemActions: const {MediaAction.seek},
          androidCompactActionIndices: const [0, 1, 3],
          processingState: _audioServiceState(_player.processingState),
          playing: _player.playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
          queueIndex: _player.currentIndex,
        ),
      );
    }, onError: _errors.add);
    _player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < queue.value.length) {
        mediaItem.add(queue.value[index]);
      }
    });
  }

  @override
  List<AyahAudioSource> get queueSources => List.unmodifiable(_sources);
  @override
  Stream<QuranEngineProcessingState> get processingStateStream =>
      _player.processingStateStream.map(_engineState).distinct();
  @override
  Stream<bool> get playingStream => _player.playingStream;
  @override
  Stream<Duration> get positionStream => _player.positionStream;
  @override
  Stream<Duration?> get durationStream => _player.durationStream;
  @override
  Stream<int?> get currentIndexStream => _player.currentIndexStream;
  @override
  Stream<Object> get errorStream => _errors.stream;

  @override
  Future<void> load(
    List<AyahAudioSource> sources, {
    int initialIndex = 0,
  }) async {
    if (sources.isEmpty || sources.any((source) => source.uri == null)) {
      throw ArgumentError('Audio queue contains an invalid source.');
    }
    _sources = List.unmodifiable(sources);
    final items = sources.map(quranMediaItemForSource).toList();
    queue.add(items);
    await _player.setAudioSources(
      sources
          .map(
            (source) => AudioSource.uri(
              source.uri!,
              tag: items[sources.indexOf(source)],
            ),
          )
          .toList(),
      initialIndex: initialIndex,
    );
  }

  @override
  Future<void> play() async {
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() async {
    await _player.stop();
    await _player.clearAudioSources();
    _sources = const [];
    queue.add(const []);
    mediaItem.add(null);
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);
  @override
  Future<void> configureRepeatMode(QuranEngineRepeatMode mode) =>
      _player.setLoopMode(switch (mode) {
        QuranEngineRepeatMode.off => LoopMode.off,
        QuranEngineRepeatMode.one => LoopMode.one,
        QuranEngineRepeatMode.all => LoopMode.all,
      });
  @override
  Future<void> next() => _player.seekToNext();
  @override
  Future<void> previous() => _player.seekToPrevious();
  @override
  Future<void> skipToNext() => next();
  @override
  Future<void> skipToPrevious() => previous();
  @override
  Future<void> dispose() async {
    await _player.dispose();
    await _errors.close();
  }

  QuranEngineProcessingState _engineState(ProcessingState value) =>
      switch (value) {
        ProcessingState.idle => QuranEngineProcessingState.idle,
        ProcessingState.loading => QuranEngineProcessingState.loading,
        ProcessingState.buffering => QuranEngineProcessingState.buffering,
        ProcessingState.ready => QuranEngineProcessingState.ready,
        ProcessingState.completed => QuranEngineProcessingState.completed,
      };
  AudioProcessingState _audioServiceState(ProcessingState value) =>
      switch (value) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      };
}

MediaItem quranMediaItemForSource(AyahAudioSource source) {
  final surah = QuranMetadata.surah(source.surahNumber);
  return MediaItem(
    id: source.sourceId,
    album: 'القرآن الكريم • الآية ${source.ayahNumber} من ${surah.ayahCount}',
    title: 'سورة ${surah.name}',
    artist: source.reciterName,
    duration: source.duration,
    extras: {
      'surahNumber': source.surahNumber,
      'ayahNumber': source.ayahNumber,
      'reciterId': source.reciterId,
      'reciterName': source.reciterName,
    },
  );
}
