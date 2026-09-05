import 'package:flutter/foundation.dart';

import '../../data/models/app_settings.dart';
import '../../data/models/khatma.dart';
import '../../data/repositories/khatma_repository.dart';

class KhatmaController extends ChangeNotifier {
  KhatmaController({KhatmaRepository? repository, DateTime Function()? clock})
    : _repository = repository ?? KhatmaRepository(),
      _clock = clock ?? DateTime.now;
  final KhatmaRepository _repository;
  final DateTime Function() _clock;
  List<KhatmaPlan> _plans = const [];
  bool loaded = false;
  String? message;

  List<KhatmaPlan> get plans => List.unmodifiable(_plans);
  KhatmaPlan? get activePlan => _plans
      .where(
        (p) =>
            p.status == KhatmaPlanStatus.active ||
            p.status == KhatmaPlanStatus.paused,
      )
      .firstOrNull;
  List<KhatmaPlan> get history => List.unmodifiable(
    _plans.where(
      (p) =>
          p.status == KhatmaPlanStatus.completed ||
          p.status == KhatmaPlanStatus.archived,
    ),
  );
  KhatmaDay? get today {
    final plan = activePlan;
    if (plan == null) return null;
    final date = khatmaDate(_clock());
    return plan.days.where((day) => day.date == date).firstOrNull;
  }

  KhatmaProgress? get progress {
    final plan = activePlan;
    return plan == null ? null : calculateKhatmaProgress(plan, _clock());
  }

  Future<void> load() async {
    _plans = await _repository.load();
    loaded = true;
    await redistributeMissedDays();
    notifyListeners();
  }

  ({int remainingPages, double pagesPerDay, DateTime targetDate}) preview({
    required KhatmaPlanType type,
    required int startPage,
    DateTime? customTarget,
  }) {
    final start = khatmaDate(_clock());
    final days = switch (type) {
      KhatmaPlanType.thirtyDays => 30,
      KhatmaPlanType.sixtyDays => 60,
      KhatmaPlanType.ninetyDays => 90,
      KhatmaPlanType.custom =>
        (customTarget == null
            ? 30
            : khatmaDate(customTarget).difference(start).inDays + 1),
    }.clamp(1, 604);
    final remaining = 605 - startPage;
    return (
      remainingPages: remaining,
      pagesPerDay: remaining / days,
      targetDate: start.add(Duration(days: days - 1)),
    );
  }

  Future<KhatmaPlan> create({
    required String title,
    required KhatmaPlanType type,
    required int startPage,
    DateTime? customTarget,
    ReminderTime? reminder,
  }) async {
    if (startPage < 1 || startPage > 604) {
      throw RangeError.range(startPage, 1, 604);
    }
    final summary = preview(
      type: type,
      startPage: startPage,
      customTarget: customTarget,
    );
    final now = _clock();
    final old = activePlan;
    final updated = _plans
        .map(
          (p) => identical(p, old)
              ? p.copyWith(status: KhatmaPlanStatus.archived)
              : p,
        )
        .toList();
    final plan = KhatmaPlan(
      id: 'khatma-${now.toUtc().microsecondsSinceEpoch}',
      title: title.trim().isEmpty ? 'ختمة القرآن' : title.trim(),
      createdAt: now.toUtc(),
      startDate: khatmaDate(now),
      targetDate: summary.targetDate,
      status: KhatmaPlanStatus.active,
      startPage: startPage,
      endPage: 604,
      currentPage: startPage,
      planType: type,
      preferredReminderTime: reminder,
      days: distributeKhatmaPages(
        startPage: startPage,
        startDate: now,
        targetDate: summary.targetDate,
      ),
    );
    _plans = List.unmodifiable([...updated, plan]);
    message = null;
    await _save();
    notifyListeners();
    return plan;
  }

  Future<void> recordReachedPage(int page) async {
    final plan = activePlan;
    final day = today;
    if (plan == null ||
        plan.status != KhatmaPlanStatus.active ||
        day == null ||
        page < day.plannedStartPage) {
      return;
    }
    final through = page.clamp(day.plannedStartPage, day.plannedEndPage);
    if ((day.completedThroughPage ?? day.plannedStartPage - 1) >= through) {
      return;
    }
    final changed = plan.days
        .map(
          (item) => item.date == day.date
              ? item.copyWith(
                  completedThroughPage: through,
                  completedAt: through >= item.plannedEndPage
                      ? _clock().toUtc()
                      : null,
                )
              : item,
        )
        .toList();
    final complete = through >= plan.endPage;
    await _replace(
      plan,
      plan.copyWith(
        currentPage: through,
        days: changed,
        status: complete ? KhatmaPlanStatus.completed : plan.status,
        completedAt: complete ? _clock().toUtc() : null,
      ),
    );
  }

  Future<void> confirmTodayCompleted() async {
    final day = today;
    if (day != null) await recordReachedPage(day.plannedEndPage);
  }

  Future<bool> redistributeMissedDays() async {
    final plan = activePlan;
    if (plan == null || plan.status != KhatmaPlanStatus.active) return false;
    final now = khatmaDate(_clock());
    final missed = plan.days.any(
      (day) => day.date.isBefore(now) && !day.isCompleted,
    );
    if (!missed) return false;
    final completedDays = plan.days.where((day) => day.isCompleted).toList();
    final completedThrough = completedDays.fold<int>(
      plan.startPage - 1,
      (max, day) =>
          day.completedThroughPage! > max ? day.completedThroughPage! : max,
    );
    final nextPage = completedThrough + 1;
    if (nextPage > plan.endPage) return false;
    final target = plan.targetDate.isBefore(now) ? now : plan.targetDate;
    final redistributed = distributeKhatmaPages(
      startPage: nextPage,
      endPage: plan.endPage,
      startDate: now,
      targetDate: target,
    );
    await _replace(
      plan,
      plan.copyWith(
        currentPage: nextPage,
        targetDate: target,
        days: [...completedDays, ...redistributed],
      ),
    );
    message = 'تم تحديث وردك اليومي';
    notifyListeners();
    return true;
  }

  Future<void> edit({
    String? title,
    DateTime? targetDate,
    ReminderTime? reminder,
    bool clearReminder = false,
    KhatmaPlanStatus? status,
  }) async {
    final plan = activePlan;
    if (plan == null) return;
    var days = plan.days;
    var target = plan.targetDate;
    if (targetDate != null &&
        !khatmaDate(targetDate).isBefore(khatmaDate(_clock()))) {
      final completed = days.where((d) => d.isCompleted).toList();
      final next =
          completed.fold<int>(
            plan.startPage - 1,
            (m, d) => d.completedThroughPage! > m ? d.completedThroughPage! : m,
          ) +
          1;
      target = khatmaDate(targetDate);
      if (next <= plan.endPage) {
        days = [
          ...completed,
          ...distributeKhatmaPages(
            startPage: next,
            endPage: plan.endPage,
            startDate: _clock(),
            targetDate: target,
          ),
        ];
      }
    }
    await _replace(
      plan,
      plan.copyWith(
        title: title,
        targetDate: target,
        planType: targetDate == null ? null : KhatmaPlanType.custom,
        days: days,
        preferredReminderTime: reminder,
        clearReminder: clearReminder,
        status: status,
      ),
    );
  }

  Future<void> archive() async {
    final plan = activePlan;
    if (plan != null) {
      await _replace(plan, plan.copyWith(status: KhatmaPlanStatus.archived));
    }
  }

  Future<void> _replace(KhatmaPlan old, KhatmaPlan next) async {
    _plans = List.unmodifiable(_plans.map((p) => p.id == old.id ? next : p));
    await _save();
    notifyListeners();
  }

  Future<void> _save() => _repository.save(_plans);
}
