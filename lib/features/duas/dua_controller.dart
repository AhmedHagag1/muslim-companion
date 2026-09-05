import 'package:flutter/foundation.dart';

import '../../core/utils/arabic_search.dart';
import '../../data/models/religious_content.dart';
import '../../data/repositories/dua_repository.dart';

class DuaController extends ChangeNotifier {
  DuaController({DuaRepository? repository})
    : _repository = repository ?? DuaRepository();

  final DuaRepository _repository;
  List<DuaCategory> categories = const [];
  List<DuaItem> items = const [];
  Set<String> favoriteIds = {};
  ReligiousContentManifest? manifest;
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.loadContent(),
        _repository.loadFavorites(),
      ]);
      final pack = results[0] as ReligiousContentPack;
      categories = pack.duaCategories;
      items = pack.duaItems;
      manifest = pack.manifest;
      favoriteIds = (results[1] as Set<String>)
          .where((id) => items.any((item) => item.id == id))
          .toSet();
    } catch (_) {
      error = 'تعذر تحميل الأدعية الموثقة المحفوظة على الجهاز.';
      categories = const [];
      items = const [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  List<DuaItem> itemsFor(String? categoryId) => categoryId == null
      ? items
      : items.where((item) => item.categoryId == categoryId).toList();

  List<DuaItem> search(String query, {String? categoryId}) {
    final normalized = normalizeArabicSearch(query);
    final categoryTitles = {
      for (final category in categories) category.id: category.title,
    };
    return itemsFor(categoryId).where((item) {
      if (normalized.isEmpty) return true;
      return normalizeArabicSearch(
        '${item.title} ${item.arabicText} ${categoryTitles[item.categoryId] ?? ''}',
      ).contains(normalized);
    }).toList();
  }

  bool isFavorite(String id) => favoriteIds.contains(id);

  Future<void> toggleFavorite(String id) async {
    if (!items.any((item) => item.id == id)) return;
    final next = {...favoriteIds};
    next.contains(id) ? next.remove(id) : next.add(id);
    favoriteIds = next;
    notifyListeners();
    await _repository.saveFavorites(next);
  }
}
