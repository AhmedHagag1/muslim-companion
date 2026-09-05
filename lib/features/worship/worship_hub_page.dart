import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/app_components.dart';
import '../../app/widgets/design_asset_card.dart';
import '../prayer/prayer_controller.dart';

class WorshipHubPage extends StatelessWidget {
  const WorshipHubPage({
    super.key,
    required this.prayerController,
    required this.onOpenPrayer,
    required this.onOpenQibla,
    required this.onOpenAdhkar,
    required this.onOpenDuas,
    required this.onOpenTasbeeh,
    required this.onOpenDaily,
  });

  final PrayerController prayerController;
  final VoidCallback onOpenPrayer;
  final VoidCallback onOpenQibla;
  final VoidCallback onOpenAdhkar;
  final VoidCallback onOpenDuas;
  final VoidCallback onOpenTasbeeh;
  final VoidCallback onOpenDaily;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('العبادة')),
    body: AnimatedBuilder(
      animation: prayerController,
      builder: (context, _) => ListView(
        key: const ValueKey('worship-hub'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          140,
        ),
        children: [
          DesignAssetCard(
            key: const ValueKey('worship-prayer-priority'),
            asset: 'assets/design/12_mosque_silhouette.webp',
            height: MediaQuery.textScalerOf(context).scale(1) > 1.2 ? 204 : 168,
            onTap: onOpenPrayer,
            semanticLabel: 'فتح مواقيت الصلاة',
            overlay: const [Color(0xF20A2421), Color(0x8A123F37)],
            child: _PrayerSummary(controller: prayerController),
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppSectionHeader('عبادتك اليومية'),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
              final columns = constraints.maxWidth < 340 || largeText ? 1 : 2;
              final width = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - AppSpacing.sm) / 2;
              final tiles = [
                IllustratedHubTile(
                  key: const ValueKey('worship-qibla'),
                  asset: 'assets/design/16_qibla_compass_illustration.png',
                  title: 'القبلة',
                  subtitle: 'الاتجاه من موقعك',
                  onTap: onOpenQibla,
                ),
                IllustratedHubTile(
                  key: const ValueKey('worship-adhkar'),
                  asset: 'assets/design/17_adhkar_illustration.png',
                  title: 'الأذكار',
                  subtitle: 'أذكار اليوم',
                  onTap: onOpenAdhkar,
                ),
                IllustratedHubTile(
                  key: const ValueKey('worship-duas'),
                  asset: 'assets/design/18_dua_illustration.png',
                  title: 'الأدعية',
                  subtitle: 'أدعية موثقة',
                  onTap: onOpenDuas,
                ),
                IllustratedHubTile(
                  key: const ValueKey('worship-tasbeeh'),
                  asset: 'assets/design/15_tasbeeh_illustration.png',
                  title: 'السبحة',
                  subtitle: 'عداد التسبيح',
                  onTap: onOpenTasbeeh,
                ),
                IllustratedHubTile(
                  key: const ValueKey('worship-daily'),
                  asset: 'assets/design/19_hijri_calendar_illustration.png',
                  title: 'اليوم الإسلامي',
                  subtitle: 'التاريخ الهجري والمواسم',
                  onTap: onOpenDaily,
                ),
              ];
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final tile in tiles)
                    SizedBox(
                      width: width,
                      height: largeText ? 190 : 170,
                      child: tile,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _PrayerSummary extends StatelessWidget {
  const _PrayerSummary({required this.controller});
  final PrayerController controller;

  @override
  Widget build(BuildContext context) {
    final next = controller.nextPrayer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'مواقيت الصلاة',
          style: TextStyle(color: AppColors.accentGold),
        ),
        const SizedBox(height: 6),
        Text(
          next?.name ??
              (controller.isLoading ? 'جارٍ تحديد الموقع' : 'مواقيت اليوم'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          next == null ? 'اضغط لعرض التفاصيل' : _formatTime(next.time),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        const Spacer(),
        const Row(
          children: [
            Text('عرض المواقيت', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(width: 6),
            Icon(Icons.arrow_back_rounded, size: 18),
          ],
        ),
      ],
    );
  }

  String _formatTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return '$hour:${value.minute.toString().padLeft(2, '0')} ${value.hour >= 12 ? 'م' : 'ص'}';
  }
}
