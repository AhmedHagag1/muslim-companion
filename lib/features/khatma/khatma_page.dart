import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/app_components.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/khatma.dart';
import '../audio/quran_audio_controller.dart';
import '../bookmarks/bookmark_controller.dart';
import '../memorization/memorization_controller.dart';
import '../mushaf/data/mushaf_preferences.dart';
import '../mushaf/data/mushaf_repository.dart';
import '../mushaf/presentation/mushaf_page_view.dart';
import '../quran/quran_controller.dart';
import 'khatma_controller.dart';

class KhatmaPage extends StatelessWidget {
  const KhatmaPage({
    super.key,
    required this.controller,
    required this.currentReadingPage,
    required this.onStartWird,
  });
  final KhatmaController controller;
  final int currentReadingPage;
  final ValueChanged<int> onStartWird;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('خطة الختمة'),
        actions: [
          if (controller.history.isNotEmpty)
            IconButton(
              tooltip: 'سجل الختمات',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => KhatmaHistoryPage(plans: controller.history),
                ),
              ),
              icon: const Icon(Icons.history_rounded),
            ),
        ],
      ),
      body: !controller.loaded
          ? const Center(child: CircularProgressIndicator())
          : controller.activePlan == null
          ? _creation(context)
          : _active(context),
    ),
  );

  Widget _creation(BuildContext context) => _KhatmaCreation(
    controller: controller,
    currentReadingPage: currentReadingPage,
  );

  Widget _active(BuildContext context) {
    final plan = controller.activePlan!;
    final day = controller.today;
    final progress = controller.progress!;
    final dayNumber = day == null ? 0 : plan.days.indexOf(day) + 1;
    return ListView(
      key: const ValueKey('khatma-active-plan'),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (controller.message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PremiumCard(
              child: Text(controller.message!, textAlign: TextAlign.center),
            ),
          ),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => _planAction(context, value),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'title',
                        child: Text('تعديل العنوان'),
                      ),
                      PopupMenuItem(
                        value: 'date',
                        child: Text('تعديل تاريخ النهاية'),
                      ),
                      PopupMenuItem(
                        value: 'pause',
                        child: Text('إيقاف/استئناف'),
                      ),
                      PopupMenuItem(
                        value: 'archive',
                        child: Text('أرشفة الخطة'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value:
                    progress.completedPages /
                    (plan.endPage - plan.startPage + 1),
              ),
              const SizedBox(height: 8),
              Text(
                '${progress.completedPages} صفحة مكتملة • ${progress.remainingPages} متبقية',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PremiumCard(
          child: Column(
            children: [
              Text(
                day == null
                    ? 'لا يوجد ورد مجدول لهذا اليوم'
                    : 'اليوم $dayNumber من ${plan.days.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              if (day != null) ...[
                Text(
                  'الصفحات ${day.plannedStartPage}–${day.plannedEndPage}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentGold,
                  ),
                ),
                Text('${progress.todayRemainingPages} صفحة متبقية اليوم'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('khatma-start-wird'),
                    onPressed: plan.status == KhatmaPlanStatus.paused
                        ? null
                        : () => onStartWird(
                            (day.completedThroughPage ??
                                    day.plannedStartPage - 1) +
                                1,
                          ),
                    icon: const Icon(Icons.menu_book_rounded),
                    label: Text(
                      day.completedThroughPage == null
                          ? 'ابدأ ورد اليوم'
                          : 'تابع ورد اليوم',
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey('khatma-confirm-today'),
                  onPressed: day.isCompleted
                      ? null
                      : controller.confirmTodayCompleted,
                  child: Text(
                    day.isCompleted ? 'تم ورد اليوم' : 'تأكيد إتمام ورد اليوم',
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PremiumCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.notifications_none_rounded),
            title: const Text('تذكير الختمة'),
            subtitle: Text(
              plan.preferredReminderTime == null
                  ? 'متوقف'
                  : _time(plan.preferredReminderTime!),
            ),
            trailing: Switch(
              value: plan.preferredReminderTime != null,
              onChanged: (value) => value
                  ? _chooseReminder(context)
                  : controller.edit(clearReminder: true),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _planAction(BuildContext context, String value) async {
    final plan = controller.activePlan!;
    if (value == 'archive') {
      await controller.archive();
      return;
    }
    if (value == 'pause') {
      await controller.edit(
        status: plan.status == KhatmaPlanStatus.paused
            ? KhatmaPlanStatus.active
            : KhatmaPlanStatus.paused,
      );
      return;
    }
    if (value == 'title') {
      await _editTitle(context, plan);
      return;
    }
    final date = await showDatePicker(
      context: context,
      initialDate: plan.targetDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 604)),
    );
    if (date != null) await controller.edit(targetDate: date);
  }

  Future<void> _editTitle(BuildContext context, KhatmaPlan plan) async {
    var title = plan.title;
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('عنوان الختمة'),
        content: TextFormField(
          initialValue: plan.title,
          autofocus: true,
          onChanged: (value) => title = value,
          decoration: const InputDecoration(hintText: 'ختمة القرآن'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, title.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (saved != null && saved.isNotEmpty) await controller.edit(title: saved);
  }

  Future<void> _chooseReminder(BuildContext context) async {
    final chosen = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 20, minute: 0),
    );
    if (chosen != null) {
      await controller.edit(reminder: ReminderTime(chosen.hour, chosen.minute));
    }
  }
}

class _KhatmaCreation extends StatefulWidget {
  const _KhatmaCreation({
    required this.controller,
    required this.currentReadingPage,
  });
  final KhatmaController controller;
  final int currentReadingPage;
  @override
  State<_KhatmaCreation> createState() => _KhatmaCreationState();
}

class _KhatmaCreationState extends State<_KhatmaCreation> {
  KhatmaPlanType type = KhatmaPlanType.thirtyDays;
  bool fromCurrent = false;
  DateTime? target;
  bool saving = false;
  int get startPage =>
      fromCurrent ? widget.currentReadingPage.clamp(1, 604) : 1;
  @override
  Widget build(BuildContext context) {
    final preview = widget.controller.preview(
      type: type,
      startPage: startPage,
      customTarget: target,
    );
    return ListView(
      key: const ValueKey('khatma-create'),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Image.asset(
          'assets/design/24_empty_no_khatma.webp',
          height: 124,
          fit: BoxFit.contain,
          cacheWidth: 480,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'خطة هادئة وواضحة لختم القرآن، موزعة على صفحات المصحف الـ604.',
        ),
        const SizedBox(height: AppSpacing.lg),
        const AppSectionHeader('مدة الخطة'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in const [
              (KhatmaPlanType.thirtyDays, '30 يومًا'),
              (KhatmaPlanType.sixtyDays, '60 يومًا'),
              (KhatmaPlanType.ninetyDays, '90 يومًا'),
              (KhatmaPlanType.custom, 'تاريخ مخصص'),
            ])
              ChoiceChip(
                label: Text(item.$2),
                selected: type == item.$1,
                onSelected: (_) async {
                  setState(() => type = item.$1);
                  if (item.$1 == KhatmaPlanType.custom) {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 29)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 604)),
                    );
                    if (mounted) setState(() => target = date ?? target);
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SwitchListTile(
          value: fromCurrent,
          onChanged: (value) => setState(() => fromCurrent = value),
          title: const Text('ابدأ من صفحة القراءة الحالية'),
          subtitle: Text('صفحة $startPage'),
        ),
        const SizedBox(height: AppSpacing.md),
        PremiumCard(
          child: Column(
            children: [
              _Summary('الصفحات المتبقية', '${preview.remainingPages}'),
              _Summary(
                'المتوسط اليومي',
                preview.pagesPerDay.toStringAsFixed(1),
              ),
              _Summary(
                'النهاية المتوقعة',
                '${preview.targetDate.day}/${preview.targetDate.month}/${preview.targetDate.year}',
              ),
              const SizedBox(height: 6),
              const Text(
                'قد يختلف عدد الصفحات بيوم واحد لتوزيع الباقي دون تكرار.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          key: const ValueKey('create-khatma-plan'),
          onPressed: saving || (type == KhatmaPlanType.custom && target == null)
              ? null
              : () async {
                  setState(() => saving = true);
                  await widget.controller.create(
                    title: 'ختمة القرآن',
                    type: type,
                    startPage: startPage,
                    customTarget: target,
                  );
                },
          child: const Text('إنشاء الخطة'),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class KhatmaHistoryPage extends StatelessWidget {
  const KhatmaHistoryPage({super.key, required this.plans});
  final List<KhatmaPlan> plans;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('سجل الختمات')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        for (final plan in plans)
          PremiumCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(plan.title),
              subtitle: Text(
                '${plan.startDate.day}/${plan.startDate.month}/${plan.startDate.year} — ${plan.completedAt == null ? 'مؤرشفة' : '${plan.completedAt!.day}/${plan.completedAt!.month}/${plan.completedAt!.year}'}\n${plan.endPage - plan.startPage + 1} صفحة',
              ),
              trailing: Text('${plan.days.length} يومًا'),
            ),
          ),
      ],
    ),
  );
}

String _time(ReminderTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  return '$hour:${value.minute.toString().padLeft(2, '0')} ${value.hour >= 12 ? 'م' : 'ص'}';
}

class KhatmaMushafPage extends StatefulWidget {
  const KhatmaMushafPage({
    super.key,
    required this.initialPage,
    required this.khatmaController,
    required this.quranController,
    required this.bookmarkController,
    this.audioController,
    this.memorizationController,
  });
  final int initialPage;
  final KhatmaController khatmaController;
  final QuranController quranController;
  final BookmarkController bookmarkController;
  final QuranAudioController? audioController;
  final MemorizationController? memorizationController;

  @override
  State<KhatmaMushafPage> createState() => _KhatmaMushafPageState();
}

class _KhatmaMushafPageState extends State<KhatmaMushafPage> {
  bool _acceptProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _acceptProgress = true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('ورد الختمة'),
      actions: [
        TextButton(
          onPressed: widget.khatmaController.confirmTodayCompleted,
          child: const Text('إتمام الورد'),
        ),
      ],
    ),
    body: MushafPageView(
      repository: MadinaMushafRepository(),
      preferences: SharedPreferencesMushafPreferences(),
      quranController: widget.quranController,
      bookmarkController: widget.bookmarkController,
      audioController: widget.audioController,
      memorizationController: widget.memorizationController,
      initialPage: widget.initialPage,
      onPageChanged: (page) {
        if (_acceptProgress) widget.khatmaController.recordReachedPage(page);
      },
    ),
  );
}
