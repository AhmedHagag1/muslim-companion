import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../data/models/surah.dart';
import '../domain/mushaf_models.dart';

abstract interface class MushafRepository {
  int get totalPages;
  bool get isLoaded;

  Future<void> load();
  MushafPage page(int pageNumber);
  int pageForCoordinate(int surahNumber, int ayahNumber);
  int firstPageForSurah(int surahNumber);
  MushafValidationResult validate();
}

abstract interface class MushafLayoutDataSource {
  Future<String> load();
}

class AssetMushafLayoutDataSource implements MushafLayoutDataSource {
  const AssetMushafLayoutDataSource([this._bundle]);

  static const assetPath = 'assets/mushaf/madina_page_boundaries.json';
  final AssetBundle? _bundle;

  @override
  Future<String> load() => (_bundle ?? rootBundle).loadString(assetPath);
}

class MadinaMushafRepository implements MushafRepository {
  MadinaMushafRepository({MushafLayoutDataSource? dataSource})
    : _dataSource = dataSource ?? const AssetMushafLayoutDataSource();

  static const expectedPageCount = 604;
  static const expectedAyahCount = 6236;

  final MushafLayoutDataSource _dataSource;
  final List<MushafPage> _pages = [];
  final Map<MushafCoordinate, int> _pageByCoordinate = {};

  @override
  bool get isLoaded => _pages.length == expectedPageCount;

  @override
  int get totalPages => isLoaded ? _pages.length : 0;

  @override
  Future<void> load() async {
    if (isLoaded) return;
    final root = jsonDecode(await _dataSource.load()) as Map<String, dynamic>;
    final edition = root['edition'] as Map<String, dynamic>;
    if (root['schemaVersion'] != 1 ||
        edition['id'] != 'tanzil-medina-page-boundaries-v1' ||
        edition['totalPages'] != expectedPageCount) {
      throw const FormatException('بيانات صفحات المصحف غير متوافقة.');
    }

    final coordinates = <MushafCoordinate>[];
    for (final surah in QuranMetadata.surahs) {
      for (var ayah = 1; ayah <= surah.ayahCount; ayah++) {
        coordinates.add(MushafCoordinate(surah.number, ayah));
      }
    }
    final ordinal = <MushafCoordinate, int>{
      for (var index = 0; index < coordinates.length; index++)
        coordinates[index]: index,
    };

    final pageStarts = _parseStarts(root['pageStarts'], 'page', ordinal);
    final juzStarts = _parseStarts(root['juzStarts'], 'juz', ordinal);
    final quarterStarts = _parseStarts(
      root['hizbQuarterStarts'],
      'quarter',
      ordinal,
    );
    if (pageStarts.length != expectedPageCount) {
      throw const FormatException('يجب أن تحتوي بيانات المصحف على 604 صفحات.');
    }

    _pages.clear();
    _pageByCoordinate.clear();
    for (var index = 0; index < pageStarts.length; index++) {
      final start = pageStarts[index];
      if (start.number != index + 1) {
        throw const FormatException('ترقيم صفحات المصحف غير متصل.');
      }
      final startOrdinal = ordinal[start.coordinate]!;
      final endOrdinal = index + 1 < pageStarts.length
          ? ordinal[pageStarts[index + 1].coordinate]! - 1
          : coordinates.length - 1;
      if (endOrdinal < startOrdinal) {
        throw const FormatException('حدود صفحات المصحف غير مرتبة.');
      }
      final pageCoordinates = List<MushafCoordinate>.unmodifiable(
        coordinates.sublist(startOrdinal, endOrdinal + 1),
      );
      final page = MushafPage(
        pageNumber: start.number,
        firstCoordinate: pageCoordinates.first,
        lastCoordinate: pageCoordinates.last,
        juzNumber: _sectionAt(juzStarts, startOrdinal, ordinal),
        hizbQuarterNumber: _sectionAt(quarterStarts, startOrdinal, ordinal),
        coordinates: pageCoordinates,
      );
      _pages.add(page);
      for (final coordinate in pageCoordinates) {
        if (_pageByCoordinate.putIfAbsent(coordinate, () => page.pageNumber) !=
            page.pageNumber) {
          throw const FormatException('تكررت آية في خريطة صفحات المصحف.');
        }
      }
    }
    validate();
  }

  List<_NumberedStart> _parseStarts(
    Object? value,
    String numberKey,
    Map<MushafCoordinate, int> ordinal,
  ) {
    if (value is! List) throw const FormatException('بيانات المصحف ناقصة.');
    return value
        .map((raw) {
          final map = raw as Map<String, dynamic>;
          final coordinate = MushafCoordinate(
            map['surah'] as int,
            map['ayah'] as int,
          );
          if (!ordinal.containsKey(coordinate)) {
            throw FormatException('إحداثي مصحف خارج النطاق: $coordinate');
          }
          return _NumberedStart(map[numberKey] as int, coordinate);
        })
        .toList(growable: false);
  }

  int _sectionAt(
    List<_NumberedStart> starts,
    int pageStartOrdinal,
    Map<MushafCoordinate, int> ordinal,
  ) {
    var result = starts.first.number;
    for (final start in starts) {
      if (ordinal[start.coordinate]! > pageStartOrdinal) break;
      result = start.number;
    }
    return result;
  }

  void _requireLoaded() {
    if (!isLoaded) throw StateError('يجب تحميل بيانات المصحف أولًا.');
  }

  @override
  MushafPage page(int pageNumber) {
    _requireLoaded();
    if (pageNumber < 1 || pageNumber > totalPages) {
      throw RangeError.range(pageNumber, 1, totalPages, 'pageNumber');
    }
    return _pages[pageNumber - 1];
  }

  @override
  int pageForCoordinate(int surahNumber, int ayahNumber) {
    _requireLoaded();
    final value = _pageByCoordinate[MushafCoordinate(surahNumber, ayahNumber)];
    if (value == null) {
      throw RangeError('إحداثي قرآني خارج النطاق: $surahNumber:$ayahNumber');
    }
    return value;
  }

  @override
  int firstPageForSurah(int surahNumber) {
    if (surahNumber < 1 || surahNumber > QuranMetadata.surahCount) {
      throw RangeError.range(surahNumber, 1, QuranMetadata.surahCount);
    }
    return pageForCoordinate(surahNumber, 1);
  }

  @override
  MushafValidationResult validate() {
    _requireLoaded();
    if (_pages.first.firstCoordinate != const MushafCoordinate(1, 1) ||
        _pages.last.lastCoordinate != const MushafCoordinate(114, 6) ||
        _pageByCoordinate.length != expectedAyahCount) {
      throw const FormatException('تغطية صفحات المصحف غير مكتملة.');
    }
    final represented = _pageByCoordinate.keys
        .map((coordinate) => coordinate.surahNumber)
        .toSet();
    if (represented.length != QuranMetadata.surahCount) {
      throw const FormatException('لا تمثل خريطة المصحف جميع السور.');
    }
    return MushafValidationResult(
      pageCount: _pages.length,
      mappedAyahCount: _pageByCoordinate.length,
      representedSurahs: Set.unmodifiable(represented),
    );
  }
}

class _NumberedStart {
  const _NumberedStart(this.number, this.coordinate);
  final int number;
  final MushafCoordinate coordinate;
}
