import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/app_components.dart';
import '../../data/repositories/quran_knowledge_repositories.dart';
import '../../data/repositories/quran_search_history_repository.dart';
import '../adhkar/adhkar_controller.dart';
import '../adhkar/adhkar_page.dart';
import '../audio/quran_audio_controller.dart';
import '../audio/listening_page.dart';
import '../bookmarks/bookmark_controller.dart';
import '../bookmarks/bookmarks_page.dart';
import '../duas/dua_controller.dart';
import '../duas/duas_page.dart';
import '../khatma/khatma_controller.dart';
import '../khatma/khatma_page.dart';
import '../memorization/memorization_controller.dart';
import '../memorization/memorization_page.dart';
import '../mushaf/data/mushaf_preferences.dart';
import '../prayer/prayer_controller.dart';
import '../prayer/prayer_page.dart';
import '../qibla/qibla_controller.dart';
import '../qibla/qibla_page.dart';
import '../quran/quran_controller.dart';
import '../quran/quran_page.dart';
import '../reader/quran_reader_page.dart';
import '../reader/reading_progress_controller.dart';
import '../study/verse_study_page.dart';
import '../tasbeeh/tasbeeh_controller.dart';
import '../tasbeeh/tasbeeh_page.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_page.dart';
import '../daily/daily_islamic_controller.dart';
import '../daily/daily_islamic_page.dart';
import 'universal_search_service.dart';

class QuranSearchPage extends StatefulWidget {
  const QuranSearchPage({
    super.key,
    required this.quranController,
    required this.readingProgressController,
    required this.bookmarkController,
    this.audioController,
    this.memorizationController,
    this.adhkarController,
    this.duaController,
    this.khatmaController,
    this.prayerController,
    this.qiblaController,
    this.tasbeehController,
    this.settingsController,
    this.dailyIslamicController,
    this.historyRepository,
  });

  final QuranController quranController;
  final ReadingProgressController readingProgressController;
  final BookmarkController bookmarkController;
  final QuranAudioController? audioController;
  final MemorizationController? memorizationController;
  final AdhkarController? adhkarController;
  final DuaController? duaController;
  final KhatmaController? khatmaController;
  final PrayerController? prayerController;
  final QiblaController? qiblaController;
  final TasbeehController? tasbeehController;
  final SettingsController? settingsController;
  final DailyIslamicController? dailyIslamicController;
  final QuranSearchHistoryRepository? historyRepository;

  @override
  State<QuranSearchPage> createState() => _QuranSearchPageState();
}

class _QuranSearchPageState extends State<QuranSearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late final QuranSearchHistoryRepository _history;
  UniversalSearchService? _searchService;
  UniversalSearchResults _results = const UniversalSearchResults([]);
  List<String> _recent = const [];
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _history = widget.historyRepository ?? QuranSearchHistoryRepository();
    _initialize();
  }

  Future<void> _initialize() async {
    final timer = Stopwatch()..start();
    final recentFuture = _history.load();
    List<QuranStudySearchDocument> studyDocuments = const [];
    try {
      studyDocuments =
          (await BundledQuranStudyRepository.load()).searchDocuments;
    } catch (_) {
      // Quran and personal content remain searchable if the study pack fails
      // its integrity gate. The UI never exposes a platform exception.
    }
    final memorization = widget.memorizationController;
    final service = UniversalSearchService(
      UniversalSearchCorpus(
        verses: widget.quranController.verses,
        studyDocuments: studyDocuments,
        dhikrCategories: widget.adhkarController?.categories ?? const [],
        dhikrItems: widget.adhkarController?.items ?? const [],
        duaCategories: widget.duaController?.categories ?? const [],
        duaItems: widget.duaController?.items ?? const [],
        bookmarks: widget.bookmarkController.bookmarks,
        memorizationPlans: memorization?.plans ?? const [],
        memorizedAyahs: memorization?.memorizedAyahs ?? const [],
        dueReviewAyahs: memorization?.dueReviewAyahs ?? const [],
        khatmaPlans: widget.khatmaController?.plans ?? const [],
        destinations: _destinations(),
      ),
    );
    final recent = await recentFuture;
    if (!mounted) return;
    setState(() {
      _searchService = service;
      _recent = recent;
      if (_query.isNotEmpty) _results = service.search(_query);
    });
    if (kDebugMode) {
      debugPrint(
        'Universal search index ready in ${timer.elapsedMilliseconds} ms',
      );
    }
  }

  List<UniversalSearchDestination> _destinations() => [
    const UniversalSearchDestination(
      id: 'quran',
      title: 'المصحف',
      subtitle: 'قراءة القرآن الكريم',
      aliases: ['القرآن', 'السور'],
    ),
    if (widget.audioController != null)
      const UniversalSearchDestination(
        id: 'listening',
        title: 'الاستماع',
        subtitle: 'التلاوات والمشغل',
        aliases: ['تلاوة', 'قارئ'],
      ),
    if (widget.prayerController != null)
      const UniversalSearchDestination(
        id: 'prayer',
        title: 'مواقيت الصلاة',
        subtitle: 'أوقات اليوم وإعدادات الحساب',
        aliases: ['الصلاة', 'الفجر', 'العصر'],
      ),
    if (widget.qiblaController != null)
      const UniversalSearchDestination(
        id: 'qibla',
        title: 'القبلة',
        subtitle: 'اتجاه القبلة',
      ),
    if (widget.adhkarController != null)
      const UniversalSearchDestination(
        id: 'adhkar',
        title: 'الأذكار',
        subtitle: 'فئات الأذكار والجلسات',
        aliases: ['ذكر', 'الصباح', 'المساء'],
      ),
    if (widget.duaController != null)
      const UniversalSearchDestination(
        id: 'duas',
        title: 'الأدعية',
        subtitle: 'الأدعية الموثقة',
        aliases: ['دعاء'],
      ),
    if (widget.tasbeehController != null)
      const UniversalSearchDestination(
        id: 'tasbeeh',
        title: 'السبحة',
        subtitle: 'عداد التسبيح',
        aliases: ['تسبيح'],
      ),
    if (widget.memorizationController != null)
      const UniversalSearchDestination(
        id: 'memorization',
        title: 'الحفظ',
        subtitle: 'الخطط والمراجعة',
        aliases: ['مراجعة'],
      ),
    if (widget.khatmaController != null)
      const UniversalSearchDestination(
        id: 'khatma',
        title: 'الختمة',
        subtitle: 'خطة الورد والختمة',
        aliases: ['ورد'],
      ),
    if (widget.dailyIslamicController != null)
      const UniversalSearchDestination(
        id: 'daily',
        title: 'التقويم الهجري',
        subtitle: 'اليوم الإسلامي والتقويم',
        aliases: ['هجري', 'الصيام'],
      ),
    const UniversalSearchDestination(
      id: 'resources',
      title: 'التفسير ومعاني الكلمات',
      subtitle: 'موارد دراسة القرآن',
      aliases: ['الترجمة', 'التفسير', 'معاني الكلمات'],
    ),
    const UniversalSearchDestination(
      id: 'bookmarks',
      title: 'المحفوظات',
      subtitle: 'الآيات المحفوظة',
      aliases: ['علامة'],
    ),
    if (widget.settingsController != null)
      const UniversalSearchDestination(
        id: 'settings',
        title: 'الإعدادات',
        subtitle: 'إعدادات التطبيق والعبادة',
      ),
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('البحث والاستكشاف')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SearchBar(
            key: const ValueKey('quran-verse-search-field'),
            controller: _controller,
            focusNode: _focusNode,
            hintText: 'آية، تفسير، ذكر، دعاء، حفظ أو ختمة',
            leading: const Icon(Icons.search_rounded),
            trailing: [
              if (_query.isNotEmpty)
                IconButton(
                  tooltip: 'مسح البحث',
                  onPressed: () {
                    _controller.clear();
                    _search('', immediate: true);
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
            onChanged: _search,
            onSubmitted: (value) {
              _search(value, immediate: true);
              _saveRecent(value);
            },
          ),
        ),
        Expanded(
          child: _searchService == null
              ? const Center(child: CircularProgressIndicator())
              : _query.trim().isEmpty
              ? _beforeSearch()
              : _resultList(),
        ),
      ],
    ),
  );

  Widget _beforeSearch() => ListView(
    padding: const EdgeInsets.all(AppSpacing.md),
    children: [
      if (_recent.isNotEmpty) ...[
        Row(
          children: [
            const Expanded(child: AppSectionHeader('عمليات البحث الأخيرة')),
            TextButton(
              onPressed: () async {
                await _history.clear();
                if (mounted) setState(() => _recent = const []);
              },
              child: const Text('مسح'),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _recent
              .map(
                (query) => ActionChip(
                  label: Text(query),
                  onPressed: () => _useQuery(query),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
      ],
      const AppSectionHeader('ابحث في التطبيق'),
      const SizedBox(height: 8),
      const PremiumCard(
        child: Text(
          'اكتب كلمة من آية أو تفسير، أو اسم سورة، أو 2:255. يشمل البحث أيضًا الأذكار والأدعية ومحفوظاتك وخطط الحفظ والختمة.',
        ),
      ),
    ],
  );

  Widget _resultList() {
    if (_results.total == 0) {
      return const AppEmptyState(
        icon: Icons.search_off_rounded,
        asset: 'assets/design/21_empty_no_results.webp',
        title: 'لا توجد نتائج',
        message: 'جرّب كلمة أقصر أو إحداثيًا مثل 2:255.',
      );
    }
    final rows = <Object>[];
    for (final group in _results.groups) {
      rows.add(group);
      rows.addAll(group.results);
    }
    return ListView.builder(
      key: const ValueKey('quran-search-results'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is UniversalSearchGroup) {
          return Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: AppSectionHeader('${row.title} (${row.results.length})'),
          );
        }
        final result = row as UniversalSearchResult;
        return Card(
          child: ListTile(
            leading: Icon(_icon(result.type), color: AppColors.accentGold),
            title: Text(result.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.subtitle),
                if (result.excerpt case final excerpt?)
                  Text(
                    excerpt,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textDirection:
                        result.type == UniversalSearchType.translation
                        ? TextDirection.ltr
                        : TextDirection.rtl,
                  ),
              ],
            ),
            onTap: () => _open(result),
          ),
        );
      },
    );
  }

  void _search(String value, {bool immediate = false}) {
    _debounce?.cancel();
    setState(() => _query = value);
    void run() {
      if (!mounted || value != _query) return;
      final timer = Stopwatch()..start();
      setState(() {
        _results =
            _searchService?.search(value) ?? const UniversalSearchResults([]);
      });
      if (kDebugMode) {
        debugPrint(
          'Universal search query completed in ${timer.elapsedMilliseconds} ms',
        );
      }
    }

    if (immediate) {
      run();
    } else {
      _debounce = Timer(const Duration(milliseconds: 120), run);
    }
  }

  void _useQuery(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _search(query, immediate: true);
  }

  Future<void> _saveRecent(String value) async {
    final next = await _history.add(value);
    if (mounted) setState(() => _recent = next);
  }

  Future<void> _open(UniversalSearchResult result) async {
    await _saveRecent(_query);
    if (!mounted) return;
    switch (result.type) {
      case UniversalSearchType.surah:
      case UniversalSearchType.ayah:
      case UniversalSearchType.bookmark:
      case UniversalSearchType.memorizationAyah:
        await _openReader(result.surahNumber!, result.ayahNumber!);
      case UniversalSearchType.translation:
      case UniversalSearchType.tafsir:
      case UniversalSearchType.wordMeaning:
        await Navigator.of(context).push(
          MaterialPageRoute(
            settings: RouteSettings(
              name: '/study/${result.surahNumber}/${result.ayahNumber}',
            ),
            builder: (_) => VerseStudyPage(
              quranController: widget.quranController,
              surahNumber: result.surahNumber!,
              ayahNumber: result.ayahNumber!,
              bookmarkController: widget.bookmarkController,
              audioController: widget.audioController,
              initialTabIndex: switch (result.type) {
                UniversalSearchType.translation => 0,
                UniversalSearchType.tafsir => 1,
                UniversalSearchType.wordMeaning => 2,
                _ => 0,
              },
            ),
          ),
        );
      case UniversalSearchType.dhikr:
        final controller = widget.adhkarController;
        if (controller == null) return;
        await controller.startSession(
          result.categoryId!,
          initialItemId: result.itemId,
        );
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            settings: RouteSettings(name: '/adhkar/${result.itemId}'),
            builder: (_) => AdhkarSessionPage(controller: controller),
          ),
        );
      case UniversalSearchType.dua:
        final controller = widget.duaController;
        final item = controller?.items
            .where((item) => item.id == result.itemId)
            .firstOrNull;
        if (controller == null || item == null) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            settings: RouteSettings(name: '/duas/${result.itemId}'),
            builder: (_) => DuaDetailPage(item: item, controller: controller),
          ),
        );
      case UniversalSearchType.memorizationPlan:
        final controller = widget.memorizationController;
        if (controller == null) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/memorization'),
            builder: (_) => MemorizationPage(
              controller: controller,
              quranController: widget.quranController,
              audioController: widget.audioController,
            ),
          ),
        );
      case UniversalSearchType.khatma:
        await _openKhatma(result.pageNumber ?? 1);
      case UniversalSearchType.destination:
        await _openDestination(result.itemId!);
    }
  }

  Future<void> _openDestination(String id) async {
    Widget? page;
    switch (id) {
      case 'quran':
        page = QuranPage(
          controller: widget.quranController,
          readingProgressController: widget.readingProgressController,
          bookmarkController: widget.bookmarkController,
          audioController: widget.audioController,
          memorizationController: widget.memorizationController,
        );
      case 'listening':
        page = ListeningPage(controller: widget.audioController);
      case 'prayer':
        final controller = widget.prayerController;
        if (controller != null) page = PrayerPage(controller: controller);
      case 'qibla':
        final controller = widget.qiblaController;
        if (controller != null) page = QiblaPage(controller: controller);
      case 'adhkar':
        final controller = widget.adhkarController;
        if (controller != null) page = AdhkarPage(controller: controller);
      case 'duas':
        final controller = widget.duaController;
        if (controller != null) page = DuasPage(controller: controller);
      case 'tasbeeh':
        final controller = widget.tasbeehController;
        if (controller != null) page = TasbeehPage(controller: controller);
      case 'memorization':
        final controller = widget.memorizationController;
        if (controller != null) {
          page = MemorizationPage(
            controller: controller,
            quranController: widget.quranController,
            audioController: widget.audioController,
          );
        }
      case 'khatma':
        await _openKhatma(
          widget.khatmaController?.activePlan?.currentPage ?? 1,
        );
        return;
      case 'daily':
        final controller = widget.dailyIslamicController;
        if (controller != null) page = DailyIslamicPage(controller: controller);
      case 'resources':
        page = const QuranResourcesPage();
      case 'bookmarks':
        page = BookmarksPage(
          bookmarkController: widget.bookmarkController,
          quranController: widget.quranController,
          readingProgressController: widget.readingProgressController,
          audioController: widget.audioController,
        );
      case 'settings':
        final controller = widget.settingsController;
        if (controller != null) {
          page = SettingsPage(
            controller: controller,
            contentManifest: widget.adhkarController?.manifest,
          );
        }
    }
    if (page == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(name: '/$id'),
        builder: (_) => page!,
      ),
    );
  }

  Future<void> _openReader(int surah, int ayah) => Navigator.of(context).push(
    MaterialPageRoute(
      settings: RouteSettings(name: '/quran/$surah/$ayah'),
      builder: (_) => QuranReaderPage(
        controller: widget.quranController,
        surahNumber: surah,
        initialAyah: ayah,
        readingProgressController: widget.readingProgressController,
        bookmarkController: widget.bookmarkController,
        audioController: widget.audioController,
        memorizationController: widget.memorizationController,
      ),
    ),
  );

  Future<void> _openKhatma(int page) async {
    final khatma = widget.khatmaController;
    if (khatma == null) return;
    final saved = await SharedPreferencesMushafPreferences().loadProgress();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/khatma'),
        builder: (_) => KhatmaPage(
          controller: khatma,
          currentReadingPage: saved?.pageNumber ?? page,
          onStartWird: (startPage) => Navigator.of(context).push(
            MaterialPageRoute(
              settings: const RouteSettings(name: '/khatma/wird'),
              builder: (_) => KhatmaMushafPage(
                initialPage: startPage,
                khatmaController: khatma,
                quranController: widget.quranController,
                bookmarkController: widget.bookmarkController,
                audioController: widget.audioController,
                memorizationController: widget.memorizationController,
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _icon(UniversalSearchType type) => switch (type) {
    UniversalSearchType.surah => Icons.menu_book_rounded,
    UniversalSearchType.ayah => Icons.format_quote_rounded,
    UniversalSearchType.translation => Icons.translate_rounded,
    UniversalSearchType.tafsir => Icons.library_books_outlined,
    UniversalSearchType.wordMeaning => Icons.text_fields_rounded,
    UniversalSearchType.dhikr => Icons.auto_awesome_rounded,
    UniversalSearchType.dua => Icons.volunteer_activism_outlined,
    UniversalSearchType.bookmark => Icons.bookmark_rounded,
    UniversalSearchType.memorizationPlan ||
    UniversalSearchType.memorizationAyah => Icons.workspace_premium_rounded,
    UniversalSearchType.khatma => Icons.auto_stories_rounded,
    UniversalSearchType.destination => Icons.arrow_circle_left_outlined,
  };
}
