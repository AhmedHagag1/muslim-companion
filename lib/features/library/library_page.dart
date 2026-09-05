import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/app_components.dart';
import '../../app/widgets/design_asset_card.dart';
import '../audio/quran_audio_controller.dart';
import '../bookmarks/bookmark_controller.dart';
import '../khatma/khatma_controller.dart';
import '../memorization/memorization_controller.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({
    super.key,
    required this.bookmarkController,
    required this.khatmaController,
    required this.memorizationController,
    required this.onOpenBookmarks,
    required this.onOpenKhatma,
    required this.onOpenMemorization,
    required this.onOpenListening,
    required this.onOpenBackup,
    required this.onOpenSettings,
    this.audioController,
  });

  final BookmarkController bookmarkController;
  final KhatmaController khatmaController;
  final MemorizationController memorizationController;
  final QuranAudioController? audioController;
  final VoidCallback onOpenBookmarks;
  final VoidCallback onOpenKhatma;
  final VoidCallback onOpenMemorization;
  final VoidCallback onOpenListening;
  final VoidCallback onOpenBackup;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('مكتبتي'),
      actions: [
        IconButton(
          key: const ValueKey('library-settings'),
          tooltip: 'الإعدادات',
          onPressed: onOpenSettings,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    ),
    body: AnimatedBuilder(
      animation: Listenable.merge([
        bookmarkController,
        khatmaController,
        memorizationController,
        ?audioController,
      ]),
      builder: (context, _) => ListView(
        key: const ValueKey('library-hub'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          140,
        ),
        children: [
          DesignAssetCard(
            asset: 'assets/design/14_closed_quran_illustration.webp',
            height: MediaQuery.textScalerOf(context).scale(1) > 1.2 ? 174 : 142,
            overlay: const [Color(0xE80A2421), Color(0xB30B2926)],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'مساحتك الخاصة',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'محفوظاتك وخططك وسجل استماعك في مكان واحد',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppSectionHeader('محتواك'),
          const SizedBox(height: AppSpacing.sm),
          _LibraryGroup(
            items: [
              _LibraryItem(
                keyName: 'library-bookmarks',
                icon: Icons.bookmark_rounded,
                title: 'المحفوظات',
                subtitle: bookmarkController.bookmarks.isEmpty
                    ? 'لا توجد آيات محفوظة بعد'
                    : '${bookmarkController.bookmarks.length} آية محفوظة',
                onTap: onOpenBookmarks,
              ),
              _LibraryItem(
                keyName: 'library-khatma',
                icon: Icons.auto_stories_rounded,
                title: 'الختمة',
                subtitle: khatmaController.activePlan == null
                    ? 'ابدأ خطة تناسبك'
                    : khatmaController.activePlan!.title,
                onTap: onOpenKhatma,
              ),
              _LibraryItem(
                keyName: 'library-memorization',
                icon: Icons.workspace_premium_rounded,
                title: 'الحفظ والمراجعات',
                subtitle: memorizationController.dueReviewAyahs.isEmpty
                    ? 'خطة الحفظ وسجل الجلسات'
                    : '${memorizationController.dueReviewAyahs.length} آيات للمراجعة',
                onTap: onOpenMemorization,
              ),
              _LibraryItem(
                keyName: 'library-listening',
                icon: Icons.history_rounded,
                title: 'سجل الاستماع',
                subtitle:
                    audioController == null || audioController!.history.isEmpty
                    ? 'لا يوجد سجل استماع بعد'
                    : '${audioController!.history.length} عناصر حديثة',
                onTap: onOpenListening,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          PremiumCard(
            key: const ValueKey('library-backup'),
            onTap: onOpenBackup,
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.backup_outlined, color: AppColors.accentGold),
              title: Text('النسخ الاحتياطي والاستعادة'),
              subtitle: Text('احفظ بياناتك أو استعدها على هذا الجهاز'),
              trailing: Icon(Icons.arrow_back_rounded),
            ),
          ),
        ],
      ),
    ),
  );
}

class _LibraryItem {
  const _LibraryItem({
    required this.keyName,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String keyName;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _LibraryGroup extends StatelessWidget {
  const _LibraryGroup({required this.items});
  final List<_LibraryItem> items;

  @override
  Widget build(BuildContext context) => PremiumCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          ListTile(
            key: ValueKey(items[index].keyName),
            leading: Icon(items[index].icon, color: AppColors.accentGold),
            title: Text(items[index].title),
            subtitle: Text(
              items[index].subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
            onTap: items[index].onTap,
          ),
          if (index < items.length - 1) const Divider(height: 1),
        ],
      ],
    ),
  );
}
