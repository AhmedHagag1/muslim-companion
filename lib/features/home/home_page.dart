import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/app_components.dart';
import '../../app/widgets/design_asset_card.dart';
import '../../core/services/location_service.dart';
import '../../data/models/surah.dart';
import '../audio/quran_audio_controller.dart';
import '../bookmarks/bookmark_controller.dart';
import '../prayer/prayer_controller.dart';
import '../quran/quran_controller.dart';
import '../reader/quran_reader_page.dart';
import '../reader/reading_progress_controller.dart';
import '../memorization/memorization_controller.dart';
import '../adhkar/adhkar_controller.dart';
import '../adhkar/adhkar_page.dart';
import '../tasbeeh/tasbeeh_controller.dart';
import '../tasbeeh/tasbeeh_page.dart';
import '../khatma/khatma_controller.dart';
import '../daily/daily_islamic_controller.dart';
import '../daily/daily_islamic_page.dart';

enum HomeContextualAction { memorization, khatma, adhkar }

@visibleForTesting
HomeContextualAction selectHomeContextualAction({
  required int dueReviewCount,
  required bool hasActiveKhatma,
}) {
  if (dueReviewCount > 0) return HomeContextualAction.memorization;
  if (hasActiveKhatma) return HomeContextualAction.khatma;
  return HomeContextualAction.adhkar;
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.prayerController,
    required this.quranController,
    required this.readingProgressController,
    required this.bookmarkController,
    required this.onOpenPrayerTimes,
    required this.onOpenQuran,
    required this.onOpenBookmarks,
    required this.onOpenMemorization,
    this.audioController,
    required this.memorizationController,
    required this.adhkarController,
    required this.tasbeehController,
    required this.khatmaController,
    required this.onOpenKhatma,
    required this.dailyIslamicController,
    required this.onOpenSearch,
    this.onOpenAsk,
    this.onOpenSettings,
    this.onOpenListening,
  });
  final PrayerController prayerController;
  final QuranController quranController;
  final ReadingProgressController readingProgressController;
  final BookmarkController bookmarkController;
  final VoidCallback onOpenPrayerTimes;
  final VoidCallback onOpenQuran;
  final VoidCallback onOpenBookmarks;
  final VoidCallback onOpenMemorization;
  final QuranAudioController? audioController;
  final MemorizationController memorizationController;
  final AdhkarController adhkarController;
  final TasbeehController tasbeehController;
  final KhatmaController khatmaController;
  final VoidCallback onOpenKhatma;
  final DailyIslamicController dailyIslamicController;
  final VoidCallback onOpenSearch;
  final VoidCallback? onOpenAsk;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenListening;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      prayerController,
      readingProgressController,
      ?audioController,
      memorizationController,
      adhkarController,
      tasbeehController,
      khatmaController,
      dailyIslamicController,
    ]),
    builder: (context, _) => ListView(
      key: const ValueKey('home-dashboard'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        _header(context),
        const SizedBox(height: AppSpacing.md),
        _prayerCard(context),
        const SizedBox(height: AppSpacing.md),
        _readingCard(context),
        const SizedBox(height: AppSpacing.md),
        _activeAction(context),
        const SizedBox(height: AppSpacing.md),
        _dailyIslamicCard(context),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          key: const ValueKey('home-ask-entry'),
          onPressed: onOpenAsk,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('ماذا تريد؟'),
        ),
        const SizedBox(height: AppSpacing.lg),
        const AppSectionHeader('اختصارات'),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          alignment: WrapAlignment.spaceAround,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            _smallShortcut(Icons.search_rounded, 'البحث', onOpenSearch),
            _smallShortcut(
              Icons.headphones_rounded,
              'الاستماع',
              onOpenListening ?? onOpenQuran,
            ),
            _smallShortcut(
              Icons.bookmark_rounded,
              'المحفوظات',
              onOpenBookmarks,
            ),
            _smallShortcut(Icons.radio_button_checked_rounded, 'السبحة', () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TasbeehPage(controller: tasbeehController),
                ),
              );
            }),
          ],
        ),
      ],
    ),
  );

  Widget _header(BuildContext context) => DesignAssetCard(
    asset: 'assets/design/01_home_hero_bg.webp',
    height: MediaQuery.textScalerOf(context).scale(1) > 1.2 ? 144 : 118,
    overlay: const [Color(0xEC061B1A), Color(0x6B061B1A)],
    child: Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'السلام عليكم',
                style: TextStyle(color: AppColors.accentGold),
              ),
              Text(
                'رفيقك اليومي',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          key: const ValueKey('home-global-search'),
          tooltip: 'البحث',
          onPressed: onOpenSearch,
          icon: const Icon(Icons.search_rounded),
        ),
        const SizedBox(width: 4),
        IconButton.filledTonal(
          key: const ValueKey('home-settings'),
          tooltip: 'الإعدادات',
          onPressed: onOpenSettings,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    ),
  );

  Widget _smallShortcut(IconData icon, String label, VoidCallback onTap) =>
      ActionChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onPressed: onTap,
      );

  Widget _readingCard(BuildContext context) {
    final progress = readingProgressController.progress;
    if (progress == null) {
      return DesignAssetCard(
        key: const ValueKey('home-start-reading'),
        asset: 'assets/design/13_open_quran_illustration.webp',
        height: MediaQuery.textScalerOf(context).scale(1) > 1.2 ? 176 : 148,
        onTap: onOpenQuran,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('القرآن', style: TextStyle(color: AppColors.accentGold)),
            SizedBox(height: 4),
            Text(
              'ابدأ القراءة من المصحف',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Text('افتح المصحف'),
                SizedBox(width: 6),
                Icon(Icons.arrow_back_rounded, size: 18),
              ],
            ),
          ],
        ),
      );
    }
    final surah = QuranMetadata.surah(progress.surahNumber);
    final ayah = progress.ayahNumber;
    final value = ayah / surah.ayahCount;
    return DesignAssetCard(
      key: const ValueKey('home-continue-reading'),
      asset: 'assets/design/13_open_quran_illustration.webp',
      height: MediaQuery.textScalerOf(context).scale(1) > 1.2 ? 194 : 164,
      onTap: () => _openReader(context, surah.number, ayah),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, color: AppColors.accentGold),
              const SizedBox(width: AppSpacing.xs),
              const Expanded(child: Text('متابعة القراءة')),
              const Icon(Icons.arrow_back_rounded),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'سورة ${surah.name}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'الآية $ayah من ${surah.ayahCount}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppProgressBar(value: value),
        ],
      ),
    );
  }

  Widget _khatmaCard(BuildContext context) {
    final plan = khatmaController.activePlan;
    final progress = khatmaController.progress;
    final day = khatmaController.today;
    if (plan == null || progress == null) {
      return PremiumCard(
        key: const ValueKey('home-start-khatma'),
        onTap: onOpenKhatma,
        child: const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.auto_stories_rounded,
            color: AppColors.accentGold,
          ),
          title: Text('ابدأ خطة ختمة'),
          subtitle: Text('وزّع صفحات المصحف على مدة تناسبك'),
          trailing: Icon(Icons.arrow_back_rounded),
        ),
      );
    }
    final dayNumber = day == null ? 0 : plan.days.indexOf(day) + 1;
    final total = plan.endPage - plan.startPage + 1;
    return PremiumCard(
      key: const ValueKey('home-khatma-card'),
      onTap: onOpenKhatma,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_stories_rounded,
                color: AppColors.accentGold,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  day == null ? plan.title : '${plan.title} • اليوم $dayNumber',
                ),
              ),
              const Icon(Icons.arrow_back_rounded),
            ],
          ),
          const SizedBox(height: 8),
          Text('${progress.todayRemainingPages} صفحة متبقية اليوم'),
          const SizedBox(height: 8),
          AppProgressBar(
            value: total == 0 ? 0 : progress.completedPages / total,
          ),
        ],
      ),
    );
  }

  Widget _prayerCard(BuildContext context) {
    if (prayerController.error != null) {
      final settings =
          prayerController.locationFailure ==
              LocationFailureType.serviceDisabled ||
          prayerController.locationFailure ==
              LocationFailureType.permissionDeniedForever;
      return PremiumCard(
        key: const ValueKey('home-prayer-unavailable'),
        child: Row(
          children: [
            const Icon(Icons.location_off_rounded),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(prayerController.error!)),
            if (settings)
              IconButton(
                onPressed: prayerController.openRelevantSettings,
                icon: const Icon(Icons.settings_rounded),
              ),
            IconButton(
              onPressed: prayerController.refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      );
    }
    final prayer = prayerController.nextPrayer;
    return DesignAssetCard(
      key: const ValueKey('home-prayer-card'),
      asset: 'assets/design/02_prayer_card_bg.webp',
      height: MediaQuery.textScalerOf(context).scale(1) > 1.2 ? 214 : 182,
      onTap: onOpenPrayerTimes,
      overlay: const [Color(0xF20A2421), Color(0x7A123F37)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'الصلاة القادمة',
            style: TextStyle(color: AppColors.accentGold),
          ),
          const SizedBox(height: 4),
          Text(
            prayer?.name ?? 'مواقيت الصلاة',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (prayer != null) ...[
            Text(
              _formatDuration(prayerController.countdown),
              textDirection: TextDirection.ltr,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text('الأذان ${_formatTime(prayer.time)}'),
          ] else
            Text(
              prayerController.isLoading
                  ? 'جارٍ تحديد موقعك'
                  : 'اضغط لعرض مواقيت اليوم',
            ),
        ],
      ),
    );
  }

  Widget _dailyIslamicCard(BuildContext context) {
    final state = dailyIslamicController.state;
    return DesignAssetCard(
      key: const ValueKey('home-daily-islamic-card'),
      asset: 'assets/design/04_daily_card_bg.webp',
      height: MediaQuery.textScalerOf(context).scale(1) > 1.2 ? 152 : 124,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DailyIslamicPage(controller: dailyIslamicController),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.nights_stay_outlined, color: AppColors.accentGold),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  state == null
                      ? 'اليوم الإسلامي'
                      : state.hijriDate.formattedArabic,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  state == null
                      ? 'جارٍ تجهيز تاريخ اليوم'
                      : dailyHomeSummary(state),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_back_rounded),
        ],
      ),
    );
  }

  Widget _activeAction(BuildContext context) {
    final due = memorizationController.dueReviewAyahs.length;
    final action = selectHomeContextualAction(
      dueReviewCount: due,
      hasActiveKhatma: khatmaController.activePlan != null,
    );
    if (action == HomeContextualAction.memorization) {
      return PremiumCard(
        key: const ValueKey('home-context-memorization'),
        onTap: onOpenMemorization,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.workspace_premium_rounded,
            color: AppColors.accentGold,
          ),
          title: const Text('مراجعة الحفظ'),
          subtitle: Text('$due آيات جاهزة للمراجعة'),
          trailing: const Icon(Icons.arrow_back_rounded),
        ),
      );
    }
    if (action == HomeContextualAction.khatma) return _khatmaCard(context);
    return PremiumCard(
      key: const ValueKey('home-context-adhkar'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdhkarPage(controller: adhkarController),
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(
          Icons.auto_awesome_rounded,
          color: AppColors.accentGold,
        ),
        title: Text(_adhkarLabel()),
        subtitle: const Text('ورد مناسب لهذا الوقت'),
        trailing: const Icon(Icons.arrow_back_rounded),
      ),
    );
  }

  void _openReader(BuildContext context, int surah, int ayah) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuranReaderPage(
            controller: quranController,
            surahNumber: surah,
            initialAyah: ayah,
            readingProgressController: readingProgressController,
            bookmarkController: bookmarkController,
            audioController: audioController,
            memorizationController: memorizationController,
          ),
        ),
      );
  String _adhkarLabel() {
    final category = adhkarController.recommendedCategory;
    if (category == null) {
      return DateTime.now().hour < 15 ? 'أذكار الصباح' : 'أذكار المساء';
    }
    final session = adhkarController.currentSession;
    if (session?.categoryId != category.id) {
      return '${category.title} • ابدأ الأذكار';
    }
    final items = adhkarController.itemsFor(category.id);
    final done = session!.progress.values.fold<int>(0, (a, b) => a + b);
    final total = items.fold<int>(0, (a, b) => a + b.repeatCount);
    return '${category.title} • $done من $total';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    return '$hour:${time.minute.toString().padLeft(2, '0')} ${time.hour >= 12 ? 'م' : 'ص'}';
  }

  String _formatDuration(Duration? value) {
    if (value == null || value.isNegative) return '--:--:--';
    final hours = value.inHours.toString().padLeft(2, '0');
    final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}
