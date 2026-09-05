import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/widgets/app_components.dart';
import '../bookmarks/bookmark_controller.dart';
import '../bookmarks/bookmarks_page.dart';
import '../prayer/prayer_controller.dart';
import '../prayer/prayer_page.dart';
import '../quran/quran_controller.dart';
import '../reader/reading_progress_controller.dart';
import '../audio/quran_audio_controller.dart';
import '../adhkar/adhkar_controller.dart';
import '../adhkar/adhkar_page.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_page.dart';
import '../search/quran_search_page.dart';
import '../memorization/memorization_controller.dart';
import '../qibla/qibla_controller.dart';
import '../qibla/qibla_page.dart';
import '../duas/dua_controller.dart';
import '../duas/duas_page.dart';
import '../tasbeeh/tasbeeh_controller.dart';
import '../tasbeeh/tasbeeh_page.dart';
import '../khatma/khatma_controller.dart';
import '../khatma/khatma_page.dart';
import '../mushaf/data/mushaf_preferences.dart';
import '../daily/daily_islamic_controller.dart';
import '../daily/daily_islamic_page.dart';
import '../settings/backup_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    required this.prayerController,
    required this.bookmarkController,
    required this.quranController,
    required this.readingProgressController,
    this.audioController,
    required this.adhkarController,
    required this.duaController,
    required this.tasbeehController,
    required this.settingsController,
    this.memorizationController,
    required this.qiblaController,
    required this.khatmaController,
    required this.dailyIslamicController,
  });
  final PrayerController prayerController;
  final BookmarkController bookmarkController;
  final QuranController quranController;
  final ReadingProgressController readingProgressController;
  final QuranAudioController? audioController;
  final AdhkarController adhkarController;
  final DuaController duaController;
  final TasbeehController tasbeehController;
  final SettingsController settingsController;
  final MemorizationController? memorizationController;
  final QiblaController qiblaController;
  final KhatmaController khatmaController;
  final DailyIslamicController dailyIslamicController;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('المزيد')),
    body: ListView(
      key: const ValueKey('more-page'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        const AppSectionHeader('أدوات القرآن'),
        const SizedBox(height: AppSpacing.xs),
        _Group(
          items: [
            _Item(
              Icons.manage_search_rounded,
              'البحث والاستكشاف',
              () => _push(
                context,
                QuranSearchPage(
                  quranController: quranController,
                  readingProgressController: readingProgressController,
                  bookmarkController: bookmarkController,
                  audioController: audioController,
                  memorizationController: memorizationController,
                  adhkarController: adhkarController,
                  duaController: duaController,
                  khatmaController: khatmaController,
                  prayerController: prayerController,
                  qiblaController: qiblaController,
                  tasbeehController: tasbeehController,
                  settingsController: settingsController,
                  dailyIslamicController: dailyIslamicController,
                ),
              ),
              key: const ValueKey('more-quran-search'),
            ),
            _Item(
              Icons.bookmark_rounded,
              'المحفوظات',
              () => _push(
                context,
                BookmarksPage(
                  bookmarkController: bookmarkController,
                  quranController: quranController,
                  readingProgressController: readingProgressController,
                  audioController: audioController,
                ),
              ),
              key: const ValueKey('more-bookmarks'),
            ),
            _Item(
              Icons.menu_book_outlined,
              'التفسير',
              () => _push(context, const QuranResourcesPage()),
            ),
            _Item(
              Icons.translate_rounded,
              'الترجمات',
              () => _push(context, const QuranResourcesPage()),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const AppSectionHeader('العبادة اليومية'),
        const SizedBox(height: AppSpacing.xs),
        _Group(
          items: [
            _Item(
              Icons.access_time_rounded,
              'مواقيت الصلاة',
              () => _push(context, PrayerPage(controller: prayerController)),
              key: const ValueKey('more-prayer'),
            ),
            _Item(
              Icons.calendar_month_rounded,
              'التقويم الهجري واليوم الإسلامي',
              () => _push(
                context,
                DailyIslamicPage(controller: dailyIslamicController),
              ),
              key: const ValueKey('more-daily-islamic'),
            ),
            _Item(
              Icons.auto_awesome_rounded,
              'الأذكار',
              () => _push(context, AdhkarPage(controller: adhkarController)),
              key: const ValueKey('more-adhkar'),
            ),
            _Item(
              Icons.explore_outlined,
              'القبلة',
              () => _push(context, QiblaPage(controller: qiblaController)),
              key: const ValueKey('more-qibla'),
            ),
            _Item(
              Icons.volunteer_activism_outlined,
              'الأدعية',
              () => _push(context, DuasPage(controller: duaController)),
              key: const ValueKey('more-duas'),
            ),
            _Item(
              Icons.radio_button_checked_rounded,
              'السبحة',
              () => _push(context, TasbeehPage(controller: tasbeehController)),
              key: const ValueKey('more-tasbeeh'),
            ),
            _Item(
              Icons.auto_stories_rounded,
              'خطة الختمة',
              () async {
                final progress = await SharedPreferencesMushafPreferences()
                    .loadProgress();
                if (!context.mounted) return;
                _push(
                  context,
                  KhatmaPage(
                    controller: khatmaController,
                    currentReadingPage: progress?.pageNumber ?? 1,
                    onStartWird: (page) => _push(
                      context,
                      KhatmaMushafPage(
                        initialPage: page,
                        khatmaController: khatmaController,
                        quranController: quranController,
                        bookmarkController: bookmarkController,
                        audioController: audioController,
                        memorizationController: memorizationController,
                      ),
                    ),
                  ),
                );
              },
              key: const ValueKey('more-khatma'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const AppSectionHeader('التطبيق'),
        const SizedBox(height: AppSpacing.xs),
        _Group(
          items: [
            _Item(
              Icons.settings_outlined,
              'الإعدادات',
              () => _push(
                context,
                SettingsPage(
                  controller: settingsController,
                  contentManifest: adhkarController.manifest,
                ),
              ),
              key: const ValueKey('more-settings'),
            ),
            _Item(
              Icons.backup_outlined,
              'النسخ الاحتياطي',
              () => _push(context, const BackupPage()),
              key: const ValueKey('more-backup'),
            ),
            _Item(
              Icons.info_outline_rounded,
              'حول التطبيق',
              () => _push(context, const _AboutPage()),
            ),
          ],
        ),
      ],
    ),
  );

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

class _AboutPage extends StatelessWidget {
  const _AboutPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('حول التطبيق')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: const [
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'رفيق المسلم',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 8),
              Text('الإصدار 1.0.0'),
              SizedBox(height: 12),
              Text(
                'مصحف وقراءة واستماع وحفظ وعبادة يومية تعمل محليًا قدر الإمكان.',
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.md),
        PremiumCard(
          child: Text(
            'لا حساب، ولا إعلانات، ولا تحليلات، ولا مزامنة سحابية. تُعرض معلومات مصادر النصوص وإصداراتها داخل الإعدادات.',
          ),
        ),
      ],
    ),
  );
}

class _Item {
  const _Item(this.icon, this.label, this.onTap, {this.key});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Key? key;
}

class _Group extends StatelessWidget {
  const _Group({required this.items});
  final List<_Item> items;
  @override
  Widget build(BuildContext context) => PremiumCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          ListTile(
            key: items[index].key,
            leading: Icon(items[index].icon),
            title: Text(items[index].label),
            trailing: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
            onTap: items[index].onTap,
          ),
          if (index < items.length - 1) const Divider(height: 1),
        ],
      ],
    ),
  );
}
