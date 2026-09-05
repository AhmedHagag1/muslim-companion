import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/memorization.dart';
import '../../data/models/quran_verse.dart';
import '../../data/models/surah.dart';
import '../audio/quran_audio_controller.dart';
import '../bookmarks/bookmark_controller.dart';
import '../memorization/memorization_controller.dart';
import '../memorization/memorization_page.dart';
import '../quran/quran_controller.dart';
import '../study/verse_study_page.dart';
import 'ayah_share_service.dart';

Future<void> showQuranAyahActions({
  required BuildContext context,
  required QuranVerse verse,
  required QuranController quranController,
  required BookmarkController bookmarkController,
  QuranAudioController? audioController,
  MemorizationController? memorizationController,
  Future<void> Function((int, int) coordinate)? onStudyCoordinate,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => AnimatedBuilder(
      animation: Listenable.merge([bookmarkController, ?audioController]),
      builder: (context, _) {
        final bookmarked = bookmarkController.isBookmarked(
          verse.surahNumber,
          verse.ayahNumber,
        );
        final current =
            audioController?.currentSurahNumber == verse.surahNumber &&
            audioController?.currentAyahNumber == verse.ayahNumber;
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              key: ValueKey(
                'ayah-actions-${verse.surahNumber}-${verse.ayahNumber}',
              ),
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('الآية ${verse.ayahNumber}'),
                  subtitle: Text(
                    'سورة ${QuranMetadata.surah(verse.surahNumber).name}',
                  ),
                ),
                if (memorizationController != null)
                  ListTile(
                    key: const ValueKey('ayah-action-memorize'),
                    leading: const Icon(Icons.workspace_premium_outlined),
                    title: const Text('ابدأ الحفظ من هنا'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CreateMemorizationPlanPage(
                            controller: memorizationController,
                            initialCoordinate: QuranCoordinate(
                              verse.surahNumber,
                              verse.ayahNumber,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                if (audioController != null)
                  ListTile(
                    key: const ValueKey('ayah-action-audio'),
                    leading: Icon(
                      current && audioController.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    title: Text(
                      current && audioController.isPlaying
                          ? 'إيقاف مؤقت'
                          : 'تشغيل الآية',
                    ),
                    onTap: () async {
                      if (current && audioController.isPlaying) {
                        await audioController.pause();
                      } else if (current &&
                          audioController.status == QuranAudioStatus.paused) {
                        await audioController.resume();
                      } else {
                        await audioController.playSurah(
                          verse.surahNumber,
                          initialAyah: verse.ayahNumber,
                        );
                      }
                    },
                  ),
                ListTile(
                  key: const ValueKey('ayah-action-bookmark'),
                  leading: Icon(
                    bookmarked
                        ? Icons.bookmark_remove_rounded
                        : Icons.bookmark_add_outlined,
                  ),
                  title: Text(bookmarked ? 'إزالة الحفظ' : 'حفظ الآية'),
                  onTap: () => bookmarkController.toggleBookmark(
                    verse.surahNumber,
                    verse.ayahNumber,
                  ),
                ),
                ListTile(
                  key: const ValueKey('ayah-action-study'),
                  leading: const Icon(Icons.library_books_outlined),
                  title: const Text('الترجمة والتفسير'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final coordinate = await Navigator.of(context)
                        .push<(int, int)>(
                          MaterialPageRoute(
                            builder: (_) => VerseStudyPage(
                              quranController: quranController,
                              surahNumber: verse.surahNumber,
                              ayahNumber: verse.ayahNumber,
                              bookmarkController: bookmarkController,
                              audioController: audioController,
                            ),
                          ),
                        );
                    if (coordinate != null) {
                      await onStudyCoordinate?.call(coordinate);
                    }
                  },
                ),
                ListTile(
                  key: const ValueKey('ayah-action-copy'),
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('نسخ'),
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text:
                            '${verse.text} (${QuranMetadata.surah(verse.surahNumber).name}: ${verse.ayahNumber})',
                      ),
                    );
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                ),
                ListTile(
                  key: const ValueKey('ayah-action-share'),
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('مشاركة الآية'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    try {
                      await const AyahShareService().share(verse);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تعذرت المشاركة الآن.')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
