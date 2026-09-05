class DhikrCategory {
  const DhikrCategory({
    required this.id,
    required this.title,
    required this.semanticType,
    required this.sortOrder,
  });
  final String id, title, semanticType;
  final int sortOrder;
  static DhikrCategory? fromJson(Object? v) {
    if (v is! Map<String, dynamic> ||
        v['id'] is! String ||
        v['title'] is! String ||
        v['semanticType'] is! String ||
        v['sortOrder'] is! int) {
      return null;
    }
    return DhikrCategory(
      id: v['id'],
      title: v['title'],
      semanticType: v['semanticType'],
      sortOrder: v['sortOrder'],
    );
  }
}

class DhikrItem {
  const DhikrItem({
    required this.id,
    required this.categoryId,
    required this.arabicText,
    required this.repeatCount,
    required this.sourceText,
    required this.reference,
    required this.provenanceId,
    this.note,
  });
  final String id, categoryId, arabicText, sourceText, reference;
  final String provenanceId;
  final int repeatCount;
  final String? note;
  static DhikrItem? fromJson(Object? v) {
    if (v is! Map<String, dynamic> ||
        v['id'] is! String ||
        v['categoryId'] is! String ||
        v['arabicText'] is! String ||
        v['repeatCount'] is! int ||
        (v['repeatCount'] as int) < 1 ||
        v['sourceText'] is! String ||
        v['reference'] is! String ||
        v['provenanceId'] is! String ||
        (v['id'] as String).trim().isEmpty ||
        (v['arabicText'] as String).trim().isEmpty ||
        (v['sourceText'] as String).trim().isEmpty ||
        (v['reference'] as String).trim().isEmpty ||
        (v['provenanceId'] as String).trim().isEmpty) {
      return null;
    }
    return DhikrItem(
      id: v['id'],
      categoryId: v['categoryId'],
      arabicText: v['arabicText'],
      repeatCount: v['repeatCount'],
      sourceText: v['sourceText'],
      reference: v['reference'],
      provenanceId: v['provenanceId'],
      note: v['note'] as String?,
    );
  }
}

class DhikrSession {
  const DhikrSession({
    required this.categoryId,
    required this.startedAt,
    this.completedAt,
    required this.currentItemIndex,
    required this.progress,
  });
  final String categoryId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int currentItemIndex;
  final Map<String, int> progress;
  bool get isCompleted => completedAt != null;
  DhikrSession copyWith({
    DateTime? completedAt,
    int? currentItemIndex,
    Map<String, int>? progress,
  }) => DhikrSession(
    categoryId: categoryId,
    startedAt: startedAt,
    completedAt: completedAt ?? this.completedAt,
    currentItemIndex: currentItemIndex ?? this.currentItemIndex,
    progress: progress ?? this.progress,
  );
  Map<String, Object?> toJson() => {
    'categoryId': categoryId,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'completedAt': completedAt?.toUtc().toIso8601String(),
    'currentItemIndex': currentItemIndex,
    'progress': progress,
  };
  static DhikrSession? fromJson(Object? v) {
    if (v is! Map<String, dynamic> ||
        v['categoryId'] is! String ||
        v['currentItemIndex'] is! int ||
        v['progress'] is! Map) {
      return null;
    }
    final s = DateTime.tryParse('${v['startedAt']}');
    final c = v['completedAt'] == null
        ? null
        : DateTime.tryParse('${v['completedAt']}');
    if (s == null || (v['completedAt'] != null && c == null)) return null;
    return DhikrSession(
      categoryId: v['categoryId'],
      startedAt: s.toUtc(),
      completedAt: c?.toUtc(),
      currentItemIndex: v['currentItemIndex'],
      progress: (v['progress'] as Map).map(
        (k, v) => MapEntry('$k', v is int ? v : 0),
      ),
    );
  }
}
