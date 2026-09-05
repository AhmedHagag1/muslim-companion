import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/app_components.dart';
import '../../core/services/islamic_daily_service.dart';
import '../../data/models/islamic_daily.dart';
import 'daily_islamic_controller.dart';

class DailyIslamicPage extends StatelessWidget {
  const DailyIslamicPage({super.key, required this.controller});

  final DailyIslamicController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('اليوم الإسلامي')),
    body: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        if (!controller.loaded) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state == null) {
          return const AppEmptyState(
            icon: Icons.calendar_month_outlined,
            title: 'التاريخ غير متاح',
            message: 'يتوفر التحويل المحلي للتواريخ بين 1900 و2076 ميلاديًا.',
          );
        }
        return ListView(
          key: const ValueKey('daily-islamic-page'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          children: [
            _DateHero(state: state),
            const SizedBox(height: AppSpacing.md),
            PremiumCard(
              key: const ValueKey('open-hijri-calendar'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HijriCalendarPage(controller: controller),
                ),
              ),
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.accentGold,
                ),
                title: Text('التقويم الهجري'),
                subtitle: Text('عرض الشهر واختيار يوم'),
                trailing: Icon(Icons.arrow_back_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _IndicatorsCard(state: state),
            const SizedBox(height: AppSpacing.md),
            _NightCard(state: state),
            const SizedBox(height: AppSpacing.md),
            _DhuhaCard(state: state),
            const SizedBox(height: AppSpacing.md),
            _OccasionCard(state: state),
          ],
        );
      },
    ),
  );
}

class _DateHero extends StatelessWidget {
  const _DateHero({required this.state});
  final DailyIslamicState state;

  @override
  Widget build(BuildContext context) => PremiumCard(
    child: Column(
      children: [
        const Icon(Icons.nights_stay_rounded, color: AppColors.accentGold),
        const SizedBox(height: 8),
        Text(
          state.hijriDate.formattedArabic,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          _gregorian(state.gregorianDate),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        const Text(
          IslamicDailyService.moonSightingDisclaimerArabic,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, height: 1.45),
        ),
      ],
    ),
  );
}

class _IndicatorsCard extends StatelessWidget {
  const _IndicatorsCard({required this.state});
  final DailyIslamicState state;

  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      if (state.fastingDays.contains(FastingDayType.monday)) 'الاثنين',
      if (state.fastingDays.contains(FastingDayType.thursday)) 'الخميس',
      if (state.fastingDays.contains(FastingDayType.whiteDay))
        'من الأيام البيض (13–15)',
    ];
    return _SectionCard(
      icon: Icons.event_available_rounded,
      title: 'مؤشرات أيام الصيام',
      child: Text(
        labels.isEmpty ? 'لا يوجد مؤشر تقويمي لهذا اليوم.' : labels.join(' • '),
      ),
    );
  }
}

class _NightCard extends StatelessWidget {
  const _NightCard({required this.state});
  final DailyIslamicState state;

  @override
  Widget build(BuildContext context) {
    final night = state.night;
    return _SectionCard(
      icon: Icons.dark_mode_rounded,
      title: 'أوقات الليل المحسوبة',
      child: night == null
          ? const Text('تظهر بعد توفر مواقيت المغرب وفجر اليوم التالي.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('منتصف الليل المحسوب: ${_time(night.midpoint)}'),
                const SizedBox(height: 6),
                Text(
                  'الثلث الأخير يبدأ تقريبًا: ${_time(night.lastThirdStart)}',
                ),
                const SizedBox(height: 6),
                Text(
                  'مدة الليل: ${night.duration.inHours} س ${night.duration.inMinutes.remainder(60)} د',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
    );
  }
}

class _DhuhaCard extends StatelessWidget {
  const _DhuhaCard({required this.state});
  final DailyIslamicState state;

  @override
  Widget build(BuildContext context) {
    final dhuha = state.dhuha;
    return _SectionCard(
      icon: Icons.wb_sunny_outlined,
      title: 'نافذة الضحى المحسوبة',
      child: dhuha == null
          ? const Text('تظهر بعد توفر وقتي الشروق والظهر.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_time(dhuha.start)} – ${_time(dhuha.end)}'),
                const SizedBox(height: 6),
                const Text(
                  'إرشاد حسابي: بعد الشروق بـ20 دقيقة وحتى قبل الظهر بـ10 دقائق، وليس تحديدًا لوقت الفضيلة.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
    );
  }
}

class _OccasionCard extends StatelessWidget {
  const _OccasionCard({required this.state});
  final DailyIslamicState state;

  @override
  Widget build(BuildContext context) {
    final today = state.todayOccasion;
    final upcoming = state.upcomingOccasion;
    return _SectionCard(
      icon: Icons.auto_awesome_outlined,
      title: today == null ? 'المناسبة المحسوبة القادمة' : 'اليوم',
      child: Text(
        today?.titleArabic ??
            (upcoming == null
                ? 'لا تتوفر مناسبة ضمن النطاق المحسوب.'
                : '${upcoming.titleArabic}\n${_gregorian(state.upcomingOccasionDate!)}'),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => PremiumCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.accentGold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class HijriCalendarPage extends StatefulWidget {
  const HijriCalendarPage({super.key, required this.controller});
  final DailyIslamicController controller;

  @override
  State<HijriCalendarPage> createState() => _HijriCalendarPageState();
}

class _HijriCalendarPageState extends State<HijriCalendarPage> {
  late int _year;
  late int _month;
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    final today = widget.controller.state!.hijriDate;
    _year = today.year;
    _month = today.month;
    _selectedDay = today.day;
  }

  void _changeMonth(int delta) {
    setState(() {
      _month += delta;
      if (_month < 1) {
        _month = 12;
        _year--;
      } else if (_month > 12) {
        _month = 1;
        _year++;
      }
      _selectedDay = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.controller.service;
    final settings = widget.controller.settings;
    final count = service.daysInMonth(_year, _month);
    final firstGregorian = service.toGregorian(
      HijriDate(year: _year, month: _month, day: 1),
      adjustment: settings.hijriAdjustment,
    );
    final selected = HijriDate(year: _year, month: _month, day: _selectedDay);
    final selectedGregorian = service.toGregorian(
      selected,
      adjustment: settings.hijriAdjustment,
    );
    final leading = firstGregorian?.weekday.remainder(7) ?? 0;
    final occasion = service.occasionFor(selected);
    final indicators = selectedGregorian == null
        ? const <FastingDayType>{}
        : service.fastingIndicators(selectedGregorian, selected);

    return Scaffold(
      appBar: AppBar(title: const Text('التقويم الهجري المحسوب')),
      body: ListView(
        key: const ValueKey('hijri-calendar-page'),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          PremiumCard(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'الشهر التالي',
                      onPressed: () => _changeMonth(1),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                    Expanded(
                      child: Text(
                        '${hijriMonthNamesArabic[_month - 1]} $_year هـ',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'الشهر السابق',
                      onPressed: () => _changeMonth(-1),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final day in ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س'])
                      Expanded(child: Center(child: Text(day))),
                  ],
                ),
                const SizedBox(height: 4),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: leading + count,
                  itemBuilder: (context, index) {
                    if (index < leading) return const SizedBox.shrink();
                    final day = index - leading + 1;
                    final date = HijriDate(
                      year: _year,
                      month: _month,
                      day: day,
                    );
                    final marked =
                        service.occasionFor(date) != null ||
                        (day >= 13 && day <= 15);
                    final selectedCell = day == _selectedDay;
                    return Semantics(
                      button: true,
                      selected: selectedCell,
                      label: '$day ${date.monthNameArabic}',
                      child: InkWell(
                        key: ValueKey('hijri-day-$day'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _selectedDay = day),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: selectedCell
                                ? AppColors.accentGold.withValues(alpha: 0.22)
                                : null,
                            borderRadius: BorderRadius.circular(10),
                            border: selectedCell
                                ? Border.all(color: AppColors.accentGold)
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('$day'),
                              if (marked)
                                const Icon(
                                  Icons.circle,
                                  size: 5,
                                  color: AppColors.accentGold,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected.formattedArabic,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (selectedGregorian != null)
                  Text(
                    _gregorian(selectedGregorian),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                if (occasion != null) ...[
                  const SizedBox(height: 8),
                  Text(occasion.titleArabic),
                ],
                if (indicators.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_fastingLabels(indicators)),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            IslamicDailyService.moonSightingDisclaimerArabic,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

String dailyHomeSummary(DailyIslamicState state) {
  if (state.fastingDays.contains(FastingDayType.whiteDay)) {
    return 'اليوم من الأيام البيض';
  }
  if (state.todayOccasion != null) return state.todayOccasion!.titleArabic;
  if (state.night != null) {
    return 'الثلث الأخير يبدأ تقريبًا ${_time(state.night!.lastThirdStart)}';
  }
  return 'التاريخ الهجري المحسوب';
}

String _fastingLabels(Set<FastingDayType> values) => [
  if (values.contains(FastingDayType.monday)) 'الاثنين',
  if (values.contains(FastingDayType.thursday)) 'الخميس',
  if (values.contains(FastingDayType.whiteDay)) 'من الأيام البيض',
].join(' • ');

String _time(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  return '$hour:${value.minute.toString().padLeft(2, '0')} ${value.hour >= 12 ? 'م' : 'ص'}';
}

String _gregorian(DateTime value) =>
    '${value.day}/${value.month}/${value.year} م';
