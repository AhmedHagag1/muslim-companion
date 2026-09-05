import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quran_app/core/services/location_service.dart';
import 'package:quran_app/features/prayer/prayer_controller.dart';
import 'package:quran_app/features/qibla/compass_service.dart';
import 'package:quran_app/features/qibla/qibla_calculator.dart';
import 'package:quran_app/features/qibla/qibla_controller.dart';
import 'package:quran_app/features/qibla/qibla_feedback_service.dart';
import 'package:quran_app/features/qibla/qibla_page.dart';

void main() {
  group('QiblaCalculator', () {
    test('returns known great-circle bearings from world locations', () {
      expect(
        QiblaCalculator.bearing(latitude: 51.5074, longitude: -0.1278),
        closeTo(118.99, 0.15),
      );
      expect(
        QiblaCalculator.bearing(latitude: 40.7128, longitude: -74.0060),
        closeTo(58.48, 0.15),
      );
      expect(
        QiblaCalculator.bearing(latitude: -6.2088, longitude: 106.8456),
        closeTo(295.15, 0.15),
      );
    });

    test('normalizes bearings and relative angles across 359/0', () {
      expect(QiblaCalculator.normalizeDegrees(361), 1);
      expect(QiblaCalculator.normalizeDegrees(-1), 359);
      expect(
        QiblaCalculator.relativeAngle(qiblaBearing: 1, deviceHeading: 359),
        2,
      );
      expect(
        QiblaCalculator.signedRelativeAngle(
          qiblaBearing: 359,
          deviceHeading: 1,
        ),
        -2,
      );
      expect(QiblaCalculator.shortestDelta(359, 1), 2);
      expect(QiblaCalculator.shortestDelta(1, 359), -2);
    });

    test('rejects invalid coordinates', () {
      expect(
        () => QiblaCalculator.bearing(latitude: 91, longitude: 0),
        throwsFormatException,
      );
    });
  });

  group('QiblaController', () {
    test('uses a valid sensor stream and calculates offline', () async {
      final location = _FakeLocationService(51.5074, -0.1278);
      final compass = _FakeCompassService();
      final prayer = PrayerController(locationService: location);
      final controller = QiblaController(
        locationService: location,
        prayerController: prayer,
        compassService: compass,
        feedbackService: _FakeFeedbackService(),
      );

      await controller.start();
      compass.add(const CompassReading(heading: 359));
      await _flush();

      expect(controller.hasLocation, isTrue);
      expect(controller.qiblaBearingDegrees, closeTo(118.99, 0.15));
      expect(controller.deviceHeading, 359);
      expect(controller.compassAvailability, CompassAvailability.available);
      expect(location.calls, 1);
      expect(identical(controller.locationService, location), isTrue);

      controller.dispose();
      prayer.dispose();
      await compass.close();
    });

    test('reports compass unavailable without crashing', () async {
      final location = _FakeLocationService(51.5074, -0.1278);
      final prayer = PrayerController(locationService: location);
      final controller = QiblaController(
        locationService: location,
        prayerController: prayer,
        compassService: const _UnavailableCompassService(),
        feedbackService: _FakeFeedbackService(),
      );

      await controller.start();

      expect(controller.compassAvailability, CompassAvailability.unavailable);
      expect(controller.deviceHeading, isNull);
      expect(controller.qiblaBearingDegrees, isNotNull);

      controller.dispose();
      prayer.dispose();
    });

    test('reports location unavailable and never exposes raw errors', () async {
      final location = _FailingLocationService(
        LocationFailureType.permissionDenied,
      );
      final compass = _FakeCompassService();
      final prayer = PrayerController(locationService: location);
      final controller = QiblaController(
        locationService: location,
        prayerController: prayer,
        compassService: compass,
        feedbackService: _FakeFeedbackService(),
      );

      await controller.start();

      expect(controller.locationFailure, LocationFailureType.permissionDenied);
      expect(controller.qiblaBearingDegrees, isNull);

      controller.dispose();
      prayer.dispose();
      await compass.close();
    });

    test('haptic fires once per alignment entry', () async {
      final location = _FakeLocationService(51.5074, -0.1278);
      final compass = _FakeCompassService();
      final feedback = _FakeFeedbackService();
      final prayer = PrayerController(locationService: location);
      final controller = QiblaController(
        locationService: location,
        prayerController: prayer,
        compassService: compass,
        feedbackService: feedback,
      );
      await controller.start();
      final bearing = controller.qiblaBearingDegrees!;

      compass.add(CompassReading(heading: bearing + 8));
      compass.add(CompassReading(heading: bearing + 3));
      compass.add(CompassReading(heading: bearing + 1));
      await _flush();
      expect(controller.isAligned, isTrue);
      expect(feedback.calls, 1);

      compass.add(CompassReading(heading: bearing + 10));
      compass.add(CompassReading(heading: bearing));
      await _flush();
      expect(feedback.calls, 2);

      controller.dispose();
      prayer.dispose();
      await compass.close();
    });

    test('source creates one shared LocationService in MainShell', () {
      final source = File('lib/app/app.dart').readAsStringSync();
      expect(RegExp(r'LocationService\(\)').allMatches(source).length, 1);
      expect(
        source,
        contains('PrayerController(locationService: _locationService)'),
      );
      expect(source, contains('locationService: _locationService'));
    });
  });

  testWidgets('page exposes unavailable sensor and location states', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final unavailableLocation = _FailingLocationService(
      LocationFailureType.serviceDisabled,
    );
    final prayer = PrayerController(locationService: unavailableLocation);
    final controller = QiblaController(
      locationService: unavailableLocation,
      prayerController: prayer,
      compassService: const _UnavailableCompassService(),
      feedbackService: _FakeFeedbackService(),
    );

    await tester.pumpWidget(
      MaterialApp(home: QiblaPage(controller: controller)),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('qibla-location-unavailable')),
      findsOneWidget,
    );
    expect(find.textContaining('Exception:'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    prayer.dispose();
  });
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

Position _position(double latitude, double longitude) => Position(
  longitude: longitude,
  latitude: latitude,
  timestamp: DateTime(2026),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class _FakeLocationService extends LocationService {
  _FakeLocationService(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
  int calls = 0;

  @override
  Future<Position> getCurrentPosition() async {
    calls++;
    return _position(latitude, longitude);
  }
}

class _FailingLocationService extends LocationService {
  _FailingLocationService(this.type);

  final LocationFailureType type;

  @override
  Future<Position> getCurrentPosition() async => throw LocationFailure(type);
}

class _FakeCompassService implements CompassService {
  final _controller = StreamController<CompassReading?>.broadcast();

  @override
  Stream<CompassReading?> get readings => _controller.stream;

  void add(CompassReading? value) => _controller.add(value);
  Future<void> close() => _controller.close();
}

class _UnavailableCompassService implements CompassService {
  const _UnavailableCompassService();

  @override
  Stream<CompassReading?>? get readings => null;
}

class _FakeFeedbackService implements QiblaFeedbackService {
  int calls = 0;

  @override
  Future<void> alignmentEntered() async => calls++;
}
