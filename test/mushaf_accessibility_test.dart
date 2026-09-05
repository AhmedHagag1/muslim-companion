import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/mushaf/data/mushaf_preferences.dart';
import 'package:quran_app/features/mushaf/presentation/mushaf_page_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mushaf accessibility V1', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('display scale clamps to tested range', () {
      expect(
        const MushafDisplaySettings().copyWith(scale: .2).scale,
        MushafDisplaySettings.minScale,
      );
      expect(
        const MushafDisplaySettings().copyWith(scale: 9).scale,
        MushafDisplaySettings.maxScale,
      );
      expect(MushafDisplaySettings.defaultScale, 1.15);
    });

    test('pinch scale is relative to gesture start and clamps safely', () {
      expect(
        mushafScaleForPinch(
          startScale: 1.2,
          startDistance: 100,
          currentDistance: 150,
        ),
        1.7,
      );
      expect(
        mushafScaleForPinch(
          startScale: 1.4,
          startDistance: 200,
          currentDistance: 100,
        ),
        1.0,
      );
      expect(
        mushafScaleForPinch(
          startScale: 1.1,
          startDistance: 0,
          currentDistance: 50,
        ),
        1.1,
      );
    });

    test(
      'display scale and comfort mode persist separately from reader mode',
      () async {
        final preferences = SharedPreferencesMushafPreferences();
        const expected = MushafDisplaySettings(scale: 1.6, comfortMode: true);
        await preferences.saveDisplaySettings(expected);
        await preferences.saveMode(QuranReaderMode.study);
        final loaded = await preferences.loadDisplaySettings();
        expect(loaded.scale, 1.6);
        expect(loaded.comfortMode, isTrue);
        expect(await preferences.loadMode(), QuranReaderMode.study);
      },
    );

    test('default/reset remains readable and exits comfort mode', () {
      const reset = MushafDisplaySettings();
      expect(reset.scale, MushafDisplaySettings.defaultScale);
      expect(reset.comfortMode, isFalse);
    });

    test('malformed and non-finite persisted scale recovers safely', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesMushafPreferences.displayKey: '{broken',
      });
      expect(
        (await SharedPreferencesMushafPreferences().loadDisplaySettings())
            .scale,
        MushafDisplaySettings.defaultScale,
      );
      SharedPreferences.setMockInitialValues({
        SharedPreferencesMushafPreferences.displayKey: jsonEncode({
          'schemaVersion': 1,
          'settings': {'scale': 'huge', 'comfortMode': true},
        }),
      });
      final recovered = await SharedPreferencesMushafPreferences()
          .loadDisplaySettings();
      expect(recovered.scale, MushafDisplaySettings.defaultScale);
      expect(recovered.comfortMode, isFalse);
    });

    test(
      'out-of-range persisted values clamp rather than corrupt state',
      () async {
        SharedPreferences.setMockInitialValues({
          SharedPreferencesMushafPreferences.displayKey: jsonEncode({
            'schemaVersion': 1,
            'settings': {'scale': 99, 'comfortMode': true},
          }),
        });
        final loaded = await SharedPreferencesMushafPreferences()
            .loadDisplaySettings();
        expect(loaded.scale, MushafDisplaySettings.maxScale);
        expect(loaded.comfortMode, isTrue);
      },
    );
  });
}
