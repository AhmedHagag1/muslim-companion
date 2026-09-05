class AyahAudioSource {
  const AyahAudioSource({
    required this.surahNumber,
    required this.ayahNumber,
    required this.reciterId,
    required this.sourceId,
    this.reciterName,
    this.duration,
  });

  final int surahNumber;
  final int ayahNumber;
  final String reciterId;
  final String sourceId;
  final String? reciterName;
  final Duration? duration;

  Uri? get uri => Uri.tryParse(sourceId);

  AyahAudioSource withReciterName(String value) => AyahAudioSource(
    surahNumber: surahNumber,
    ayahNumber: ayahNumber,
    reciterId: reciterId,
    sourceId: sourceId,
    reciterName: value,
    duration: duration,
  );
}
