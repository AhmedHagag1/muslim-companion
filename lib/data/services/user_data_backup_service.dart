import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/memorization.dart';

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BackupSection {
  const BackupSection({
    required this.id,
    required this.storageKey,
    required this.label,
    this.isPlainString = false,
  });
  final String id;
  final String storageKey;
  final String label;
  final bool isPlainString;
}

class BackupPreview {
  const BackupPreview({
    required this.createdAt,
    required this.sourceAppVersion,
    required this.sections,
    required this.document,
  });
  final DateTime createdAt;
  final String sourceAppVersion;
  final Map<String, int> sections;
  final Map<String, dynamic> document;
}

class UserDataBackupService {
  const UserDataBackupService();

  static const appBackupVersion = 1;
  static const maxImportBytes = 2 * 1024 * 1024;
  static const maxNestingDepth = 32;
  static const sourceAppVersion = '1.0.0+1';
  static const sections = <BackupSection>[
    BackupSection(
      id: 'bookmarks',
      storageKey: 'quran.bookmarks',
      label: 'المحفوظات',
    ),
    BackupSection(
      id: 'readingProgress',
      storageKey: 'quran.reading_progress',
      label: 'تقدم القراءة',
    ),
    BackupSection(
      id: 'mushafProgress',
      storageKey: 'quran.mushaf_progress.v1',
      label: 'موضع المصحف',
    ),
    BackupSection(
      id: 'readerMode',
      storageKey: 'quran.reader_mode.v1',
      label: 'نمط القراءة',
      isPlainString: true,
    ),
    BackupSection(
      id: 'mushafDisplay',
      storageKey: 'quran.mushaf_display.v1',
      label: 'عرض المصحف',
    ),
    BackupSection(
      id: 'memorization',
      storageKey: 'quran.memorization.v1',
      label: 'الحفظ والمراجعة',
    ),
    BackupSection(
      id: 'khatma',
      storageKey: 'quran.khatma.v1',
      label: 'خطة الختمة',
    ),
    BackupSection(
      id: 'duaFavorites',
      storageKey: 'dua.favorites.v1',
      label: 'الأدعية المفضلة',
    ),
    BackupSection(
      id: 'tasbeeh',
      storageKey: 'tasbeeh.state.v1',
      label: 'السبحة',
    ),
    BackupSection(
      id: 'adhkarSession',
      storageKey: 'adhkar.session.v1',
      label: 'جلسة الأذكار',
    ),
    BackupSection(
      id: 'appSettings',
      storageKey: 'app.settings.v1',
      label: 'إعدادات التطبيق',
    ),
    BackupSection(
      id: 'prayerSettings',
      storageKey: 'prayer.settings.v2',
      label: 'إعدادات الصلاة',
    ),
    BackupSection(
      id: 'dailySettings',
      storageKey: 'islamic.daily.settings.v1',
      label: 'إعدادات اليوم الإسلامي',
    ),
  ];

  Future<String> exportJson({
    SharedPreferences? preferences,
    DateTime Function()? clock,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final exported = <String, Object?>{};
    for (final section in sections) {
      final raw = prefs.getString(section.storageKey);
      if (raw == null) continue;
      if (section.isPlainString) {
        if (!_validPlainValue(section.id, raw)) continue;
        exported[section.id] = raw;
      } else {
        try {
          exported[section.id] = jsonDecode(raw);
        } on FormatException {
          // Corrupt local state is never propagated into a backup.
        }
      }
    }
    return const JsonEncoder.withIndent('  ').convert({
      'appBackupVersion': appBackupVersion,
      'createdAt': (clock ?? DateTime.now)().toUtc().toIso8601String(),
      'sourceAppVersion': sourceAppVersion,
      'sections': exported,
    });
  }

  BackupPreview preview(String raw) {
    if (utf8.encode(raw).length > maxImportBytes) {
      throw const BackupFormatException(
        'ملف النسخة الاحتياطية أكبر من الحد المسموح.',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const BackupFormatException('ملف النسخة الاحتياطية غير صالح.');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['appBackupVersion'] != appBackupVersion ||
        decoded['sourceAppVersion'] is! String ||
        decoded['sections'] is! Map<String, dynamic>) {
      throw const BackupFormatException('إصدار النسخة غير مدعوم.');
    }
    final createdAt = DateTime.tryParse('${decoded['createdAt']}');
    if (createdAt == null) {
      throw const BackupFormatException('تاريخ النسخة غير صالح.');
    }
    final rawSections = decoded['sections'] as Map<String, dynamic>;
    final allowed = {for (final section in sections) section.id: section};
    final summary = <String, int>{};
    for (final entry in rawSections.entries) {
      final definition = allowed[entry.key];
      if (definition == null) {
        throw const BackupFormatException('تحتوي النسخة على قسم غير معروف.');
      }
      _validateSection(definition, entry.value);
      summary[definition.label] = _entryCount(entry.value);
    }
    return BackupPreview(
      createdAt: createdAt.toUtc(),
      sourceAppVersion: decoded['sourceAppVersion'] as String,
      sections: Map.unmodifiable(summary),
      document: decoded,
    );
  }

  Future<void> replaceFromPreview(
    BackupPreview preview, {
    required bool confirmed,
    SharedPreferences? preferences,
  }) async {
    if (!confirmed) {
      throw const BackupFormatException('يلزم تأكيد الاستبدال أولًا.');
    }
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final values = preview.document['sections'] as Map<String, dynamic>;
    final definitions = {for (final section in sections) section.id: section};
    final oldValues = <String, String?>{};
    try {
      for (final entry in values.entries) {
        final section = definitions[entry.key]!;
        oldValues[section.storageKey] = prefs.getString(section.storageKey);
        final encoded = section.isPlainString
            ? entry.value as String
            : jsonEncode(entry.value);
        if (!await prefs.setString(section.storageKey, encoded)) {
          throw const BackupFormatException('تعذر حفظ النسخة على الجهاز.');
        }
      }
    } catch (_) {
      for (final entry in oldValues.entries) {
        final value = entry.value;
        if (value == null) {
          await prefs.remove(entry.key);
        } else {
          await prefs.setString(entry.key, value);
        }
      }
      rethrow;
    }
  }

  static void _validateSection(BackupSection section, Object? value) {
    if (section.isPlainString) {
      if (value is! String || !_validPlainValue(section.id, value)) {
        throw const BackupFormatException('قيمة إعداد القراءة غير صالحة.');
      }
      return;
    }
    if (value is! Map<String, dynamic>) {
      throw const BackupFormatException('بيانات أحد الأقسام غير صالحة.');
    }
    final version = value['version'] ?? value['schemaVersion'];
    if (version is! int || version < 1 || version > 2) {
      throw const BackupFormatException('إصدار أحد الأقسام غير مدعوم.');
    }
    _validateCoordinatesAndPages(value, 0);
  }

  static bool _validPlainValue(String id, String value) =>
      id == 'readerMode' && (value == 'mushaf' || value == 'study');

  static void _validateCoordinatesAndPages(Object? node, int depth) {
    if (depth > maxNestingDepth) {
      throw const BackupFormatException(
        'بنية ملف النسخة الاحتياطية متداخلة بشكل غير صالح.',
      );
    }
    if (node is List) {
      for (final value in node) {
        _validateCoordinatesAndPages(value, depth + 1);
      }
      return;
    }
    if (node is! Map) return;
    final surah = node['surah'] ?? node['surahNumber'];
    final ayah = node['ayah'] ?? node['ayahNumber'];
    if (surah != null || ayah != null) {
      if (surah is! int ||
          ayah is! int ||
          !QuranCoordinate(surah, ayah).isValid) {
        throw const BackupFormatException(
          'تحتوي النسخة على موضع قرآن غير صالح.',
        );
      }
    }
    const pageKeys = {
      'pageNumber',
      'startPage',
      'endPage',
      'currentPage',
      'lastCompletedPage',
    };
    for (final entry in node.entries) {
      if (pageKeys.contains(entry.key) &&
          (entry.value is! int ||
              (entry.value as int) < 1 ||
              (entry.value as int) > 604)) {
        throw const BackupFormatException(
          'تحتوي النسخة على صفحة مصحف غير صالحة.',
        );
      }
      _validateCoordinatesAndPages(entry.value, depth + 1);
    }
  }

  static int _entryCount(Object? value) {
    if (value is List) return value.length;
    if (value is Map) {
      for (final key in const [
        'bookmarks',
        'plans',
        'ayahs',
        'sessions',
        'history',
        'favorites',
      ]) {
        final entries = value[key];
        if (entries is List) return entries.length;
      }
    }
    return 1;
  }
}
