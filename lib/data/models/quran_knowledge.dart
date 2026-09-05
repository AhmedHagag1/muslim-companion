import 'surah.dart';

enum QuranResourceType {
  arabicQuran,
  translation,
  tafsir,
  wordMeanings,
  recitation,
}

class QuranTranslation {
  const QuranTranslation({
    required this.id,
    required this.name,
    required this.languageCode,
    required this.author,
    required this.provider,
    required this.source,
    required this.license,
    required this.version,
  });

  final String id;
  final String name;
  final String languageCode;
  final String author;
  final String provider;
  final String source;
  final String license;
  final String version;
}

class TranslatedAyah {
  const TranslatedAyah({
    required this.translationId,
    required this.surahNumber,
    required this.ayahNumber,
    required this.text,
    this.footnotes,
  });

  final String translationId;
  final int surahNumber;
  final int ayahNumber;
  final String text;
  final String? footnotes;

  static TranslatedAyah? fromJson(
    Object? value, {
    required String translationId,
  }) {
    if (value is! Map<String, dynamic>) return null;
    final surah = value['surahNumber'];
    final ayah = value['ayahNumber'];
    final text = value['text'];
    if (surah is! int ||
        ayah is! int ||
        text is! String ||
        text.trim().isEmpty ||
        !_validCoordinate(surah, ayah)) {
      return null;
    }
    return TranslatedAyah(
      translationId: translationId,
      surahNumber: surah,
      ayahNumber: ayah,
      text: text,
      footnotes: value['footnotes'] is String
          ? value['footnotes'] as String
          : null,
    );
  }
}

class TafsirSource {
  const TafsirSource({
    required this.id,
    required this.title,
    required this.author,
    required this.languageCode,
    required this.source,
    required this.license,
    required this.version,
  });

  final String id;
  final String title;
  final String author;
  final String languageCode;
  final String source;
  final String license;
  final String version;
}

class TafsirEntry {
  const TafsirEntry({
    required this.sourceId,
    required this.startSurahNumber,
    required this.startAyahNumber,
    required this.endSurahNumber,
    required this.endAyahNumber,
    required this.text,
    this.footnotes,
  });

  final String sourceId;
  final int startSurahNumber;
  final int startAyahNumber;
  final int endSurahNumber;
  final int endAyahNumber;
  final String text;
  final String? footnotes;

  bool covers(int surahNumber, int ayahNumber) {
    final coordinate = surahNumber * 1000 + ayahNumber;
    final start = startSurahNumber * 1000 + startAyahNumber;
    final end = endSurahNumber * 1000 + endAyahNumber;
    return coordinate >= start && coordinate <= end;
  }
}

class WordMeaningSource {
  const WordMeaningSource({
    required this.id,
    required this.title,
    required this.publisher,
    required this.source,
    required this.license,
    required this.version,
  });

  final String id;
  final String title;
  final String publisher;
  final String source;
  final String license;
  final String version;
}

class WordMeaningEntry {
  const WordMeaningEntry({
    required this.sourceId,
    required this.surahNumber,
    required this.ayahNumber,
    required this.text,
  });

  final String sourceId;
  final int surahNumber;
  final int ayahNumber;
  final String text;
}

class QuranResourceManifest {
  const QuranResourceManifest({
    required this.id,
    required this.type,
    required this.language,
    required this.version,
    required this.size,
    required this.checksum,
    required this.source,
    required this.license,
    required this.installed,
    this.title = '',
    this.publisher = '',
    this.provider = '',
    this.asset = '',
    this.lastUpdate = '',
    this.retrievedAt = '',
    this.recordCount = 0,
    this.nonEmptyRecordCount = 0,
  });

  final String id;
  final QuranResourceType type;
  final String language;
  final String version;
  final int size;
  final String checksum;
  final String source;
  final String license;
  final bool installed;
  final String title;
  final String publisher;
  final String provider;
  final String asset;
  final String lastUpdate;
  final String retrievedAt;
  final int recordCount;
  final int nonEmptyRecordCount;

  static QuranResourceManifest? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final typeName = value['type'];
    final checksum = value['checksum'] ?? value['sha256'];
    final installed = value['installed'] ?? true;
    final type = QuranResourceType.values
        .where((candidate) => candidate.name == typeName)
        .firstOrNull;
    if (type == null ||
        value['id'] is! String ||
        value['language'] is! String ||
        value['version'] is! String ||
        value['size'] is! int ||
        checksum is! String ||
        value['source'] is! String ||
        value['license'] is! String ||
        installed is! bool) {
      return null;
    }
    return QuranResourceManifest(
      id: value['id'] as String,
      type: type,
      language: value['language'] as String,
      version: value['version'] as String,
      size: value['size'] as int,
      checksum: checksum,
      source: value['source'] as String,
      license: value['license'] as String,
      installed: installed,
      title: value['title'] is String ? value['title'] as String : '',
      publisher: value['publisher'] is String
          ? value['publisher'] as String
          : '',
      provider: value['provider'] is String ? value['provider'] as String : '',
      asset: value['asset'] is String ? value['asset'] as String : '',
      lastUpdate: value['lastUpdate'] is String
          ? value['lastUpdate'] as String
          : '',
      retrievedAt: value['retrievedAt'] is String
          ? value['retrievedAt'] as String
          : '',
      recordCount: value['recordCount'] is int
          ? value['recordCount'] as int
          : 0,
      nonEmptyRecordCount: value['nonEmptyRecordCount'] is int
          ? value['nonEmptyRecordCount'] as int
          : 0,
    );
  }
}

abstract final class BundledQuranResources {
  static const arabicQuran = QuranResourceManifest(
    id: 'quran-uthmani-canonical',
    type: QuranResourceType.arabicQuran,
    language: 'ar',
    version: 'protected-2026-08-13',
    size: 1359946,
    checksum:
        '829083F684ECB5C71853029CA1970946A12C2DC90528D6E0E3CD6DBC41204B7C',
    source: 'Tanzil Quran Text (Uthmani 1.1) — https://tanzil.net',
    license: 'Creative Commons Attribution 3.0; verbatim distribution only',
    installed: true,
  );

  static const installed = [arabicQuran];
}

bool _validCoordinate(int surahNumber, int ayahNumber) {
  if (surahNumber < 1 || surahNumber > QuranMetadata.surahCount) return false;
  return ayahNumber >= 1 &&
      ayahNumber <= QuranMetadata.surah(surahNumber).ayahCount;
}
