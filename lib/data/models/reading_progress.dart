class ReadingProgress {
  const ReadingProgress({
    required this.surahNumber,
    required this.ayahNumber,
    required this.updatedAt,
  });

  final int surahNumber;
  final int ayahNumber;
  final DateTime updatedAt;

  Map<String, Object> toJson() => {
    'surahNumber': surahNumber,
    'ayahNumber': ayahNumber,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  static ReadingProgress? fromJson(Map<String, dynamic> json) {
    final surahNumber = json['surahNumber'];
    final ayahNumber = json['ayahNumber'];
    final updatedAt = DateTime.tryParse(json['updatedAt']?.toString() ?? '');

    if (surahNumber is! int || ayahNumber is! int || updatedAt == null) {
      return null;
    }

    return ReadingProgress(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      updatedAt: updatedAt,
    );
  }
}
