class Reciter {
  const Reciter({
    required this.id,
    required this.displayNameArabic,
    this.displayNameEnglish,
  });

  final String id;
  final String displayNameArabic;
  final String? displayNameEnglish;
}
