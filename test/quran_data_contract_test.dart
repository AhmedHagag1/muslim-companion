import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/data/models/surah.dart';
import 'package:quran_app/data/repositories/quran_repository.dart';
import 'package:quran_app/features/quran/quran_controller.dart';
import 'package:quran_app/features/quran/quran_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Canonical Quran metadata', () {
    test('contains exactly surahs 1 through 114', () {
      expect(QuranMetadata.surahs, hasLength(114));
      expect(
        QuranMetadata.surahs.map((surah) => surah.number),
        orderedEquals(List<int>.generate(114, (index) => index + 1)),
      );
    });

    test('ayah counts total 6236', () {
      final total = QuranMetadata.surahs.fold<int>(
        0,
        (sum, surah) => sum + surah.ayahCount,
      );

      expect(total, 6236);
    });

    test('QuranPage consumes the canonical metadata unchanged', () {
      expect(identical(QuranPage.surahs, QuranMetadata.surahs), isTrue);
      expect(QuranPage.surahs, orderedEquals(QuranMetadata.surahs));
    });

    test('preserves the established basmala policies', () {
      expect(
        QuranMetadata.surah(1).basmalaPolicy,
        BasmalaPolicy.partOfFirstAyah,
      );
      expect(QuranMetadata.surah(9).basmalaPolicy, BasmalaPolicy.none);
      for (var number = 2; number <= 114; number++) {
        if (number == 9) continue;
        expect(
          QuranMetadata.surah(number).basmalaPolicy,
          BasmalaPolicy.separate,
          reason: 'Surah $number should retain a separate basmala',
        );
      }
    });
  });

  group('Quran data contract', () {
    late QuranController controller;

    setUp(() async {
      controller = QuranController(repository: QuranRepository());
      await controller.load();
    });

    tearDown(() {
      controller.dispose();
    });

    test('loads exactly 114 surahs and 6236 ayahs', () {
      expect(controller.error, isNull);
      expect(controller.surahCount, 114);
      expect(controller.verseCount, 6236);
    });

    test('every surah exists with sequential ayah numbers', () {
      for (var surahNumber = 1; surahNumber <= 114; surahNumber++) {
        final verses = controller.getSurah(surahNumber);

        expect(verses, isNotEmpty, reason: 'Surah $surahNumber must exist');

        expect(
          verses.map((verse) => verse.ayahNumber),
          orderedEquals(
            List<int>.generate(verses.length, (index) => index + 1),
          ),
          reason: 'Surah $surahNumber ayahs must be sequential',
        );
      }
    });

    test('key surah ayah counts match the established dataset', () {
      expect(controller.getSurah(1), hasLength(7));
      expect(controller.getSurah(2), hasLength(286));
      expect(controller.getSurah(9), hasLength(129));
    });

    test('preserves the existing separate-basmala policy', () {
      expect(controller.hasBasmala(9), isFalse);

      for (var surahNumber = 1; surahNumber <= 114; surahNumber++) {
        if (surahNumber == 9) continue;

        expect(
          controller.hasBasmala(surahNumber),
          isTrue,
          reason: 'Surah $surahNumber should use the existing separate basmala',
        );
      }

      expect(controller.getBasmala(), isNotEmpty);
    });
  });
}
