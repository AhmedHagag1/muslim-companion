import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/services/effective_prayer_times_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/prayer_api_service.dart';
import '../../core/services/prayer_models.dart';
import '../../data/repositories/prayer_settings_repository.dart';

class PrayerController extends ChangeNotifier {
  PrayerController({
    PrayerApiService? prayerApiService,
    EffectivePrayerTimesService? effectiveService,
    PrayerSettingsRepository? settingsRepository,
    LocationService? locationService,
  }) : _effectiveService =
           effectiveService ??
           EffectivePrayerTimesService(remote: prayerApiService),
       _settingsRepository = settingsRepository ?? PrayerSettingsRepository(),
       _locationService = locationService ?? LocationService();

  final EffectivePrayerTimesService _effectiveService;
  final PrayerSettingsRepository _settingsRepository;
  final LocationService _locationService;

  EffectivePrayerTimes? _today;
  EffectivePrayerTimes? _tomorrow;
  PrayerSettings _settings = const PrayerSettings();
  PrayerTimeItem? _nextPrayer;
  bool _isLoading = false;
  bool _settingsLoaded = false;
  String? _error;
  LocationFailureType? _locationFailure;
  Timer? _timer;
  double? _latitude;
  double? _longitude;

  EffectivePrayerTimes? get effectiveTimes => _today;
  PrayerSettings get settings => _settings;
  List<PrayerTimeItem> get prayers =>
      List.unmodifiable(_today?.times ?? const []);
  List<PrayerTimeItem> get notificationPrayers =>
      List.unmodifiable([...?_today?.times, ...?_tomorrow?.times]);
  PrayerTimeItem? get nextPrayer => _nextPrayer;
  bool get isLoading => _isLoading;
  String? get error => _error;
  LocationFailureType? get locationFailure => _locationFailure;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  Duration? get countdown => _nextPrayer?.time.difference(DateTime.now());
  DateTime? get tonightMaghrib => _today?.named('المغرب')?.time;
  DateTime? get tomorrowFajr => _tomorrow?.named('الفجر')?.time;
  DateTime? get todaySunrise => _today?.named('الشروق')?.time;
  DateTime? get todayDhuhr => _today?.named('الظهر')?.time;

  DateTime? get calculatedMidnight {
    final maghrib = _today?.named('المغرب')?.time;
    final fajr = _tomorrow?.named('الفجر')?.time;
    if (maghrib == null || fajr == null || !fajr.isAfter(maghrib)) return null;
    return maghrib.add(
      Duration(seconds: fajr.difference(maghrib).inSeconds ~/ 2),
    );
  }

  DateTime? get calculatedLastThird {
    final maghrib = _today?.named('المغرب')?.time;
    final fajr = _tomorrow?.named('الفجر')?.time;
    if (maghrib == null || fajr == null || !fajr.isAfter(maghrib)) return null;
    return maghrib.add(
      Duration(seconds: fajr.difference(maghrib).inSeconds * 2 ~/ 3),
    );
  }

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    _locationFailure = null;
    notifyListeners();
    try {
      if (!_settingsLoaded) {
        _settings = await _settingsRepository.load();
        _settingsLoaded = true;
      }
      final position = await _locationService.getCurrentPosition();
      _latitude = position.latitude;
      _longitude = position.longitude;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final results = await Future.wait([
        _effectiveService.resolve(
          latitude: _latitude!,
          longitude: _longitude!,
          settings: _settings,
          date: today,
        ),
        _effectiveService.resolve(
          latitude: _latitude!,
          longitude: _longitude!,
          settings: _settings,
          date: tomorrow,
        ),
      ]);
      _today = results[0];
      _tomorrow = results[1];
      _updateNextPrayer();
      _startTimer();
    } on LocationFailure catch (failure) {
      _locationFailure = failure.type;
      _error = switch (failure.type) {
        LocationFailureType.serviceDisabled =>
          'فعّل خدمة الموقع لعرض مواقيت الصلاة.',
        LocationFailureType.permissionDenied =>
          'نحتاج إذن الموقع لحساب المواقيت في مدينتك.',
        LocationFailureType.permissionDeniedForever =>
          'اسمح بالوصول إلى الموقع من إعدادات التطبيق.',
        LocationFailureType.unavailable =>
          'تعذر تحديد موقعك الآن. حاول مرة أخرى.',
      };
    } catch (_) {
      _error = 'تعذر حساب مواقيت الصلاة الآن. حاول مرة أخرى.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateSettings(PrayerSettings value) async {
    _settings = value;
    _settingsLoaded = true;
    await _settingsRepository.save(value);
    notifyListeners();
    await refresh();
  }

  Future<void> setAdjustment(String prayer, int minutes) {
    if (!adjustablePrayerNames.contains(prayer)) return Future.value();
    final next = Map<String, int>.from(_settings.adjustments);
    final safe = minutes.clamp(-30, 30);
    if (safe == 0) {
      next.remove(prayer);
    } else {
      next[prayer] = safe;
    }
    return updateSettings(_settings.copyWith(adjustments: next));
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateNextPrayer(),
    );
  }

  void _updateNextPrayer() {
    final now = DateTime.now();
    _nextPrayer = notificationPrayers
        .where((item) => item.name != 'الشروق' && item.time.isAfter(now))
        .firstOrNull;
    notifyListeners();
  }

  Future<void> refresh() async {
    _timer?.cancel();
    _isLoading = false;
    await load();
  }

  Future<void> openRelevantSettings() async {
    if (_locationFailure == LocationFailureType.serviceDisabled) {
      await _locationService.openLocationSettings();
    } else if (_locationFailure ==
        LocationFailureType.permissionDeniedForever) {
      await _locationService.openAppSettings();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _effectiveService.dispose();
    super.dispose();
  }
}
