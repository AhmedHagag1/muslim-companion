import 'adhkar.dart';

class ReligiousContentManifest {
  const ReligiousContentManifest({
    required this.id,
    required this.version,
    required this.schemaVersion,
    required this.locale,
    required this.contentType,
    required this.itemCount,
    required this.sourceName,
    required this.sourceEdition,
    required this.license,
    required this.checksum,
    required this.publishedAt,
    required this.minimumAppSchema,
  });

  final String id;
  final String version;
  final int schemaVersion;
  final String locale;
  final String contentType;
  final int itemCount;
  final String sourceName;
  final String sourceEdition;
  final String license;
  final String checksum;
  final DateTime publishedAt;
  final int minimumAppSchema;

  static ReligiousContentManifest? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final publishedAt = DateTime.tryParse('${value['publishedAt']}');
    final manifest = ReligiousContentManifest(
      id: value['id'] is String ? value['id'] as String : '',
      version: value['version'] is String ? value['version'] as String : '',
      schemaVersion: value['schemaVersion'] is int
          ? value['schemaVersion'] as int
          : 0,
      locale: value['locale'] is String ? value['locale'] as String : '',
      contentType: value['contentType'] is String
          ? value['contentType'] as String
          : '',
      itemCount: value['itemCount'] is int ? value['itemCount'] as int : -1,
      sourceName: value['sourceName'] is String
          ? value['sourceName'] as String
          : '',
      sourceEdition: value['sourceEdition'] is String
          ? value['sourceEdition'] as String
          : '',
      license: value['license'] is String ? value['license'] as String : '',
      checksum: value['checksum'] is String ? value['checksum'] as String : '',
      publishedAt: publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      minimumAppSchema: value['minimumAppSchema'] is int
          ? value['minimumAppSchema'] as int
          : 0,
    );
    if (publishedAt == null ||
        manifest.id.trim().isEmpty ||
        manifest.version.trim().isEmpty ||
        manifest.schemaVersion < 1 ||
        manifest.locale.trim().isEmpty ||
        manifest.contentType.trim().isEmpty ||
        manifest.itemCount < 1 ||
        manifest.sourceName.trim().isEmpty ||
        manifest.sourceEdition.trim().isEmpty ||
        manifest.license.trim().isEmpty ||
        !RegExp(r'^[A-Fa-f0-9]{64}$').hasMatch(manifest.checksum) ||
        manifest.minimumAppSchema < 1) {
      return null;
    }
    return manifest;
  }
}

class ContentProvenance {
  const ContentProvenance({
    required this.id,
    required this.sourceName,
    required this.sourceEdition,
    required this.sourceUrl,
    required this.licenseConclusion,
  });

  final String id;
  final String sourceName;
  final String sourceEdition;
  final String sourceUrl;
  final String licenseConclusion;

  static ContentProvenance? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final fields = [
      value['id'],
      value['sourceName'],
      value['sourceEdition'],
      value['sourceUrl'],
      value['licenseConclusion'],
    ];
    if (fields.any((field) => field is! String || field.trim().isEmpty)) {
      return null;
    }
    return ContentProvenance(
      id: value['id'],
      sourceName: value['sourceName'],
      sourceEdition: value['sourceEdition'],
      sourceUrl: value['sourceUrl'],
      licenseConclusion: value['licenseConclusion'],
    );
  }
}

class DuaCategory {
  const DuaCategory({
    required this.id,
    required this.title,
    required this.sortOrder,
  });

  final String id;
  final String title;
  final int sortOrder;

  static DuaCategory? fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['title'] is! String ||
        value['sortOrder'] is! int ||
        (value['id'] as String).trim().isEmpty ||
        (value['title'] as String).trim().isEmpty) {
      return null;
    }
    return DuaCategory(
      id: value['id'],
      title: value['title'],
      sortOrder: value['sortOrder'],
    );
  }
}

class DuaItem {
  const DuaItem({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.arabicText,
    required this.sourceText,
    required this.reference,
    required this.provenanceId,
    this.repeatCount,
  });

  final String id;
  final String categoryId;
  final String title;
  final String arabicText;
  final String sourceText;
  final String reference;
  final String provenanceId;
  final int? repeatCount;

  static DuaItem? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final repeat = value['repeatCount'];
    final requiredStrings = [
      value['id'],
      value['categoryId'],
      value['title'],
      value['arabicText'],
      value['sourceText'],
      value['reference'],
      value['provenanceId'],
    ];
    if (requiredStrings.any(
          (field) => field is! String || field.trim().isEmpty,
        ) ||
        (repeat != null && (repeat is! int || repeat < 1))) {
      return null;
    }
    return DuaItem(
      id: value['id'],
      categoryId: value['categoryId'],
      title: value['title'],
      arabicText: value['arabicText'],
      sourceText: value['sourceText'],
      reference: value['reference'],
      provenanceId: value['provenanceId'],
      repeatCount: repeat as int?,
    );
  }
}

class TasbeehPhrase {
  const TasbeehPhrase({
    required this.id,
    required this.arabicText,
    required this.sourceText,
    required this.reference,
    required this.provenanceId,
    this.suggestedTarget,
  });

  final String id;
  final String arabicText;
  final String sourceText;
  final String reference;
  final String provenanceId;
  final int? suggestedTarget;

  static TasbeehPhrase? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final target = value['suggestedTarget'];
    final requiredStrings = [
      value['id'],
      value['arabicText'],
      value['sourceText'],
      value['reference'],
      value['provenanceId'],
    ];
    if (requiredStrings.any(
          (field) => field is! String || field.trim().isEmpty,
        ) ||
        (target != null && (target is! int || target < 1))) {
      return null;
    }
    return TasbeehPhrase(
      id: value['id'],
      arabicText: value['arabicText'],
      sourceText: value['sourceText'],
      reference: value['reference'],
      provenanceId: value['provenanceId'],
      suggestedTarget: target as int?,
    );
  }
}

class ReligiousContentPack {
  const ReligiousContentPack({
    required this.manifest,
    required this.provenances,
    required this.adhkarCategories,
    required this.adhkarItems,
    required this.duaCategories,
    required this.duaItems,
    required this.tasbeehPhrases,
  });

  final ReligiousContentManifest manifest;
  final List<ContentProvenance> provenances;
  final List<DhikrCategory> adhkarCategories;
  final List<DhikrItem> adhkarItems;
  final List<DuaCategory> duaCategories;
  final List<DuaItem> duaItems;
  final List<TasbeehPhrase> tasbeehPhrases;

  ContentProvenance? provenanceFor(String id) =>
      provenances.where((item) => item.id == id).firstOrNull;
}
