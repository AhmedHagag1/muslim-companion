import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/navigation/internal_destination.dart';
import 'package:quran_app/data/services/user_data_backup_service.dart';

void main() {
  test('production identifiers and brand are configured', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final ios = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(gradle, contains('com.ahmedhaggag.muslimcompanion'));
    expect(gradle, isNot(contains('com.example')));
    expect(manifest, contains('android:label="رفيق المسلم"'));
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
    expect(ios, contains('com.ahmedhaggag.muslimcompanion'));
    expect(ios, isNot(contains('com.example')));
  });

  test('internal destinations reject unsafe schemes and malformed paths', () {
    for (final value in [
      'https://example.com/quran/2/255',
      'http://example.com/quran/2/255',
      'javascript:alert(1)',
      'file:///etc/passwd',
      'content://settings/system',
      '/quran/2/255/../../settings',
      '//example.com/quran/2/255',
      '/quran/2/999',
    ]) {
      expect(InternalDestination.parse(value), isNull, reason: value);
    }
  });

  test('backup rejects oversized and excessively nested documents', () {
    const service = UserDataBackupService();
    expect(
      () => service.preview(' ' * (UserDataBackupService.maxImportBytes + 1)),
      throwsA(isA<BackupFormatException>()),
    );

    Object nested = <String, Object?>{'version': 1};
    for (var i = 0; i < UserDataBackupService.maxNestingDepth + 2; i++) {
      nested = <String, Object?>{'version': 1, 'child': nested};
    }
    final document = jsonEncode({
      'appBackupVersion': 1,
      'createdAt': DateTime.utc(2026).toIso8601String(),
      'sourceAppVersion': '1.0.0+1',
      'sections': {'bookmarks': nested},
    });
    expect(
      () => service.preview(document),
      throwsA(isA<BackupFormatException>()),
    );
  });
}
