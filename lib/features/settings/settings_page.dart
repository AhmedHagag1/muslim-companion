import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/widgets/app_components.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/prayer_models.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/quran_knowledge.dart';
import '../../data/models/religious_content.dart';
import '../../data/repositories/quran_knowledge_repositories.dart';
import 'settings_controller.dart';
import 'worship_notification_scheduler.dart';
import '../mushaf/data/mushaf_preferences.dart';
import '../prayer/prayer_page.dart';
import '../daily/daily_islamic_settings_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    this.contentManifest,
  });

  final SettingsController controller;
  final ReligiousContentManifest? contentManifest;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الإعدادات')),
    body: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.loaded) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _section('المظهر', [
              const ListTile(
                title: Text('الهوية الداكنة'),
                subtitle: Text(
                  'الزمرد الداكن والذهبي هما مظهر التطبيق المعتمد',
                ),
              ),
            ]),
            _section('القرآن', [
              ListTile(
                key: const ValueKey('mushaf-display-settings'),
                title: const Text('عرض المصحف'),
                subtitle: const Text('حجم العرض ووضع القراءة المريحة'),
                trailing: const Icon(Icons.arrow_back_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MushafDisplaySettingsPage(),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                key: const ValueKey('quran-resources-settings'),
                title: const Text('موارد القرآن'),
                subtitle: const Text('النص العربي والترجمات والتفسير'),
                trailing: const Icon(Icons.arrow_back_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuranResourcesPage()),
                ),
              ),
            ]),
            _section('الصوت', [
              const ListTile(
                title: Text('إعدادات التلاوة'),
                subtitle: Text('تدار من مشغل القرآن'),
              ),
            ]),
            _section('الصلاة والأذان', [
              ListTile(
                key: const ValueKey('prayer-calculation-settings'),
                title: const Text('طريقة الحساب والتعديلات'),
                subtitle: Text(
                  '${controller.prayerController.settings.method.arabicName} • ${controller.prayerController.settings.madhab.arabicName}',
                ),
                trailing: const Icon(Icons.arrow_back_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrayerSettingsPage(
                      controller: controller.prayerController,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('تحديث مواقيت الصلاة'),
                subtitle: const Text('تحديث مواقيت اليوم وغدٍ حسب موقعك'),
                onTap: controller.prayerController.refresh,
              ),
            ]),
            _section('التقويم الهجري واليوم الإسلامي', [
              ListTile(
                key: const ValueKey('daily-islamic-settings'),
                title: const Text('إعدادات اليوم الإسلامي'),
                subtitle: Text(
                  'تعديل هجري ${controller.dailyIslamicController.settings.hijriAdjustment >= 0 ? '+' : ''}${controller.dailyIslamicController.settings.hijriAdjustment} • تذكيرات اختيارية',
                ),
                trailing: const Icon(Icons.arrow_back_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        DailyIslamicSettingsPage(controller: controller),
                  ),
                ),
              ),
            ]),
            _section('الإشعارات والتذكيرات', [
              ListTile(
                key: const ValueKey('notification-settings'),
                title: const Text('إدارة تذكيرات العبادة'),
                subtitle: Text(
                  controller.settings.anyNotificationEnabled
                      ? 'بعض التذكيرات مفعّلة'
                      : 'جميع التذكيرات متوقفة',
                ),
                trailing: const Icon(Icons.arrow_back_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        NotificationSettingsPage(controller: controller),
                  ),
                ),
              ),
            ]),
            _section('الأذكار والحفظ', [
              ListTile(
                title: Text('بيانات محلية'),
                subtitle: Text(
                  contentManifest == null
                      ? 'الجلسات والخطط محفوظة على الجهاز'
                      : 'حزمة العبادة ${contentManifest!.version} • ${contentManifest!.itemCount} مادة موثقة',
                ),
              ),
              if (contentManifest != null) ...[
                const Divider(height: 1),
                ListTile(
                  key: const ValueKey('religious-content-info'),
                  title: const Text('مصدر محتوى العبادة'),
                  subtitle: Text(contentManifest!.sourceName),
                  trailing: const Icon(Icons.arrow_back_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ReligiousContentInfoPage(manifest: contentManifest!),
                    ),
                  ),
                ),
              ],
            ]),
            _section('الخصوصية والبيانات', [
              const ListTile(
                title: Text('الخصوصية'),
                subtitle: Text(
                  'لا حساب، ولا إعلانات، ولا تحليلات، ولا مزامنة سحابية',
                ),
              ),
            ]),
            _section('حول التطبيق', [
              ListTile(
                key: const ValueKey('about-page-link'),
                title: const Text('رفيق المسلم'),
                subtitle: const Text('Muslim Companion • الإصدار 1.0.0+1'),
                trailing: const Icon(Icons.arrow_back_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutPage()),
                ),
              ),
            ]),
          ],
        );
      },
    ),
  );

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title),
        const SizedBox(height: 8),
        PremiumCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    ),
  );
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('حول التطبيق')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: const [
        PremiumCard(
          child: Column(
            children: [
              Image(
                image: AssetImage('assets/branding/muslim_companion_logo.png'),
                height: 180,
                fit: BoxFit.contain,
                semanticLabel: 'شعار رفيق المسلم',
              ),
              SizedBox(height: AppSpacing.md),
              Text(
                'رفيق المسلم',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              Text('Muslim Companion', textDirection: TextDirection.ltr),
              SizedBox(height: AppSpacing.sm),
              Text('الإصدار 1.0.0+1'),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.md),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('المطور', style: TextStyle(fontWeight: FontWeight.w700)),
              Text('Ahmed Haggag', textDirection: TextDirection.ltr),
              SizedBox(height: AppSpacing.sm),
              Text('الدعم', style: TextStyle(fontWeight: FontWeight.w700)),
              SelectableText(
                'ahmedhaggagdev@gmail.com',
                textDirection: TextDirection.ltr,
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.md),
        PremiumCard(
          child: Text(
            'إلى روح والدي، رحمه الله — نسأل الله أن يجعل هذا العمل صدقةً جارية له.',
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: AppSpacing.md),
        PremiumCard(
          child: Text(
            'لا حساب، ولا إعلانات، ولا تحليلات، ولا مزامنة سحابية. يعمل المساعد محليًا دون مزود ذكاء اصطناعي. تفاصيل الخصوصية والأمان ومصادر المحتوى وتراخيصها متاحة في مستندات المشروع وصفحات الموارد داخل الإعدادات.',
          ),
        ),
      ],
    ),
  );
}

class MushafDisplaySettingsPage extends StatefulWidget {
  const MushafDisplaySettingsPage({super.key});
  @override
  State<MushafDisplaySettingsPage> createState() =>
      _MushafDisplaySettingsPageState();
}

class _MushafDisplaySettingsPageState extends State<MushafDisplaySettingsPage> {
  final MushafPreferences preferences = SharedPreferencesMushafPreferences();
  MushafDisplaySettings? settings;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await preferences.loadDisplaySettings();
    if (mounted) setState(() => settings = value);
  }

  Future<void> _save(MushafDisplaySettings value) async {
    setState(() => settings = value);
    await preferences.saveDisplaySettings(value);
  }

  @override
  Widget build(BuildContext context) {
    final value = settings;
    return Scaffold(
      appBar: AppBar(title: const Text('عرض المصحف')),
      body: value == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                PremiumCard(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('حجم عرض المصحف'),
                        subtitle: Text('${value.scale.toStringAsFixed(2)}×'),
                      ),
                      Slider(
                        key: const ValueKey('mushaf-settings-scale'),
                        value: value.scale,
                        min: MushafDisplaySettings.minScale,
                        max: MushafDisplaySettings.maxScale,
                        divisions: 7,
                        onChanged: (scale) =>
                            _save(value.copyWith(scale: scale)),
                      ),
                      SwitchListTile(
                        key: const ValueKey('mushaf-settings-comfort'),
                        value: value.comfortMode,
                        onChanged: (enabled) =>
                            _save(value.copyWith(comfortMode: enabled)),
                        title: const Text('وضع القراءة المريحة'),
                        subtitle: const Text(
                          'نص أكبر وهوامش أقل مع تمرير رأسي داخل الصفحة',
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        key: const ValueKey('mushaf-settings-reset'),
                        title: const Text('استعادة الحجم الافتراضي'),
                        trailing: const Icon(Icons.restart_alt_rounded),
                        onTap: () => _save(const MushafDisplaySettings()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class QuranResourcesPage extends StatelessWidget {
  const QuranResourcesPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('موارد القرآن')),
    body: FutureBuilder<List<QuranResourceManifest>>(
      future: const QuranResourceRepository().installedResources(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final resources = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            PremiumCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var index = 0; index < resources.length; index++) ...[
                    _resourceTile(context, resources[index]),
                    if (index < resources.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'الموارد مدمجة وتعمل دون اتصال. التحديث البعيد معطّل حتى تتوفر حزمة موقعة، والتحقق من هوية الناشر، ومنع الرجوع إلى إصدار أقدم.',
            ),
          ],
        );
      },
    ),
  );

  Widget _resourceTile(BuildContext context, QuranResourceManifest resource) {
    final title = switch (resource.type) {
      QuranResourceType.arabicQuran => 'القرآن العربي',
      QuranResourceType.translation => 'الترجمة الإنجليزية',
      QuranResourceType.tafsir => 'التفسير الميسر',
      QuranResourceType.wordMeanings => 'معاني الكلمات',
      QuranResourceType.recitation => 'التلاوة',
    };
    final icon = switch (resource.type) {
      QuranResourceType.arabicQuran => Icons.menu_book_rounded,
      QuranResourceType.translation => Icons.translate_rounded,
      QuranResourceType.tafsir => Icons.library_books_outlined,
      QuranResourceType.wordMeanings => Icons.text_fields_rounded,
      QuranResourceType.recitation => Icons.headphones_rounded,
    };
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text('مدمج • الإصدار ${resource.version}'),
      trailing: const Icon(Icons.check_circle_rounded),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              QuranResourceInfoPage(manifest: resource, displayTitle: title),
        ),
      ),
    );
  }
}

class QuranResourceInfoPage extends StatelessWidget {
  const QuranResourceInfoPage({
    super.key,
    required this.manifest,
    required this.displayTitle,
  });

  final QuranResourceManifest manifest;
  final String displayTitle;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(displayTitle)),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        PremiumCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _row(
                'الناشر',
                manifest.publisher.isEmpty
                    ? manifest.source
                    : manifest.publisher,
              ),
              const Divider(height: 1),
              _row(
                'المصدر',
                manifest.provider.isEmpty ? manifest.source : manifest.provider,
              ),
              const Divider(height: 1),
              _row('الإصدار', manifest.version),
              if (manifest.lastUpdate.isNotEmpty) ...[
                const Divider(height: 1),
                _row('آخر تحديث للمصدر', manifest.lastUpdate),
              ],
              if (manifest.recordCount > 0) ...[
                const Divider(height: 1),
                _row('السجلات', '${manifest.recordCount}'),
              ],
              const Divider(height: 1),
              _row('سلامة الملف', 'SHA-256\n${manifest.checksum}'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(manifest.license),
      ],
    ),
  );

  Widget _row(String title, String value) =>
      ListTile(title: Text(title), subtitle: Text(value));
}

class ReligiousContentInfoPage extends StatelessWidget {
  const ReligiousContentInfoPage({super.key, required this.manifest});

  final ReligiousContentManifest manifest;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مصدر محتوى العبادة')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        PremiumCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                title: const Text('المصدر'),
                subtitle: Text(manifest.sourceName),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('الطبعة'),
                subtitle: Text(manifest.sourceEdition),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('إصدار الحزمة'),
                subtitle: Text(manifest.version),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('عدد المواد'),
                subtitle: Text('${manifest.itemCount}'),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('إذن النشر'),
                subtitle: Text(manifest.license),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('سلامة الحزمة'),
                subtitle: Text('SHA-256\n${manifest.checksum}'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'المحتوى العربي منقول حرفيًا مع العزو. لا توجد نصوص دينية مولّدة أو شروح غير موثقة في هذه الحزمة.',
        ),
      ],
    ),
  );
}

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key, required this.controller});

  final SettingsController controller;

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  SettingsController get controller => widget.controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الإشعارات والتذكيرات')),
    body: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final settings = controller.settings;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _healthCard(context),
            if (controller.message != null) ...[
              const SizedBox(height: 12),
              PremiumCard(child: Text(controller.message!)),
            ],
            const SizedBox(height: 20),
            const AppSectionHeader('الصلاة والأذان'),
            const SizedBox(height: 8),
            PremiumCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('تذكيرات الصلاة'),
                    subtitle: Text(
                      '${settings.prayers.values.where((value) => value.enabled).length} صلوات محددة',
                    ),
                    value: settings.prayerNotifications,
                    onChanged: (value) => _update(
                      settings.copyWith(prayerNotifications: value),
                      NotificationScheduleGroup.prayer,
                      enable: value,
                    ),
                  ),
                  if (settings.prayerNotifications)
                    ...settings.prayers.entries.map(
                      (entry) => _prayerTile(settings, entry),
                    ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('التوقيت الدقيق للصلاة'),
                    subtitle: Text(
                      settings.exactPrayerAlarms && controller.exactAvailable
                          ? 'مفعّل — يستخدم سماح المنبهات الدقيقة'
                          : settings.exactPrayerAlarms
                          ? 'غير متاح حاليًا — يعمل بالتوقيت التقريبي'
                          : 'تقريبي — لا يحتاج صلاحية خاصة',
                    ),
                    value: settings.exactPrayerAlarms,
                    onChanged: (value) async {
                      if (value) {
                        await _explainAndRequestExact();
                      } else {
                        await controller.useInexactPrayerTiming();
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const AppSectionHeader('الأذكار والحفظ'),
            const SizedBox(height: 8),
            PremiumCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('الصلاة على النبي ﷺ'),
                    subtitle: Text(_salawatSummary(settings)),
                    value: settings.salawat,
                    onChanged: (value) => _update(
                      settings.copyWith(salawat: value),
                      NotificationScheduleGroup.salawat,
                      enable: value,
                    ),
                  ),
                  if (settings.salawat) _salawatEditor(settings),
                  _timeSwitch(
                    title: 'أذكار الصباح',
                    value: settings.morningAdhkar,
                    time: settings.morningTime,
                    group: NotificationScheduleGroup.morning,
                    onToggle: (value) =>
                        settings.copyWith(morningAdhkar: value),
                    onTime: (time) => settings.copyWith(morningTime: time),
                  ),
                  _timeSwitch(
                    title: 'أذكار المساء',
                    value: settings.eveningAdhkar,
                    time: settings.eveningTime,
                    group: NotificationScheduleGroup.evening,
                    onToggle: (value) =>
                        settings.copyWith(eveningAdhkar: value),
                    onTime: (time) => settings.copyWith(eveningTime: time),
                  ),
                  _timeSwitch(
                    title: 'ورد القرآن',
                    value: settings.wird,
                    time: settings.wirdTime,
                    group: NotificationScheduleGroup.wird,
                    onToggle: (value) => settings.copyWith(wird: value),
                    onTime: (time) => settings.copyWith(wirdTime: time),
                  ),
                  _timeSwitch(
                    title: 'الحفظ اليومي',
                    value: settings.memorization,
                    time: settings.memorizationTime,
                    group: NotificationScheduleGroup.memorization,
                    enabled:
                        controller.memorizationController.activePlan != null,
                    disabledText: 'يتطلب خطة حفظ نشطة',
                    onToggle: (value) => settings.copyWith(memorization: value),
                    onTime: (time) => settings.copyWith(memorizationTime: time),
                  ),
                  _timeSwitch(
                    title: 'مراجعات الحفظ',
                    value: settings.review,
                    time: settings.reviewTime,
                    group: NotificationScheduleGroup.review,
                    enabled:
                        controller.memorizationController.activePlan != null,
                    disabledText: 'يتطلب خطة حفظ نشطة',
                    onToggle: (value) => settings.copyWith(review: value),
                    onTime: (time) => settings.copyWith(reviewTime: time),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const AppSectionHeader('اختبار الإشعارات'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      controller.sendTest(NotificationTestKind.normal),
                  icon: const Icon(Icons.notifications_outlined),
                  label: const Text('اختبار إشعار عادي'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      controller.sendTest(NotificationTestKind.prayer),
                  icon: const Icon(Icons.access_time_rounded),
                  label: const Text('اختبار تنبيه الصلاة'),
                ),
                OutlinedButton.icon(
                  onPressed: controller.scheduleNearFutureTest,
                  icon: const Icon(Icons.schedule_send_rounded),
                  label: const Text('اختبار مجدول بعد دقيقة'),
                ),
                if (LocalNotificationService.hasBundledAdhan)
                  FilledButton.icon(
                    onPressed: () =>
                        controller.sendTest(NotificationTestKind.adhan),
                    icon: const Icon(Icons.volume_up_outlined),
                    label: const Text('اختبار صوت الأذان'),
                  ),
              ],
            ),
          ],
        );
      },
    ),
  );

  Widget _healthCard(BuildContext context) {
    final health = controller.health;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'حالة الإشعارات',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          _status('الإشعارات', health.allowed ? 'مسموح بها' : 'محظورة'),
          _status(
            'التوقيت الدقيق',
            health.exactAvailable ? 'متاح' : 'غير متاح',
          ),
          _status('تذكيرات الصلاة', '${health.enabledPrayerCount} مفعّلة'),
          _status(
            'صوت الأذان',
            health.adhanInstalled ? 'مثبّت' : 'غير مثبّت بعد',
          ),
          _status(
            'التذكير القادم',
            health.nextReminder == null
                ? 'لا يوجد تذكير معلوم'
                : _dateTime(health.nextReminder!),
          ),
          if (!health.allowed ||
              (controller.settings.exactPrayerAlarms &&
                  !health.exactAvailable)) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: health.allowed
                  ? _explainAndRequestExact
                  : controller.openNotificationSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('إصلاح الإعدادات'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _status(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value),
      ],
    ),
  );

  Widget _prayerTile(
    AppSettings settings,
    MapEntry<String, PrayerReminderSettings> entry,
  ) {
    final value = entry.value;
    return ExpansionTile(
      title: Text(entry.key),
      subtitle: Text(
        value.adhan
            ? 'صوت الأذان عند دخول الوقت'
            : value.beforeMinutes == 0
            ? 'عند وقت الصلاة'
            : 'قبلها ${value.beforeMinutes} دقائق',
      ),
      trailing: Switch(
        value: value.enabled,
        onChanged: (enabled) => _updatePrayer(
          settings,
          entry.key,
          value.copyWith(enabled: enabled),
        ),
      ),
      children: [
        SwitchListTile(
          title: const Text('استخدام صوت الأذان المثبّت'),
          value: value.adhan,
          onChanged: value.enabled
              ? (adhan) => _updatePrayer(
                  settings,
                  entry.key,
                  value.copyWith(adhan: adhan),
                )
              : null,
        ),
        ListTile(
          title: const Text('تنبيه مسبق'),
          trailing: DropdownButton<int>(
            value: value.beforeMinutes,
            items: const [
              DropdownMenuItem(value: 0, child: Text('بدون')),
              DropdownMenuItem(value: 5, child: Text('5 دقائق')),
              DropdownMenuItem(value: 10, child: Text('10 دقائق')),
              DropdownMenuItem(value: 15, child: Text('15 دقيقة')),
              DropdownMenuItem(value: 30, child: Text('30 دقيقة')),
            ],
            onChanged: value.enabled
                ? (minutes) {
                    if (minutes != null) {
                      _updatePrayer(
                        settings,
                        entry.key,
                        value.copyWith(beforeMinutes: minutes),
                      );
                    }
                  }
                : null,
          ),
        ),
      ],
    );
  }

  Widget _salawatEditor(AppSettings settings) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Column(
      children: [
        DropdownButtonFormField<SalawatFrequency>(
          initialValue: settings.salawatFrequency,
          decoration: const InputDecoration(labelText: 'عدد التذكيرات'),
          items: const [
            DropdownMenuItem(
              value: SalawatFrequency.once,
              child: Text('مرة واحدة'),
            ),
            DropdownMenuItem(
              value: SalawatFrequency.three,
              child: Text('3 مرات'),
            ),
            DropdownMenuItem(
              value: SalawatFrequency.five,
              child: Text('5 مرات'),
            ),
            DropdownMenuItem(
              value: SalawatFrequency.custom,
              child: Text('أوقات مخصصة'),
            ),
          ],
          onChanged: (frequency) {
            if (frequency != null) {
              _update(
                settings.copyWith(salawatFrequency: frequency),
                NotificationScheduleGroup.salawat,
              );
            }
          },
        ),
        if (settings.salawatFrequency == SalawatFrequency.custom) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ...settings.salawatTimes.map(
                (time) => InputChip(
                  label: Text(_time(time)),
                  onDeleted: settings.salawatTimes.length <= 1
                      ? null
                      : () => _update(
                          settings.copyWith(
                            salawatTimes: settings.salawatTimes
                                .where((value) => value != time)
                                .toList(),
                          ),
                          NotificationScheduleGroup.salawat,
                        ),
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.add_rounded),
                label: const Text('إضافة وقت'),
                onPressed: () async {
                  final time = await _pickTime(const ReminderTime(12, 0));
                  if (time == null) return;
                  if (settings.salawatTimes.contains(time)) {
                    _showMessage('هذا الوقت مضاف بالفعل.');
                    return;
                  }
                  if (settings.salawatTimes.length >= 5) {
                    _showMessage('الحد الأقصى خمسة أوقات.');
                    return;
                  }
                  await _update(
                    settings.copyWith(
                      salawatTimes: [...settings.salawatTimes, time],
                    ),
                    NotificationScheduleGroup.salawat,
                  );
                },
              ),
            ],
          ),
        ],
      ],
    ),
  );

  Widget _timeSwitch({
    required String title,
    required bool value,
    required ReminderTime time,
    required NotificationScheduleGroup group,
    required AppSettings Function(bool value) onToggle,
    required AppSettings Function(ReminderTime time) onTime,
    bool enabled = true,
    String? disabledText,
  }) => ListTile(
    title: Text(title),
    subtitle: Text(enabled ? 'يوميًا الساعة ${_time(time)}' : disabledText!),
    leading: Switch(
      value: value && enabled,
      onChanged: enabled
          ? (next) => _update(onToggle(next), group, enable: next)
          : null,
    ),
    trailing: value && enabled
        ? TextButton(
            onPressed: () async {
              final picked = await _pickTime(time);
              if (picked != null) await _update(onTime(picked), group);
            },
            child: const Text('تغيير'),
          )
        : null,
  );

  Future<ReminderTime?> _pickTime(ReminderTime initial) async {
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      helpText: 'اختر وقت التذكير',
      cancelText: 'إلغاء',
      confirmText: 'حفظ',
      hourLabelText: 'الساعة',
      minuteLabelText: 'الدقيقة',
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    return result == null ? null : ReminderTime(result.hour, result.minute);
  }

  Future<void> _update(
    AppSettings next,
    NotificationScheduleGroup group, {
    bool enable = false,
  }) => controller.update(next, explicitEnable: enable, groups: {group});

  Future<void> _updatePrayer(
    AppSettings settings,
    String name,
    PrayerReminderSettings prayer,
  ) => _update(
    settings.copyWith(prayers: {...settings.prayers, name: prayer}),
    NotificationScheduleGroup.prayer,
  );

  Future<void> _explainAndRequestExact() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('التوقيت الدقيق للصلاة'),
        content: const Text(
          'يحتاج أندرويد إلى سماح خاص لتسليم تنبيه الصلاة في الدقيقة المحددة. لن يطلبه التطبيق تلقائيًا، ويمكنك الاستمرار بالتوقيت التقريبي.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('استخدام التقريبي'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('فتح السماح الخاص'),
          ),
        ],
      ),
    );
    if (accepted == true) await controller.requestExactAccess();
  }

  String _salawatSummary(AppSettings settings) {
    final label = switch (settings.salawatFrequency) {
      SalawatFrequency.once => 'مرة واحدة',
      SalawatFrequency.three => '3 مرات',
      SalawatFrequency.five => '5 مرات',
      SalawatFrequency.custom => settings.salawatTimes.map(_time).join('، '),
    };
    return label;
  }

  String _time(ReminderTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  String _dateTime(DateTime value) =>
      '${value.day}/${value.month} — ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
