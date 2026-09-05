import 'package:flutter/foundation.dart';
import '../../core/utils/arabic_search.dart';
import '../../data/models/adhkar.dart';
import '../../data/models/religious_content.dart';
import '../../data/repositories/adhkar_repository.dart';

class AdhkarController extends ChangeNotifier {
  AdhkarController({AdhkarRepository? repository, DateTime Function()? clock})
    : _repository = repository ?? AdhkarRepository(),
      _clock = clock ?? DateTime.now;
  final AdhkarRepository _repository;
  final DateTime Function() _clock;
  List<DhikrCategory> categories = [];
  List<DhikrItem> items = [];
  ReligiousContentManifest? manifest;
  DhikrSession? currentSession;
  bool loading = false;
  String? error;
  DhikrCategory? get recommendedCategory {
    final id = _clock().hour < 15 ? 'morning' : 'evening';
    return categories.where((e) => e.id == id).firstOrNull;
  }

  List<DhikrItem> itemsFor(String id) =>
      items.where((e) => e.categoryId == id).toList();

  List<DhikrItem> search(String query) {
    final normalized = normalizeArabicSearch(query);
    if (normalized.isEmpty) return const [];
    final categoryNames = {
      for (final category in categories) category.id: category.title,
    };
    return items
        .where(
          (item) => normalizeArabicSearch(
            '${item.arabicText} ${categoryNames[item.categoryId] ?? ''}',
          ).contains(normalized),
        )
        .toList();
  }

  DhikrItem? get currentItem {
    final s = currentSession;
    if (s == null) return null;
    final list = itemsFor(s.categoryId);
    return s.currentItemIndex >= 0 && s.currentItemIndex < list.length
        ? list[s.currentItemIndex]
        : null;
  }

  Future<void> load() async {
    loading = true;
    notifyListeners();
    final d = await _repository.loadData();
    categories = d.categories;
    items = d.items;
    manifest = d.manifest;
    currentSession = await _repository.loadSession();
    final session = currentSession;
    if (session != null) {
      final sessionItems = itemsFor(session.categoryId);
      if (sessionItems.isEmpty ||
          session.currentItemIndex < 0 ||
          session.currentItemIndex >= sessionItems.length ||
          session.progress.keys.any(
            (id) => !sessionItems.any((item) => item.id == id),
          )) {
        currentSession = null;
        await _repository.saveSession(null);
      }
    }
    if (categories.isEmpty) error = 'تعذر تحميل بيانات الأذكار المحلية.';
    loading = false;
    notifyListeners();
  }

  Future<void> startSession(String categoryId, {String? initialItemId}) async {
    final categoryItems = itemsFor(categoryId);
    if (categoryItems.isEmpty) throw ArgumentError('Unknown category');
    final initialIndex = initialItemId == null
        ? 0
        : categoryItems.indexWhere((item) => item.id == initialItemId);
    if (initialIndex < 0) throw ArgumentError('Unknown item');
    currentSession = DhikrSession(
      categoryId: categoryId,
      startedAt: _clock().toUtc(),
      currentItemIndex: initialIndex,
      progress: const {},
    );
    await _save();
  }

  Future<void> increment() async {
    final s = currentSession, item = currentItem;
    if (s == null || item == null || s.isCompleted) return;
    final count = (s.progress[item.id] ?? 0);
    if (count >= item.repeatCount) return;
    currentSession = s.copyWith(progress: {...s.progress, item.id: count + 1});
    await _save();
  }

  Future<void> decrement() async {
    final s = currentSession, item = currentItem;
    if (s == null || item == null) return;
    final count = (s.progress[item.id] ?? 0);
    if (count <= 0) return;
    currentSession = s.copyWith(progress: {...s.progress, item.id: count - 1});
    await _save();
  }

  Future<void> next() async {
    final s = currentSession, item = currentItem;
    if (s == null ||
        item == null ||
        (s.progress[item.id] ?? 0) < item.repeatCount) {
      return;
    }
    final list = itemsFor(s.categoryId);
    if (s.currentItemIndex == list.length - 1) {
      await completeSession();
      return;
    }
    currentSession = s.copyWith(currentItemIndex: s.currentItemIndex + 1);
    await _save();
  }

  Future<void> previous() async {
    final s = currentSession;
    if (s == null || s.currentItemIndex == 0) return;
    currentSession = s.copyWith(currentItemIndex: s.currentItemIndex - 1);
    await _save();
  }

  Future<void> resetSession() async {
    currentSession = null;
    await _repository.saveSession(null);
    notifyListeners();
  }

  Future<void> completeSession() async {
    final s = currentSession;
    if (s == null) return;
    currentSession = s.copyWith(completedAt: _clock().toUtc());
    await _save();
  }

  Future<void> _save() async {
    await _repository.saveSession(currentSession);
    notifyListeners();
  }
}
