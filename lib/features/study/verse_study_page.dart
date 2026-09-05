import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/widgets/app_components.dart';
import '../../data/models/quran_knowledge.dart';
import '../../data/models/quran_verse.dart';
import '../../data/models/surah.dart';
import '../../data/repositories/quran_knowledge_repositories.dart';
import '../audio/quran_audio_controller.dart';
import '../bookmarks/bookmark_controller.dart';
import '../quran/quran_controller.dart';

class VerseStudyPage extends StatefulWidget {
  const VerseStudyPage({
    super.key,
    required this.quranController,
    required this.surahNumber,
    required this.ayahNumber,
    required this.bookmarkController,
    this.audioController,
    this.translationRepository = const BundledTranslationRepository(),
    this.tafsirRepository = const BundledTafsirRepository(),
    this.wordMeaningRepository = const BundledWordMeaningRepository(),
    this.initialTabIndex = 0,
  });

  final QuranController quranController;
  final int surahNumber;
  final int ayahNumber;
  final BookmarkController bookmarkController;
  final QuranAudioController? audioController;
  final TranslationRepository translationRepository;
  final TafsirRepository tafsirRepository;
  final WordMeaningRepository wordMeaningRepository;
  final int initialTabIndex;

  @override
  State<VerseStudyPage> createState() => _VerseStudyPageState();
}

class _VerseStudyPageState extends State<VerseStudyPage> {
  late int _surahNumber = widget.surahNumber;
  late int _ayahNumber = widget.ayahNumber;
  List<QuranTranslation> _translations = const [];
  List<TafsirSource> _tafsirs = const [];
  List<WordMeaningSource> _wordSources = const [];
  QuranTranslation? _translation;
  TafsirSource? _tafsir;
  WordMeaningSource? _wordSource;
  TranslatedAyah? _translatedAyah;
  TafsirEntry? _tafsirEntry;
  WordMeaningEntry? _wordMeaningEntry;
  bool _loadingResources = true;

  QuranVerse? get _verse =>
      widget.quranController.getVerse(_surahNumber, _ayahNumber);
  Surah get _surah => QuranMetadata.surah(_surahNumber);

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  Future<void> _loadSources() async {
    final timer = Stopwatch()..start();
    final values = await Future.wait([
      widget.translationRepository.installedTranslations(),
      widget.tafsirRepository.installedSources(),
      widget.wordMeaningRepository.installedSources(),
    ]);
    _translations = values[0] as List<QuranTranslation>;
    _tafsirs = values[1] as List<TafsirSource>;
    _wordSources = values[2] as List<WordMeaningSource>;
    _translation = _translations.firstOrNull;
    _tafsir = _tafsirs.firstOrNull;
    _wordSource = _wordSources.firstOrNull;
    await _loadEntries();
    if (kDebugMode) {
      debugPrint('Verse study ready in ${timer.elapsedMilliseconds} ms');
    }
  }

  Future<void> _loadEntries() async {
    setState(() => _loadingResources = true);
    _translatedAyah = _translation == null
        ? null
        : await widget.translationRepository.getAyah(
            _translation!.id,
            _surahNumber,
            _ayahNumber,
          );
    _tafsirEntry = _tafsir == null
        ? null
        : await widget.tafsirRepository.getEntry(
            _tafsir!.id,
            _surahNumber,
            _ayahNumber,
          );
    _wordMeaningEntry = _wordSource == null
        ? null
        : await widget.wordMeaningRepository.getEntry(
            _wordSource!.id,
            _surahNumber,
            _ayahNumber,
          );
    if (mounted) setState(() => _loadingResources = false);
  }

  @override
  Widget build(BuildContext context) {
    final verse = _verse;
    if (verse == null) {
      return const Scaffold(
        body: AppEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'إحداثي آية غير صالح',
          message: 'تعذر فتح صفحة الدراسة لهذه الآية.',
        ),
      );
    }
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
      child: Scaffold(
        appBar: AppBar(
          title: Text('سورة ${_surah.name} • $_ayahNumber'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'الترجمة'),
              Tab(text: 'التفسير'),
              Tab(text: 'الكلمات'),
            ],
          ),
        ),
        body: Column(
          children: [
            Flexible(
              flex: 2,
              child: SingleChildScrollView(
                key: const ValueKey('study-canonical-scroll'),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: PremiumCard(
                  child: Column(
                    children: [
                      Text(
                        verse.text,
                        key: const ValueKey('study-canonical-ayah'),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'AmiriQuran',
                          fontSize: 28,
                          height: 1.9,
                        ),
                      ),
                      Text('سورة ${_surah.name} — الآية $_ayahNumber'),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: TabBarView(
                children: [_translationTab(), _tafsirTab(), _wordMeaningsTab()],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'الآية السابقة',
                  onPressed: _previousCoordinate() == null
                      ? null
                      : () => _move(_previousCoordinate()!),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
                IconButton(
                  tooltip: 'حفظ الآية',
                  onPressed: () async {
                    await widget.bookmarkController.toggleBookmark(
                      _surahNumber,
                      _ayahNumber,
                    );
                    if (mounted) setState(() {});
                  },
                  icon: Icon(
                    widget.bookmarkController.isBookmarked(
                          _surahNumber,
                          _ayahNumber,
                        )
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                  ),
                ),
                if (widget.audioController != null)
                  IconButton(
                    tooltip: 'تشغيل الآية',
                    onPressed: () => widget.audioController!.playAyah(
                      _surahNumber,
                      _ayahNumber,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                  ),
                TextButton.icon(
                  onPressed: () =>
                      Navigator.pop(context, (_surahNumber, _ayahNumber)),
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('العودة للمصحف'),
                ),
                IconButton(
                  tooltip: 'الآية التالية',
                  onPressed: _nextCoordinate() == null
                      ? null
                      : () => _move(_nextCoordinate()!),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _translationTab() {
    if (_loadingResources) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_translations.isEmpty) {
      return const AppEmptyState(
        key: ValueKey('translation-not-installed'),
        icon: Icons.translate_rounded,
        title: 'لا توجد ترجمة موثّقة مثبتة',
        message:
            'لم تُضمّن ترجمة لأن شروط إعادة التوزيع للمصادر المرشحة لم تكن مناسبة بوضوح لهذا الإصدار.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<QuranTranslation>(
          initialValue: _translation,
          decoration: const InputDecoration(labelText: 'الترجمة'),
          items: _translations
              .map(
                (translation) => DropdownMenuItem(
                  value: translation,
                  child: Text(translation.name),
                ),
              )
              .toList(),
          onChanged: (value) {
            _translation = value;
            _loadEntries();
          },
        ),
        const SizedBox(height: 12),
        SelectableText(
          _translatedAyah?.text ?? 'ترجمة هذه الآية غير متاحة.',
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontSize: 17, height: 1.55),
        ),
        if (_translatedAyah?.footnotes case final notes?) ...[
          const SizedBox(height: 12),
          Text(notes, textDirection: TextDirection.ltr),
        ],
        const SizedBox(height: 16),
        _sourceCard(
          title: _translation!.name,
          publisher: _translation!.author,
          version: _translation!.version,
          source: _translation!.provider,
        ),
      ],
    );
  }

  Widget _tafsirTab() {
    if (_loadingResources) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_tafsirs.isEmpty) {
      return const AppEmptyState(
        key: ValueKey('tafsir-not-installed'),
        icon: Icons.menu_book_outlined,
        title: 'لا يوجد تفسير موثّق مثبت',
        message:
            'بنية التفسير جاهزة، ولم يُضمّن نص لم تثبت شروط إعادة توزيعه بوضوح.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('التفسير الميسر', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SelectableText(
          _tafsirEntry?.text ?? 'تفسير هذه الآية غير متاح.',
          style: const TextStyle(fontSize: 17, height: 1.75),
        ),
        if (_tafsirEntry?.footnotes case final notes?) ...[
          const SizedBox(height: 12),
          Text(notes),
        ],
        const SizedBox(height: 16),
        _sourceCard(
          title: 'التفسير الميسر',
          publisher: _tafsir!.author,
          version: _tafsir!.version,
          source: 'QuranEnc.com',
        ),
      ],
    );
  }

  Widget _wordMeaningsTab() {
    if (_loadingResources) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_wordSources.isEmpty) {
      return const AppEmptyState(
        key: ValueKey('word-meanings-not-installed'),
        icon: Icons.text_fields_rounded,
        title: 'معاني الكلمات غير متاحة',
        message: 'تعذر فتح المورد المحلي الموثّق.',
      );
    }
    final text = _wordMeaningEntry?.text ?? '';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('معاني الكلمات', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (text.isEmpty)
          const Text('لا يورد المصدر معنىً مستقلًا لكلمات هذه الآية.')
        else
          SelectableText(
            text,
            style: const TextStyle(fontSize: 17, height: 1.8),
          ),
        const SizedBox(height: 16),
        _sourceCard(
          title: 'معاني الكلمات',
          publisher: _wordSource!.publisher,
          version: _wordSource!.version,
          source: 'QuranEnc.com',
        ),
      ],
    );
  }

  Widget _sourceCard({
    required String title,
    required String publisher,
    required String version,
    required String source,
  }) => PremiumCard(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(publisher),
        const SizedBox(height: 4),
        Text('$source • الإصدار $version'),
        const SizedBox(height: 4),
        const Text('النص منقول حرفيًا وفق شروط المصدر.'),
      ],
    ),
  );

  (int, int)? _previousCoordinate() {
    if (_ayahNumber > 1) return (_surahNumber, _ayahNumber - 1);
    if (_surahNumber == 1) return null;
    final surah = QuranMetadata.surah(_surahNumber - 1);
    return (surah.number, surah.ayahCount);
  }

  (int, int)? _nextCoordinate() {
    if (_ayahNumber < _surah.ayahCount) return (_surahNumber, _ayahNumber + 1);
    if (_surahNumber == QuranMetadata.surahCount) return null;
    return (_surahNumber + 1, 1);
  }

  void _move((int, int) coordinate) {
    setState(() {
      _surahNumber = coordinate.$1;
      _ayahNumber = coordinate.$2;
    });
    _loadEntries();
  }
}
