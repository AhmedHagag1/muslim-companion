import '../../data/models/memorization.dart';

enum InternalDestinationType {
  ayah,
  verseStudy,
  khatma,
  memorization,
  dua,
  adhkar,
  prayer,
  qibla,
}

enum VerseStudySection { translation, tafsir, words }

class InternalDestination {
  const InternalDestination._(
    this.type, {
    this.coordinate,
    this.studySection,
    this.itemId,
  });

  const InternalDestination.ayah(QuranCoordinate coordinate)
    : this._(InternalDestinationType.ayah, coordinate: coordinate);
  const InternalDestination.study(
    QuranCoordinate coordinate,
    VerseStudySection section,
  ) : this._(
        InternalDestinationType.verseStudy,
        coordinate: coordinate,
        studySection: section,
      );
  const InternalDestination.simple(InternalDestinationType type) : this._(type);
  const InternalDestination.item(InternalDestinationType type, String id)
    : this._(type, itemId: id);

  final InternalDestinationType type;
  final QuranCoordinate? coordinate;
  final VerseStudySection? studySection;
  final String? itemId;

  String get path => switch (type) {
    InternalDestinationType.ayah =>
      '/quran/${coordinate!.surahNumber}/${coordinate!.ayahNumber}',
    InternalDestinationType.verseStudy =>
      '/study/${coordinate!.surahNumber}/${coordinate!.ayahNumber}?tab=${studySection!.name}',
    InternalDestinationType.khatma => '/khatma',
    InternalDestinationType.memorization => '/memorization',
    InternalDestinationType.dua => '/duas/$itemId',
    InternalDestinationType.adhkar => '/adhkar/$itemId',
    InternalDestinationType.prayer => '/prayer',
    InternalDestinationType.qibla => '/qibla',
  };

  static InternalDestination? parse(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.hasScheme || uri.host.isNotEmpty) return null;
    final segments = uri.pathSegments;
    if (segments.length == 3 &&
        (segments.first == 'quran' || segments.first == 'study')) {
      final coordinate = QuranCoordinate(
        int.tryParse(segments[1]) ?? 0,
        int.tryParse(segments[2]) ?? 0,
      );
      if (!coordinate.isValid) return null;
      if (segments.first == 'quran') {
        return InternalDestination.ayah(coordinate);
      }
      final section = VerseStudySection.values
          .where((e) => e.name == uri.queryParameters['tab'])
          .firstOrNull;
      if (section == null) return null;
      return InternalDestination.study(coordinate, section);
    }
    if (segments.length == 1) {
      return switch (segments.firstOrNull) {
        'khatma' => const InternalDestination.simple(
          InternalDestinationType.khatma,
        ),
        'memorization' => const InternalDestination.simple(
          InternalDestinationType.memorization,
        ),
        'prayer' => const InternalDestination.simple(
          InternalDestinationType.prayer,
        ),
        'qibla' => const InternalDestination.simple(
          InternalDestinationType.qibla,
        ),
        _ => null,
      };
    }
    if (segments.length == 2 && segments[1].trim().isNotEmpty) {
      return switch (segments.first) {
        'duas' => InternalDestination.item(
          InternalDestinationType.dua,
          segments[1],
        ),
        'adhkar' => InternalDestination.item(
          InternalDestinationType.adhkar,
          segments[1],
        ),
        _ => null,
      };
    }
    return null;
  }
}
