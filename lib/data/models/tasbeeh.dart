class TasbeehHistoryEntry {
  const TasbeehHistoryEntry({
    required this.phraseId,
    required this.count,
    required this.completedAt,
  });

  final String phraseId;
  final int count;
  final DateTime completedAt;

  Map<String, Object> toJson() => {
    'phraseId': phraseId,
    'count': count,
    'completedAt': completedAt.toUtc().toIso8601String(),
  };

  static TasbeehHistoryEntry? fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['phraseId'] is! String ||
        value['count'] is! int ||
        (value['count'] as int) < 1) {
      return null;
    }
    final completedAt = DateTime.tryParse('${value['completedAt']}');
    if (completedAt == null) return null;
    return TasbeehHistoryEntry(
      phraseId: value['phraseId'],
      count: value['count'],
      completedAt: completedAt.toUtc(),
    );
  }
}

class TasbeehState {
  const TasbeehState({
    required this.phraseId,
    required this.count,
    required this.target,
    required this.updatedAt,
    required this.history,
  });

  final String phraseId;
  final int count;
  final int? target;
  final DateTime updatedAt;
  final List<TasbeehHistoryEntry> history;

  TasbeehState copyWith({
    String? phraseId,
    int? count,
    Object? target = _unchanged,
    DateTime? updatedAt,
    List<TasbeehHistoryEntry>? history,
  }) => TasbeehState(
    phraseId: phraseId ?? this.phraseId,
    count: count ?? this.count,
    target: identical(target, _unchanged) ? this.target : target as int?,
    updatedAt: updatedAt ?? this.updatedAt,
    history: history ?? this.history,
  );

  Map<String, Object?> toJson() => {
    'phraseId': phraseId,
    'count': count,
    'target': target,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'history': history.map((entry) => entry.toJson()).toList(),
  };

  static TasbeehState? fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['phraseId'] is! String ||
        value['count'] is! int ||
        (value['count'] as int) < 0 ||
        (value['target'] != null &&
            (value['target'] is! int || (value['target'] as int) < 1)) ||
        value['history'] is! List) {
      return null;
    }
    final updatedAt = DateTime.tryParse('${value['updatedAt']}');
    final rawHistory = value['history'] as List;
    final history = rawHistory
        .map(TasbeehHistoryEntry.fromJson)
        .whereType<TasbeehHistoryEntry>()
        .toList();
    if (updatedAt == null || history.length != rawHistory.length) return null;
    return TasbeehState(
      phraseId: value['phraseId'],
      count: value['count'],
      target: value['target'] as int?,
      updatedAt: updatedAt.toUtc(),
      history: history,
    );
  }
}

const _unchanged = Object();
