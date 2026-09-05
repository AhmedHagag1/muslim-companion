import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/data/models/religious_content.dart';
import 'package:quran_app/data/repositories/dua_repository.dart';
import 'package:quran_app/data/repositories/religious_content_repository.dart';
import 'package:quran_app/data/repositories/tasbeeh_repository.dart';
import 'package:quran_app/features/duas/dua_controller.dart';
import 'package:quran_app/features/tasbeeh/tasbeeh_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String manifestJson;
  late String payloadJson;

  setUpAll(() async {
    manifestJson = await rootBundle.loadString(
      ReligiousContentRepository.manifestAsset,
    );
    payloadJson = await rootBundle.loadString(
      ReligiousContentRepository.payloadAsset,
    );
  });

  group('verified religious content pack', () {
    test('loads all declared offline content with provenance', () async {
      final pack = await ReligiousContentRepository().load();
      expect(pack.manifest.itemCount, 51);
      expect(pack.adhkarItems, hasLength(29));
      expect(pack.duaItems, hasLength(17));
      expect(pack.tasbeehPhrases, hasLength(5));
      expect(pack.provenances, hasLength(1));
      expect(pack.adhkarItems.map((item) => item.provenanceId).toSet(), {
        'hisn-muslim-ar-approved-1421',
      });
      expect(pack.duaItems.map((item) => item.provenanceId).toSet(), {
        'hisn-muslim-ar-approved-1421',
      });
      expect(pack.tasbeehPhrases.map((item) => item.provenanceId).toSet(), {
        'hisn-muslim-ar-approved-1421',
      });
    });

    test('rejects payload tampering by checksum', () {
      expect(
        () => const ReligiousContentCodec().decode(
          ReligiousContentCandidate(
            manifestJson: manifestJson,
            payloadJson: payloadJson.replaceFirst('سُبْحَانَ', 'سبحان'),
          ),
        ),
        throwsA(isA<ReligiousContentException>()),
      );
    });

    test('rejects unsupported schema before activation', () {
      expect(
        () => const ReligiousContentCodec().decode(
          ReligiousContentCandidate(
            manifestJson: manifestJson.replaceFirst(
              '"schemaVersion": 1',
              '"schemaVersion": 2',
            ),
            payloadJson: payloadJson,
          ),
        ),
        throwsA(
          isA<ReligiousContentException>().having(
            (error) => error.reason,
            'reason',
            'schema_mismatch',
          ),
        ),
      );
    });

    test('rejects duplicate stable IDs', () {
      final payload = payloadJson.replaceFirst('"hm-dua-123"', '"hm-dua-122"');
      expect(
        () => const ReligiousContentCodec().decode(
          _candidateWithChecksum(manifestJson, payload),
        ),
        throwsA(
          isA<ReligiousContentException>().having(
            (error) => error.reason,
            'reason',
            'duplicate_id',
          ),
        ),
      );
    });

    test('rejects broken category references', () {
      final payload = payloadJson.replaceFirst(
        '"categoryId": "dua-distress"',
        '"categoryId": "missing"',
      );
      expect(
        () => const ReligiousContentCodec().decode(
          _candidateWithChecksum(manifestJson, payload),
        ),
        throwsA(
          isA<ReligiousContentException>().having(
            (error) => error.reason,
            'reason',
            'invalid_reference',
          ),
        ),
      );
    });

    test('rejects invalid repeat counts', () {
      final payload = payloadJson.replaceFirst(
        '"repeatCount": 1',
        '"repeatCount": 0',
      );
      expect(
        () => const ReligiousContentCodec().decode(
          _candidateWithChecksum(manifestJson, payload),
        ),
        throwsA(
          isA<ReligiousContentException>().having(
            (error) => error.reason,
            'reason',
            'invalid_item',
          ),
        ),
      );
    });

    test('stages, revalidates, and activates an update', () async {
      final candidate = ReligiousContentCandidate(
        manifestJson: manifestJson,
        payloadJson: payloadJson,
      );
      final source = _UpdateSource(candidate);
      final store = _ActivationStore();
      final manager = ReligiousContentPackManager(source: source, store: store);
      final manifest = ReligiousContentManifest.fromJson(
        jsonDecode(manifestJson),
      )!;
      final result = await manager.stageAndActivate(manifest);
      expect(result.manifest.version, '2.0.0');
      expect(store.activated, isTrue);
      expect(store.rolledBack, isFalse);
    });

    test('rolls back a corrupt update and never activates it', () async {
      final candidate = ReligiousContentCandidate(
        manifestJson: manifestJson,
        payloadJson: '$payloadJson ',
      );
      final store = _ActivationStore();
      final manager = ReligiousContentPackManager(
        source: _UpdateSource(candidate),
        store: store,
      );
      final manifest = ReligiousContentManifest.fromJson(
        jsonDecode(manifestJson),
      )!;
      await expectLater(
        manager.stageAndActivate(manifest),
        throwsA(isA<ReligiousContentException>()),
      );
      expect(store.activated, isFalse);
      expect(store.rolledBack, isTrue);
    });

    test('candidate must match the manifest that was checked', () async {
      final candidate = ReligiousContentCandidate(
        manifestJson: manifestJson,
        payloadJson: payloadJson,
      );
      final expected = ReligiousContentManifest.fromJson(
        jsonDecode(
          manifestJson.replaceFirst('"version": "2.0.0"', '"version": "2.0.1"'),
        ),
      )!;
      final store = _ActivationStore();
      final manager = ReligiousContentPackManager(
        source: _UpdateSource(candidate),
        store: store,
      );
      await expectLater(
        manager.stageAndActivate(expected),
        throwsA(
          isA<ReligiousContentException>().having(
            (error) => error.reason,
            'reason',
            'manifest_mismatch',
          ),
        ),
      );
      expect(store.activated, isFalse);
      expect(store.rolledBack, isTrue);
    });
  });

  group('duas', () {
    test('searches Arabic text and categories', () async {
      final controller = DuaController(
        repository: DuaRepository(store: _DuaStore()),
      );
      await controller.load();
      expect(
        controller.search('رحمتك ارجو').map((item) => item.id),
        contains('hm-dua-123'),
      );
      expect(controller.search('', categoryId: 'dua-rain'), hasLength(3));
    });

    test('favorites persist and unknown IDs are discarded', () async {
      final store = _DuaStore();
      final controller = DuaController(repository: DuaRepository(store: store));
      await controller.load();
      await controller.toggleFavorite('hm-dua-172');
      expect(controller.isFavorite('hm-dua-172'), isTrue);
      final resumed = DuaController(repository: DuaRepository(store: store));
      await resumed.load();
      expect(resumed.isFavorite('hm-dua-172'), isTrue);
      await resumed.toggleFavorite('not-content');
      expect(resumed.favoriteIds, {'hm-dua-172'});
    });
  });

  group('tasbeeh', () {
    test('increment, decrement, and target persist', () async {
      final store = _TasbeehStore();
      final controller = TasbeehController(
        repository: TasbeehRepository(store: store),
        clock: () => DateTime.utc(2026, 8, 14, 10),
      );
      await controller.load();
      expect(controller.state?.target, 33);
      await controller.increment();
      await controller.increment();
      await controller.decrement();
      await controller.setTarget(100);
      expect(controller.state?.count, 1);
      expect(controller.state?.target, 100);

      final resumed = TasbeehController(
        repository: TasbeehRepository(store: store),
      );
      await resumed.load();
      expect(resumed.state?.count, 1);
      expect(resumed.state?.target, 100);
    });

    test('reset records a modest history and never goes below zero', () async {
      final controller = TasbeehController(
        repository: TasbeehRepository(store: _TasbeehStore()),
        clock: () => DateTime.utc(2026, 8, 14, 11),
      );
      await controller.load();
      await controller.decrement();
      expect(controller.state?.count, 0);
      await controller.increment();
      await controller.reset();
      expect(controller.state?.count, 0);
      expect(controller.state?.history.single.count, 1);
    });

    test('changing phrase archives a non-zero counter', () async {
      final controller = TasbeehController(
        repository: TasbeehRepository(store: _TasbeehStore()),
      );
      await controller.load();
      await controller.increment();
      await controller.selectPhrase('tasbeeh-hawqala');
      expect(controller.selectedPhrase?.id, 'tasbeeh-hawqala');
      expect(controller.state?.count, 0);
      expect(controller.state?.target, isNull);
      expect(controller.state?.history, hasLength(1));
    });
  });
}

ReligiousContentCandidate _candidateWithChecksum(
  String manifest,
  String payload,
) {
  final checksum = sha256.convert(utf8.encode(payload)).toString();
  final updated = manifest.replaceFirst(
    RegExp(r'"checksum":\s*"[A-Fa-f0-9]{64}"'),
    '"checksum": "$checksum"',
  );
  return ReligiousContentCandidate(manifestJson: updated, payloadJson: payload);
}

class _DuaStore implements DuaFavoritesStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

class _TasbeehStore implements TasbeehStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

class _UpdateSource implements ReligiousContentUpdateSource {
  _UpdateSource(this.candidate);
  final ReligiousContentCandidate candidate;
  @override
  Future<ReligiousContentManifest?> checkManifest() async =>
      ReligiousContentManifest.fromJson(jsonDecode(candidate.manifestJson));
  @override
  Future<ReligiousContentCandidate> downloadCandidate(
    ReligiousContentManifest manifest,
  ) async => candidate;
}

class _ActivationStore implements ReligiousContentActivationStore {
  ReligiousContentCandidate? staged;
  bool activated = false;
  bool rolledBack = false;
  @override
  Future<void> stage(ReligiousContentCandidate candidate) async =>
      staged = candidate;
  @override
  Future<ReligiousContentCandidate?> readStaged() async => staged;
  @override
  Future<void> activateStaged() async => activated = true;
  @override
  Future<void> rollback() async {
    rolledBack = true;
    staged = null;
  }
}
