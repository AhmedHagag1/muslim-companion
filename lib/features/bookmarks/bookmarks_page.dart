import 'package:flutter/material.dart';

import '../../data/models/surah.dart';
import '../quran/quran_controller.dart';
import '../reader/quran_reader_page.dart';
import '../reader/reading_progress_controller.dart';
import 'bookmark_controller.dart';
import '../audio/quran_audio_controller.dart';

class BookmarksPage extends StatelessWidget {
  const BookmarksPage({
    super.key,
    required this.bookmarkController,
    required this.quranController,
    required this.readingProgressController,
    this.audioController,
  });

  final BookmarkController bookmarkController;
  final QuranController quranController;
  final ReadingProgressController readingProgressController;
  final QuranAudioController? audioController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: bookmarkController,
      builder: (context, _) {
        final bookmarks = bookmarkController.bookmarks;
        return Scaffold(
          appBar: AppBar(title: const Text('المحفوظات'), centerTitle: true),
          body: bookmarks.isEmpty
              ? const _EmptyBookmarks()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                  itemCount: bookmarks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final bookmark = bookmarks[index];
                    final surah = QuranMetadata.surah(bookmark.surahNumber);
                    final verse = quranController.getVerse(
                      bookmark.surahNumber,
                      bookmark.ayahNumber,
                    );
                    return Card(
                      child: ListTile(
                        key: ValueKey(
                          'bookmark-tile-${bookmark.coordinateKey}',
                        ),
                        title: Text(
                          'سورة ${surah.name} • الآية ${bookmark.ayahNumber}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          verse?.text ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(fontFamily: 'AmiriQuran'),
                        ),
                        trailing: IconButton(
                          tooltip: 'إزالة الحفظ',
                          onPressed: () => bookmarkController.removeBookmark(
                            bookmark.surahNumber,
                            bookmark.ayahNumber,
                          ),
                          icon: const Icon(Icons.bookmark_rounded),
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => QuranReaderPage(
                                controller: quranController,
                                surahNumber: bookmark.surahNumber,
                                initialAyah: bookmark.ayahNumber,
                                readingProgressController:
                                    readingProgressController,
                                bookmarkController: bookmarkController,
                                audioController: audioController,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _EmptyBookmarks extends StatelessWidget {
  const _EmptyBookmarks();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/design/22_empty_no_bookmarks.webp',
              height: 150,
              fit: BoxFit.contain,
              cacheWidth: 480,
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد آيات محفوظة بعد',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'يمكنك حفظ أي آية من صفحة القراءة والعودة إليها هنا.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
