import 'package:flutter/material.dart';

import '../../data/models/surah.dart';
import '../reader/quran_reader_page.dart';
import '../reader/reading_progress_controller.dart';
import '../bookmarks/bookmark_controller.dart';
import '../audio/quran_audio_controller.dart';
import '../memorization/memorization_controller.dart';
import '../search/quran_search_page.dart';
import '../mushaf/data/mushaf_preferences.dart';
import '../mushaf/data/mushaf_repository.dart';
import '../mushaf/presentation/mushaf_page_view.dart';
import 'quran_controller.dart';

class QuranPage extends StatefulWidget {
  const QuranPage({
    super.key,
    required this.controller,
    required this.readingProgressController,
    required this.bookmarkController,
    this.audioController,
    this.memorizationController,
    this.mushafRepository,
    this.mushafPreferences,
    this.onOpenSearch,
    this.initialMode,
  });

  final QuranController controller;
  final ReadingProgressController readingProgressController;
  final BookmarkController bookmarkController;
  final QuranAudioController? audioController;
  final MemorizationController? memorizationController;
  final MushafRepository? mushafRepository;
  final MushafPreferences? mushafPreferences;
  final VoidCallback? onOpenSearch;
  final QuranReaderMode? initialMode;

  static const List<Surah> surahs = QuranMetadata.surahs;

  @override
  State<QuranPage> createState() => _QuranPageState();
}

@visibleForTesting
String normalizeSurahSearch(String value) => value
    .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ؤ', 'و')
    .replaceAll('ئ', 'ي')
    .replaceAll('ة', 'ه')
    .replaceAll(RegExp(r'\s+'), '')
    .trim()
    .toLowerCase();

@visibleForTesting
List<Surah> filterSurahs(String query) {
  final normalized = normalizeSurahSearch(query);
  if (normalized.isEmpty) return QuranMetadata.surahs;
  return QuranMetadata.surahs
      .where((surah) => normalizeSurahSearch(surah.name).contains(normalized))
      .toList(growable: false);
}

class _QuranPageState extends State<QuranPage> {
  final _searchController = TextEditingController();
  final _mushafNavigationController = MushafNavigationController();
  late final MushafRepository _mushafRepository;
  late final MushafPreferences _mushafPreferences;
  String _query = '';
  QuranReaderMode _mode = QuranReaderMode.mushaf;
  bool _modeLoaded = false;

  @override
  void initState() {
    super.initState();
    _mushafRepository = widget.mushafRepository ?? MadinaMushafRepository();
    _mushafPreferences =
        widget.mushafPreferences ?? SharedPreferencesMushafPreferences();
    widget.audioController?.addListener(_onAudioChanged);
    _loadMode();
  }

  void _onAudioChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadMode() async {
    final mode = widget.initialMode ?? await _mushafPreferences.loadMode();
    if (mounted) {
      setState(() {
        _mode = mode;
        _modeLoaded = true;
      });
    }
  }

  Future<void> _setMode(QuranReaderMode mode) async {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    await _mushafPreferences.saveMode(mode);
  }

  @override
  void dispose() {
    widget.audioController?.removeListener(_onAudioChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mushafMode = _mode == QuranReaderMode.mushaf;
    return Scaffold(
      appBar: AppBar(
        title: _ReaderModeSwitch(mode: _mode, onChanged: _setMode),
        centerTitle: true,
        actions: [
          IconButton(
            key: const ValueKey('open-quran-search'),
            tooltip: 'البحث والاستكشاف',
            onPressed: _openSearch,
            icon: const Icon(Icons.manage_search_rounded),
          ),
          if (mushafMode) ...[
            IconButton(
              key: const ValueKey('mushaf-surah-jump'),
              tooltip: 'الانتقال إلى سورة',
              onPressed: _showSurahJump,
              icon: const Icon(Icons.format_list_numbered_rtl_rounded),
            ),
            IconButton(
              key: const ValueKey('mushaf-page-jump'),
              tooltip: 'الانتقال إلى صفحة',
              onPressed: _showPageJump,
              icon: const Icon(Icons.find_in_page_outlined),
            ),
            if (widget.audioController?.currentSurahNumber != null)
              IconButton(
                key: const ValueKey('mushaf-go-playing'),
                tooltip: 'الانتقال إلى الآية المشغلة',
                onPressed: _goToPlayingAyah,
                icon: const Icon(Icons.graphic_eq_rounded),
              ),
          ],
        ],
      ),
      body: !_modeLoaded
          ? const Center(child: CircularProgressIndicator())
          : mushafMode
          ? MushafPageView(
              repository: _mushafRepository,
              preferences: _mushafPreferences,
              quranController: widget.controller,
              bookmarkController: widget.bookmarkController,
              audioController: widget.audioController,
              memorizationController: widget.memorizationController,
              navigationController: _mushafNavigationController,
            )
          : _buildStudyBody(),
    );
  }

  Widget _buildStudyBody() {
    final surahs = filterSurahs(_query);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: TextField(
            key: const ValueKey('surah-search-field'),
            controller: _searchController,
            textDirection: TextDirection.rtl,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'ابحث باسم السورة',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      key: const ValueKey('clear-surah-search'),
                      tooltip: 'مسح البحث',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: surahs.isEmpty
              ? const _EmptySearchResult()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 30),
                  itemCount: surahs.length,
                  itemBuilder: (context, index) => _SurahCard(
                    surah: surahs[index],
                    controller: widget.controller,
                    readingProgressController: widget.readingProgressController,
                    bookmarkController: widget.bookmarkController,
                    audioController: widget.audioController,
                    memorizationController: widget.memorizationController,
                  ),
                ),
        ),
      ],
    );
  }

  void _openSearch() {
    final callback = widget.onOpenSearch;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuranSearchPage(
          quranController: widget.controller,
          readingProgressController: widget.readingProgressController,
          bookmarkController: widget.bookmarkController,
          audioController: widget.audioController,
          memorizationController: widget.memorizationController,
        ),
      ),
    );
  }

  Future<void> _showPageJump() async {
    final page = await showMushafPageJumpDialog(context);
    if (page != null) await _mushafNavigationController.jumpToPage(page);
  }

  Future<void> _showSurahJump() async {
    final surah = await showModalBottomSheet<Surah>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.builder(
          key: const ValueKey('mushaf-surah-list'),
          itemCount: QuranMetadata.surahCount,
          itemBuilder: (context, index) {
            final item = QuranMetadata.surahs[index];
            return ListTile(
              title: Text('سورة ${item.name}'),
              leading: Text('${item.number}'),
              onTap: () => Navigator.pop(context, item),
            );
          },
        ),
      ),
    );
    if (surah != null) {
      await _mushafNavigationController.jumpToSurah(surah.number);
    }
  }

  Future<void> _goToPlayingAyah() async {
    final audio = widget.audioController;
    if (audio?.currentSurahNumber == null || audio?.currentAyahNumber == null) {
      return;
    }
    await _mushafNavigationController.jumpToCoordinate(
      audio!.currentSurahNumber!,
      audio.currentAyahNumber!,
    );
  }
}

Future<int?> showMushafPageJumpDialog(BuildContext context) {
  var input = '';
  return showDialog<int>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('الانتقال إلى صفحة'),
      content: TextField(
        key: const ValueKey('mushaf-page-input'),
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(hintText: '1 — 604'),
        onChanged: (value) => input = value,
        onSubmitted: (_) => _submitMushafPage(dialogContext, input),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => _submitMushafPage(dialogContext, input),
          child: const Text('انتقل'),
        ),
      ],
    ),
  );
}

void _submitMushafPage(BuildContext context, String input) {
  final page = int.tryParse(input);
  if (page != null && page >= 1 && page <= 604) {
    Navigator.pop(context, page);
  }
}

class _ReaderModeSwitch extends StatelessWidget {
  const _ReaderModeSwitch({required this.mode, required this.onChanged});
  final QuranReaderMode mode;
  final ValueChanged<QuranReaderMode> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<QuranReaderMode>(
    key: const ValueKey('quran-reader-mode-switch'),
    showSelectedIcon: false,
    segments: const [
      ButtonSegment(value: QuranReaderMode.mushaf, label: Text('المصحف')),
      ButtonSegment(value: QuranReaderMode.study, label: Text('دراسة الآيات')),
    ],
    selected: {mode},
    onSelectionChanged: (selection) => onChanged(selection.single),
    style: const ButtonStyle(
      visualDensity: VisualDensity(horizontal: -3, vertical: -3),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
}

class _EmptySearchResult extends StatelessWidget {
  const _EmptySearchResult();

  @override
  Widget build(BuildContext context) => const Center(
    key: ValueKey('surah-search-empty'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.search_off_rounded, size: 44),
        SizedBox(height: 12),
        Text('لا توجد سورة بهذا الاسم'),
      ],
    ),
  );
}

class _SurahCard extends StatelessWidget {
  const _SurahCard({
    required this.surah,
    required this.controller,
    required this.readingProgressController,
    required this.bookmarkController,
    this.audioController,
    this.memorizationController,
  });

  final Surah surah;
  final QuranController controller;
  final ReadingProgressController readingProgressController;
  final BookmarkController bookmarkController;
  final QuranAudioController? audioController;
  final MemorizationController? memorizationController;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => QuranReaderPage(
                controller: controller,
                surahNumber: surah.number,
                readingProgressController: readingProgressController,
                bookmarkController: bookmarkController,
                audioController: audioController,
                memorizationController: memorizationController,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              _SurahNumber(number: surah.number),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سورة ${surah.name}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${surah.revelationType} • ${surah.ayahCount} آيات',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurahNumber extends StatelessWidget {
  const _SurahNumber({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}
