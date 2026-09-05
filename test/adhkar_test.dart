import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/data/repositories/adhkar_repository.dart';
import 'package:quran_app/data/repositories/religious_content_repository.dart';
import 'package:quran_app/features/adhkar/adhkar_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ReligiousContentRepository content() => ReligiousContentRepository();

  test(
    'verified bundled dataset parses offline and orders categories',
    () async {
      final data = await AdhkarRepository(
        contentRepository: content(),
        store: _Store(),
      ).loadData();
      expect(data.categories.length, 9);
      expect(data.categories.take(2).map((item) => item.id), [
        'morning',
        'evening',
      ]);
      expect(data.items.length, 29);
      expect(data.items.every((item) => item.reference.isNotEmpty), isTrue);
      expect(data.items.every((item) => item.provenanceId.isNotEmpty), isTrue);
      expect(data.manifest?.version, '2.0.0');
    },
  );

  test('invalid signed dataset recovers as empty without raw errors', () async {
    final data = await AdhkarRepository(
      contentRepository: ReligiousContentRepository(bundle: _BrokenBundle()),
      store: _Store(),
    ).loadData();
    expect(data.categories, isEmpty);
    expect(data.items, isEmpty);
    expect(data.manifest, isNull);
  });

  test('session counts to target, navigates, persists and resumes', () async {
    final store = _Store();
    final repository = AdhkarRepository(
      contentRepository: content(),
      store: store,
    );
    final controller = AdhkarController(
      repository: repository,
      clock: () => DateTime(2026, 8, 13, 9),
    );
    await controller.load();
    expect(controller.recommendedCategory!.id, 'morning');
    await controller.startSession('morning');
    await controller.increment();
    await controller.increment();
    expect(
      controller.currentSession!.progress[controller
          .itemsFor('morning')
          .first
          .id],
      1,
    );
    await controller.next();
    expect(controller.currentSession!.currentItemIndex, 1);

    final resumed = AdhkarController(
      repository: AdhkarRepository(contentRepository: content(), store: store),
    );
    await resumed.load();
    expect(resumed.currentSession!.currentItemIndex, 1);
  });

  test(
    'search ignores Arabic marks and can begin at a matching item',
    () async {
      final controller = AdhkarController(
        repository: AdhkarRepository(
          contentRepository: content(),
          store: _Store(),
        ),
      );
      await controller.load();
      final results = controller.search('الحمد لله');
      expect(results, isNotEmpty);
      final match = results.first;
      await controller.startSession(match.categoryId, initialItemId: match.id);
      expect(controller.currentItem?.id, match.id);
    },
  );

  test('evening recommendation and reset have no audio state', () async {
    final controller = AdhkarController(
      repository: AdhkarRepository(
        contentRepository: content(),
        store: _Store(),
      ),
      clock: () => DateTime(2026, 8, 13, 20),
    );
    await controller.load();
    expect(controller.recommendedCategory!.id, 'evening');
    await controller.startSession('evening');
    await controller.resetSession();
    expect(controller.currentSession, isNull);
  });
}

class _BrokenBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData(0);

  @override
  Future<String> loadString(String key, {bool cache = true}) async => '{bad';
}

class _Store implements AdhkarSessionStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? value) async => this.value = value;
}
