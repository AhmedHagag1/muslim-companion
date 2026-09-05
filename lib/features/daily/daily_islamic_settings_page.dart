import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/app_components.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/islamic_daily.dart';
import '../settings/settings_controller.dart';

class DailyIslamicSettingsPage extends StatelessWidget {
  const DailyIslamicSettingsPage({super.key, required this.controller});
  final SettingsController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('التقويم الهجري واليوم الإسلامي')),
    body: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final settings = controller.dailyIslamicController.settings;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const AppSectionHeader('التاريخ الهجري'),
            const SizedBox(height: 8),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تعديل اليوم حسب الإعلان المحلي',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      key: const ValueKey('hijri-adjustment'),
                      segments: const [
                        ButtonSegment(value: -1, label: Text('−1')),
                        ButtonSegment(value: 0, label: Text('0')),
                        ButtonSegment(value: 1, label: Text('+1')),
                      ],
                      selected: {settings.hijriAdjustment},
                      onSelectionChanged: (value) =>
                          controller.updateDailySettings(
                            settings.copyWith(hijriAdjustment: value.first),
                          ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'التحويل محلي محسوب وفق أم القرى، وقد يختلف عن رؤية الهلال الرسمية في بلدك.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const AppSectionHeader('تذكيرات اختيارية'),
            const SizedBox(height: 8),
            PremiumCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _toggle(
                    key: const ValueKey('monday-fasting-reminder'),
                    title: 'تذكير صيام الاثنين',
                    value: settings.mondayReminder,
                    onChanged: (value) => _update(
                      settings.copyWith(mondayReminder: value),
                      value,
                    ),
                  ),
                  const Divider(height: 1),
                  _toggle(
                    key: const ValueKey('thursday-fasting-reminder'),
                    title: 'تذكير صيام الخميس',
                    value: settings.thursdayReminder,
                    onChanged: (value) => _update(
                      settings.copyWith(thursdayReminder: value),
                      value,
                    ),
                  ),
                  const Divider(height: 1),
                  _toggle(
                    key: const ValueKey('white-days-reminder'),
                    title: 'تذكير الأيام البيض',
                    subtitle: '13 و14 و15 هجريًا — تواريخ محسوبة',
                    value: settings.whiteDaysReminder,
                    onChanged: (value) => _update(
                      settings.copyWith(whiteDaysReminder: value),
                      value,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    key: const ValueKey('fasting-reminder-time'),
                    title: const Text('وقت تذكير الصيام'),
                    subtitle: const Text('مساء اليوم السابق'),
                    trailing: Text(
                      _formatReminder(settings.fastingReminderTime),
                    ),
                    onTap: () => _pickTime(context, settings),
                  ),
                  const Divider(height: 1),
                  _toggle(
                    key: const ValueKey('last-third-reminder'),
                    title: 'بداية الثلث الأخير المحسوبة',
                    subtitle: 'يتطلب مواقيت المغرب وفجر اليوم التالي',
                    value: settings.lastThirdReminder,
                    onChanged: (value) => _update(
                      settings.copyWith(lastThirdReminder: value),
                      value,
                    ),
                  ),
                  const Divider(height: 1),
                  _toggle(
                    key: const ValueKey('dhuha-reminder'),
                    title: 'بداية نافذة الضحى المحسوبة',
                    subtitle: 'بعد الشروق بـ20 دقيقة',
                    value: settings.dhuhaReminder,
                    onChanged: (value) =>
                        _update(settings.copyWith(dhuhaReminder: value), value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'كل التذكيرات متوقفة افتراضيًا، ولا تُنشأ تذكيرات أوقات الليل أو الضحى عند غياب مواقيت الصلاة اللازمة.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        );
      },
    ),
  );

  SwitchListTile _toggle({
    required Key key,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => SwitchListTile(
    key: key,
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
    value: value,
    onChanged: onChanged,
  );

  void _update(IslamicCalendarSettings settings, bool enabling) {
    controller.updateDailySettings(settings, explicitEnable: enabling);
  }

  Future<void> _pickTime(
    BuildContext context,
    IslamicCalendarSettings settings,
  ) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.fastingReminderTime.hour,
        minute: settings.fastingReminderTime.minute,
      ),
    );
    if (selected == null) return;
    await controller.updateDailySettings(
      settings.copyWith(
        fastingReminderTime: ReminderTime(selected.hour, selected.minute),
      ),
    );
  }

  String _formatReminder(ReminderTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}
