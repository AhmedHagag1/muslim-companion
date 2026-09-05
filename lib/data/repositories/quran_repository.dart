import 'package:flutter/services.dart';

import '../models/quran_verse.dart';
import '../models/surah.dart';

class QuranRepository {
  static const String _quranAsset = 'assets/quran/quran-uthmani.txt';

  Future<List<QuranVerse>> loadQuran() async {
    final content = await rootBundle.loadString(_quranAsset);

    final lines = content
        .replaceFirst('\uFEFF', '')
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final result = <QuranVerse>[];

    int lineIndex = 0;

    for (final surah in QuranMetadata.surahs) {
      final verseCount = surah.ayahCount;

      for (int ayah = 1; ayah <= verseCount; ayah++) {
        if (lineIndex >= lines.length) {
          throw Exception(
            'انتهى ملف القرآن قبل اكتمال البيانات '
            'عند السورة ${surah.number} الآية $ayah',
          );
        }

        String text = lines[lineIndex];

        // ملف القرآن عندك يضع البسملة في بداية
        // أول آية من معظم السور.
        //
        // نحذفها من نص الآية حتى نعرضها
        // كعنصر مستقل في واجهة القراءة.
        if (ayah == 1 && surah.basmalaPolicy == BasmalaPolicy.separate) {
          text = _removeBasmala(text);
        }

        result.add(
          QuranVerse(surahNumber: surah.number, ayahNumber: ayah, text: text),
        );

        lineIndex++;
      }
    }

    return result;
  }

  String _removeBasmala(String text) {
    if (text.startsWith(QuranMetadata.basmala)) {
      return text.substring(QuranMetadata.basmala.length).trim();
    }

    return text;
  }
}
