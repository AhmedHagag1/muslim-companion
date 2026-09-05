import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../models/quran_knowledge.dart';
import '../models/surah.dart';

abstract interface class TranslationRepository {
  Future<List<QuranTranslation>> installedTranslations();
  Future<TranslatedAyah?> getAyah(
    String translationId,
    int surahNumber,
    int ayahNumber,
  );
}

abstract interface class TafsirRepository {
  Future<List<TafsirSource>> installedSources();
  Future<TafsirEntry?> getEntry(
    String sourceId,
    int surahNumber,
    int ayahNumber,
  );
}

abstract interface class WordMeaningRepository {
  Future<List<WordMeaningSource>> installedSources();
  Future<WordMeaningEntry?> getEntry(
    String sourceId,
    int surahNumber,
    int ayahNumber,
  );
}

class BundledTranslationRepository implements TranslationRepository {
  const BundledTranslationRepository();

  @override
  Future<List<QuranTranslation>> installedTranslations() async {
    try {
      return (await BundledQuranStudyRepository.load()).translations;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<TranslatedAyah?> getAyah(
    String translationId,
    int surahNumber,
    int ayahNumber,
  ) async {
    if (!_validCoordinate(surahNumber, ayahNumber)) return null;
    try {
      return (await BundledQuranStudyRepository.load())
          .translationsByCoordinate[translationId]?['$surahNumber:$ayahNumber'];
    } catch (_) {
      return null;
    }
  }
}

class BundledTafsirRepository implements TafsirRepository {
  const BundledTafsirRepository();

  @override
  Future<List<TafsirSource>> installedSources() async {
    try {
      return (await BundledQuranStudyRepository.load()).tafsirs;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<TafsirEntry?> getEntry(
    String sourceId,
    int surahNumber,
    int ayahNumber,
  ) async {
    if (!_validCoordinate(surahNumber, ayahNumber)) return null;
    try {
      return (await BundledQuranStudyRepository.load())
          .tafsirsByCoordinate[sourceId]?['$surahNumber:$ayahNumber'];
    } catch (_) {
      return null;
    }
  }
}

class BundledWordMeaningRepository implements WordMeaningRepository {
  const BundledWordMeaningRepository();

  @override
  Future<List<WordMeaningSource>> installedSources() async {
    try {
      return (await BundledQuranStudyRepository.load()).wordMeaningSources;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<WordMeaningEntry?> getEntry(
    String sourceId,
    int surahNumber,
    int ayahNumber,
  ) async {
    if (!_validCoordinate(surahNumber, ayahNumber)) return null;
    try {
      return (await BundledQuranStudyRepository.load())
          .wordMeaningsByCoordinate[sourceId]?['$surahNumber:$ayahNumber'];
    } catch (_) {
      return null;
    }
  }
}

class QuranStudySearchDocument {
  const QuranStudySearchDocument({
    required this.resourceId,
    required this.resourceType,
    required this.resourceTitle,
    required this.surahNumber,
    required this.ayahNumber,
    required this.text,
  });

  final String resourceId;
  final QuranResourceType resourceType;
  final String resourceTitle;
  final int surahNumber;
  final int ayahNumber;
  final String text;
}

class BundledQuranStudyData {
  const BundledQuranStudyData({
    required this.manifests,
    required this.translations,
    required this.tafsirs,
    required this.wordMeaningSources,
    required this.translationsByCoordinate,
    required this.tafsirsByCoordinate,
    required this.wordMeaningsByCoordinate,
    required this.searchDocuments,
  });

  final List<QuranResourceManifest> manifests;
  final List<QuranTranslation> translations;
  final List<TafsirSource> tafsirs;
  final List<WordMeaningSource> wordMeaningSources;
  final Map<String, Map<String, TranslatedAyah>> translationsByCoordinate;
  final Map<String, Map<String, TafsirEntry>> tafsirsByCoordinate;
  final Map<String, Map<String, WordMeaningEntry>> wordMeaningsByCoordinate;
  final List<QuranStudySearchDocument> searchDocuments;
}

abstract final class BundledQuranStudyRepository {
  static const manifestAsset = 'assets/quran_study/manifest.json';
  static Future<BundledQuranStudyData>? _cached;

  static Future<BundledQuranStudyData> load() => _cached ??= _load();

  static void clearCacheForTesting() => _cached = null;

  static Future<BundledQuranStudyData> _load() async {
    final manifestData = await rootBundle.load(manifestAsset);
    final manifestBytes = manifestData.buffer.asUint8List(
      manifestData.offsetInBytes,
      manifestData.lengthInBytes,
    );
    final manifestRoot = jsonDecode(utf8.decode(manifestBytes));
    if (manifestRoot is! Map<String, dynamic> ||
        manifestRoot['schemaVersion'] != 1 ||
        manifestRoot['canonicalQuranIncluded'] != false ||
        manifestRoot['resources'] is! List) {
      throw const FormatException('Invalid Quran study manifest.');
    }
    final activation = manifestRoot['remoteActivation'];
    if (activation is! Map<String, dynamic> || activation['enabled'] != false) {
      throw const FormatException(
        'Remote Quran resource activation is unsafe.',
      );
    }

    final manifests = <QuranResourceManifest>[];
    final translations = <QuranTranslation>[];
    final tafsirs = <TafsirSource>[];
    final wordSources = <WordMeaningSource>[];
    final translated = <String, Map<String, TranslatedAyah>>{};
    final interpreted = <String, Map<String, TafsirEntry>>{};
    final meanings = <String, Map<String, WordMeaningEntry>>{};
    final searchDocuments = <QuranStudySearchDocument>[];

    for (final rawResource in manifestRoot['resources'] as List) {
      if (rawResource is! Map<String, dynamic>) {
        throw const FormatException('Invalid Quran study resource metadata.');
      }
      final manifest = QuranResourceManifest.fromJson(rawResource);
      if (manifest == null || manifest.recordCount != 6236) {
        throw const FormatException('Invalid Quran study resource manifest.');
      }
      final bytes = await rootBundle.load(manifest.asset);
      final payloadBytes = bytes.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
      if (payloadBytes.length != manifest.size ||
          sha256.convert(payloadBytes).toString().toUpperCase() !=
              manifest.checksum.toUpperCase()) {
        throw StateError('Quran study resource checksum mismatch.');
      }
      final payload = jsonDecode(utf8.decode(payloadBytes));
      if (payload is! Map<String, dynamic> ||
          payload['resourceId'] != manifest.id ||
          payload['entries'] is! List ||
          (payload['entries'] as List).length != manifest.recordCount) {
        throw const FormatException('Invalid Quran study resource payload.');
      }
      final entries = _parseEntries(
        payload['entries'] as List,
        manifest,
        searchDocuments,
      );
      manifests.add(manifest);
      switch (manifest.type) {
        case QuranResourceType.translation:
          translations.add(
            QuranTranslation(
              id: manifest.id,
              name: manifest.title,
              languageCode: manifest.language,
              author: manifest.publisher,
              provider: manifest.provider,
              source: manifest.source,
              license: manifest.license,
              version: manifest.version,
            ),
          );
          translated[manifest.id] = {
            for (final entry in entries)
              _key(entry.$1, entry.$2): TranslatedAyah(
                translationId: manifest.id,
                surahNumber: entry.$1,
                ayahNumber: entry.$2,
                text: entry.$3,
                footnotes: entry.$4,
              ),
          };
        case QuranResourceType.tafsir:
          tafsirs.add(
            TafsirSource(
              id: manifest.id,
              title: manifest.title,
              author: manifest.publisher,
              languageCode: manifest.language,
              source: manifest.source,
              license: manifest.license,
              version: manifest.version,
            ),
          );
          interpreted[manifest.id] = {
            for (final entry in entries)
              _key(entry.$1, entry.$2): TafsirEntry(
                sourceId: manifest.id,
                startSurahNumber: entry.$1,
                startAyahNumber: entry.$2,
                endSurahNumber: entry.$1,
                endAyahNumber: entry.$2,
                text: entry.$3,
                footnotes: entry.$4,
              ),
          };
        case QuranResourceType.wordMeanings:
          wordSources.add(
            WordMeaningSource(
              id: manifest.id,
              title: manifest.title,
              publisher: manifest.publisher,
              source: manifest.source,
              license: manifest.license,
              version: manifest.version,
            ),
          );
          meanings[manifest.id] = {
            for (final entry in entries)
              _key(entry.$1, entry.$2): WordMeaningEntry(
                sourceId: manifest.id,
                surahNumber: entry.$1,
                ayahNumber: entry.$2,
                text: entry.$3,
              ),
          };
        case QuranResourceType.arabicQuran:
        case QuranResourceType.recitation:
          throw const FormatException('Unexpected study resource type.');
      }
    }
    if (translations.length != 1 ||
        tafsirs.length != 1 ||
        wordSources.length != 1) {
      throw const FormatException('Incomplete bundled Quran study pack.');
    }
    return BundledQuranStudyData(
      manifests: List.unmodifiable(manifests),
      translations: List.unmodifiable(translations),
      tafsirs: List.unmodifiable(tafsirs),
      wordMeaningSources: List.unmodifiable(wordSources),
      translationsByCoordinate: translated,
      tafsirsByCoordinate: interpreted,
      wordMeaningsByCoordinate: meanings,
      searchDocuments: List.unmodifiable(searchDocuments),
    );
  }

  static List<(int, int, String, String?)> _parseEntries(
    List<dynamic> rawEntries,
    QuranResourceManifest manifest,
    List<QuranStudySearchDocument> searchDocuments,
  ) {
    final entries = <(int, int, String, String?)>[];
    final coordinates = <String>{};
    var nonEmpty = 0;
    for (final raw in rawEntries) {
      if (raw is! Map<String, dynamic> ||
          raw['surahNumber'] is! int ||
          raw['ayahNumber'] is! int ||
          raw['text'] is! String ||
          (raw['footnotes'] != null && raw['footnotes'] is! String)) {
        throw const FormatException('Invalid Quran study entry.');
      }
      final surah = raw['surahNumber'] as int;
      final ayah = raw['ayahNumber'] as int;
      final text = raw['text'] as String;
      final footnotes = raw['footnotes'] as String?;
      if (!_validCoordinate(surah, ayah) ||
          !coordinates.add(_key(surah, ayah))) {
        throw const FormatException('Invalid Quran study coordinates.');
      }
      if (text.isNotEmpty) {
        nonEmpty++;
        searchDocuments.add(
          QuranStudySearchDocument(
            resourceId: manifest.id,
            resourceType: manifest.type,
            resourceTitle: manifest.title,
            surahNumber: surah,
            ayahNumber: ayah,
            text: text,
          ),
        );
      }
      entries.add((surah, ayah, text, footnotes));
    }
    if (nonEmpty != manifest.nonEmptyRecordCount) {
      throw const FormatException('Quran study non-empty count mismatch.');
    }
    return entries;
  }
}

bool _validCoordinate(int surahNumber, int ayahNumber) {
  if (surahNumber < 1 || surahNumber > QuranMetadata.surahCount) return false;
  return ayahNumber >= 1 &&
      ayahNumber <= QuranMetadata.surah(surahNumber).ayahCount;
}

String _key(int surahNumber, int ayahNumber) => '$surahNumber:$ayahNumber';

class QuranResourceRepository {
  const QuranResourceRepository();

  Future<List<QuranResourceManifest>> installedResources() async {
    try {
      final study = await BundledQuranStudyRepository.load();
      return [BundledQuranResources.arabicQuran, ...study.manifests];
    } catch (_) {
      return BundledQuranResources.installed;
    }
  }

  bool checksumMatches(QuranResourceManifest manifest, String actual) =>
      manifest.checksum.toUpperCase() == actual.trim().toUpperCase();
}
