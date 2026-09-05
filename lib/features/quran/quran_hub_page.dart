import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/app_components.dart';
import '../../app/widgets/design_asset_card.dart';
import '../../data/models/surah.dart';
import '../reader/reading_progress_controller.dart';

class QuranHubPage extends StatelessWidget {
  const QuranHubPage({
    super.key,
    required this.readingProgressController,
    required this.onContinueReading,
    required this.onOpenMushaf,
    required this.onOpenStudy,
    required this.onOpenSearch,
    required this.onOpenListening,
    required this.onOpenTranslation,
    required this.onOpenTafsir,
    required this.onOpenWordMeanings,
    required this.onOpenMemorization,
  });

  final ReadingProgressController readingProgressController;
  final VoidCallback onContinueReading;
  final VoidCallback onOpenMushaf;
  final VoidCallback onOpenStudy;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenListening;
  final VoidCallback onOpenTranslation;
  final VoidCallback onOpenTafsir;
  final VoidCallback onOpenWordMeanings;
  final VoidCallback onOpenMemorization;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('القرآن'),
      actions: [
        IconButton(
          key: const ValueKey('quran-hub-search-action'),
          tooltip: 'البحث في القرآن',
          onPressed: onOpenSearch,
          icon: const Icon(Icons.search_rounded),
        ),
      ],
    ),
    body: AnimatedBuilder(
      animation: readingProgressController,
      builder: (context, _) {
        final progress = readingProgressController.progress;
        final surah = progress == null
            ? null
            : QuranMetadata.surah(progress.surahNumber);
        return ListView(
          key: const ValueKey('quran-hub'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            140,
          ),
          children: [
            DesignAssetCard(
              key: const ValueKey('quran-hub-continue'),
              asset: 'assets/design/13_open_quran_illustration.webp',
              height: MediaQuery.textScalerOf(context).scale(1) > 1.2
                  ? 218
                  : 188,
              onTap: progress == null ? onOpenMushaf : onContinueReading,
              semanticLabel: progress == null
                  ? 'فتح المصحف'
                  : 'متابعة القراءة من سورة ${surah!.name}',
              overlay: const [Color(0xEE08201E), Color(0x8A123F37)],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    progress == null ? 'ابدأ من المصحف' : 'متابعة القراءة',
                    style: const TextStyle(color: AppColors.accentGold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    progress == null ? 'القرآن الكريم' : 'سورة ${surah!.name}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (progress != null)
                    Text(
                      'الآية ${progress.ayahNumber}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  const Spacer(),
                  const Row(
                    children: [
                      Text(
                        'افتح الآن',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_back_rounded, size: 18),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const AppSectionHeader('القراءة'),
            const SizedBox(height: AppSpacing.sm),
            _ActionRow(
              children: [
                _ActionTile(
                  keyName: 'quran-open-mushaf',
                  icon: Icons.menu_book_rounded,
                  label: 'المصحف',
                  onTap: onOpenMushaf,
                ),
                _ActionTile(
                  keyName: 'quran-open-study',
                  icon: Icons.chrome_reader_mode_outlined,
                  label: 'دراسة الآيات',
                  onTap: onOpenStudy,
                ),
                _ActionTile(
                  keyName: 'quran-open-search',
                  icon: Icons.manage_search_rounded,
                  label: 'البحث',
                  onTap: onOpenSearch,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            PremiumCard(
              key: const ValueKey('quran-open-listening'),
              onTap: onOpenListening,
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.headphones_rounded,
                  color: AppColors.accentGold,
                ),
                title: Text('الاستماع'),
                subtitle: Text('التلاوات والقارئ وسجل الاستماع'),
                trailing: Icon(Icons.arrow_back_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const AppSectionHeader('الدراسة'),
            const SizedBox(height: AppSpacing.sm),
            _StudyGroup(
              items: [
                _StudyItem(
                  'الترجمة',
                  Icons.translate_rounded,
                  onOpenTranslation,
                ),
                _StudyItem(
                  'التفسير',
                  Icons.auto_stories_outlined,
                  onOpenTafsir,
                ),
                _StudyItem(
                  'معاني الكلمات',
                  Icons.text_fields_rounded,
                  onOpenWordMeanings,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            PremiumCard(
              key: const ValueKey('quran-open-memorization'),
              onTap: onOpenMemorization,
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.accentGold,
                ),
                title: Text('الحفظ والمراجعة'),
                subtitle: Text('خطتك وجلساتك وآيات المراجعة'),
                trailing: Icon(Icons.arrow_back_rounded),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stack =
          constraints.maxWidth < 340 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.25;
      if (stack) {
        return Column(
          children: [
            for (final child in children) ...[
              SizedBox(width: double.infinity, height: 92, child: child),
              if (child != children.last) const SizedBox(height: AppSpacing.sm),
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            Expanded(child: SizedBox(height: 106, child: children[i])),
            if (i < children.length - 1) const SizedBox(width: AppSpacing.sm),
          ],
        ],
      );
    },
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.keyName,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final String keyName;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PremiumCard(
    key: ValueKey(keyName),
    onTap: onTap,
    padding: const EdgeInsets.all(AppSpacing.sm),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: AppColors.accentGold),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center, maxLines: 2),
      ],
    ),
  );
}

class _StudyItem {
  const _StudyItem(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _StudyGroup extends StatelessWidget {
  const _StudyGroup({required this.items});
  final List<_StudyItem> items;

  @override
  Widget build(BuildContext context) => PremiumCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          ListTile(
            leading: Icon(items[index].icon, color: AppColors.accentGold),
            title: Text(items[index].label),
            trailing: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
            onTap: items[index].onTap,
          ),
          if (index < items.length - 1) const Divider(height: 1),
        ],
      ],
    ),
  );
}
