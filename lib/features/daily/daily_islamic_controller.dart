import 'package:flutter/foundation.dart';

import '../../core/services/islamic_daily_service.dart';
import '../../data/models/islamic_daily.dart';
import '../../data/repositories/islamic_calendar_settings_repository.dart';
import '../prayer/prayer_controller.dart';

class DailyIslamicController extends ChangeNotifier {
  DailyIslamicController({
    required this.prayerController,
    IslamicDailyService? service,
    IslamicCalendarSettingsRepository? repository,
    DateTime Function()? clock,
  }) : service = service ?? const IslamicDailyService(),
       _repository = repository ?? IslamicCalendarSettingsRepository(),
       _clock = clock ?? DateTime.now {
    prayerController.addListener(_prayerChanged);
  }

  final PrayerController prayerController;
  final IslamicDailyService service;
  final IslamicCalendarSettingsRepository _repository;
  final DateTime Function() _clock;

  IslamicCalendarSettings settings = const IslamicCalendarSettings();
  DailyIslamicState? state;
  bool loaded = false;

  Future<void> load() async {
    settings = await _repository.load();
    loaded = true;
    refresh();
  }

  void refresh() {
    state = service.buildState(
      now: _clock(),
      settings: settings,
      maghrib: prayerController.tonightMaghrib,
      nextFajr: prayerController.tomorrowFajr,
      sunrise: prayerController.todaySunrise,
      dhuhr: prayerController.todayDhuhr,
    );
    notifyListeners();
  }

  Future<void> updateSettings(IslamicCalendarSettings value) async {
    settings = value;
    await _repository.save(value);
    refresh();
  }

  void _prayerChanged() {
    if (loaded) refresh();
  }

  @override
  void dispose() {
    prayerController.removeListener(_prayerChanged);
    super.dispose();
  }
}
