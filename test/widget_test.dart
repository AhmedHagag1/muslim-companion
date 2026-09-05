import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/features/bookmarks/bookmarks_page.dart';
import 'package:quran_app/features/prayer/prayer_page.dart';
import 'package:quran_app/features/qibla/qibla_page.dart';
import 'package:quran_app/features/adhkar/adhkar_page.dart';
import 'package:quran_app/features/duas/duas_page.dart';
import 'package:quran_app/features/tasbeeh/tasbeeh_page.dart';

void main() {
  testWidgets('Quran app loads its data and shows the main navigation', (
    WidgetTester tester,
  ) async {
    final quranAsset = await rootBundle.load('assets/quran/quran-uthmani.txt');
    final manifestAsset = await rootBundle.load(
      'assets/religious_content/daily_worship_ar_manifest.json',
    );
    final payloadAsset = await rootBundle.load(
      'assets/religious_content/daily_worship_ar_payload.json',
    );
    final assets = <String, ByteData>{
      'AssetManifest.bin': await rootBundle.load('AssetManifest.bin'),
      'assets/quran/quran-uthmani.txt': quranAsset,
      'assets/religious_content/daily_worship_ar_manifest.json': manifestAsset,
      'assets/religious_content/daily_worship_ar_payload.json': payloadAsset,
    };
    final tinyImage = ByteData.sublistView(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
    for (final name in const [
      '01_home_hero_bg.webp',
      '02_prayer_card_bg.webp',
      '04_daily_card_bg.webp',
      '11_islamic_pattern_dark.webp',
      '12_mosque_silhouette.webp',
      '13_open_quran_illustration.webp',
      '14_closed_quran_illustration.webp',
      '15_tasbeeh_illustration.png',
      '16_qibla_compass_illustration.png',
      '17_adhkar_illustration.png',
      '18_dua_illustration.png',
      '19_hijri_calendar_illustration.png',
      '22_empty_no_bookmarks.webp',
    ]) {
      final key = 'assets/design/$name';
      assets[key] = tinyImage;
    }

    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (ByteData? message) async {
        final assetKey = const StringCodec().decodeMessage(message);
        return assets[assetKey];
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      );
    });

    await tester.pumpWidget(const QuranApp());

    expect(find.text('جاري تجهيز القرآن الكريم'), findsOneWidget);

    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    final mainNavigation = find.text('الرئيسية');
    for (
      var frame = 0;
      frame < 50 && mainNavigation.evaluate().isEmpty;
      frame++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(mainNavigation, findsOneWidget);
    Finder navLabel(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );
    expect(navLabel('القرآن'), findsOneWidget);
    expect(navLabel('العبادة'), findsOneWidget);
    expect(navLabel('اسأل'), findsOneWidget);
    expect(navLabel('مكتبتي'), findsOneWidget);
    expect(find.text('المزيد'), findsNothing);

    await tester.tap(navLabel('القرآن'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quran-hub')), findsOneWidget);
    expect(find.byKey(const ValueKey('quran-open-mushaf')), findsOneWidget);

    await tester.tap(navLabel('العبادة'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('worship-hub')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('worship-prayer-priority')),
      findsOneWidget,
    );
    await tester.drag(
      find.byKey(const ValueKey('worship-hub')),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('worship-adhkar')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AdhkarPage), findsOneWidget);
    expect(find.text('قريبًا'), findsNothing);
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byKey(const ValueKey('worship-duas')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DuasPage), findsOneWidget);
    expect(find.text('قريبًا'), findsNothing);
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.ensureVisible(find.byKey(const ValueKey('worship-tasbeeh')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('worship-tasbeeh')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TasbeehPage), findsOneWidget);
    expect(find.text('قريبًا'), findsNothing);
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.ensureVisible(find.byKey(const ValueKey('worship-qibla')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('worship-qibla')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(QiblaPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(navLabel('اسأل'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ask-page')), findsOneWidget);

    await tester.tap(navLabel('مكتبتي'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('library-hub')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('library-bookmarks')));
    await tester.tap(find.byKey(const ValueKey('library-bookmarks')));
    await tester.pumpAndSettle();
    expect(find.byType(BookmarksPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(navLabel('العبادة'));
    await tester.pumpAndSettle();
    await tester.fling(
      find.byKey(const ValueKey('worship-hub')),
      const Offset(0, 1200),
      1200,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('worship-prayer-priority')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PrayerPage), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
