import 'package:flutter/material.dart';

import '../features/home/home_page.dart';
import '../features/bookmarks/bookmark_controller.dart';
import '../features/bookmarks/bookmarks_page.dart';
import '../features/audio/audio_mini_player.dart';
import '../features/audio/quran_audio_controller.dart';
import '../features/audio/listening_page.dart';
import '../features/memorization/memorization_page.dart';
import '../features/memorization/memorization_controller.dart';
import '../data/models/memorization.dart';
import '../features/adhkar/adhkar_controller.dart';
import '../features/adhkar/adhkar_page.dart';
import '../features/duas/dua_controller.dart';
import '../features/tasbeeh/tasbeeh_controller.dart';
import '../data/repositories/adhkar_repository.dart';
import '../data/repositories/dua_repository.dart';
import '../data/repositories/religious_content_repository.dart';
import '../data/repositories/tasbeeh_repository.dart';
import '../data/repositories/quran_knowledge_repositories.dart';
import '../features/settings/settings_controller.dart';
import '../features/settings/settings_page.dart';
import '../features/settings/backup_page.dart';
import '../features/settings/notification_routing.dart';
import '../features/settings/worship_notification_scheduler.dart';
import '../features/prayer/prayer_controller.dart';
import '../features/prayer/prayer_page.dart';
import '../features/quran/quran_controller.dart';
import '../features/quran/quran_page.dart';
import '../features/quran/quran_hub_page.dart';
import '../features/reader/reading_progress_controller.dart';
import '../features/reader/quran_reader_page.dart';
import '../core/services/location_service.dart';
import '../features/qibla/qibla_controller.dart';
import '../features/qibla/qibla_page.dart';
import '../features/khatma/khatma_controller.dart';
import '../features/khatma/khatma_page.dart';
import '../features/daily/daily_islamic_controller.dart';
import '../features/daily/daily_islamic_page.dart';
import '../features/duas/duas_page.dart';
import '../features/tasbeeh/tasbeeh_page.dart';
import '../features/study/verse_study_page.dart';
import '../features/worship/worship_hub_page.dart';
import '../features/library/library_page.dart';
import '../features/assistant/ask_page.dart';
import '../features/assistant/assistant_intent_service.dart';
import '../features/search/quran_search_page.dart';
import '../features/mushaf/data/mushaf_preferences.dart';
import 'theme/app_theme.dart';

class QuranApp extends StatefulWidget {
  const QuranApp({super.key, this.audioController});
  final QuranAudioController? audioController;

  @override
  State<QuranApp> createState() => _QuranAppState();
}

class _QuranAppState extends State<QuranApp> {
  final QuranController _quranController = QuranController();

  @override
  void initState() {
    super.initState();
    _quranController.load();
  }

  @override
  void dispose() {
    _quranController.dispose();
    widget.audioController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'رفيق المسلم',
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: AnimatedBuilder(
        animation: _quranController,
        builder: (context, _) {
          if (_quranController.isLoading) {
            return const _LoadingScreen();
          }

          if (_quranController.error != null) {
            return _ErrorScreen(onRetry: _quranController.load);
          }

          return MainShell(
            quranController: _quranController,
            audioController: widget.audioController,
          );
        },
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.quranController,
    this.audioController,
  });

  final QuranController quranController;
  final QuranAudioController? audioController;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  late final PrayerController _prayerController;
  late final ReadingProgressController _readingProgressController;
  late final BookmarkController _bookmarkController;
  late final MemorizationController _memorizationController;
  late final AdhkarController _adhkarController;
  late final DuaController _duaController;
  late final TasbeehController _tasbeehController;
  late final SettingsController _settingsController;
  late final LocationService _locationService;
  late final QiblaController _qiblaController;
  late final KhatmaController _khatmaController;
  late final DailyIslamicController _dailyIslamicController;
  late final MushafPreferences _mushafPreferences;

  int _currentIndex = 0;
  final List<Widget?> _tabPages = List<Widget?>.filled(5, null);
  NotificationDestination? _openNotificationDestination;
  int? _lastPrayerScheduleSignature;

  @override
  void initState() {
    super.initState();

    _locationService = LocationService();
    _prayerController = PrayerController(locationService: _locationService);
    _prayerController.load();
    _readingProgressController = ReadingProgressController();
    _bookmarkController = BookmarkController();
    _memorizationController = MemorizationController();
    _khatmaController = KhatmaController();
    _dailyIslamicController = DailyIslamicController(
      prayerController: _prayerController,
    );
    _mushafPreferences = SharedPreferencesMushafPreferences();
    final religiousContentRepository = ReligiousContentRepository();
    _adhkarController = AdhkarController(
      repository: AdhkarRepository(
        contentRepository: religiousContentRepository,
      ),
    );
    _duaController = DuaController(
      repository: DuaRepository(contentRepository: religiousContentRepository),
    );
    _tasbeehController = TasbeehController(
      repository: TasbeehRepository(
        contentRepository: religiousContentRepository,
      ),
    );
    _settingsController = SettingsController(
      prayerController: _prayerController,
      memorizationController: _memorizationController,
      khatmaController: _khatmaController,
      dailyIslamicController: _dailyIslamicController,
    );
    _qiblaController = QiblaController(
      locationService: _locationService,
      prayerController: _prayerController,
    );
    _initializeLocalServices();
    _prayerController.addListener(_reschedulePrayerNotifications);
    _khatmaController.addListener(_rescheduleKhatmaNotification);
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _initializeLocalServices() async {
    await Future.wait([
      _readingProgressController.load(),
      _bookmarkController.load(),
      _memorizationController.load(),
      _khatmaController.load(),
      _dailyIslamicController.load(),
      _adhkarController.load(),
      _duaController.load(),
      _tasbeehController.load(),
    ]);
    await _settingsController.load();
    if (mounted) {
      _settingsController.routeCoordinator.attach(_handleNotificationRoute);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settingsController.routeCoordinator.detach();
    _prayerController.removeListener(_reschedulePrayerNotifications);
    _khatmaController.removeListener(_rescheduleKhatmaNotification);
    _qiblaController.dispose();
    _dailyIslamicController.dispose();
    _prayerController.dispose();
    _readingProgressController.dispose();
    _bookmarkController.dispose();
    _memorizationController.dispose();
    _khatmaController.dispose();
    _adhkarController.dispose();
    _duaController.dispose();
    _tasbeehController.dispose();
    _settingsController.dispose();
    super.dispose();
  }

  void _openPrayerTimes() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PrayerPage(controller: _prayerController),
    ),
  );

  void _openQuran() {
    setState(() => _currentIndex = 1);
  }

  void _openMemorization() {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/memorization'),
        builder: (_) => MemorizationPage(
          controller: _memorizationController,
          quranController: widget.quranController,
          audioController: widget.audioController,
          onOpenAyah: _openMemorizationAyah,
        ),
      ),
    );
  }

  Future<void> _openMemorizationAyah(QuranCoordinate coordinate) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(name: '/quran/${coordinate.key}'),
        builder: (_) => QuranReaderPage(
          controller: widget.quranController,
          surahNumber: coordinate.surahNumber,
          initialAyah: coordinate.ayahNumber,
          readingProgressController: _readingProgressController,
          bookmarkController: _bookmarkController,
          audioController: widget.audioController,
          memorizationController: _memorizationController,
        ),
      ),
    );
  }

  void _openGlobalSearch() => Navigator.of(context).push(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/search'),
      builder: (_) => QuranSearchPage(
        quranController: widget.quranController,
        readingProgressController: _readingProgressController,
        bookmarkController: _bookmarkController,
        audioController: widget.audioController,
        memorizationController: _memorizationController,
        adhkarController: _adhkarController,
        duaController: _duaController,
        khatmaController: _khatmaController,
        prayerController: _prayerController,
        qiblaController: _qiblaController,
        tasbeehController: _tasbeehController,
        settingsController: _settingsController,
        dailyIslamicController: _dailyIslamicController,
      ),
    ),
  );

  void _openSettings() => Navigator.of(context).push(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/settings'),
      builder: (_) => SettingsPage(
        controller: _settingsController,
        contentManifest: _adhkarController.manifest,
      ),
    ),
  );

  void _openBackup() => Navigator.of(context).push(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/backup'),
      builder: (_) => const BackupPage(),
    ),
  );

  void _openListening() => Navigator.of(context).push(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/listening'),
      builder: (_) => ListeningPage(controller: widget.audioController),
    ),
  );

  void _openQuranMode(QuranReaderMode mode) => Navigator.of(context).push(
    MaterialPageRoute(
      settings: RouteSettings(name: '/quran/${mode.name}'),
      builder: (_) => QuranPage(
        controller: widget.quranController,
        readingProgressController: _readingProgressController,
        bookmarkController: _bookmarkController,
        audioController: widget.audioController,
        memorizationController: _memorizationController,
        mushafPreferences: _mushafPreferences,
        onOpenSearch: _openGlobalSearch,
        initialMode: mode,
      ),
    ),
  );

  void _openContinueReading() {
    final progress = _readingProgressController.progress;
    if (progress == null) {
      _openQuranMode(QuranReaderMode.mushaf);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/quran/continue'),
        builder: (_) => QuranReaderPage(
          controller: widget.quranController,
          surahNumber: progress.surahNumber,
          initialAyah: progress.ayahNumber,
          readingProgressController: _readingProgressController,
          bookmarkController: _bookmarkController,
          audioController: widget.audioController,
          memorizationController: _memorizationController,
        ),
      ),
    );
  }

  void _openStudyResource(int tab, {int? surah, int? ayah}) {
    final progress = _readingProgressController.progress;
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/quran/study'),
        builder: (_) => VerseStudyPage(
          quranController: widget.quranController,
          surahNumber: surah ?? progress?.surahNumber ?? 1,
          ayahNumber: ayah ?? progress?.ayahNumber ?? 1,
          bookmarkController: _bookmarkController,
          audioController: widget.audioController,
          initialTabIndex: tab,
        ),
      ),
    );
  }

  void _openQibla() => Navigator.of(context).push(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/qibla'),
      builder: (_) => QiblaPage(controller: _qiblaController),
    ),
  );

  void _openAdhkar() => Navigator.of(context).push(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/adhkar'),
      builder: (_) => AdhkarPage(controller: _adhkarController),
    ),
  );

  void _openDuas() => Navigator.of(context).push(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/duas'),
      builder: (_) => DuasPage(controller: _duaController),
    ),
  );

  void _openTasbeeh() => Navigator.of(context).push(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/tasbeeh'),
      builder: (_) => TasbeehPage(controller: _tasbeehController),
    ),
  );

  void _openDaily() => Navigator.of(context).push(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/daily'),
      builder: (_) => DailyIslamicPage(controller: _dailyIslamicController),
    ),
  );

  Future<AssistantResponse?> _executeAssistant(AssistantCommand command) async {
    switch (command.type) {
      case AssistantIntentType.openSurah:
        _openReaderCoordinate(command.surahNumber!, 1);
        return null;
      case AssistantIntentType.openVerse:
        _openReaderCoordinate(command.surahNumber!, command.ayahNumber!);
        return null;
      case AssistantIntentType.quranVerse:
        final verse = widget.quranController.getVerse(
          command.surahNumber!,
          command.ayahNumber!,
        );
        if (verse == null) return _assistantUnavailable();
        return AssistantResponse(
          sourceText: verse.text,
          citations: [
            AssistantCitation(
              title: 'القرآن الكريم',
              detail: '${command.surahNumber}:${command.ayahNumber}',
              actionType: AssistantIntentType.openVerse,
              surahNumber: command.surahNumber,
              ayahNumber: command.ayahNumber,
            ),
          ],
        );
      case AssistantIntentType.translation:
        final repository = const BundledTranslationRepository();
        final sources = await repository.installedTranslations();
        if (sources.isEmpty) return _assistantUnavailable();
        final entry = await repository.getAyah(
          sources.first.id,
          command.surahNumber!,
          command.ayahNumber!,
        );
        if (entry == null || entry.text.isEmpty) return _assistantUnavailable();
        return AssistantResponse(
          sourceText: entry.text,
          citations: [
            AssistantCitation(
              title: sources.first.name,
              detail:
                  '${sources.first.provider} — ${command.surahNumber}:${command.ayahNumber}',
              surahNumber: command.surahNumber,
              ayahNumber: command.ayahNumber,
              actionType: AssistantIntentType.translation,
            ),
          ],
        );
      case AssistantIntentType.prayerTime:
        final prayer = _prayerController.prayers
            .where((item) => item.name == command.prayerName)
            .firstOrNull;
        if (prayer == null) {
          return _assistantUnavailable('لم تُجهّز مواقيت الصلاة بعد.');
        }
        return AssistantResponse(
          sourceText: '${prayer.name} اليوم ${_formatClock(prayer.time)}',
          citations: const [
            AssistantCitation(
              title: 'حساب مواقيت الصلاة',
              detail: 'إعدادات الحساب والموقع المحفوظة على الجهاز',
              actionType: AssistantIntentType.prayerTimes,
            ),
          ],
        );
      case AssistantIntentType.prayerTimes:
        _openPrayerTimes();
        return null;
      case AssistantIntentType.qibla:
        _openQibla();
        return null;
      case AssistantIntentType.morningAdhkar:
      case AssistantIntentType.sleepAdhkar:
        _openAdhkar();
        return null;
      case AssistantIntentType.duas:
        _openDuas();
        return null;
      case AssistantIntentType.tasbeeh:
        _openTasbeeh();
        return null;
      case AssistantIntentType.khatma:
        _openKhatma();
        return null;
      case AssistantIntentType.memorization:
        _openMemorization();
        return null;
      case AssistantIntentType.tafsir:
        final repository = const BundledTafsirRepository();
        final sources = await repository.installedSources();
        if (sources.isEmpty) return _assistantUnavailable();
        final entry = await repository.getEntry(
          sources.first.id,
          command.surahNumber!,
          command.ayahNumber!,
        );
        if (entry == null || entry.text.isEmpty) return _assistantUnavailable();
        return AssistantResponse(
          sourceText: entry.text,
          citations: [
            AssistantCitation(
              title: sources.first.title,
              detail:
                  '${sources.first.author} — ${command.surahNumber}:${command.ayahNumber}',
              surahNumber: command.surahNumber,
              ayahNumber: command.ayahNumber,
              actionType: AssistantIntentType.tafsir,
            ),
          ],
        );
      case AssistantIntentType.wordMeaning:
        final repository = const BundledWordMeaningRepository();
        final sources = await repository.installedSources();
        if (sources.isEmpty) return _assistantUnavailable();
        final entry = await repository.getEntry(
          sources.first.id,
          command.surahNumber!,
          command.ayahNumber!,
        );
        if (entry == null || entry.text.isEmpty) return _assistantUnavailable();
        return AssistantResponse(
          sourceText: entry.text,
          citations: [
            AssistantCitation(
              title: sources.first.title,
              detail:
                  '${sources.first.publisher} — ${command.surahNumber}:${command.ayahNumber}',
              surahNumber: command.surahNumber,
              ayahNumber: command.ayahNumber,
              actionType: AssistantIntentType.wordMeaning,
            ),
          ],
        );
      case AssistantIntentType.religiousRuling:
        return const AssistantResponse(
          sourceText:
              'لا يصدر هذا المساعد فتاوى أو أحكاماً شرعية شخصية. يمكنه عرض نصوص موثقة من المصادر المثبتة في التطبيق عند تحديد سورة وآية، أما الحكم على حالتك فراجِع عالماً مؤهلاً.',
          citations: [],
          boundary: true,
        );
      case AssistantIntentType.unsupported:
        return _assistantUnavailable();
    }
  }

  AssistantResponse _assistantUnavailable([String? message]) =>
      AssistantResponse(
        sourceText:
            message ?? 'لا توجد مصادر محلية كافية للإجابة عن هذا الطلب.',
        citations: const [],
        boundary: true,
      );

  Future<void> _openAssistantCitation(AssistantCitation citation) async {
    switch (citation.actionType) {
      case AssistantIntentType.openVerse:
        _openReaderCoordinate(citation.surahNumber!, citation.ayahNumber!);
      case AssistantIntentType.translation:
        _openStudyResource(
          0,
          surah: citation.surahNumber,
          ayah: citation.ayahNumber,
        );
      case AssistantIntentType.tafsir:
        _openStudyResource(
          1,
          surah: citation.surahNumber,
          ayah: citation.ayahNumber,
        );
      case AssistantIntentType.wordMeaning:
        _openStudyResource(
          2,
          surah: citation.surahNumber,
          ayah: citation.ayahNumber,
        );
      case AssistantIntentType.prayerTimes:
        _openPrayerTimes();
      default:
        return;
    }
  }

  void _openReaderCoordinate(int surah, int ayah) => Navigator.of(context).push(
    MaterialPageRoute(
      settings: RouteSettings(name: '/quran/$surah:$ayah'),
      builder: (_) => QuranReaderPage(
        controller: widget.quranController,
        surahNumber: surah,
        initialAyah: ayah,
        readingProgressController: _readingProgressController,
        bookmarkController: _bookmarkController,
        audioController: widget.audioController,
        memorizationController: _memorizationController,
      ),
    ),
  );

  String _formatClock(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return '$hour:${value.minute.toString().padLeft(2, '0')} ${value.hour >= 12 ? 'م' : 'ص'}';
  }

  Future<void> _openKhatma() async {
    final saved = await _mushafPreferences.loadProgress();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/khatma'),
        builder: (_) => KhatmaPage(
          controller: _khatmaController,
          currentReadingPage: saved?.pageNumber ?? 1,
          onStartWird: _openKhatmaMushaf,
        ),
      ),
    );
  }

  void _openKhatmaMushaf(int page) => Navigator.of(context).push(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/khatma/wird'),
      builder: (_) => KhatmaMushafPage(
        initialPage: page,
        khatmaController: _khatmaController,
        quranController: widget.quranController,
        bookmarkController: _bookmarkController,
        audioController: widget.audioController,
        memorizationController: _memorizationController,
      ),
    ),
  );

  void _rescheduleKhatmaNotification() {
    if (!_settingsController.loaded) return;
    _settingsController.reschedule(groups: {NotificationScheduleGroup.khatma});
  }

  void _openListeningPlayer() {
    final audio = widget.audioController;
    if (audio == null || !audio.hasActiveItem) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/listening/player'),
        builder: (_) => ListeningPlayerPage(controller: audio),
      ),
    );
  }

  void _reschedulePrayerNotifications() {
    if (!_settingsController.loaded) return;
    if (_prayerController.isLoading || _prayerController.prayers.isEmpty) {
      return;
    }
    if (!_isToday(_prayerController.prayers.first.time)) {
      _prayerController.refresh();
    } else {
      final signature = Object.hashAll(
        _prayerController.notificationPrayers.expand(
          (prayer) => [prayer.name, prayer.time.millisecondsSinceEpoch],
        ),
      );
      if (_lastPrayerScheduleSignature == signature) return;
      _lastPrayerScheduleSignature = signature;
      _settingsController.reschedule(
        groups: {
          NotificationScheduleGroup.prayer,
          NotificationScheduleGroup.dailyNight,
          NotificationScheduleGroup.dailyDhuha,
        },
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _settingsController.refreshHealth();
      // Refreshing on resume captures timezone, date and material location
      // changes; the schedule signature prevents duplicate notifications.
      _prayerController.refresh();
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  void _handleNotificationRoute(NotificationDestination destination) {
    if (_openNotificationDestination == destination) return;
    _openNotificationDestination = destination;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _openNotificationDestination = null;
        return;
      }
      switch (destination) {
        case NotificationDestination.prayer:
          await Navigator.of(context).push(
            MaterialPageRoute(
              settings: const RouteSettings(name: '/prayer'),
              builder: (_) => PrayerPage(controller: _prayerController),
            ),
          );
        case NotificationDestination.morningAdhkar:
        case NotificationDestination.eveningAdhkar:
          final category = destination == NotificationDestination.morningAdhkar
              ? 'morning'
              : 'evening';
          if (_adhkarController.currentSession?.categoryId != category ||
              _adhkarController.currentSession?.isCompleted == true) {
            await _adhkarController.startSession(category);
          }
          if (mounted) {
            await Navigator.of(context).push(
              MaterialPageRoute(
                settings: RouteSettings(name: '/adhkar/$category'),
                builder: (_) =>
                    AdhkarSessionPage(controller: _adhkarController),
              ),
            );
          }
        case NotificationDestination.quran:
          final progress = _readingProgressController.progress;
          if (progress == null) {
            setState(() => _currentIndex = 1);
          } else {
            await Navigator.of(context).push(
              MaterialPageRoute(
                settings: const RouteSettings(name: '/quran/continue'),
                builder: (_) => QuranReaderPage(
                  controller: widget.quranController,
                  surahNumber: progress.surahNumber,
                  initialAyah: progress.ayahNumber,
                  readingProgressController: _readingProgressController,
                  bookmarkController: _bookmarkController,
                  audioController: widget.audioController,
                  memorizationController: _memorizationController,
                ),
              ),
            );
          }
        case NotificationDestination.memorization:
          _openMemorization();
        case NotificationDestination.review:
          await Navigator.of(context).push(
            MaterialPageRoute(
              settings: const RouteSettings(name: '/memorization/review'),
              builder: (_) => ReviewQueuePage(
                controller: _memorizationController,
                quranController: widget.quranController,
                audioController: widget.audioController,
              ),
            ),
          );
        case NotificationDestination.khatma:
          await _openKhatma();
        case NotificationDestination.dailyIslamic:
          await Navigator.of(context).push(
            MaterialPageRoute(
              settings: const RouteSettings(name: '/daily'),
              builder: (_) =>
                  DailyIslamicPage(controller: _dailyIslamicController),
            ),
          );
      }
      _openNotificationDestination = null;
    });
  }

  void _openBookmarks() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BookmarksPage(
        bookmarkController: _bookmarkController,
        quranController: widget.quranController,
        readingProgressController: _readingProgressController,
        audioController: widget.audioController,
      ),
    ),
  );

  void _selectTab(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  Widget _buildTab(int index) => switch (index) {
    0 => HomePage(
      prayerController: _prayerController,
      quranController: widget.quranController,
      readingProgressController: _readingProgressController,
      bookmarkController: _bookmarkController,
      onOpenPrayerTimes: _openPrayerTimes,
      onOpenQuran: _openQuran,
      onOpenBookmarks: _openBookmarks,
      onOpenMemorization: _openMemorization,
      audioController: widget.audioController,
      memorizationController: _memorizationController,
      adhkarController: _adhkarController,
      tasbeehController: _tasbeehController,
      khatmaController: _khatmaController,
      onOpenKhatma: _openKhatma,
      dailyIslamicController: _dailyIslamicController,
      onOpenSearch: _openGlobalSearch,
      onOpenAsk: () => _selectTab(3),
      onOpenSettings: _openSettings,
      onOpenListening: _openListening,
    ),
    1 => QuranHubPage(
      readingProgressController: _readingProgressController,
      onContinueReading: _openContinueReading,
      onOpenMushaf: () => _openQuranMode(QuranReaderMode.mushaf),
      onOpenStudy: () => _openQuranMode(QuranReaderMode.study),
      onOpenSearch: _openGlobalSearch,
      onOpenListening: _openListening,
      onOpenTranslation: () => _openStudyResource(0),
      onOpenTafsir: () => _openStudyResource(1),
      onOpenWordMeanings: () => _openStudyResource(2),
      onOpenMemorization: _openMemorization,
    ),
    2 => WorshipHubPage(
      prayerController: _prayerController,
      onOpenPrayer: _openPrayerTimes,
      onOpenQibla: _openQibla,
      onOpenAdhkar: _openAdhkar,
      onOpenDuas: _openDuas,
      onOpenTasbeeh: _openTasbeeh,
      onOpenDaily: _openDaily,
    ),
    3 => AskPage(
      onExecute: _executeAssistant,
      onCitationTap: _openAssistantCitation,
    ),
    4 => LibraryPage(
      bookmarkController: _bookmarkController,
      khatmaController: _khatmaController,
      memorizationController: _memorizationController,
      audioController: widget.audioController,
      onOpenBookmarks: _openBookmarks,
      onOpenKhatma: _openKhatma,
      onOpenMemorization: _openMemorization,
      onOpenListening: _openListening,
      onOpenBackup: _openBackup,
      onOpenSettings: _openSettings,
    ),
    _ => const SizedBox.shrink(),
  };

  @override
  Widget build(BuildContext context) {
    _tabPages[_currentIndex] ??= _buildTab(_currentIndex);

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            for (final page in _tabPages) page ?? const SizedBox.shrink(),
          ],
        ),
      ),
      bottomSheet: widget.audioController == null
          ? null
          : AudioMiniPlayer(
              controller: widget.audioController!,
              onOpen: _openListeningPlayer,
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'القرآن',
          ),
          NavigationDestination(
            icon: Icon(Icons.mosque_outlined),
            selectedIcon: Icon(Icons.mosque_rounded),
            label: 'العبادة',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome_rounded),
            label: 'اسأل',
          ),
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark_outlined),
            selectedIcon: Icon(Icons.collections_bookmark_rounded),
            label: 'مكتبتي',
          ),
        ],
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded, size: 64, color: colorScheme.primary),
            const SizedBox(height: 20),
            const Text(
              'جاري تجهيز القرآن الكريم',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 64),
              const SizedBox(height: 16),
              const Text(
                'حدث خطأ أثناء تحميل القرآن',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'تعذر التحقق من ملف القرآن المحلي. أعد المحاولة.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
