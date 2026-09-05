import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/app_components.dart';
import '../../core/services/location_service.dart';
import '../../core/services/prayer_models.dart';
import 'prayer_controller.dart';

class PrayerPage extends StatelessWidget {
  const PrayerPage({super.key, required this.controller});
  final PrayerController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text('مواقيت الصلاة'),
        ),
        actions: [
          IconButton(
            key: const ValueKey('prayer-settings'),
            tooltip: 'إعدادات الصلاة',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PrayerSettingsPage(controller: controller),
              ),
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            onPressed: controller.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: controller.isLoading && controller.prayers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : controller.error != null
          ? _PrayerUnavailable(controller: controller)
          : _content(context),
    ),
  );

  Widget _content(BuildContext context) {
    final result = controller.effectiveTimes;
    return ListView(
      key: const ValueKey('prayer-v2-page'),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          _formatDate(result?.date ?? DateTime.now()),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        PremiumCard(
          child: Column(
            children: [
              const Text(
                'الصلاة القادمة',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                controller.nextPrayer?.name ?? 'اكتملت صلوات اليوم',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (controller.nextPrayer != null) ...[
                Text(
                  _formatTime(controller.nextPrayer!.time),
                  style: const TextStyle(
                    fontSize: 24,
                    color: AppColors.accentGold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _formatCountdown(controller.countdown),
                  key: const ValueKey('prayer-countdown'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PremiumCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < controller.prayers.length; i++) ...[
                _PrayerTile(item: controller.prayers[i]),
                if (i < controller.prayers.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${result?.source == PrayerTimesSource.remote ? 'متصل' : 'حساب محلي'} • ${controller.settings.method.arabicName}',
                key: const ValueKey('prayer-source'),
              ),
              const SizedBox(height: 4),
              Text(
                'العصر: ${controller.settings.madhab.arabicName} • المنطقة: ${result?.timezone ?? '—'}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (controller.calculatedMidnight != null) ...[
          const SizedBox(height: AppSpacing.md),
          PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _DerivedTile(
                  'منتصف الليل • وقت محسوب',
                  controller.calculatedMidnight!,
                ),
                const Divider(height: 1),
                if (controller.calculatedLastThird != null)
                  _DerivedTile(
                    'بداية الثلث الأخير • وقت محسوب',
                    controller.calculatedLastThird!,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _formatDate(DateTime value) =>
      '${value.day}/${value.month}/${value.year}';
  static String _formatCountdown(Duration? duration) {
    if (duration == null || duration.isNegative) return '';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return 'متبقي ${hours > 0 ? '$hours س ' : ''}$minutes د';
  }
}

class PrayerSettingsPage extends StatelessWidget {
  const PrayerSettingsPage({super.key, required this.controller});
  final PrayerController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('إعدادات الصلاة')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const AppSectionHeader('طريقة الحساب'),
          const SizedBox(height: 8),
          PremiumCard(
            padding: EdgeInsets.zero,
            child: DropdownButtonFormField<PrayerCalculationMethod>(
              key: const ValueKey('prayer-method'),
              initialValue: controller.settings.method,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              items: PrayerCalculationMethod.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.arabicName),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  controller.updateSettings(
                    controller.settings.copyWith(method: value),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 18),
          const AppSectionHeader('مذهب العصر'),
          const SizedBox(height: 8),
          SegmentedButton<PrayerMadhab>(
            key: const ValueKey('prayer-madhab'),
            segments: PrayerMadhab.values
                .map(
                  (value) => ButtonSegment(
                    value: value,
                    label: Text(value.arabicName),
                  ),
                )
                .toList(),
            selected: {controller.settings.madhab},
            onSelectionChanged: (values) => controller.updateSettings(
              controller.settings.copyWith(madhab: values.first),
            ),
          ),
          const SizedBox(height: 18),
          const AppSectionHeader('معالجة خطوط العرض العليا'),
          const SizedBox(height: 8),
          PremiumCard(
            padding: EdgeInsets.zero,
            child: DropdownButtonFormField<PrayerHighLatitudeRule>(
              initialValue: controller.settings.highLatitudeRule,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              items: PrayerHighLatitudeRule.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.arabicName),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  controller.updateSettings(
                    controller.settings.copyWith(highLatitudeRule: value),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 18),
          const AppSectionHeader('التعديلات اليدوية بالدقائق'),
          const SizedBox(height: 8),
          PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < adjustablePrayerNames.length; i++) ...[
                  _AdjustmentRow(
                    controller: controller,
                    name: adjustablePrayerNames[i],
                  ),
                  if (i < adjustablePrayerNames.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _AdjustmentRow extends StatelessWidget {
  const _AdjustmentRow({required this.controller, required this.name});
  final PrayerController controller;
  final String name;
  @override
  Widget build(BuildContext context) {
    final value = controller.settings.adjustmentFor(name);
    return ListTile(
      title: Text(name),
      subtitle: Row(
        children: [
          IconButton(
            key: ValueKey('prayer-adjust-minus-$name'),
            onPressed: value <= -30
                ? null
                : () => controller.setAdjustment(name, value - 1),
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          Expanded(
            child: Text(
              'من -30 إلى +30',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            key: ValueKey('prayer-adjust-plus-$name'),
            onPressed: value >= 30
                ? null
                : () => controller.setAdjustment(name, value + 1),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      trailing: SizedBox(
        width: 42,
        child: Text(
          value > 0 ? '+$value' : '$value',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _PrayerUnavailable extends StatelessWidget {
  const _PrayerUnavailable({required this.controller});
  final PrayerController controller;
  @override
  Widget build(BuildContext context) {
    final failure = controller.locationFailure;
    final settingsLabel = failure == LocationFailureType.serviceDisabled
        ? 'تفعيل الموقع'
        : failure == LocationFailureType.permissionDeniedForever
        ? 'فتح إعدادات التطبيق'
        : null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_rounded, size: 48),
            const SizedBox(height: 16),
            Text(controller.error!, textAlign: TextAlign.center),
            if (settingsLabel != null)
              FilledButton.icon(
                key: const ValueKey('prayer-open-settings'),
                onPressed: controller.openRelevantSettings,
                icon: const Icon(Icons.settings_rounded),
                label: Text(settingsLabel),
              ),
            TextButton.icon(
              key: const ValueKey('prayer-retry'),
              onPressed: controller.refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrayerTile extends StatelessWidget {
  const _PrayerTile({required this.item});
  final PrayerTimeItem item;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(
      item.name == 'الشروق'
          ? Icons.wb_sunny_outlined
          : Icons.access_time_rounded,
    ),
    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
    trailing: Text(
      _formatTime(item.time),
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    ),
  );
}

class _DerivedTile extends StatelessWidget {
  const _DerivedTile(this.label, this.time);
  final String label;
  final DateTime time;
  @override
  Widget build(BuildContext context) =>
      ListTile(title: Text(label), trailing: Text(_formatTime(time)));
}

String _formatTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  return '$hour:${time.minute.toString().padLeft(2, '0')} ${time.hour >= 12 ? 'م' : 'ص'}';
}
