import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../../data/models/quran_verse.dart';
import '../../data/models/surah.dart';
import '../quran/quran_controller.dart';
import '../bookmarks/bookmark_controller.dart';
import '../audio/quran_audio_controller.dart';
import 'reading_progress_controller.dart';
import '../memorization/memorization_controller.dart';
import 'quran_ayah_actions.dart';

class QuranReaderNavigationController {
  Future<void> Function(int ayahNumber)? _scrollToAyah;

  bool get isAttached => _scrollToAyah != null;

  Future<void> scrollToAyah(int ayahNumber) async {
    final callback = _scrollToAyah;
    if (callback != null) await callback(ayahNumber);
  }

  void _attach(Future<void> Function(int ayahNumber) callback) {
    _scrollToAyah = callback;
  }

  void _detach() {
    _scrollToAyah = null;
  }
}

@visibleForTesting
int? mostVisibleAyahIndex(Iterable<ItemPosition> positions) {
  ItemPosition? best;
  var bestFraction = 0.0;

  for (final position in positions) {
    final visibleStart = position.itemLeadingEdge.clamp(0.0, 1.0);
    final visibleEnd = position.itemTrailingEdge.clamp(0.0, 1.0);
    final visibleFraction = visibleEnd - visibleStart;
    if (visibleFraction <= 0) continue;

    if (best == null ||
        visibleFraction > bestFraction ||
        (visibleFraction == bestFraction && position.index < best.index)) {
      best = position;
      bestFraction = visibleFraction;
    }
  }

  return best?.index;
}

class QuranReaderPage extends StatefulWidget {
  const QuranReaderPage({
    super.key,
    required this.controller,
    required this.surahNumber,
    required this.readingProgressController,
    required this.bookmarkController,
    this.navigationController,
    this.initialAyah,
    this.audioController,
    this.memorizationController,
  });

  final QuranController controller;
  final int surahNumber;
  final ReadingProgressController readingProgressController;
  final BookmarkController bookmarkController;
  final QuranReaderNavigationController? navigationController;
  final int? initialAyah;
  final QuranAudioController? audioController;
  final MemorizationController? memorizationController;

  @override
  State<QuranReaderPage> createState() => _QuranReaderPageState();
}

class _QuranReaderPageState extends State<QuranReaderPage> {
  static const _progressDebounce = Duration(milliseconds: 400);
  static const _fontSizeKey = 'quran.reader_font_size';
  static const double minFontSize = 22;
  static const double maxFontSize = 42;
  static const double defaultFontSize = 30;

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  double _fontSize = defaultFontSize;
  int? _selectedAyah;
  Timer? _progressTimer;
  int? _pendingAyah;
  int? _lastTrackedAyah;
  int? _lastAudioAyah;

  Surah get _surah => QuranMetadata.surah(widget.surahNumber);
  List<QuranVerse> get _verses =>
      widget.controller.getSurah(widget.surahNumber);

  @override
  void initState() {
    super.initState();
    widget.navigationController?._attach(scrollToAyah);
    _itemPositionsListener.itemPositions.addListener(_onPositionsChanged);
    _initializeProgress();
    _loadFontSize();
    widget.audioController?.addListener(_onAudioChanged);
  }

  Future<void> _loadFontSize() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getDouble(_fontSizeKey);
    if (!mounted || saved == null) return;
    setState(() => _fontSize = saved.clamp(minFontSize, maxFontSize));
  }

  Future<void> _setFontSize(double value) async {
    final next = value.clamp(minFontSize, maxFontSize);
    if (mounted) setState(() => _fontSize = next);
    await _persistFontSize(next);
  }

  Future<void> _persistFontSize(double value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_fontSizeKey, value);
  }

  void _onAudioChanged() {
    final audio = widget.audioController;
    if (audio == null || audio.currentSurahNumber != widget.surahNumber) return;
    final ayah = audio.currentAyahNumber;
    if (ayah == null || ayah == _lastAudioAyah) return;
    _lastAudioAyah = ayah;
    if (mounted) {
      setState(() {});
      scrollToAyah(ayah);
    }
  }

  Future<void> _initializeProgress() async {
    await widget.readingProgressController.load();
    if (!mounted) return;

    final saved = widget.readingProgressController.progress;
    final requestedAyah = widget.initialAyah;
    final targetAyah =
        requestedAyah != null &&
            requestedAyah >= 1 &&
            requestedAyah <= _surah.ayahCount
        ? requestedAyah
        : saved?.surahNumber == widget.surahNumber
        ? saved!.ayahNumber
        : 1;

    if (requestedAyah == null && saved?.surahNumber != widget.surahNumber) {
      await widget.readingProgressController.update(
        surahNumber: widget.surahNumber,
        ayahNumber: 1,
      );
    }
    _lastTrackedAyah = targetAyah;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) scrollToAyah(targetAyah, animated: false);
    });
  }

  Future<void> scrollToAyah(int ayahNumber, {bool animated = true}) async {
    if (ayahNumber < 1 ||
        ayahNumber > _surah.ayahCount ||
        !_itemScrollController.isAttached) {
      return;
    }

    final index = ayahNumber - 1;
    if (animated) {
      await _itemScrollController.scrollTo(
        index: index,
        alignment: 0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _itemScrollController.jumpTo(index: index, alignment: 0);
    }
  }

  void _onPositionsChanged() {
    final index = mostVisibleAyahIndex(
      _itemPositionsListener.itemPositions.value,
    );
    if (index == null) return;

    final ayahNumber = index + 1;
    if (ayahNumber == _lastTrackedAyah || ayahNumber == _pendingAyah) return;

    _pendingAyah = ayahNumber;
    _progressTimer?.cancel();
    _progressTimer = Timer(_progressDebounce, () async {
      final pending = _pendingAyah;
      if (pending == null || !mounted) return;
      _pendingAyah = null;
      _lastTrackedAyah = pending;
      await widget.readingProgressController.update(
        surahNumber: widget.surahNumber,
        ayahNumber: pending,
      );
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _itemPositionsListener.itemPositions.removeListener(_onPositionsChanged);
    widget.navigationController?._detach();
    widget.audioController?.removeListener(_onAudioChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final verses = _verses;
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios_rounded),
          tooltip: 'رجوع',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'سورة ${_surah.name}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            key: const ValueKey('reader-overflow'),
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'المزيد',
            onPressed: () => _showReaderMenu(context),
          ),
        ],
      ),
      body: verses.isEmpty
          ? const Center(child: Text('لا توجد آيات لهذه السورة'))
          : Center(
              child: Container(
                key: const ValueKey('mushaf-surface'),
                constraints: const BoxConstraints(maxWidth: 760),
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                decoration: BoxDecoration(
                  color: AppColors.mushafBackground,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: Border.all(
                    color: AppColors.accentGold.withValues(alpha: 0.65),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    const _MushafOrnament(),
                    Expanded(child: _buildQuranContent(context, verses)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildQuranContent(BuildContext context, List<QuranVerse> verses) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.bookmarkController,
        if (widget.audioController != null) widget.audioController!,
      ]),
      builder: (context, _) => ScrollablePositionedList.builder(
        itemScrollController: _itemScrollController,
        itemPositionsListener: _itemPositionsListener,
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 48),
        itemCount: verses.length,
        itemBuilder: (context, index) {
          final verse = verses[index];
          return Column(
            key: ValueKey('ayah-${verse.surahNumber}-${verse.ayahNumber}'),
            children: [
              if (index == 0) ...[
                _buildSurahHeader(context),
                const SizedBox(height: 16),
                if (_surah.basmalaPolicy == BasmalaPolicy.separate) ...[
                  _buildBasmala(context),
                  const SizedBox(height: 18),
                ],
              ],
              QuranAyahItem(
                verse: verse,
                fontSize: _fontSize,
                isActive:
                    widget.audioController?.currentSurahNumber ==
                        verse.surahNumber &&
                    widget.audioController?.currentAyahNumber ==
                        verse.ayahNumber,
                isSelected: _selectedAyah == verse.ayahNumber,
                onTap: () => _showAyahActions(verse),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSurahHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Text(
            'سورة ${_surah.name}',
            key: const ValueKey('reader-surah-header'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.quranFont,
              fontSize: 25,
              color: AppColors.textOnCream,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${_surah.revelationType} • ${_surah.ayahCount} آيات',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textOnCream.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasmala(BuildContext context) {
    return Text(
      QuranMetadata.basmala,
      key: const ValueKey('reader-basmala'),
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      style: TextStyle(
        fontFamily: AppTypography.quranFont,
        fontSize: (_fontSize - 3).clamp(minFontSize, maxFontSize),
        height: 1.8,
        color: AppColors.textOnCream,
      ),
    );
  }

  Future<void> _showAyahActions(QuranVerse verse) async {
    setState(() => _selectedAyah = verse.ayahNumber);
    await showQuranAyahActions(
      context: context,
      verse: verse,
      quranController: widget.controller,
      bookmarkController: widget.bookmarkController,
      audioController: widget.audioController,
      memorizationController: widget.memorizationController,
      onStudyCoordinate: (coordinate) async {
        if (coordinate.$1 == widget.surahNumber) {
          await scrollToAyah(coordinate.$2);
        }
      },
    );
    if (mounted) setState(() => _selectedAyah = null);
  }

  void _showReaderMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restart_alt_rounded),
              title: const Text('إعادة حجم الخط'),
              onTap: () {
                _setFontSize(defaultFontSize);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.format_size_rounded),
              title: const Text('حجم خط القراءة'),
              subtitle: StatefulBuilder(
                builder: (context, setSheetState) => Slider(
                  key: const ValueKey('reader-font-size-slider'),
                  min: minFontSize,
                  max: maxFontSize,
                  divisions: 20,
                  value: _fontSize,
                  label: _fontSize.round().toString(),
                  onChanged: (value) {
                    setSheetState(() {});
                    _setFontSize(value);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuranAyahItem extends StatelessWidget {
  const QuranAyahItem({
    super.key,
    required this.verse,
    required this.fontSize,
    required this.isActive,
    this.isSelected = false,
    required this.onTap,
  });

  final QuranVerse verse;
  final double fontSize;
  final bool isActive;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('ayah-tap-${verse.surahNumber}-${verse.ayahNumber}'),
      onTap: onTap,
      child: AnimatedContainer(
        key: ValueKey('ayah-surface-${verse.surahNumber}-${verse.ayahNumber}'),
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        decoration: BoxDecoration(
          color: isActive || isSelected
              ? AppColors.accentGold.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Semantics(
          container: true,
          label: 'سورة ${verse.surahNumber}، الآية ${verse.ayahNumber}',
          child: Text(
            '${verse.text} ۝${verse.ayahNumber}',
            semanticsLabel: '${verse.text}، الآية ${verse.ayahNumber}',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.justify,
            style: TextStyle(
              fontFamily: AppTypography.quranFont,
              fontSize: fontSize,
              height: 1.9,
              color: AppColors.textOnCream,
            ),
          ),
        ),
      ),
    );
  }
}

class _MushafOrnament extends StatelessWidget {
  const _MushafOrnament();
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('mushaf-ornament'),
    height: 10,
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: AppColors.accentGold.withValues(alpha: 0.55)),
      ),
      gradient: LinearGradient(
        colors: [
          Colors.transparent,
          AppColors.accentGold.withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ),
    ),
  );
}
