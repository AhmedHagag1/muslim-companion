import 'package:flutter/foundation.dart';

import '../../data/models/quran_verse.dart';
import '../../data/models/surah.dart';
import '../../data/repositories/quran_repository.dart';

class QuranController extends ChangeNotifier {
  QuranController({QuranRepository? repository})
    : _repository = repository ?? QuranRepository();

  final QuranRepository _repository;

  static const int expectedSurahCount = QuranMetadata.surahCount;
  static const int expectedVerseCount = 6236;

  static const String basmala = QuranMetadata.basmala;

  List<QuranVerse> _verses = [];

  bool _isLoading = false;
  String? _error;

  List<QuranVerse> get verses => List.unmodifiable(_verses);

  bool get isLoading => _isLoading;

  String? get error => _error;

  int get verseCount => _verses.length;

  int get surahCount {
    return _verses.map((verse) => verse.surahNumber).toSet().length;
  }

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final loadedVerses = await _repository.loadQuran();

      _validate(loadedVerses);

      _verses = loadedVerses;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<QuranVerse> getSurah(int surahNumber) {
    return _verses
        .where((verse) => verse.surahNumber == surahNumber)
        .toList(growable: false);
  }

  QuranVerse? getVerse(int surahNumber, int ayahNumber) {
    for (final verse in _verses) {
      if (verse.surahNumber == surahNumber && verse.ayahNumber == ayahNumber) {
        return verse;
      }
    }

    return null;
  }

  /// البسملة مستقلة عن نص الآيات.
  ///
  /// سورة التوبة هي السورة الوحيدة التي لا تبدأ بالبسملة.
  bool hasBasmala(int surahNumber) {
    return QuranMetadata.surah(surahNumber).basmalaPolicy != BasmalaPolicy.none;
  }

  String getBasmala() {
    return basmala;
  }

  void _validate(List<QuranVerse> verses) {
    if (verses.length != expectedVerseCount) {
      throw Exception(
        'عدد الآيات غير صحيح: '
        '${verses.length} بدل $expectedVerseCount',
      );
    }

    final surahNumbers = verses.map((verse) => verse.surahNumber).toSet();

    if (surahNumbers.length != expectedSurahCount) {
      throw Exception(
        'عدد السور غير صحيح: '
        '${surahNumbers.length} بدل $expectedSurahCount',
      );
    }

    for (int surah = 1; surah <= expectedSurahCount; surah++) {
      final surahVerses = getSurahFromList(verses, surah);

      if (surahVerses.isEmpty) {
        throw Exception('السورة رقم $surah غير موجودة.');
      }

      for (int index = 0; index < surahVerses.length; index++) {
        final expectedAyah = index + 1;
        final actualAyah = surahVerses[index].ayahNumber;

        if (actualAyah != expectedAyah) {
          throw Exception(
            'خطأ في ترقيم سورة $surah: '
            'المتوقع $expectedAyah، '
            'الموجود $actualAyah.',
          );
        }
      }
    }
  }

  List<QuranVerse> getSurahFromList(List<QuranVerse> verses, int surahNumber) {
    return verses
        .where((verse) => verse.surahNumber == surahNumber)
        .toList(growable: false);
  }
}
