import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/app_components.dart';
import '../../data/models/religious_content.dart';
import 'dua_controller.dart';

class DuasPage extends StatefulWidget {
  const DuasPage({super.key, required this.controller});
  final DuaController controller;

  @override
  State<DuasPage> createState() => _DuasPageState();
}

class _DuasPageState extends State<DuasPage> {
  final _searchController = TextEditingController();
  String? _categoryId;
  bool _favoritesOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الأدعية')),
    body: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        if (controller.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.error != null) {
          return AppEmptyState(
            icon: Icons.error_outline,
            title: 'تعذر فتح الأدعية',
            message: controller.error!,
          );
        }
        var results = controller.search(
          _searchController.text,
          categoryId: _categoryId,
        );
        if (_favoritesOnly) {
          results = results
              .where((item) => controller.isFavorite(item.id))
              .toList();
        }
        return ListView(
          key: const ValueKey('duas-page'),
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            TextField(
              key: const ValueKey('dua-search'),
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'ابحث في الأدعية',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('الكل'),
                    selected: _categoryId == null && !_favoritesOnly,
                    onSelected: (_) => setState(() {
                      _categoryId = null;
                      _favoritesOnly = false;
                    }),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    key: const ValueKey('dua-favorites-filter'),
                    avatar: const Icon(Icons.favorite_outline, size: 18),
                    label: const Text('المفضلة'),
                    selected: _favoritesOnly,
                    onSelected: (value) => setState(() {
                      _favoritesOnly = value;
                      if (value) _categoryId = null;
                    }),
                  ),
                  ...controller.categories.map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(category.title),
                        selected: _categoryId == category.id,
                        onSelected: (_) => setState(() {
                          _categoryId = category.id;
                          _favoritesOnly = false;
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (results.isEmpty)
              const AppEmptyState(
                icon: Icons.volunteer_activism_outlined,
                title: 'لا توجد نتائج',
                message: 'غيّر البحث أو التصنيف لعرض الأدعية.',
              )
            else
              ...results.map(
                (item) => _DuaCard(item: item, controller: controller),
              ),
          ],
        );
      },
    ),
  );
}

class _DuaCard extends StatelessWidget {
  const _DuaCard({required this.item, required this.controller});
  final DuaItem item;
  final DuaController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: ValueKey('dua-favorite-${item.id}'),
                tooltip: controller.isFavorite(item.id)
                    ? 'إزالة من المفضلة'
                    : 'إضافة إلى المفضلة',
                onPressed: () => controller.toggleFavorite(item.id),
                icon: Icon(
                  controller.isFavorite(item.id)
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: AppColors.accentGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.arabicText,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 25, height: 1.8),
          ),
          if (item.repeatCount != null) ...[
            const SizedBox(height: 8),
            Text(
              'التكرار: ${item.repeatCount}',
              style: const TextStyle(color: AppColors.accentGold),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '${item.sourceText} • ${item.reference}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}

class DuaDetailPage extends StatelessWidget {
  const DuaDetailPage({
    super.key,
    required this.item,
    required this.controller,
  });

  final DuaItem item;
  final DuaController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(item.title)),
    body: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => ListView(
        key: ValueKey('dua-detail-${item.id}'),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [_DuaCard(item: item, controller: controller)],
      ),
    ),
  );
}
