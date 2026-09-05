import 'package:flutter_device_compass/flutter_device_compass.dart';

class CompassReading {
  const CompassReading({required this.heading, this.reportedAccuracy});

  final double heading;

  /// Supplied for diagnostics only. Android values from the plugin are not
  /// reliable enough to display as a user-facing accuracy percentage.
  final double? reportedAccuracy;
}

abstract interface class CompassService {
  Stream<CompassReading?>? get readings;
}

class DeviceCompassService implements CompassService {
  const DeviceCompassService();

  @override
  Stream<CompassReading?>? get readings => FlutterCompass.events?.map((event) {
    final heading = event.heading;
    if (heading == null || !heading.isFinite) return null;
    return CompassReading(heading: heading, reportedAccuracy: event.accuracy);
  });
}
