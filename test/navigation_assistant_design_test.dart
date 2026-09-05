import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/assistant/assistant_intent_service.dart';
import 'package:quran_app/features/assistant/ask_page.dart';
import 'package:quran_app/features/home/home_page.dart';
import 'package:quran_app/features/prayer/prayer_controller.dart';
import 'package:quran_app/features/quran/quran_hub_page.dart';
import 'package:quran_app/features/reader/reading_progress_controller.dart';
import 'package:quran_app/features/worship/worship_hub_page.dart';

void main() {
  const service = AssistantIntentService();

  test('assistant maps safe deterministic commands to real intent types', () {
    final cases = <String, AssistantIntentType>{
      'سورة الكهف': AssistantIntentType.openSurah,
      '2:255': AssistantIntentType.quranVerse,
      'متى المغرب': AssistantIntentType.prayerTime,
      'افتح القبلة': AssistantIntentType.qibla,
      'أذكار الصباح': AssistantIntentType.morningAdhkar,
      'ورد اليوم': AssistantIntentType.khatma,
      'مراجعة الحفظ': AssistantIntentType.memorization,
      'تفسير 2:255': AssistantIntentType.tafsir,
      'معنى آية الكرسي': AssistantIntentType.wordMeaning,
    };

    for (final entry in cases.entries) {
      expect(service.parse(entry.key).type, entry.value, reason: entry.key);
    }
    expect(service.parse('سورة الكهف').surahNumber, 18);
    expect(service.parse('2:255').ayahNumber, 255);
  });

  test('assistant rejects invalid coordinates and unsupported guidance', () {
    expect(service.parse('2:999').isSupported, isFalse);
    expect(
      service.parse('أعطني فتوى في معاملة').type,
      AssistantIntentType.unsupported,
    );
  });

  test('assistant separates retrieval, navigation, and ruling boundaries', () {
    expect(service.parse('افتح 2:255').type, AssistantIntentType.openVerse);
    expect(service.parse('ترجمة 2:255').type, AssistantIntentType.translation);
    expect(service.parse('تفسير آية الكرسي').type, AssistantIntentType.tafsir);
    expect(service.parse('أذكار النوم').type, AssistantIntentType.sleepAdhkar);
    expect(service.parse('افتح الأدعية').type, AssistantIntentType.duas);
    final ruling = service.parse('هل هذا حلال أم حرام؟');
    expect(ruling.type, AssistantIntentType.religiousRuling);
    expect(ruling.requiresReligiousBoundary, isTrue);
  });

  test('assistant response keeps source text distinct from summary and citations', () {
    const response = AssistantResponse(
      sourceText: 'verified source',
      summary: 'generated or deterministic summary',
      citations: [AssistantCitation(title: 'source', detail: '2:255')],
    );
    expect(response.sourceText, isNot(response.summary));
    expect(response.citations.single.detail, '2:255');
    expect(response.boundary, isFalse);
  });

  test('home contextual action keeps a single deterministic priority', () {
    expect(
      selectHomeContextualAction(dueReviewCount: 3, hasActiveKhatma: true),
      HomeContextualAction.memorization,
    );
    expect(
      selectHomeContextualAction(dueReviewCount: 0, hasActiveKhatma: true),
      HomeContextualAction.khatma,
    );
    expect(
      selectHomeContextualAction(dueReviewCount: 0, hasActiveKhatma: false),
      HomeContextualAction.adhkar,
    );
  });

  test('all supplied design assets exist and the directory is declared', () {
    final directory = Directory('assets/design');
    final files = directory
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .toSet();
    expect(files.length, 24);
    for (var index = 1; index <= 24; index++) {
      final prefix = index.toString().padLeft(2, '0');
      expect(files.any((name) => name.startsWith('${prefix}_')), isTrue);
    }
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/design/'),
    );
  });

  testWidgets('Ask uses a calm fallback without invoking an executor', (
    tester,
  ) async {
    var executions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AskPage(
          onExecute: (_) async {
            executions++;
            return null;
          },
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('ask-input')),
      'أعطني فتوى',
    );
    await tester.tap(find.byKey(const ValueKey('ask-submit')));
    await tester.pump();
    expect(find.byKey(const ValueKey('ask-unsupported')), findsOneWidget);
    expect(executions, 0);
  });

  testWidgets('Quran and Worship hubs lay out at 1.3 text scale', (
    tester,
  ) async {
    final manifest = await rootBundle.load('AssetManifest.bin');
    final tinyImage = ByteData.sublistView(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (message) async {
        final key = const StringCodec().decodeMessage(message);
        if (key == 'AssetManifest.bin') return manifest;
        if (key?.startsWith('assets/design/') == true) return tinyImage;
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      );
    });
    final reading = ReadingProgressController();
    final prayer = PrayerController();
    addTearDown(prayer.dispose);
    Widget scaled(Widget child) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: child,
      ),
    );
    void noop() {}

    await tester.pumpWidget(
      scaled(
        QuranHubPage(
          readingProgressController: reading,
          onContinueReading: noop,
          onOpenMushaf: noop,
          onOpenStudy: noop,
          onOpenSearch: noop,
          onOpenListening: noop,
          onOpenTranslation: noop,
          onOpenTafsir: noop,
          onOpenWordMeanings: noop,
          onOpenMemorization: noop,
        ),
      ),
    );
    await tester.drag(
      find.byKey(const ValueKey('quran-hub')),
      const Offset(0, -500),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      scaled(
        WorshipHubPage(
          prayerController: prayer,
          onOpenPrayer: noop,
          onOpenQibla: noop,
          onOpenAdhkar: noop,
          onOpenDuas: noop,
          onOpenTasbeeh: noop,
          onOpenDaily: noop,
        ),
      ),
    );
    await tester.drag(
      find.byKey(const ValueKey('worship-hub')),
      const Offset(0, -600),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
