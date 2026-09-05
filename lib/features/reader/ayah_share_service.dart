import 'package:share_plus/share_plus.dart';

import '../../data/models/quran_verse.dart';
import '../../data/models/surah.dart';

class AyahShareService {
  const AyahShareService();

  String canonicalText(QuranVerse verse) =>
      '${verse.text}\n\nسورة ${QuranMetadata.surah(verse.surahNumber).name} — الآية ${verse.ayahNumber}\nالقرآن الكريم';

  Future<void> share(QuranVerse verse) => SharePlus.instance.share(
    ShareParams(
      title: 'مشاركة آية',
      subject:
          'سورة ${QuranMetadata.surah(verse.surahNumber).name} — ${verse.ayahNumber}',
      text: canonicalText(verse),
    ),
  );
}
