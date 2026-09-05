import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models/surah.dart';
import '../domain/mushaf_models.dart';

enum QuranReaderMode { mushaf, study }

class MushafDisplaySettings {
  const MushafDisplaySettings({
    this.scale = defaultScale,
    this.comfortMode = false,
  });
  static const minScale = 1.0;
  static const maxScale = 1.7;
  static const defaultScale = 1.15;
  final double scale;
  final bool comfortMode;
  MushafDisplaySettings copyWith({double? scale, bool? comfortMode}) =>
      MushafDisplaySettings(
        scale: (scale ?? this.scale).clamp(minScale, maxScale),
        comfortMode: comfortMode ?? this.comfortMode,
      );
  Map<String, Object> toJson() => {'scale': scale, 'comfortMode': comfortMode};
  static MushafDisplaySettings fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return const MushafDisplaySettings();
    final raw = value['scale'];
    if (raw is! num || !raw.isFinite) return const MushafDisplaySettings();
    return MushafDisplaySettings(
      scale: raw.toDouble().clamp(minScale, maxScale),
      comfortMode: value['comfortMode'] == true,
    );
  }
}

class MushafReadingProgress {
  const MushafReadingProgress({
    required this.pageNumber,
    required this.coordinate,
  });

  final int pageNumber;
  final MushafCoordinate coordinate;
}

abstract interface class MushafPreferences {
  Future<MushafReadingProgress?> loadProgress();
  Future<void> saveProgress(MushafReadingProgress progress);
  Future<QuranReaderMode> loadMode();
  Future<void> saveMode(QuranReaderMode mode);
  Future<MushafDisplaySettings> loadDisplaySettings();
  Future<void> saveDisplaySettings(MushafDisplaySettings settings);
}

class SharedPreferencesMushafPreferences implements MushafPreferences {
  static const progressKey = 'quran.mushaf_progress.v1';
  static const modeKey = 'quran.reader_mode.v1';
  static const displayKey = 'quran.mushaf_display.v1';

  @override
  Future<MushafReadingProgress?> loadProgress() async {
    final raw = (await SharedPreferences.getInstance()).getString(progressKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['schemaVersion'] != 1 && json['schemaVersion'] != 2) return null;
      final progress = MushafReadingProgress(
        pageNumber: json['pageNumber'] as int,
        coordinate: MushafCoordinate(
          json['surahNumber'] as int,
          json['ayahNumber'] as int,
        ),
      );
      if (progress.pageNumber < 1 ||
          progress.pageNumber > 604 ||
          progress.coordinate.surahNumber < 1 ||
          progress.coordinate.surahNumber > QuranMetadata.surahCount ||
          progress.coordinate.ayahNumber < 1 ||
          progress.coordinate.ayahNumber >
              QuranMetadata.surah(progress.coordinate.surahNumber).ayahCount) {
        return null;
      }
      if (json['schemaVersion'] == 1) await saveProgress(progress);
      return progress;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveProgress(MushafReadingProgress progress) async {
    await (await SharedPreferences.getInstance()).setString(
      progressKey,
      jsonEncode({
        'schemaVersion': 2,
        'pageNumber': progress.pageNumber,
        'surahNumber': progress.coordinate.surahNumber,
        'ayahNumber': progress.coordinate.ayahNumber,
      }),
    );
  }

  @override
  Future<QuranReaderMode> loadMode() async {
    final raw = (await SharedPreferences.getInstance()).getString(modeKey);
    return raw == QuranReaderMode.study.name
        ? QuranReaderMode.study
        : QuranReaderMode.mushaf;
  }

  @override
  Future<void> saveMode(QuranReaderMode mode) async {
    await (await SharedPreferences.getInstance()).setString(modeKey, mode.name);
  }

  @override
  Future<MushafDisplaySettings> loadDisplaySettings() async {
    final raw = (await SharedPreferences.getInstance()).getString(displayKey);
    if (raw == null) return const MushafDisplaySettings();
    try {
      final root = jsonDecode(raw);
      if (root is! Map<String, dynamic> ||
          (root['schemaVersion'] != 1 && root['schemaVersion'] != 2)) {
        return const MushafDisplaySettings();
      }
      final settings = MushafDisplaySettings.fromJson(root['settings']);
      if (root['schemaVersion'] == 1) await saveDisplaySettings(settings);
      return settings;
    } catch (_) {
      return const MushafDisplaySettings();
    }
  }

  @override
  Future<void> saveDisplaySettings(MushafDisplaySettings settings) async {
    await (await SharedPreferences.getInstance()).setString(
      displayKey,
      jsonEncode({'schemaVersion': 2, 'settings': settings.toJson()}),
    );
  }
}
