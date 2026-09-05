import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/app_components.dart';
import '../../data/models/memorization.dart';
import '../../data/models/surah.dart';
import '../audio/quran_audio_controller.dart';
import '../quran/quran_controller.dart';
import 'memorization_controller.dart';

class MemorizationPage extends StatelessWidget {
  const MemorizationPage({
    super.key,
    required this.controller,
    required this.quranController,
    this.audioController,
    this.onOpenAyah,
  });
  final MemorizationController controller;
  final QuranController quranController;
  final QuranAudioController? audioController;
  final Future<void> Function(QuranCoordinate coordinate)? onOpenAyah;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الحفظ')),
    body: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final plan = controller.activePlan;
        if (plan == null) {
          return AppEmptyState(
            key: const ValueKey('memorization-empty'),
            icon: Icons.workspace_premium_outlined,
            title: 'ابدأ أول خطة حفظ',
            message: 'أنشئ خطة حقيقية بنطاق وهدف يناسبان وقتك.',
            action: FilledButton(
              onPressed: () => _create(context),
              child: const Text('إنشاء خطة'),
            ),
          );
        }
        final completed = controller.completedFor(plan);
        return ListView(
          key: const ValueKey('memorization-dashboard'),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const AppSectionHeader('خطة نشطة'),
            const SizedBox(height: 12),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('$completed من ${plan.totalAyahs} آية'),
                  const SizedBox(height: 8),
                  AppProgressBar(value: controller.progressFor(plan)),
                  const SizedBox(height: 8),
                  Text(
                    'الموضع الحالي: ${_coordinateLabel(_next(plan))}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const AppSectionHeader('اختر نوع الجلسة'),
            const SizedBox(height: 8),
            PremiumCard(
              child: Column(
                children: [
                  _sessionModeTile(
                    context,
                    Icons.auto_stories_outlined,
                    'حفظ جديد',
                    'الآيات التالية في خطتك',
                    MemorizationSessionMode.newMemorization,
                  ),
                  _sessionModeTile(
                    context,
                    Icons.refresh_rounded,
                    'مراجعة قريبة',
                    'الآيات الحديثة المستحقة',
                    MemorizationSessionMode.nearReview,
                  ),
                  _sessionModeTile(
                    context,
                    Icons.history_rounded,
                    'مراجعة قديمة',
                    'الآيات الأقدم المستحقة',
                    MemorizationSessionMode.oldReview,
                  ),
                  _sessionModeTile(
                    context,
                    Icons.visibility_off_outlined,
                    'اختبار ذاتي',
                    'استحضار بلا درجات أو تقييم آلي',
                    MemorizationSessionMode.selfTest,
                  ),
                ],
              ),
            ),
            if (controller.weakReviewAyahs.isNotEmpty) ...[
              const SizedBox(height: 20),
              const AppSectionHeader('آيات تحتاج مراجعة'),
              const SizedBox(height: 8),
              PremiumCard(
                onTap: () => _startMode(
                  context,
                  MemorizationSessionMode.selfTest,
                  MemorizationTestMode.fullAyah,
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.replay_circle_filled_outlined),
                  title: Text('${controller.weakReviewAyahs.length} آيات'),
                  subtitle: const Text('بناءً على تقييمك أو مراجعة فات موعدها'),
                  trailing: const Icon(Icons.arrow_back_rounded),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const AppSectionHeader('جلسة اليوم'),
            const SizedBox(height: 12),
            PremiumCard(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.today_rounded,
                      color: AppColors.accentGold,
                    ),
                    title: Text('${plan.dailyNewAyahTarget} آيات جديدة'),
                    subtitle: Text(
                      '${controller.dueReviewAyahs.length} مراجعات مستحقة',
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _start(context),
                      child: Text(
                        controller.todaySession == null
                            ? 'ابدأ جلسة اليوم'
                            : 'استئناف جلسة اليوم',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          MemorizationHistoryPage(controller: controller),
                    ),
                  ),
                  child: const Text('السجل'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReviewQueuePage(
                        controller: controller,
                        quranController: quranController,
                        audioController: audioController,
                        onOpenAyah: onOpenAyah,
                      ),
                    ),
                  ),
                  child: const Text('المراجعات'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditMemorizationPlanPage(
                        controller: controller,
                        plan: plan,
                      ),
                    ),
                  ),
                  child: const Text('تعديل الخطة'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const AppSectionHeader('الخطط السابقة'),
            ...controller.plans
                .where((e) => e.id != plan.id)
                .map(
                  (e) => ListTile(
                    title: Text(e.title),
                    subtitle: Text(e.status.name),
                    onTap: () => controller.activatePlan(e.id),
                  ),
                ),
          ],
        );
      },
    ),
  );
  QuranCoordinate _next(MemorizationPlan plan) {
    final done = controller.memorizedAyahs
        .where((e) => e.planId == plan.id)
        .map((e) => e.coordinate)
        .toSet();
    return QuranRange.coordinates(
          plan.start,
          plan.end,
        ).where((e) => !done.contains(e)).firstOrNull ??
        plan.end;
  }

  Future<void> _create(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateMemorizationPlanPage(controller: controller),
      ),
    );
  }

  Future<void> _start(BuildContext context) async {
    final session = await controller.generateTodaySession();
    if (!context.mounted) return;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد مهام جديدة أو مراجعات مستحقة اليوم.'),
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemorizationSessionPage(
          controller: controller,
          quranController: quranController,
          audioController: audioController,
          onOpenAyah: onOpenAyah,
          session: session,
        ),
      ),
    );
  }

  Widget _sessionModeTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    MemorizationSessionMode mode,
  ) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.arrow_back_rounded),
    onTap: () async {
      final testMode = await showModalBottomSheet<MemorizationTestMode>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('طريقة الاستظهار')),
              _testModeItem(
                context,
                'إخفاء الآية كاملة',
                MemorizationTestMode.fullAyah,
              ),
              _testModeItem(
                context,
                'إظهار الكلمات الأولى',
                MemorizationTestMode.firstWords,
              ),
              _testModeItem(
                context,
                'كشف تدريجي',
                MemorizationTestMode.progressiveReveal,
              ),
              _testModeItem(
                context,
                'ما الآية التالية؟',
                MemorizationTestMode.nextAyah,
              ),
            ],
          ),
        ),
      );
      if (testMode != null && context.mounted) {
        await _startMode(context, mode, testMode);
      }
    },
  );

  Widget _testModeItem(
    BuildContext context,
    String label,
    MemorizationTestMode mode,
  ) => ListTile(title: Text(label), onTap: () => Navigator.pop(context, mode));

  Future<void> _startMode(
    BuildContext context,
    MemorizationSessionMode mode,
    MemorizationTestMode testMode,
  ) async {
    final session = await controller.generateSession(mode, testMode: testMode);
    if (!context.mounted) return;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد آيات مناسبة لهذه الجلسة الآن.')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/memorization/session'),
        builder: (_) => MemorizationSessionPage(
          controller: controller,
          quranController: quranController,
          audioController: audioController,
          onOpenAyah: onOpenAyah,
          session: session,
        ),
      ),
    );
  }
}

class CreateMemorizationPlanPage extends StatefulWidget {
  const CreateMemorizationPlanPage({
    super.key,
    required this.controller,
    this.initialCoordinate,
  });
  final MemorizationController controller;
  final QuranCoordinate? initialCoordinate;
  @override
  State<CreateMemorizationPlanPage> createState() => _CreateState();
}

class _CreateState extends State<CreateMemorizationPlanPage> {
  late int startSurah, startAyah, endSurah, endAyah;
  bool wholeSurah = true, useDate = false;
  int daily = 5;
  DateTime? target;
  final title = TextEditingController();
  @override
  void initState() {
    super.initState();
    startSurah = widget.initialCoordinate?.surahNumber ?? 67;
    startAyah = widget.initialCoordinate?.ayahNumber ?? 1;
    endSurah = startSurah;
    endAyah = QuranMetadata.surah(startSurah).ayahCount;
    title.text = 'حفظ سورة ${QuranMetadata.surah(startSurah).name}';
  }

  QuranCoordinate get start => QuranCoordinate(startSurah, startAyah);
  QuranCoordinate get end => QuranCoordinate(endSurah, endAyah);
  int get total => QuranRange.coordinates(start, end).length;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إنشاء خطة حفظ')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'اسم الخطة'),
        ),
        SwitchListTile(
          value: wholeSurah,
          title: const Text('سورة كاملة'),
          onChanged: (v) => setState(() => wholeSurah = v),
        ),
        _surah(
          'سورة البداية',
          startSurah,
          (v) => setState(() {
            startSurah = v;
            startAyah = 1;
            if (wholeSurah) {
              endSurah = v;
              endAyah = QuranMetadata.surah(v).ayahCount;
            }
          }),
        ),
        if (!wholeSurah) ...[
          _ayah(
            'آية البداية',
            startAyah,
            startSurah,
            (v) => setState(() => startAyah = v),
          ),
          _surah(
            'سورة النهاية',
            endSurah,
            (v) => setState(() {
              endSurah = v;
              endAyah = 1;
            }),
          ),
          _ayah(
            'آية النهاية',
            endAyah,
            endSurah,
            (v) => setState(() => endAyah = v),
          ),
        ],
        SwitchListTile(
          value: useDate,
          title: const Text('تحديد تاريخ مستهدف'),
          onChanged: (v) => setState(() => useDate = v),
        ),
        if (useDate)
          ListTile(
            title: Text(
              target == null
                  ? 'اختر التاريخ'
                  : '${target!.year}-${target!.month}-${target!.day}',
            ),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                firstDate: DateTime.now().add(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (d != null) setState(() => target = d);
            },
          )
        else
          DropdownButtonFormField<int>(
            initialValue: daily,
            decoration: const InputDecoration(
              labelText: 'الآيات الجديدة يوميًا',
            ),
            items: [1, 2, 3, 5, 7, 10, 15]
                .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                .toList(),
            onChanged: (v) => setState(() => daily = v!),
          ),
        const SizedBox(height: 16),
        PremiumCard(
          child: Text(
            QuranRange.valid(start, end)
                ? 'الإجمالي: $total آية\nالعبء التقريبي: ${useDate && target != null ? (total / target!.difference(DateTime.now()).inDays.clamp(1, 9999)).ceil() : daily} آيات يوميًا'
                : 'النطاق غير صالح',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('create-plan-submit'),
          onPressed:
              QuranRange.valid(start, end) && (!useDate || target != null)
              ? () async {
                  await widget.controller.createPlan(
                    title: title.text,
                    start: start,
                    end: end,
                    targetDate: useDate ? target : null,
                    dailyNewAyahTarget: useDate ? null : daily,
                  );
                  if (context.mounted) Navigator.pop(context);
                }
              : null,
          child: const Text('حفظ الخطة'),
        ),
      ],
    ),
  );
  Widget _surah(String label, int value, ValueChanged<int> change) =>
      DropdownButtonFormField<int>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: QuranMetadata.surahs
            .map(
              (s) => DropdownMenuItem(
                value: s.number,
                child: Text('${s.number}. ${s.name}'),
              ),
            )
            .toList(),
        onChanged: (v) => change(v!),
      );
  Widget _ayah(String label, int value, int surah, ValueChanged<int> change) =>
      DropdownButtonFormField<int>(
        key: ValueKey('$label-$surah'),
        initialValue: value.clamp(1, QuranMetadata.surah(surah).ayahCount),
        decoration: InputDecoration(labelText: label),
        items: List.generate(
          QuranMetadata.surah(surah).ayahCount,
          (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
        ),
        onChanged: (v) => change(v!),
      );
}

class MemorizationSessionPage extends StatefulWidget {
  const MemorizationSessionPage({
    super.key,
    required this.controller,
    required this.quranController,
    required this.session,
    this.audioController,
    this.onOpenAyah,
  });
  final MemorizationController controller;
  final QuranController quranController;
  final MemorizationSession session;
  final QuranAudioController? audioController;
  final Future<void> Function(QuranCoordinate coordinate)? onOpenAyah;
  @override
  State<MemorizationSessionPage> createState() => _SessionState();
}

class _SessionState extends State<MemorizationSessionPage> {
  int index = 0;
  bool revealed = false;
  int revealedWords = 2;
  List<QuranCoordinate> get items => [
    ...widget.session.newAyahs,
    ...widget.session.reviewAyahs,
  ];
  @override
  void initState() {
    super.initState();
    final next = items.indexWhere(
      (e) => !widget.session.results.containsKey(e.key),
    );
    index = next < 0 ? items.length - 1 : next;
  }

  @override
  Widget build(BuildContext context) {
    final c = items[index];
    final verse = widget.quranController.getVerse(c.surahNumber, c.ayahNumber);
    return Scaffold(
      appBar: AppBar(
        title: Text(_sessionTitle(widget.session.mode)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'إلغاء الجلسة',
            onPressed: () async {
              final yes = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('إلغاء الجلسة؟'),
                  content: const Text('سيُحذف تقدم هذه الجلسة فقط.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('رجوع'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('إلغاء'),
                    ),
                  ],
                ),
              );
              if (yes == true) {
                await widget.controller.abandonSession();
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                '${QuranMetadata.surah(c.surahNumber).name} • الآية ${c.ayahNumber}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: PremiumCard(
                  child: Center(child: _testContent(c, verse?.text ?? '')),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.audioController != null)
                    IconButton(
                      onPressed: () => widget.audioController!.playAyah(
                        c.surahNumber,
                        c.ayahNumber,
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      tooltip: 'استمع إلى الآية',
                    ),
                  IconButton(
                    onPressed: () => widget.audioController?.setRepeatMode(
                      QuranRepeatMode.ayah,
                    ),
                    icon: const Icon(Icons.repeat_rounded),
                    tooltip: 'تكرار الآية',
                  ),
                  if (widget.onOpenAyah != null)
                    IconButton(
                      onPressed: () => widget.onOpenAyah!(c),
                      icon: const Icon(Icons.menu_book_outlined),
                      tooltip: 'افتح في المصحف',
                    ),
                  TextButton(
                    key: const ValueKey('memorization-reveal'),
                    onPressed: _reveal,
                    child: Text(
                      widget.session.testMode ==
                                  MemorizationTestMode.progressiveReveal &&
                              !revealed
                          ? 'اكشف المزيد'
                          : revealed
                          ? 'تم الكشف'
                          : 'اكشف الآية',
                    ),
                  ),
                ],
              ),
              if (revealed)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _rate('ثابت', MemorizationSessionResult.mastered),
                    _rate(
                      'تحتاج مراجعة',
                      MemorizationSessionResult.needsReview,
                    ),
                    _rate('صعب', MemorizationSessionResult.notMastered),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _testContent(QuranCoordinate coordinate, String text) {
    const style = TextStyle(
      fontFamily: AppTypography.quranFont,
      fontSize: 30,
      height: 1.9,
      color: AppColors.textPrimary,
    );
    if (revealed) {
      return Text(
        text,
        key: const ValueKey('session-ayah-text'),
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: style,
      );
    }
    final words = text.trim().split(RegExp(r'\s+'));
    switch (widget.session.testMode) {
      case MemorizationTestMode.fullAyah:
        return const _ConcealedAyah(message: 'استحضر الآية ثم اكشفها.');
      case MemorizationTestMode.firstWords:
        return Text(
          '${words.take(3).join(' ')} …',
          key: const ValueKey('session-first-words'),
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: style,
        );
      case MemorizationTestMode.progressiveReveal:
        return Text(
          '${words.take(revealedWords).join(' ')}${revealedWords < words.length ? ' …' : ''}',
          key: const ValueKey('session-progressive'),
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: style,
        );
      case MemorizationTestMode.nextAyah:
        final previous = _previousCoordinate(coordinate);
        final prompt = previous == null
            ? null
            : widget.quranController.getVerse(
                previous.surahNumber,
                previous.ayahNumber,
              );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ما الآية التالية؟'),
            const SizedBox(height: 12),
            if (prompt != null)
              Text(
                prompt.text,
                key: const ValueKey('session-next-prompt'),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: style.copyWith(fontSize: 25),
              )
            else
              const _ConcealedAyah(message: 'ابدأ باستحضار أول آية.'),
          ],
        );
    }
  }

  void _reveal() {
    if (revealed) return;
    if (widget.session.testMode == MemorizationTestMode.progressiveReveal) {
      final coordinate = items[index];
      final text =
          widget.quranController
              .getVerse(coordinate.surahNumber, coordinate.ayahNumber)
              ?.text ??
          '';
      final count = text.trim().split(RegExp(r'\s+')).length;
      setState(() {
        revealedWords = (revealedWords + 2).clamp(0, count);
        revealed = revealedWords >= count;
      });
      return;
    }
    setState(() => revealed = true);
  }

  Widget _rate(String label, MemorizationSessionResult result) =>
      OutlinedButton(
        onPressed: () async {
          final c = items[index];
          final isReview = widget.session.reviewAyahs.contains(c);
          if (isReview) {
            await widget.controller.recordReviewRating(c, result);
          } else {
            await widget.controller.markAyahMemorized(c, result: result);
          }
          if (index == items.length - 1) {
            await widget.controller.completeSession();
            if (mounted) {
              await Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: '/memorization/summary'),
                  builder: (_) => MemorizationSessionSummaryPage(
                    controller: widget.controller,
                    session: widget.controller.sessions
                        .where((e) => e.id == widget.session.id)
                        .first,
                  ),
                ),
              );
            }
          } else {
            setState(() {
              index++;
              revealed = false;
              revealedWords = 2;
            });
          }
        },
        child: Text(label),
      );
}

class _ConcealedAyah extends StatelessWidget {
  const _ConcealedAyah({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('concealed'),
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.visibility_off_outlined, size: 50),
      const SizedBox(height: 12),
      Text(message),
    ],
  );
}

String _sessionTitle(MemorizationSessionMode mode) => switch (mode) {
  MemorizationSessionMode.newMemorization => 'حفظ جديد',
  MemorizationSessionMode.nearReview => 'مراجعة قريبة',
  MemorizationSessionMode.oldReview => 'مراجعة قديمة',
  MemorizationSessionMode.selfTest => 'اختبار ذاتي',
};

QuranCoordinate? _previousCoordinate(QuranCoordinate coordinate) {
  if (coordinate.ayahNumber > 1) {
    return QuranCoordinate(coordinate.surahNumber, coordinate.ayahNumber - 1);
  }
  if (coordinate.surahNumber <= 1) return null;
  final previousSurah = coordinate.surahNumber - 1;
  return QuranCoordinate(
    previousSurah,
    QuranMetadata.surah(previousSurah).ayahCount,
  );
}

class MemorizationSessionSummaryPage extends StatelessWidget {
  const MemorizationSessionSummaryPage({
    super.key,
    required this.controller,
    required this.session,
  });
  final MemorizationController controller;
  final MemorizationSession session;

  @override
  Widget build(BuildContext context) {
    final needs = session.results.values
        .where((e) => e != MemorizationSessionResult.mastered)
        .length;
    final next = controller.nextScheduledReview?.toLocal();
    final plan = controller.activePlan;
    final progress = plan == null ? 0.0 : controller.progressFor(plan);
    return Scaffold(
      appBar: AppBar(title: const Text('ملخص الجلسة')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('راجعت ${session.results.length} آيات'),
                Text('تحتاج مراجعة: $needs'),
                Text(
                  next == null
                      ? 'لا توجد مراجعة مجدولة'
                      : 'المراجعة القادمة: ${next.year}-${next.month}-${next.day}',
                ),
                const SizedBox(height: 12),
                AppProgressBar(value: progress),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تم'),
          ),
        ],
      ),
    );
  }
}

String _coordinateLabel(QuranCoordinate c) =>
    '${QuranMetadata.surah(c.surahNumber).name} ${c.ayahNumber}';

class EditMemorizationPlanPage extends StatefulWidget {
  const EditMemorizationPlanPage({
    super.key,
    required this.controller,
    required this.plan,
  });
  final MemorizationController controller;
  final MemorizationPlan plan;
  @override
  State<EditMemorizationPlanPage> createState() => _EditPlanState();
}

class _EditPlanState extends State<EditMemorizationPlanPage> {
  late final TextEditingController title;
  late Set<int> days;
  late int daily;
  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.plan.title);
    days = {...widget.plan.preferredStudyDays};
    daily = widget.plan.dailyNewAyahTarget;
  }

  @override
  Widget build(BuildContext context) {
    const names = {
      6: 'السبت',
      7: 'الأحد',
      1: 'الاثنين',
      2: 'الثلاثاء',
      3: 'الأربعاء',
      4: 'الخميس',
      5: 'الجمعة',
    };
    final expected = widget.plan
        .copyWith(preferredStudyDays: days, dailyNewAyahTarget: daily)
        .estimatedCompletion(
          DateTime.now(),
          completed: widget.controller.completedFor(widget.plan),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل الخطة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'اسم الخطة'),
          ),
          const SizedBox(height: 16),
          const Text('نطاق القرآن ثابت لحماية تقدمك المحفوظ.'),
          Text(
            '${_coordinateLabel(widget.plan.start)} — ${_coordinateLabel(widget.plan.end)}',
          ),
          const SizedBox(height: 16),
          const Text('أيام الدراسة'),
          Wrap(
            spacing: 6,
            children: names.entries
                .map(
                  (e) => FilterChip(
                    label: Text(e.value),
                    selected: days.contains(e.key),
                    onSelected: (v) => setState(
                      () => v ? days.add(e.key) : days.remove(e.key),
                    ),
                  ),
                )
                .toList(),
          ),
          Slider(
            min: 1,
            max: 15,
            divisions: 14,
            value: daily.toDouble(),
            onChanged: (v) => setState(() => daily = v.round()),
          ),
          Text('العبء الأسبوعي: ${daily * days.length} آية'),
          Text(
            'الإتمام المتوقع: ${expected.year}-${expected.month}-${expected.day}',
          ),
          FilledButton(
            onPressed: days.isEmpty
                ? null
                : () async {
                    await widget.controller.editPlan(
                      widget.plan.id,
                      title: title.text,
                      preferredStudyDays: days,
                      dailyNewAyahTarget: daily,
                      targetDate: widget.plan.targetDate,
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
            child: const Text('حفظ التعديلات'),
          ),
        ],
      ),
    );
  }
}

class MemorizationHistoryPage extends StatelessWidget {
  const MemorizationHistoryPage({super.key, required this.controller});
  final MemorizationController controller;
  @override
  Widget build(BuildContext context) {
    final p = controller.activePlan;
    final h = p == null
        ? const <MemorizationSession>[]
        : controller.historyFor(p.id);
    return Scaffold(
      appBar: AppBar(title: const Text('سجل الجلسات')),
      body: h.isEmpty
          ? const AppEmptyState(
              icon: Icons.history,
              title: 'لا توجد جلسات مكتملة',
              message: 'ستظهر الجلسات بعد إتمامها.',
            )
          : ListView(
              children: h.map((s) {
                final ok = s.results.values
                    .where((e) => e == MemorizationSessionResult.mastered)
                    .length;
                return ListTile(
                  title: Text(
                    '${s.startedAt.toLocal().year}-${s.startedAt.toLocal().month}-${s.startedAt.toLocal().day}',
                  ),
                  subtitle: Text(
                    '${s.completedAt!.difference(s.startedAt).inMinutes} دقيقة • ${s.newAyahs.length} جديد • $ok متقن • ${s.results.length - ok} يحتاج مراجعة',
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class ReviewQueuePage extends StatelessWidget {
  const ReviewQueuePage({
    super.key,
    required this.controller,
    required this.quranController,
    this.audioController,
    this.onOpenAyah,
  });
  final MemorizationController controller;
  final QuranController quranController;
  final QuranAudioController? audioController;
  final Future<void> Function(QuranCoordinate coordinate)? onOpenAyah;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc(), p = controller.activePlan;
    final all =
        controller.memorizedAyahs.where((e) => e.planId == p?.id).toList()
          ..sort((a, b) => a.nextReviewAt.compareTo(b.nextReviewAt));
    return Scaffold(
      appBar: AppBar(title: const Text('قائمة المراجعة')),
      body: ListView(
        children: all.map((e) {
          final start = DateTime.utc(now.year, now.month, now.day),
              over = e.nextReviewAt.isBefore(start),
              due = !e.nextReviewAt.isAfter(now);
          return ListTile(
            title: Text(_coordinateLabel(e.coordinate)),
            subtitle: Text(
              over
                  ? 'متأخرة'
                  : due
                  ? 'مستحقة اليوم'
                  : 'قادمة',
            ),
            onTap: due
                ? () async {
                    final s = await controller.generateTodaySession();
                    if (context.mounted && s != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MemorizationSessionPage(
                            controller: controller,
                            quranController: quranController,
                            audioController: audioController,
                            onOpenAyah: onOpenAyah,
                            session: s,
                          ),
                        ),
                      );
                    }
                  }
                : null,
          );
        }).toList(),
      ),
    );
  }
}
