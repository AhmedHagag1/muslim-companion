import 'package:flutter/foundation.dart';

@immutable
class MushafCoordinate implements Comparable<MushafCoordinate> {
  const MushafCoordinate(this.surahNumber, this.ayahNumber);

  final int surahNumber;
  final int ayahNumber;

  @override
  int compareTo(MushafCoordinate other) {
    final surah = surahNumber.compareTo(other.surahNumber);
    return surah == 0 ? ayahNumber.compareTo(other.ayahNumber) : surah;
  }

  @override
  bool operator ==(Object other) =>
      other is MushafCoordinate &&
      surahNumber == other.surahNumber &&
      ayahNumber == other.ayahNumber;

  @override
  int get hashCode => Object.hash(surahNumber, ayahNumber);

  @override
  String toString() => '$surahNumber:$ayahNumber';
}

@immutable
class MushafAyahBoundary {
  const MushafAyahBoundary({
    required this.coordinate,
    required this.pageNumber,
  });

  final MushafCoordinate coordinate;
  final int pageNumber;
}

@immutable
class MushafPage {
  const MushafPage({
    required this.pageNumber,
    required this.firstCoordinate,
    required this.lastCoordinate,
    required this.juzNumber,
    required this.hizbQuarterNumber,
    required this.coordinates,
  });

  final int pageNumber;
  final MushafCoordinate firstCoordinate;
  final MushafCoordinate lastCoordinate;
  final int juzNumber;
  final int hizbQuarterNumber;
  final List<MushafCoordinate> coordinates;
}

@immutable
class MushafValidationResult {
  const MushafValidationResult({
    required this.pageCount,
    required this.mappedAyahCount,
    required this.representedSurahs,
  });

  final int pageCount;
  final int mappedAyahCount;
  final Set<int> representedSurahs;
}
