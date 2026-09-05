import 'package:flutter/foundation.dart';

import 'app_settings.dart';

enum KhatmaPlanStatus { active, paused, completed, archived }

enum KhatmaPlanType { thirtyDays, sixtyDays, ninetyDays, custom }

DateTime khatmaDate(DateTime value) =>
    DateTime(value.year, value.month, value.day);
String _dateText(DateTime value) => khatmaDate(value).toIso8601String();

@immutable
class KhatmaDay {
  const KhatmaDay({
    required this.date,
    required this.plannedStartPage,
    required this.plannedEndPage,
    this.completedThroughPage,
    this.completedAt,
  });
  final DateTime date;
  final int plannedStartPage;
  final int plannedEndPage;
  final int? completedThroughPage;
  final DateTime? completedAt;
  bool get isCompleted =>
      completedThroughPage != null && completedThroughPage! >= plannedEndPage;

  KhatmaDay copyWith({int? completedThroughPage, DateTime? completedAt}) =>
      KhatmaDay(
        date: date,
        plannedStartPage: plannedStartPage,
        plannedEndPage: plannedEndPage,
        completedThroughPage: completedThroughPage ?? this.completedThroughPage,
        completedAt: completedAt ?? this.completedAt,
      );
  Map<String, Object?> toJson() => {
    'date': _dateText(date),
    'plannedStartPage': plannedStartPage,
    'plannedEndPage': plannedEndPage,
    'completedThroughPage': completedThroughPage,
    'completedAt': completedAt?.toUtc().toIso8601String(),
  };
  static KhatmaDay? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final date = DateTime.tryParse(value['date']?.toString() ?? '');
    final start = value['plannedStartPage'];
    final end = value['plannedEndPage'];
    final through = value['completedThroughPage'];
    final completedAt = DateTime.tryParse(
      value['completedAt']?.toString() ?? '',
    );
    if (date == null ||
        start is! int ||
        end is! int ||
        start < 1 ||
        end > 604 ||
        start > end ||
        (through != null &&
            (through is! int || through < start || through > end))) {
      return null;
    }
    return KhatmaDay(
      date: khatmaDate(date),
      plannedStartPage: start,
      plannedEndPage: end,
      completedThroughPage: through as int?,
      completedAt: completedAt,
    );
  }
}

@immutable
class KhatmaPlan {
  const KhatmaPlan({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.startDate,
    required this.targetDate,
    required this.status,
    required this.startPage,
    required this.endPage,
    required this.currentPage,
    required this.planType,
    required this.days,
    this.preferredReminderTime,
    this.completedAt,
  });
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime startDate;
  final DateTime targetDate;
  final KhatmaPlanStatus status;
  final int startPage, endPage, currentPage;
  final KhatmaPlanType planType;
  final ReminderTime? preferredReminderTime;
  final List<KhatmaDay> days;
  final DateTime? completedAt;

  KhatmaPlan copyWith({
    String? title,
    DateTime? targetDate,
    KhatmaPlanStatus? status,
    int? currentPage,
    KhatmaPlanType? planType,
    List<KhatmaDay>? days,
    ReminderTime? preferredReminderTime,
    bool clearReminder = false,
    DateTime? completedAt,
  }) => KhatmaPlan(
    id: id,
    title: title ?? this.title,
    createdAt: createdAt,
    startDate: startDate,
    targetDate: targetDate ?? this.targetDate,
    status: status ?? this.status,
    startPage: startPage,
    endPage: endPage,
    currentPage: currentPage ?? this.currentPage,
    planType: planType ?? this.planType,
    preferredReminderTime: clearReminder
        ? null
        : preferredReminderTime ?? this.preferredReminderTime,
    days: List.unmodifiable(days ?? this.days),
    completedAt: completedAt ?? this.completedAt,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'startDate': _dateText(startDate),
    'targetDate': _dateText(targetDate),
    'status': status.name,
    'startPage': startPage,
    'endPage': endPage,
    'currentPage': currentPage,
    'planType': planType.name,
    'preferredReminderTime': preferredReminderTime?.toJson(),
    'days': days.map((item) => item.toJson()).toList(),
    'completedAt': completedAt?.toUtc().toIso8601String(),
  };
  static KhatmaPlan? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final created = DateTime.tryParse(value['createdAt']?.toString() ?? '');
    final start = DateTime.tryParse(value['startDate']?.toString() ?? '');
    final target = DateTime.tryParse(value['targetDate']?.toString() ?? '');
    final status = KhatmaPlanStatus.values
        .where((e) => e.name == value['status'])
        .firstOrNull;
    final type = KhatmaPlanType.values
        .where((e) => e.name == value['planType'])
        .firstOrNull;
    final rawDays = value['days'];
    final days = rawDays is List
        ? rawDays.map(KhatmaDay.fromJson).whereType<KhatmaDay>().toList()
        : <KhatmaDay>[];
    final startPage = value['startPage'];
    final endPage = value['endPage'];
    final currentPage = value['currentPage'];
    if (value['id'] is! String ||
        value['title'] is! String ||
        created == null ||
        start == null ||
        target == null ||
        status == null ||
        type == null ||
        startPage is! int ||
        endPage is! int ||
        currentPage is! int ||
        startPage < 1 ||
        endPage > 604 ||
        startPage > endPage ||
        currentPage < startPage ||
        currentPage > endPage ||
        days.isEmpty) {
      return null;
    }
    return KhatmaPlan(
      id: value['id'] as String,
      title: value['title'] as String,
      createdAt: created,
      startDate: khatmaDate(start),
      targetDate: khatmaDate(target),
      status: status,
      startPage: startPage,
      endPage: endPage,
      currentPage: currentPage,
      planType: type,
      preferredReminderTime: ReminderTime.fromJson(
        value['preferredReminderTime'],
      ),
      days: List.unmodifiable(days),
      completedAt: DateTime.tryParse(value['completedAt']?.toString() ?? ''),
    );
  }
}

@immutable
class KhatmaProgress {
  const KhatmaProgress({
    required this.planId,
    required this.completedPages,
    required this.remainingPages,
    required this.todayRemainingPages,
    required this.daysRemaining,
    required this.projectedCompletionDate,
  });
  final String planId;
  final int completedPages, remainingPages, todayRemainingPages, daysRemaining;
  final DateTime projectedCompletionDate;
}

List<KhatmaDay> distributeKhatmaPages({
  required int startPage,
  int endPage = 604,
  required DateTime startDate,
  required DateTime targetDate,
}) {
  if (startPage < 1 || endPage > 604 || startPage > endPage) {
    throw RangeError('Invalid Khatma page range');
  }
  final firstDate = khatmaDate(startDate);
  final lastDate = khatmaDate(targetDate);
  final dayCount = lastDate.difference(firstDate).inDays + 1;
  if (dayCount < 1) {
    throw ArgumentError('Target date must not precede start date');
  }
  final pageCount = endPage - startPage + 1;
  final usedDays = dayCount.clamp(1, pageCount);
  final base = pageCount ~/ usedDays;
  final remainder = pageCount % usedDays;
  var page = startPage;
  return List.unmodifiable(
    List.generate(usedDays, (index) {
      final count = base + (index < remainder ? 1 : 0);
      final day = KhatmaDay(
        date: firstDate.add(Duration(days: index)),
        plannedStartPage: page,
        plannedEndPage: page + count - 1,
      );
      page += count;
      return day;
    }),
  );
}

KhatmaProgress calculateKhatmaProgress(KhatmaPlan plan, DateTime now) {
  final today = khatmaDate(now);
  final completed = plan.days.fold<int>(0, (total, day) {
    final through = day.completedThroughPage;
    return total + (through == null ? 0 : through - day.plannedStartPage + 1);
  });
  final day = plan.days.where((item) => item.date == today).firstOrNull;
  final todayRemaining = day == null
      ? 0
      : (day.plannedEndPage -
                (day.completedThroughPage ?? day.plannedStartPage - 1))
            .clamp(0, 604);
  final totalPages = plan.endPage - plan.startPage + 1;
  final remaining = (totalPages - completed).clamp(0, 604);
  final futureDays = plan.days
      .where((item) => !item.date.isBefore(today))
      .length;
  return KhatmaProgress(
    planId: plan.id,
    completedPages: completed,
    remainingPages: remaining,
    todayRemainingPages: todayRemaining,
    daysRemaining: futureDays,
    projectedCompletionDate: plan.targetDate,
  );
}
