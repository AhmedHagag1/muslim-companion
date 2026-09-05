import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/services/location_service.dart';
import '../prayer/prayer_controller.dart';
import 'compass_service.dart';
import 'qibla_calculator.dart';
import 'qibla_feedback_service.dart';

enum CompassAvailability { checking, available, unavailable }

enum CompassCalibrationState { unknown, guidance }

class QiblaController extends ChangeNotifier {
  QiblaController({
    required this.locationService,
    required this.prayerController,
    this.compassService = const DeviceCompassService(),
    this.feedbackService = const SystemQiblaFeedbackService(),
    this.alignmentThreshold = 4,
  }) {
    prayerController.addListener(_readPrayerLocation);
    _readPrayerLocation(notify: false);
  }

  final LocationService locationService;
  final PrayerController prayerController;
  final CompassService compassService;
  final QiblaFeedbackService feedbackService;
  final double alignmentThreshold;

  StreamSubscription<CompassReading?>? _compassSubscription;
  Timer? _sensorTimeout;
  bool _started = false;
  bool _wasAligned = false;
  bool _locationLoading = false;
  double? _latitude;
  double? _longitude;
  double? _qiblaBearing;
  double? _deviceHeading;
  LocationFailureType? _locationFailure;
  CompassAvailability _compassAvailability = CompassAvailability.checking;
  CompassCalibrationState _calibrationState = CompassCalibrationState.unknown;

  bool get locationLoading => _locationLoading;
  bool get hasLocation => _qiblaBearing != null;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  double? get qiblaBearingDegrees => _qiblaBearing;
  double? get deviceHeading => _deviceHeading;
  LocationFailureType? get locationFailure => _locationFailure;
  CompassAvailability get compassAvailability => _compassAvailability;
  CompassCalibrationState get calibrationState => _calibrationState;
  bool get isStarted => _started;

  double? get relativeQiblaAngle =>
      _qiblaBearing == null || _deviceHeading == null
      ? null
      : QiblaCalculator.relativeAngle(
          qiblaBearing: _qiblaBearing!,
          deviceHeading: _deviceHeading!,
        );

  double? get signedRelativeQiblaAngle =>
      _qiblaBearing == null || _deviceHeading == null
      ? null
      : QiblaCalculator.signedRelativeAngle(
          qiblaBearing: _qiblaBearing!,
          deviceHeading: _deviceHeading!,
        );

  bool get isAligned {
    final angle = signedRelativeQiblaAngle;
    return angle != null && angle.abs() <= alignmentThreshold;
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _startCompass();
    if (!hasLocation) await _loadLocation();
  }

  Future<void> retryLocation() => _loadLocation();

  Future<void> openRelevantSettings() async {
    if (_locationFailure == LocationFailureType.serviceDisabled) {
      await locationService.openLocationSettings();
    } else if (_locationFailure ==
        LocationFailureType.permissionDeniedForever) {
      await locationService.openAppSettings();
    }
  }

  void stop() {
    _started = false;
    _sensorTimeout?.cancel();
    _sensorTimeout = null;
    _compassSubscription?.cancel();
    _compassSubscription = null;
    _wasAligned = false;
    _deviceHeading = null;
    _compassAvailability = CompassAvailability.checking;
  }

  void _startCompass() {
    _compassAvailability = CompassAvailability.checking;
    _calibrationState = CompassCalibrationState.unknown;
    final stream = compassService.readings;
    if (stream == null) {
      _setCompassUnavailable();
      return;
    }
    _sensorTimeout = Timer(const Duration(seconds: 4), () {
      if (_deviceHeading == null) _setCompassUnavailable();
    });
    _compassSubscription = stream.listen(
      _onCompassReading,
      onError: (_) => _setCompassUnavailable(),
      cancelOnError: false,
    );
    notifyListeners();
  }

  void _onCompassReading(CompassReading? reading) {
    if (!_started) return;
    if (reading == null) {
      _setCompassUnavailable();
      return;
    }
    _sensorTimeout?.cancel();
    _compassAvailability = CompassAvailability.available;
    _calibrationState = CompassCalibrationState.guidance;
    _deviceHeading = QiblaCalculator.normalizeDegrees(reading.heading);
    _updateAlignmentFeedback();
    notifyListeners();
  }

  void _setCompassUnavailable() {
    _sensorTimeout?.cancel();
    _compassAvailability = CompassAvailability.unavailable;
    _deviceHeading = null;
    _wasAligned = false;
    if (_started) notifyListeners();
  }

  Future<void> _loadLocation() async {
    _locationLoading = true;
    _locationFailure = null;
    notifyListeners();
    try {
      final prayerLatitude = prayerController.latitude;
      final prayerLongitude = prayerController.longitude;
      if (prayerLatitude != null && prayerLongitude != null) {
        _setCoordinates(prayerLatitude, prayerLongitude);
      } else {
        final cached = locationService.lastPosition;
        final position = cached ?? await locationService.getCurrentPosition();
        _setCoordinates(position.latitude, position.longitude);
      }
    } on LocationFailure catch (failure) {
      _locationFailure = failure.type;
    } catch (_) {
      _locationFailure = LocationFailureType.unavailable;
    } finally {
      _locationLoading = false;
      notifyListeners();
    }
  }

  void _readPrayerLocation({bool notify = true}) {
    final latitude = prayerController.latitude;
    final longitude = prayerController.longitude;
    if (latitude == null || longitude == null) return;
    if (latitude == _latitude && longitude == _longitude) return;
    _setCoordinates(latitude, longitude);
    if (notify) notifyListeners();
  }

  void _setCoordinates(double latitude, double longitude) {
    _latitude = latitude;
    _longitude = longitude;
    _qiblaBearing = QiblaCalculator.bearing(
      latitude: latitude,
      longitude: longitude,
    );
    _locationFailure = null;
    _updateAlignmentFeedback();
  }

  void _updateAlignmentFeedback() {
    final aligned = isAligned;
    if (aligned && !_wasAligned) {
      unawaited(feedbackService.alignmentEntered());
    }
    _wasAligned = aligned;
  }

  @override
  void dispose() {
    stop();
    prayerController.removeListener(_readPrayerLocation);
    super.dispose();
  }
}
