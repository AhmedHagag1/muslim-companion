class QuranBookmark {
  const QuranBookmark({
    required this.surahNumber,
    required this.ayahNumber,
    required this.createdAt,
  });

  final int surahNumber;
  final int ayahNumber;
  final DateTime createdAt;

  String get coordinateKey => '$surahNumber:$ayahNumber';

  Map<String, Object> toJson() => {
    'surahNumber': surahNumber,
    'ayahNumber': ayahNumber,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  static QuranBookmark? fromJson(Map<String, dynamic> json) {
    final surah = json['surahNumber'];
    final ayah = json['ayahNumber'];
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    if (surah is! int || ayah is! int || createdAt == null) return null;
    return QuranBookmark(
      surahNumber: surah,
      ayahNumber: ayah,
      createdAt: createdAt,
    );
  }
}
