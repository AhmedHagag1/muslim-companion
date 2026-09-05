import '../../data/models/surah.dart';

enum AssistantIntentType {
  openSurah,
  openVerse,
  quranVerse,
  translation,
  prayerTime,
  prayerTimes,
  qibla,
  morningAdhkar,
  sleepAdhkar,
  duas,
  tasbeeh,
  khatma,
  memorization,
  tafsir,
  wordMeaning,
  religiousRuling,
  unsupported,
}

class AssistantCommand {
  const AssistantCommand({
    required this.type,
    required this.query,
    this.surahNumber,
    this.ayahNumber,
    this.prayerName,
  });
  final AssistantIntentType type;
  final String query;
  final int? surahNumber;
  final int? ayahNumber;
  final String? prayerName;
  bool get isSupported => type != AssistantIntentType.unsupported;
  bool get requiresReligiousBoundary =>
      type == AssistantIntentType.religiousRuling;
}

class AssistantCitation {
  const AssistantCitation({
    required this.title,
    required this.detail,
    this.actionType,
    this.surahNumber,
    this.ayahNumber,
  });
  final String title;
  final String detail;
  final AssistantIntentType? actionType;
  final int? surahNumber;
  final int? ayahNumber;
}

class AssistantResponse {
  const AssistantResponse({
    required this.sourceText,
    required this.citations,
    this.summary,
    this.boundary = false,
  });
  final String sourceText;
  final String? summary;
  final List<AssistantCitation> citations;
  final bool boundary;
}

class AssistantIntentService {
  const AssistantIntentService();

  AssistantCommand parse(String input) {
    final normalized = _normalize(input);
    if (normalized.isEmpty) return _unsupported(input);
    if (_isReligiousRuling(normalized)) {
      return AssistantCommand(
        type: AssistantIntentType.religiousRuling,
        query: input,
      );
    }

    final study = RegExp(
      r'^(تفسير|ترجمه|معني)\s*(?:سوره\s*)?(\d{1,3})\s*[:：]\s*(\d{1,3})$',
    ).firstMatch(normalized);
    if (study != null) {
      final coordinate = _coordinate(study.group(2), study.group(3));
      if (coordinate != null) {
        return AssistantCommand(
          type: switch (study.group(1)) {
            'تفسير' => AssistantIntentType.tafsir,
            'ترجمه' => AssistantIntentType.translation,
            _ => AssistantIntentType.wordMeaning,
          },
          query: input,
          surahNumber: coordinate.$1,
          ayahNumber: coordinate.$2,
        );
      }
    }

    if (normalized.contains('ايه الكرسي')) {
      return AssistantCommand(
        type: normalized.startsWith('معني')
            ? AssistantIntentType.wordMeaning
            : normalized.startsWith('تفسير')
            ? AssistantIntentType.tafsir
            : normalized.startsWith('ترجمه')
            ? AssistantIntentType.translation
            : AssistantIntentType.quranVerse,
        query: input,
        surahNumber: 2,
        ayahNumber: 255,
      );
    }

    final coordinateMatch = RegExp(
      r'^(?:(?:افتح|اعرض)\s*)?(?:ايه\s*)?(\d{1,3})\s*[:：]\s*(\d{1,3})$',
    ).firstMatch(normalized);
    if (coordinateMatch != null) {
      final coordinate = _coordinate(
        coordinateMatch.group(1),
        coordinateMatch.group(2),
      );
      if (coordinate != null) {
        return AssistantCommand(
          type: normalized.startsWith('افتح')
              ? AssistantIntentType.openVerse
              : AssistantIntentType.quranVerse,
          query: input,
          surahNumber: coordinate.$1,
          ayahNumber: coordinate.$2,
        );
      }
    }

    if (normalized.startsWith('متي ')) {
      const prayers = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
      for (final prayer in prayers) {
        if (normalized.contains(prayer)) {
          return AssistantCommand(
            type: AssistantIntentType.prayerTime,
            query: input,
            prayerName: prayer,
          );
        }
      }
    }
    if (normalized.contains('مواقيت الصلاه')) {
      return AssistantCommand(
        type: AssistantIntentType.prayerTimes,
        query: input,
      );
    }
    if (normalized.contains('القبله')) {
      return AssistantCommand(type: AssistantIntentType.qibla, query: input);
    }
    if (normalized.contains('اذكار الصباح')) {
      return AssistantCommand(
        type: AssistantIntentType.morningAdhkar,
        query: input,
      );
    }
    if (normalized.contains('اذكار النوم')) {
      return AssistantCommand(
        type: AssistantIntentType.sleepAdhkar,
        query: input,
      );
    }
    if (normalized.contains('دعاء') || normalized.contains('الادعيه')) {
      return AssistantCommand(type: AssistantIntentType.duas, query: input);
    }
    if (normalized.contains('السبحه') || normalized.contains('تسبيح')) {
      return AssistantCommand(type: AssistantIntentType.tasbeeh, query: input);
    }
    if (normalized.contains('ورد اليوم') ||
        normalized.contains('الختمه') ||
        normalized.contains('صفحه على الختمه')) {
      return AssistantCommand(type: AssistantIntentType.khatma, query: input);
    }
    if (normalized.contains('مراجعه الحفظ') ||
        normalized.startsWith('راجع ') ||
        normalized == 'الحفظ') {
      return AssistantCommand(
        type: AssistantIntentType.memorization,
        query: input,
      );
    }

    final surahQuery = normalized
        .replaceFirst(RegExp(r'^(?:افتح\s+)?سوره\s+'), '')
        .trim();
    for (final surah in QuranMetadata.surahs) {
      if (_normalize(surah.name) == surahQuery) {
        return AssistantCommand(
          type: AssistantIntentType.openSurah,
          query: input,
          surahNumber: surah.number,
          ayahNumber: 1,
        );
      }
    }
    return _unsupported(input);
  }

  bool _isReligiousRuling(String value) {
    const markers = [
      'فتوى',
      'حلال',
      'حرام',
      'يجوز',
      'لا يجوز',
      'حكم',
      'طلاق',
      'زواج',
      'ربا',
      'ميراث',
      'مذهب',
      'افتي',
    ];
    return markers.any(value.contains);
  }

  AssistantCommand _unsupported(String input) =>
      AssistantCommand(type: AssistantIntentType.unsupported, query: input);
  (int, int)? _coordinate(String? s, String? a) {
    final surah = int.tryParse(s ?? '');
    final ayah = int.tryParse(a ?? '');
    if (surah == null ||
        ayah == null ||
        surah < 1 ||
        surah > 114 ||
        ayah < 1 ||
        ayah > QuranMetadata.surah(surah).ayahCount) {
      return null;
    }
    return (surah, ayah);
  }

  String _normalize(String value) => value
      .trim()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'\s+'), ' ');
}
