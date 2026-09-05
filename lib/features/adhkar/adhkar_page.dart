import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/app_components.dart';
import '../../data/models/adhkar.dart';
import 'adhkar_controller.dart';

class AdhkarPage extends StatefulWidget {
  const AdhkarPage({super.key, required this.controller});
  final AdhkarController controller;

  @override
  State<AdhkarPage> createState() => _AdhkarPageState();
}

class _AdhkarPageState extends State<AdhkarPage> {
  final _searchController = TextEditingController();

  AdhkarController get controller => widget.controller;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الأذكار')),
    body: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.error != null) {
          return AppEmptyState(
            icon: Icons.error_outline,
            title: 'تعذر فتح الأذكار',
            message: controller.error!,
          );
        }
        final recommended = controller.recommendedCategory;
        final results = controller.search(_searchController.text);
        return ListView(
          key: const ValueKey('adhkar-page'),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            TextField(
              key: const ValueKey('adhkar-search'),
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'ابحث في الأذكار',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_searchController.text.trim().isNotEmpty) ...[
              const AppSectionHeader('نتائج البحث'),
              const SizedBox(height: AppSpacing.xs),
              if (results.isEmpty)
                const AppEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'لا توجد نتائج',
                  message: 'جرّب عبارة بحث أخرى.',
                )
              else
                ...results.map((item) => _searchTile(context, item)),
            ] else ...[
              if (controller.currentSession != null &&
                  controller.currentSession?.isCompleted == false) ...[
                const AppSectionHeader('متابعة الجلسة'),
                _tile(
                  context,
                  controller.categories.firstWhere(
                    (category) =>
                        category.id == controller.currentSession!.categoryId,
                  ),
                ),
                const SizedBox(height: 20),
              ],
              const AppSectionHeader('المقترح الآن'),
              if (recommended != null) _tile(context, recommended),
              const SizedBox(height: 20),
              const AppSectionHeader('التصنيفات'),
              ...controller.categories.map((c) => _tile(context, c)),
            ],
          ],
        );
      },
    ),
  );

  Widget _tile(BuildContext context, DhikrCategory c) {
    final session = controller.currentSession?.categoryId == c.id
        ? controller.currentSession
        : null;
    final list = controller.itemsFor(c.id);
    final done = session?.progress.values.fold<int>(0, (a, b) => a + b) ?? 0;
    final total = list.fold<int>(0, (a, b) => a + b.repeatCount);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: PremiumCard(
        onTap: () => _open(context, c),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            c.id == 'morning'
                ? Icons.wb_sunny_outlined
                : Icons.nights_stay_outlined,
            color: AppColors.accentGold,
          ),
          title: Text(c.title),
          subtitle: Text(
            session == null
                ? '${list.length} أذكار • ابدأ الأذكار'
                : 'متابعة الجلسة • $done من $total',
          ),
          trailing: const Icon(Icons.arrow_back_rounded),
        ),
      ),
    );
  }

  Widget _searchTile(BuildContext context, DhikrItem item) {
    final category = controller.categories.firstWhere(
      (value) => value.id == item.categoryId,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: PremiumCard(
        onTap: () => _open(context, category, initialItemId: item.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              category.title,
              style: const TextStyle(color: AppColors.accentGold),
            ),
            const SizedBox(height: 6),
            Text(
              item.arabicText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, height: 1.7),
            ),
            const SizedBox(height: 6),
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

  Future<void> _open(
    BuildContext context,
    DhikrCategory c, {
    String? initialItemId,
  }) async {
    if (initialItemId != null ||
        controller.currentSession?.categoryId != c.id ||
        controller.currentSession!.isCompleted) {
      await controller.startSession(c.id, initialItemId: initialItemId);
    }
    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdhkarSessionPage(controller: controller),
        ),
      );
    }
  }
}

class AdhkarSessionPage extends StatelessWidget {
  const AdhkarSessionPage({super.key, required this.controller});
  final AdhkarController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final s = controller.currentSession, item = controller.currentItem;
      if (s == null || item == null) {
        return const Scaffold(
          body: AppEmptyState(
            icon: Icons.check_circle_outline,
            title: 'اكتملت الجلسة',
            message: 'تقبل الله ذكرك.',
          ),
        );
      }
      final list = controller.itemsFor(s.categoryId),
          count = s.progress[item.id] ?? 0;
      return Scaffold(
        appBar: AppBar(
          title: Text(
            controller.categories.firstWhere((e) => e.id == s.categoryId).title,
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text('${s.currentItemIndex + 1} من ${list.length}'),
              const SizedBox(height: 12),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'زيادة عداد الذكر',
                  child: InkWell(
                    onTap: () async {
                      await HapticFeedback.selectionClick();
                      await controller.increment();
                    },
                    borderRadius: BorderRadius.circular(AppRadius.large),
                    child: PremiumCard(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Text(
                            item.arabicText,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(fontSize: 27, height: 1.8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${item.sourceText} • ${item.reference}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Text(
                '$count / ${item.repeatCount}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              AppProgressBar(value: count / item.repeatCount),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: s.currentItemIndex > 0
                        ? controller.previous
                        : null,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                  TextButton(
                    onPressed: controller.decrement,
                    child: const Text('تراجع'),
                  ),
                  FilledButton(
                    onPressed: count >= item.repeatCount
                        ? controller.next
                        : null,
                    child: Text(
                      s.currentItemIndex == list.length - 1
                          ? 'إتمام'
                          : 'التالي',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
