import 'package:flutter/foundation.dart';

import '../../data/models/reading_progress.dart';
import '../../data/models/surah.dart';
import '../../data/repositories/reading_progress_repository.dart';

class ReadingProgressController extends ChangeNotifier {
  ReadingProgressController({ReadingProgressRepository? repository})
    : _repository = repository ?? ReadingProgressRepository();

  final ReadingProgressRepository _repository;

  ReadingProgress? _progress;
  bool _isLoaded = false;
  Future<void>? _loadFuture;

  ReadingProgress? get progress => _progress;
  bool get isLoaded => _isLoaded;

  Future<void> load() => _loadFuture ??= _load();

  Future<void> _load() async {
    final saved = await _repository.load();
    _progress = _isValid(saved) ? saved : null;
    _isLoaded = true;
    notifyListeners();
  }

  Future<bool> update({
    required int surahNumber,
    required int ayahNumber,
    DateTime? updatedAt,
  }) async {
    if (!_isLoaded) await load();

    final progress = ReadingProgress(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      updatedAt: updatedAt ?? DateTime.now(),
    );
    if (!_isValid(progress)) return false;

    _progress = progress;
    _isLoaded = true;
    notifyListeners();
    await _repository.save(progress);
    return true;
  }

  bool _isValid(ReadingProgress? progress) {
    if (progress == null ||
        progress.surahNumber < 1 ||
        progress.surahNumber > QuranMetadata.surahCount) {
      return false;
    }

    final surah = QuranMetadata.surah(progress.surahNumber);
    return progress.ayahNumber >= 1 && progress.ayahNumber <= surah.ayahCount;
  }
}
