import 'package:http/http.dart' as http;

import '../models/ayah_audio_source.dart';
import '../models/reciter.dart';
import '../models/surah.dart';

abstract interface class QuranAudioRepository {
  Future<List<Reciter>> getReciters();
  Future<AyahAudioSource?> resolveAyah({
    required String reciterId,
    required int surahNumber,
    required int ayahNumber,
  });
  Future<List<AyahAudioSource>> resolveSurah({
    required String reciterId,
    required int surahNumber,
  });
}

enum QuranAudioResolutionFailure { networkUnavailable, sourceUnavailable }

class QuranAudioResolutionException implements Exception {
  const QuranAudioResolutionException(this.failure);
  final QuranAudioResolutionFailure failure;
}

class EveryAyahAudioRepository implements QuranAudioRepository {
  EveryAyahAudioRepository({http.Client? client})
    : _client = client ?? http.Client();

  static const _base = 'https://everyayah.com/data';
  static const _paths = <String, String>{
    'alafasy-128': 'Alafasy_128kbps',
    'abdulbasit-murattal-64': 'Abdul_Basit_Murattal_64kbps',
  };
  static const _reciters = <Reciter>[
    Reciter(
      id: 'alafasy-128',
      displayNameArabic: 'مشاري راشد العفاسي',
      displayNameEnglish: 'Mishary Rashid Alafasy',
    ),
    Reciter(
      id: 'abdulbasit-murattal-64',
      displayNameArabic: 'عبد الباسط عبد الصمد',
      displayNameEnglish: 'Abdul Basit Abdus Samad',
    ),
  ];
  final http.Client _client;

  @override
  Future<List<Reciter>> getReciters() async => _reciters;

  @override
  Future<AyahAudioSource?> resolveAyah({
    required String reciterId,
    required int surahNumber,
    required int ayahNumber,
  }) async {
    if (!_valid(surahNumber, ayahNumber) || !_paths.containsKey(reciterId)) {
      return null;
    }
    final uri = _uri(reciterId, surahNumber, ayahNumber);
    try {
      final response = await _client
          .head(uri)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 400) {
        throw const QuranAudioResolutionException(
          QuranAudioResolutionFailure.sourceUnavailable,
        );
      }
      final contentType = response.headers['content-type'];
      if (contentType != null && !contentType.startsWith('audio/')) {
        throw const QuranAudioResolutionException(
          QuranAudioResolutionFailure.sourceUnavailable,
        );
      }
      return AyahAudioSource(
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
        reciterId: reciterId,
        sourceId: uri.toString(),
      );
    } on QuranAudioResolutionException {
      rethrow;
    } catch (_) {
      throw const QuranAudioResolutionException(
        QuranAudioResolutionFailure.networkUnavailable,
      );
    }
  }

  @override
  Future<List<AyahAudioSource>> resolveSurah({
    required String reciterId,
    required int surahNumber,
  }) async {
    if (surahNumber < 1 ||
        surahNumber > QuranMetadata.surahCount ||
        !_paths.containsKey(reciterId)) {
      return const [];
    }
    return List.generate(QuranMetadata.surah(surahNumber).ayahCount, (index) {
      final ayah = index + 1;
      return AyahAudioSource(
        surahNumber: surahNumber,
        ayahNumber: ayah,
        reciterId: reciterId,
        sourceId: _uri(reciterId, surahNumber, ayah).toString(),
      );
    });
  }

  Uri _uri(String reciterId, int surah, int ayah) => Uri.parse(
    '$_base/${_paths[reciterId]}/${surah.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}.mp3',
  );
  bool _valid(int surah, int ayah) =>
      surah >= 1 &&
      surah <= QuranMetadata.surahCount &&
      ayah >= 1 &&
      ayah <= QuranMetadata.surah(surah).ayahCount;
  void dispose() => _client.close();
}

class UnsupportedQuranAudioRepository implements QuranAudioRepository {
  const UnsupportedQuranAudioRepository();
  @override
  Future<List<Reciter>> getReciters() async => const [];
  @override
  Future<AyahAudioSource?> resolveAyah({
    required String reciterId,
    required int surahNumber,
    required int ayahNumber,
  }) async => null;
  @override
  Future<List<AyahAudioSource>> resolveSurah({
    required String reciterId,
    required int surahNumber,
  }) async => const [];
}
