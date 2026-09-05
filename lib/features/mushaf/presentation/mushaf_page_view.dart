import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../data/models/quran_verse.dart';
import '../../../data/models/surah.dart';
import '../../audio/quran_audio_controller.dart';
import '../../bookmarks/bookmark_controller.dart';
import '../../memorization/memorization_controller.dart';
import '../../quran/quran_controller.dart';
import '../../reader/quran_ayah_actions.dart';
import '../data/mushaf_preferences.dart';
import '../data/mushaf_repository.dart';
import '../domain/mushaf_models.dart';

class MushafNavigationController {
  Future<void> Function(int page)? _page;
  Future<void> Function(int surah)? _surah;
  Future<void> Function(int surah, int ayah)? _coordinate;

  bool get isAttached => _page != null;
  Future<void> jumpToPage(int page) async => _page?.call(page);
  Future<void> jumpToSurah(int surah) async => _surah?.call(surah);
  Future<void> jumpToCoordinate(int surah, int ayah) async =>
      _coordinate?.call(surah, ayah);

  void _attach({
    required Future<void> Function(int) page,
    required Future<void> Function(int) surah,
    required Future<void> Function(int, int) coordinate,
  }) {
    _page = page;
    _surah = surah;
    _coordinate = coordinate;
  }

  void _detach() {
    _page = null;
    _surah = null;
    _coordinate = null;
  }
}

@visibleForTesting
double mushafScaleForPinch({
  required double startScale,
  required double startDistance,
  required double currentDistance,
}) {
  if (startDistance <= 0 ||
      !startDistance.isFinite ||
      !currentDistance.isFinite) {
    return startScale.clamp(
      MushafDisplaySettings.minScale,
      MushafDisplaySettings.maxScale,
    );
  }
  return (startScale * (currentDistance / startDistance)).clamp(
    MushafDisplaySettings.minScale,
    MushafDisplaySettings.maxScale,
  );
}

class MushafPageView extends StatefulWidget {
  const MushafPageView({
    super.key,
    required this.repository,
    required this.preferences,
    required this.quranController,
    required this.bookmarkController,
    this.audioController,
    this.memorizationController,
    this.navigationController,
    this.initialPage,
    this.onPageChanged,
  });

  final MushafRepository repository;
  final MushafPreferences preferences;
  final QuranController quranController;
  final BookmarkController bookmarkController;
  final QuranAudioController? audioController;
  final MemorizationController? memorizationController;
  final MushafNavigationController? navigationController;
  final int? initialPage;
  final ValueChanged<int>? onPageChanged;

  @override
  State<MushafPageView> createState() => _MushafPageViewState();
}

class _MushafPageViewState extends State<MushafPageView> {
  PageController? _pageController;
  Object? _error;
  int _currentPage = 1;
  int? _selectedSurah;
  int? _selectedAyah;
  MushafDisplaySettings _display = const MushafDisplaySettings();
  double _scaleStart = MushafDisplaySettings.defaultScale;
  double _previousScale = MushafDisplaySettings.defaultScale;
  final Map<int, Offset> _pointers = {};
  double? _pinchStartDistance;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await widget.repository.load();
      final saved = await widget.preferences.loadProgress();
      final display = await widget.preferences.loadDisplaySettings();
      final requested = widget.initialPage ?? saved?.pageNumber ?? 1;
      final page = requested.clamp(1, widget.repository.totalPages);
      if (!mounted) return;
      _currentPage = page;
      _display = display;
      _pageController = PageController(initialPage: page - 1);
      widget.navigationController?._attach(
        page: jumpToPage,
        surah: jumpToSurah,
        coordinate: jumpToCoordinate,
      );
      setState(() {});
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    widget.navigationController?._detach();
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> jumpToPage(int page) async {
    if (page < 1 || page > widget.repository.totalPages) return;
    await _pageController?.animateToPage(
      page - 1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> jumpToSurah(int surah) =>
      jumpToPage(widget.repository.firstPageForSurah(surah));

  Future<void> jumpToCoordinate(int surah, int ayah) =>
      jumpToPage(widget.repository.pageForCoordinate(surah, ayah));

  Future<void> _onPageChanged(int zeroBasedPage) async {
    final page = widget.repository.page(zeroBasedPage + 1);
    setState(() {
      _currentPage = page.pageNumber;
      _selectedSurah = null;
      _selectedAyah = null;
    });
    await widget.preferences.saveProgress(
      MushafReadingProgress(
        pageNumber: page.pageNumber,
        coordinate: page.firstCoordinate,
      ),
    );
    widget.onPageChanged?.call(page.pageNumber);
  }

  void _updateDisplay(MushafDisplaySettings value, {bool persist = false}) {
    setState(() => _display = value);
    if (persist) widget.preferences.saveDisplaySettings(value);
  }

  void _pointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 2) {
      _scaleStart = _display.scale;
      _pinchStartDistance = _pointerDistance;
    }
  }

  void _pointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    final start = _pinchStartDistance;
    if (_pointers.length < 2 || start == null || start <= 0) return;
    _updateDisplay(
      _display.copyWith(
        scale: mushafScaleForPinch(
          startScale: _scaleStart,
          startDistance: start,
          currentDistance: _pointerDistance,
        ),
      ),
    );
  }

  void _pointerEnd(PointerEvent event) {
    final wasPinching = _pinchStartDistance != null;
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) _pinchStartDistance = null;
    if (wasPinching) widget.preferences.saveDisplaySettings(_display);
  }

  double get _pointerDistance {
    final values = _pointers.values.take(2).toList();
    return values.length < 2 ? 0 : (values[0] - values[1]).distance;
  }

  void _toggleDoubleTap() {
    if (_display.scale < 1.4) {
      _previousScale = _display.scale;
      _updateDisplay(_display.copyWith(scale: 1.45), persist: true);
    } else {
      _updateDisplay(_display.copyWith(scale: _previousScale), persist: true);
    }
  }

  Future<void> _showDisplaySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          void apply(MushafDisplaySettings value) {
            _updateDisplay(value, persist: true);
            setSheetState(() {});
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ListTile(
                    title: Text('عرض المصحف'),
                    subtitle: Text(
                      'المصحف العادي يحافظ على الصفحات، ووضع الراحة يعطي الأولوية لحجم النص.',
                    ),
                  ),
                  SwitchListTile(
                    key: const ValueKey('mushaf-comfort-mode'),
                    title: const Text('وضع القراءة المريحة'),
                    value: _display.comfortMode,
                    onChanged: (value) =>
                        apply(_display.copyWith(comfortMode: value)),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('mushaf-decrease'),
                          onPressed: () => apply(
                            _display.copyWith(scale: _display.scale - .1),
                          ),
                          icon: const Icon(Icons.text_decrease_rounded),
                          label: const Text('تصغير'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('mushaf-reset'),
                          onPressed: () => apply(
                            const MushafDisplaySettings(comfortMode: false),
                          ),
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('الافتراضي'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          key: const ValueKey('mushaf-increase'),
                          onPressed: () => apply(
                            _display.copyWith(scale: _display.scale + .1),
                          ),
                          icon: const Icon(Icons.text_increase_rounded),
                          label: const Text('تكبير'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${_display.scale.toStringAsFixed(2)}×',
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _select(QuranVerse verse) async {
    setState(() {
      _selectedSurah = verse.surahNumber;
      _selectedAyah = verse.ayahNumber;
    });
    await showQuranAyahActions(
      context: context,
      verse: verse,
      quranController: widget.quranController,
      bookmarkController: widget.bookmarkController,
      audioController: widget.audioController,
      memorizationController: widget.memorizationController,
      onStudyCoordinate: (coordinate) =>
          jumpToCoordinate(coordinate.$1, coordinate.$2),
    );
    if (mounted) {
      setState(() {
        _selectedSurah = null;
        _selectedAyah = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return const Center(child: Text('تعذر تحميل تخطيط المصحف.'));
    }
    final controller = _pageController;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _pointerDown,
          onPointerMove: _pointerMove,
          onPointerUp: _pointerEnd,
          onPointerCancel: _pointerEnd,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: PageView.builder(
              key: const ValueKey('mushaf-page-view'),
              controller: controller,
              itemCount: widget.repository.totalPages,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) => RepaintBoundary(
                key: ValueKey('mushaf-page-${index + 1}'),
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    widget.bookmarkController,
                    if (widget.audioController != null) widget.audioController!,
                  ]),
                  builder: (context, _) => _MushafPaperPage(
                    page: widget.repository.page(index + 1),
                    quranController: widget.quranController,
                    audioController: widget.audioController,
                    selectedSurah: _selectedSurah,
                    selectedAyah: _selectedAyah,
                    onAyah: _select,
                    display: _display,
                    onDoubleTap: _toggleDoubleTap,
                  ),
                ),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: 8,
          end: 12,
          child: IconButton.filledTonal(
            key: const ValueKey('mushaf-display-action'),
            tooltip: 'إعدادات عرض المصحف',
            onPressed: _showDisplaySheet,
            icon: const Icon(Icons.text_fields_rounded),
          ),
        ),
        PositionedDirectional(
          bottom: 10,
          start: 0,
          end: 0,
          child: Center(
            child: Semantics(
              liveRegion: true,
              label: 'الصفحة $_currentPage من ${widget.repository.totalPages}',
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.appBackground.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.accentGold.withValues(alpha: 0.6),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: Text(
                    '$_currentPage / ${widget.repository.totalPages}',
                    key: const ValueKey('mushaf-current-page'),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MushafPaperPage extends StatefulWidget {
  const _MushafPaperPage({
    required this.page,
    required this.quranController,
    required this.audioController,
    required this.selectedSurah,
    required this.selectedAyah,
    required this.onAyah,
    required this.display,
    required this.onDoubleTap,
  });

  final MushafPage page;
  final QuranController quranController;
  final QuranAudioController? audioController;
  final int? selectedSurah;
  final int? selectedAyah;
  final ValueChanged<QuranVerse> onAyah;
  final MushafDisplaySettings display;
  final VoidCallback onDoubleTap;

  @override
  State<_MushafPaperPage> createState() => _MushafPaperPageState();
}

QuranVerse? mushafVerseForTextOffset(
  Iterable<({int start, int end, QuranVerse verse})> ranges,
  int offset,
) {
  for (final range in ranges) {
    if (offset >= range.start && offset < range.end) return range.verse;
  }
  return null;
}

class _MushafPaperPageState extends State<_MushafPaperPage> {
  final GlobalKey _textKey = GlobalKey();
  final List<({int start, int end, QuranVerse verse})> _ayahRanges = [];

  @override
  void dispose() {
    super.dispose();
  }

  List<InlineSpan> _spans() {
    _ayahRanges.clear();
    final spans = <InlineSpan>[];
    var offset = 0;
    int? previousSurah;
    for (final coordinate in widget.page.coordinates) {
      final verse = widget.quranController.getVerse(
        coordinate.surahNumber,
        coordinate.ayahNumber,
      );
      if (verse == null) continue;
      if (verse.surahNumber != previousSurah && verse.ayahNumber == 1) {
        final surah = QuranMetadata.surah(verse.surahNumber);
        final header = '${offset == 0 ? '' : '\n'}۞ سورة ${surah.name} ۞\n';
        spans.add(
          TextSpan(
            text: header,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 21,
              fontWeight: FontWeight.bold,
              height: 1.55,
            ),
          ),
        );
        offset += header.length;
        if (surah.basmalaPolicy == BasmalaPolicy.separate) {
          final basmala = '${QuranMetadata.basmala}\n';
          spans.add(
            TextSpan(
              text: basmala,
              style: const TextStyle(fontSize: 20, height: 1.65),
            ),
          );
          offset += basmala.length;
        }
      }
      previousSurah = verse.surahNumber;
      final text = '${verse.text} ۝${verse.ayahNumber} ';
      final start = offset;
      offset += text.length;
      _ayahRanges.add((start: start, end: offset, verse: verse));
      final active =
          widget.audioController?.currentSurahNumber == verse.surahNumber &&
          widget.audioController?.currentAyahNumber == verse.ayahNumber;
      final selected =
          widget.selectedSurah == verse.surahNumber &&
          widget.selectedAyah == verse.ayahNumber;
      spans.add(
        TextSpan(
          text: text,
          style: TextStyle(
            backgroundColor: active || selected
                ? AppColors.accentGold.withValues(alpha: 0.22)
                : null,
          ),
        ),
      );
    }
    return spans;
  }

  void _onLongPress(LongPressStartDetails details) {
    final render = _textKey.currentContext?.findRenderObject();
    if (render is! RenderParagraph) return;
    final local = render.globalToLocal(details.globalPosition);
    final offset = render.getPositionForOffset(local).offset;
    final verse = mushafVerseForTextOffset(_ayahRanges, offset);
    if (verse != null) widget.onAyah(verse);
  }

  void _onTap(TapUpDetails details) {
    final render = _textKey.currentContext?.findRenderObject();
    if (render is! RenderParagraph) return;
    final local = render.globalToLocal(details.globalPosition);
    final verse = mushafVerseForTextOffset(
      _ayahRanges,
      render.getPositionForOffset(local).offset,
    );
    if (verse != null) widget.onAyah(verse);
  }

  @override
  Widget build(BuildContext context) {
    final comfort = widget.display.comfortMode;
    return Padding(
      padding: EdgeInsets.fromLTRB(comfort ? 2 : 8, 4, comfort ? 2 : 8, 42),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.mushafBackground,
          image: const DecorationImage(
            image: ResizeImage(
              AssetImage('assets/design/10_mushaf_paper_texture.webp'),
              width: 900,
            ),
            fit: BoxFit.cover,
            opacity: 0.08,
          ),
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(
            color: AppColors.accentGold.withValues(alpha: 0.72),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44000000),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/design/05_mushaf_header_ornament.png',
                      fit: BoxFit.fill,
                      opacity: const AlwaysStoppedAnimation(0.24),
                      cacheWidth: 900,
                    ),
                  ),
                  PositionedDirectional(
                    top: 3,
                    start: 3,
                    width: 26,
                    height: 26,
                    child: Image.asset(
                      'assets/design/07_mushaf_corner_tl.png',
                      fit: BoxFit.contain,
                      opacity: const AlwaysStoppedAnimation(0.3),
                      cacheWidth: 96,
                    ),
                  ),
                  PositionedDirectional(
                    top: 3,
                    end: 3,
                    width: 26,
                    height: 26,
                    child: Image.asset(
                      'assets/design/08_mushaf_corner_tr.png',
                      fit: BoxFit.contain,
                      opacity: const AlwaysStoppedAnimation(0.3),
                      cacheWidth: 96,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Row(
                      children: [
                        Text(
                          'الجزء ${widget.page.juzNumber}',
                          style: const TextStyle(color: AppColors.textOnCream),
                        ),
                        const Spacer(),
                        Text(
                          'ربع ${widget.page.hizbQuarterNumber}',
                          style: const TextStyle(color: AppColors.textOnCream),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 5,
              child: Image.asset(
                'assets/design/06_mushaf_divider.png',
                width: double.infinity,
                fit: BoxFit.fill,
                opacity: const AlwaysStoppedAnimation(0.42),
                cacheWidth: 900,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: comfort ? 10 : 20,
                  vertical: comfort ? 14 : 10,
                ),
                child: GestureDetector(
                  key: ValueKey('mushaf-page-hit-${widget.page.pageNumber}'),
                  behavior: HitTestBehavior.translucent,
                  onTapUp: _onTap,
                  onDoubleTap: widget.onDoubleTap,
                  onLongPressStart: _onLongPress,
                  child: Text.rich(
                    key: _textKey,
                    TextSpan(children: _spans()),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                      fontFamily: AppTypography.quranFont,
                      fontSize: 22 * widget.display.scale,
                      height: comfort ? 2.0 : 1.82,
                      color: AppColors.textOnCream,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 10,
              child: Image.asset(
                'assets/design/09_mushaf_footer_ornament.png',
                width: double.infinity,
                fit: BoxFit.fill,
                opacity: const AlwaysStoppedAnimation(0.32),
                cacheWidth: 900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
