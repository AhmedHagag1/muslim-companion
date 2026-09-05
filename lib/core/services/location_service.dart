import 'package:geolocator/geolocator.dart';

enum LocationFailureType {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class LocationFailure implements Exception {
  const LocationFailure(this.type);
  final LocationFailureType type;
}

class LocationService {
  Position? _lastPosition;
  Future<Position>? _inFlight;

  Position? get lastPosition => _lastPosition;

  Future<Position> getCurrentPosition() {
    final activeRequest = _inFlight;
    if (activeRequest != null) return activeRequest;
    final request = _resolveCurrentPosition();
    _inFlight = request;
    return request.whenComplete(() {
      if (identical(_inFlight, request)) _inFlight = null;
    });
  }

  Future<Position> _resolveCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure(LocationFailureType.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationFailure(LocationFailureType.permissionDenied);
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(LocationFailureType.permissionDeniedForever);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _lastPosition = position;
      return position;
    } catch (_) {
      throw const LocationFailure(LocationFailureType.unavailable);
    }
  }

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}
