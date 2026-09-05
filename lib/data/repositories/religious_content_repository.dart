import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../models/adhkar.dart';
import '../models/religious_content.dart';

class ReligiousContentException implements Exception {
  const ReligiousContentException(this.reason);
  final String reason;
}

class ReligiousContentCandidate {
  const ReligiousContentCandidate({
    required this.manifestJson,
    required this.payloadJson,
  });

  final String manifestJson;
  final String payloadJson;
}

class ReligiousContentCodec {
  const ReligiousContentCodec();
  static const supportedSchema = 1;

  ReligiousContentPack decode(ReligiousContentCandidate candidate) {
    final manifestValue = jsonDecode(candidate.manifestJson);
    final payloadValue = jsonDecode(candidate.payloadJson);
    final manifest = ReligiousContentManifest.fromJson(manifestValue);
    if (manifest == null) {
      throw const ReligiousContentException('invalid_manifest');
    }
    if (manifest.schemaVersion != supportedSchema ||
        manifest.minimumAppSchema > supportedSchema) {
      throw const ReligiousContentException('schema_mismatch');
    }
    final actualChecksum = sha256
        .convert(utf8.encode(candidate.payloadJson))
        .toString();
    if (actualChecksum.toLowerCase() != manifest.checksum.toLowerCase()) {
      throw const ReligiousContentException('checksum_mismatch');
    }
    if (payloadValue is! Map<String, dynamic>) {
      throw const ReligiousContentException('invalid_payload');
    }

    final provenances = _parseList(
      payloadValue['provenances'],
      ContentProvenance.fromJson,
    );
    final adhkarCategories = _parseList(
      payloadValue['adhkarCategories'],
      DhikrCategory.fromJson,
    )..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final adhkarItems = _parseList(
      payloadValue['adhkarItems'],
      DhikrItem.fromJson,
    );
    final duaCategories = _parseList(
      payloadValue['duaCategories'],
      DuaCategory.fromJson,
    )..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final duaItems = _parseList(payloadValue['duaItems'], DuaItem.fromJson);
    final tasbeehPhrases = _parseList(
      payloadValue['tasbeehPhrases'],
      TasbeehPhrase.fromJson,
    );

    final allIds = <String>[
      ...provenances.map((item) => item.id),
      ...adhkarCategories.map((item) => item.id),
      ...adhkarItems.map((item) => item.id),
      ...duaCategories.map((item) => item.id),
      ...duaItems.map((item) => item.id),
      ...tasbeehPhrases.map((item) => item.id),
    ];
    if (allIds.toSet().length != allIds.length) {
      throw const ReligiousContentException('duplicate_id');
    }
    if (provenances.isEmpty ||
        adhkarCategories.isEmpty ||
        adhkarItems.isEmpty ||
        duaCategories.isEmpty ||
        duaItems.isEmpty ||
        tasbeehPhrases.isEmpty) {
      throw const ReligiousContentException('empty_content');
    }
    final provenanceIds = provenances.map((item) => item.id).toSet();
    final adhkarCategoryIds = adhkarCategories.map((item) => item.id).toSet();
    final duaCategoryIds = duaCategories.map((item) => item.id).toSet();
    final invalidReference =
        adhkarItems.any(
          (item) =>
              !adhkarCategoryIds.contains(item.categoryId) ||
              !provenanceIds.contains(item.provenanceId),
        ) ||
        duaItems.any(
          (item) =>
              !duaCategoryIds.contains(item.categoryId) ||
              !provenanceIds.contains(item.provenanceId),
        ) ||
        tasbeehPhrases.any(
          (item) => !provenanceIds.contains(item.provenanceId),
        );
    if (invalidReference) {
      throw const ReligiousContentException('invalid_reference');
    }
    final actualItemCount =
        adhkarItems.length + duaItems.length + tasbeehPhrases.length;
    if (actualItemCount != manifest.itemCount) {
      throw const ReligiousContentException('item_count_mismatch');
    }
    return ReligiousContentPack(
      manifest: manifest,
      provenances: List.unmodifiable(provenances),
      adhkarCategories: List.unmodifiable(adhkarCategories),
      adhkarItems: List.unmodifiable(adhkarItems),
      duaCategories: List.unmodifiable(duaCategories),
      duaItems: List.unmodifiable(duaItems),
      tasbeehPhrases: List.unmodifiable(tasbeehPhrases),
    );
  }

  List<T> _parseList<T>(Object? value, T? Function(Object?) parser) {
    if (value is! List) {
      throw const ReligiousContentException('invalid_payload');
    }
    final parsed = value.map(parser).whereType<T>().toList();
    if (parsed.length != value.length) {
      throw const ReligiousContentException('invalid_item');
    }
    return parsed;
  }
}

class ReligiousContentRepository {
  ReligiousContentRepository({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  static const manifestAsset =
      'assets/religious_content/daily_worship_ar_manifest.json';
  static const payloadAsset =
      'assets/religious_content/daily_worship_ar_payload.json';

  final AssetBundle _bundle;
  final ReligiousContentCodec _codec = const ReligiousContentCodec();
  ReligiousContentPack? _cached;
  Future<ReligiousContentPack>? _loading;

  Future<ReligiousContentPack> load() {
    final cached = _cached;
    if (cached != null) return Future.value(cached);
    return _loading ??= _loadOnce();
  }

  Future<ReligiousContentPack> _loadOnce() async {
    try {
      final pack = _codec.decode(
        ReligiousContentCandidate(
          manifestJson: await _bundle.loadString(manifestAsset),
          payloadJson: await _bundle.loadString(payloadAsset),
        ),
      );
      return _cached = pack;
    } finally {
      _loading = null;
    }
  }
}

abstract interface class ReligiousContentUpdateSource {
  Future<ReligiousContentManifest?> checkManifest();
  Future<ReligiousContentCandidate> downloadCandidate(
    ReligiousContentManifest manifest,
  );
}

abstract interface class ReligiousContentActivationStore {
  Future<void> stage(ReligiousContentCandidate candidate);
  Future<ReligiousContentCandidate?> readStaged();
  Future<void> activateStaged();
  Future<void> rollback();
}

class ReligiousContentPackManager {
  const ReligiousContentPackManager({
    required this.source,
    required this.store,
    this.codec = const ReligiousContentCodec(),
  });

  final ReligiousContentUpdateSource source;
  final ReligiousContentActivationStore store;
  final ReligiousContentCodec codec;

  Future<ReligiousContentManifest?> checkForUpdate() => source.checkManifest();

  Future<ReligiousContentPack> stageAndActivate(
    ReligiousContentManifest manifest,
  ) async {
    try {
      final candidate = await source.downloadCandidate(manifest);
      final downloaded = codec.decode(candidate);
      if (!_matchesExpectedManifest(downloaded.manifest, manifest)) {
        throw const ReligiousContentException('manifest_mismatch');
      }
      await store.stage(candidate);
      final staged = await store.readStaged();
      if (staged == null) {
        throw const ReligiousContentException('stage_missing');
      }
      final validated = codec.decode(staged);
      await store.activateStaged();
      return validated;
    } catch (_) {
      await store.rollback();
      rethrow;
    }
  }

  bool _matchesExpectedManifest(
    ReligiousContentManifest actual,
    ReligiousContentManifest expected,
  ) =>
      actual.id == expected.id &&
      actual.version == expected.version &&
      actual.schemaVersion == expected.schemaVersion &&
      actual.locale == expected.locale &&
      actual.contentType == expected.contentType &&
      actual.itemCount == expected.itemCount &&
      actual.checksum.toLowerCase() == expected.checksum.toLowerCase();
}
