import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/app_components.dart';
import '../../app/widgets/design_asset_card.dart';
import '../../data/models/listening_history.dart';
import '../../data/models/reciter.dart';
import '../../data/models/surah.dart';
import 'quran_audio_controller.dart';

class ListeningPage extends StatefulWidget {
  const ListeningPage({super.key, this.controller});
  final QuranAudioController? controller;

  @override
  State<ListeningPage> createState() => _ListeningPageState();
}

class _ListeningPageState extends State<ListeningPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الاستماع')),
    body: widget.controller == null
        ? const AppEmptyState(
            icon: Icons.headphones_rounded,
            title: 'الاستماع غير متاح',
            message: 'تعذر تهيئة مشغل التلاوة على هذا الجهاز.',
          )
        : AnimatedBuilder(
            animation: widget.controller!,
            builder: (context, _) => _buildLibrary(widget.controller!),
          ),
  );

  Widget _buildLibrary(QuranAudioController controller) {
    final normalized = _normalize(_query);
    final surahs = QuranMetadata.surahs
        .where((surah) => _normalize(surah.name).contains(normalized))
        .toList(growable: false);
    return Semantics(
      label: 'مكتبة 114 سورة',
      child: CustomScrollView(
        key: const ValueKey('listening-library'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            sliver: SliverList.list(
              children: [
                DesignAssetCard(
                  key: const ValueKey('listening-hero'),
                  asset: 'assets/design/03_listening_bg.webp',
                  height: MediaQuery.textScalerOf(context).scale(1) > 1.2
                      ? 184
                      : 154,
                  overlay: const [Color(0xEC061B1A), Color(0x7A123F37)],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'الاستماع',
                        style: TextStyle(color: AppColors.accentGold),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        controller.hasActiveItem
                            ? 'سورة ${QuranMetadata.surah(controller.currentSurahNumber!).name}'
                            : 'تلاوات القرآن الكريم',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        controller.hasActiveItem
                            ? controller.selectedReciter?.displayNameArabic ??
                                  'التلاوة الحالية'
                            : 'اختر القارئ ثم السورة',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _ReciterSelector(controller: controller),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey('listening-surah-search'),
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن سورة',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'مسح البحث',
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                if (controller.error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _AudioErrorCard(controller: controller),
                ],
                if (controller.hasActiveItem) ...[
                  const SizedBox(height: AppSpacing.md),
                  _NowPlayingCard(
                    controller: controller,
                    onOpen: () => _openPlayer(controller),
                  ),
                ],
                if (controller.history.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'استمع مؤخرًا',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 112,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: controller.history.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (context, index) => _RecentSurahCard(
                        entry: controller.history[index],
                        onTap: () =>
                            _resume(controller, controller.history[index]),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'سور القرآن',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Text(
                      '${surahs.length} سورة',
                      key: const ValueKey('listening-surah-count'),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
          if (surahs.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.search_off_rounded,
                asset: 'assets/design/21_empty_no_results.webp',
                title: 'لا توجد سورة بهذا الاسم',
                message: 'جرّب كتابة اسم آخر.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                180,
              ),
              sliver: SliverList.separated(
                itemCount: surahs.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final surah = surahs[index];
                  final active = controller.currentSurahNumber == surah.number;
                  return _SurahAudioTile(
                    key: ValueKey('listening-surah-${surah.number}'),
                    surah: surah,
                    active: active,
                    onTap: () => _playSurah(controller, surah.number),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _playSurah(
    QuranAudioController controller,
    int surahNumber,
  ) async {
    final played = await controller.playSurah(surahNumber);
    if (played && mounted) await _openPlayer(controller);
  }

  Future<void> _resume(
    QuranAudioController controller,
    ListeningHistoryEntry entry,
  ) async {
    final played = await controller.resumeHistory(entry);
    if (played && mounted) await _openPlayer(controller);
  }

  Future<void> _openPlayer(QuranAudioController controller) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/listening/player'),
          builder: (_) => ListeningPlayerPage(controller: controller),
        ),
      );

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .trim();
}

class _ReciterSelector extends StatelessWidget {
  const _ReciterSelector({required this.controller});
  final QuranAudioController controller;

  @override
  Widget build(BuildContext context) => PremiumCard(
    child: Row(
      children: [
        const CircleAvatar(child: Icon(Icons.mic_rounded)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'القارئ',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              Text(
                controller.selectedReciter?.displayNameArabic ??
                    'لا يوجد قارئ متاح',
                key: const ValueKey('selected-reciter-name'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        PopupMenuButton<Reciter>(
          key: const ValueKey('reciter-selector'),
          enabled: controller.reciters.isNotEmpty,
          tooltip: 'اختيار القارئ',
          onSelected: controller.selectReciter,
          itemBuilder: (context) => controller.reciters
              .map(
                (reciter) => PopupMenuItem(
                  value: reciter,
                  child: Text(reciter.displayNameArabic),
                ),
              )
              .toList(),
          icon: const Icon(Icons.expand_more_rounded),
        ),
      ],
    ),
  );
}

class _NowPlayingCard extends StatelessWidget {
  const _NowPlayingCard({required this.controller, required this.onOpen});
  final QuranAudioController controller;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final surah = QuranMetadata.surah(controller.currentSurahNumber!);
    return PremiumCard(
      onTap: onOpen,
      child: Row(
        children: [
          const Icon(Icons.graphic_eq_rounded, color: AppColors.accentGold),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'يُشغّل الآن',
                  style: TextStyle(color: AppColors.accentGold),
                ),
                Text(
                  'سورة ${surah.name} • الآية ${controller.currentAyahNumber}',
                ),
              ],
            ),
          ),
          const Icon(Icons.open_in_full_rounded),
        ],
      ),
    );
  }
}

class _RecentSurahCard extends StatelessWidget {
  const _RecentSurahCard({required this.entry, required this.onTap});
  final ListeningHistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surah = QuranMetadata.surah(entry.surahNumber);
    return SizedBox(
      width: 172,
      child: PremiumCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'سورة ${surah.name}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'متابعة من الآية ${entry.ayahNumber}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurahAudioTile extends StatelessWidget {
  const _SurahAudioTile({
    super.key,
    required this.surah,
    required this.active,
    required this.onTap,
  });
  final Surah surah;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PremiumCard(
    onTap: onTap,
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: active
              ? AppColors.accentGold
              : AppColors.surfaceSoft,
          foregroundColor: active
              ? AppColors.appBackground
              : AppColors.textPrimary,
          child: Text('${surah.number}'),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سورة ${surah.name}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${surah.ayahCount} آية • ${surah.revelationType}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Icon(
          active ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded,
          color: active ? AppColors.accentGold : AppColors.textSecondary,
        ),
      ],
    ),
  );
}

class ListeningPlayerPage extends StatelessWidget {
  const ListeningPlayerPage({super.key, required this.controller});
  final QuranAudioController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      if (!controller.hasActiveItem) {
        return Scaffold(
          appBar: AppBar(title: const Text('مشغل التلاوة')),
          body: const AppEmptyState(
            icon: Icons.headphones_rounded,
            title: 'لا توجد تلاوة نشطة',
            message: 'اختر سورة من مكتبة الاستماع.',
          ),
        );
      }
      final surah = QuranMetadata.surah(controller.currentSurahNumber!);
      final busy =
          controller.status == QuranAudioStatus.loading ||
          controller.status == QuranAudioStatus.buffering;
      return Scaffold(
        key: const ValueKey('listening-full-player'),
        appBar: AppBar(
          title: const Text('الاستماع'),
          actions: [
            IconButton(
              key: const ValueKey('listening-queue'),
              tooltip: 'قائمة آيات السورة',
              onPressed: () => _showQueue(context, surah),
              icon: const Icon(Icons.queue_music_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            120,
          ),
          children: [
            const _ListeningArtwork(),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'سورة ${surah.name}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              controller.selectedReciter?.displayNameArabic ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'الآية ${controller.currentAyahNumber} من ${surah.ayahCount}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.accentGold),
            ),
            const SizedBox(height: AppSpacing.lg),
            Slider(
              key: const ValueKey('listening-seek'),
              value: controller.positionFraction,
              onChanged: controller.canSeek
                  ? (value) => controller.seekToFraction(value)
                  : null,
            ),
            Row(
              children: [
                Text(_formatDuration(controller.position)),
                const Spacer(),
                Text(
                  controller.duration == null
                      ? '--:--'
                      : _formatDuration(controller.duration!),
                ),
              ],
            ),
            if (controller.error != null) ...[
              const SizedBox(height: AppSpacing.md),
              _AudioErrorCard(controller: controller),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton.filledTonal(
                  tooltip: 'الآية السابقة',
                  onPressed: controller.canPreviousAyah
                      ? controller.previousAyah
                      : null,
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
                FilledButton(
                  key: const ValueKey('listening-play-pause'),
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(24),
                    backgroundColor: AppColors.accentGold,
                    foregroundColor: AppColors.appBackground,
                  ),
                  onPressed: busy
                      ? null
                      : controller.isPlaying
                      ? controller.pause
                      : controller.resume,
                  child: busy
                      ? const SizedBox.square(
                          dimension: 30,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          controller.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 40,
                        ),
                ),
                IconButton.filledTonal(
                  tooltip: 'الآية التالية',
                  onPressed: controller.canNextAyah
                      ? controller.nextAyah
                      : null,
                  icon: const Icon(Icons.skip_next_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            PremiumCard(
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      key: const ValueKey('previous-surah'),
                      onPressed: controller.canPreviousSurah
                          ? controller.playPreviousSurah
                          : null,
                      icon: const Icon(Icons.first_page_rounded),
                      label: const Text('السورة السابقة'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      key: const ValueKey('next-surah'),
                      onPressed: controller.canNextSurah
                          ? controller.playNextSurah
                          : null,
                      icon: const Icon(Icons.last_page_rounded),
                      label: const Text('السورة التالية'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PremiumCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  PopupMenuButton<double>(
                    key: const ValueKey('playback-speed'),
                    tooltip: 'سرعة التشغيل',
                    onSelected: controller.setPlaybackSpeed,
                    itemBuilder: (context) =>
                        const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                            .map(
                              (speed) => PopupMenuItem(
                                value: speed,
                                child: Text('$speed×'),
                              ),
                            )
                            .toList(),
                    child: _PlayerOption(
                      icon: Icons.speed_rounded,
                      label: '${controller.playbackSpeed}×',
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('repeat-mode'),
                    onPressed: controller.cycleRepeatMode,
                    child: _PlayerOption(
                      icon: controller.repeatMode == QuranRepeatMode.ayah
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      label: _repeatLabel(controller.repeatMode),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _showQueue(BuildContext context, Surah surah) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            children: [
              Text(
                'آيات سورة ${surah.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ListView.builder(
                  itemCount: surah.ayahCount,
                  itemBuilder: (context, index) {
                    final ayah = index + 1;
                    return ListTile(
                      selected: controller.currentAyahNumber == ayah,
                      leading: CircleAvatar(child: Text('$ayah')),
                      title: Text('الآية $ayah'),
                      trailing: const Icon(Icons.play_arrow_rounded),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        controller.playSurah(surah.number, initialAyah: ayah);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
}

class _ListeningArtwork extends StatelessWidget {
  const _ListeningArtwork();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 230,
      height: 230,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: const DecorationImage(
          image: ResizeImage(
            AssetImage('assets/design/03_listening_bg.webp'),
            width: 520,
          ),
          fit: BoxFit.cover,
          opacity: 0.48,
        ),
        gradient: const RadialGradient(
          colors: [AppColors.surfaceSoft, AppColors.appBackground],
        ),
        border: Border.all(color: AppColors.accentGold, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x553D806B), blurRadius: 32, spreadRadius: 4),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.divider),
            ),
          ),
          const Icon(
            Icons.auto_awesome_rounded,
            size: 64,
            color: AppColors.accentGold,
          ),
        ],
      ),
    ),
  );
}

class _PlayerOption extends StatelessWidget {
  const _PlayerOption({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon),
      const SizedBox(height: AppSpacing.xxs),
      Text(label),
    ],
  );
}

class _AudioErrorCard extends StatelessWidget {
  const _AudioErrorCard({required this.controller});
  final QuranAudioController controller;

  @override
  Widget build(BuildContext context) => PremiumCard(
    child: Row(
      children: [
        const Icon(Icons.info_outline_rounded, color: AppColors.error),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(controller.error!)),
        TextButton(
          onPressed: controller.retry,
          child: const Text('إعادة المحاولة'),
        ),
      ],
    ),
  );
}

String _repeatLabel(QuranRepeatMode mode) => switch (mode) {
  QuranRepeatMode.off => 'بدون تكرار',
  QuranRepeatMode.ayah => 'تكرار الآية',
  QuranRepeatMode.surah => 'تكرار السورة',
};

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
