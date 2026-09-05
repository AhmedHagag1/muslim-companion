import 'package:flutter/foundation.dart';

import '../../data/models/quran_bookmark.dart';
import '../../data/models/surah.dart';
import '../../data/repositories/bookmark_repository.dart';

class BookmarkController extends ChangeNotifier {
  BookmarkController({BookmarkRepository? repository})
    : _repository = repository ?? BookmarkRepository();

  final BookmarkRepository _repository;
  final List<QuranBookmark> _bookmarks = [];
  Future<void>? _loadFuture;

  List<QuranBookmark> get bookmarks => List.unmodifiable(_bookmarks);

  Future<void> load() => _loadFuture ??= _load();

  Future<void> _load() async {
    final loaded = await _repository.load();
    final unique = <String, QuranBookmark>{};
    for (final bookmark in loaded) {
      if (_isValid(bookmark.surahNumber, bookmark.ayahNumber)) {
        final existing = unique[bookmark.coordinateKey];
        if (existing == null ||
            bookmark.createdAt.isAfter(existing.createdAt)) {
          unique[bookmark.coordinateKey] = bookmark;
        }
      }
    }
    _bookmarks
      ..clear()
      ..addAll(unique.values);
    _sort();
    notifyListeners();
  }

  bool isBookmarked(int surahNumber, int ayahNumber) => _bookmarks.any(
    (bookmark) =>
        bookmark.surahNumber == surahNumber &&
        bookmark.ayahNumber == ayahNumber,
  );

  Future<bool> addBookmark(
    int surahNumber,
    int ayahNumber, {
    DateTime? createdAt,
  }) async {
    await load();
    if (!_isValid(surahNumber, ayahNumber) ||
        isBookmarked(surahNumber, ayahNumber)) {
      return false;
    }
    _bookmarks.add(
      QuranBookmark(
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
        createdAt: createdAt ?? DateTime.now(),
      ),
    );
    _sort();
    notifyListeners();
    await _repository.save(_bookmarks);
    return true;
  }

  Future<bool> removeBookmark(int surahNumber, int ayahNumber) async {
    await load();
    final before = _bookmarks.length;
    _bookmarks.removeWhere(
      (bookmark) =>
          bookmark.surahNumber == surahNumber &&
          bookmark.ayahNumber == ayahNumber,
    );
    if (_bookmarks.length == before) return false;
    notifyListeners();
    await _repository.save(_bookmarks);
    return true;
  }

  Future<bool> toggleBookmark(int surahNumber, int ayahNumber) async {
    if (isBookmarked(surahNumber, ayahNumber)) {
      return removeBookmark(surahNumber, ayahNumber);
    }
    return addBookmark(surahNumber, ayahNumber);
  }

  bool _isValid(int surahNumber, int ayahNumber) {
    if (surahNumber < 1 || surahNumber > QuranMetadata.surahCount) return false;
    return ayahNumber >= 1 &&
        ayahNumber <= QuranMetadata.surah(surahNumber).ayahCount;
  }

  void _sort() => _bookmarks.sort((a, b) {
    final byDate = b.createdAt.compareTo(a.createdAt);
    return byDate != 0 ? byDate : a.coordinateKey.compareTo(b.coordinateKey);
  });
}
