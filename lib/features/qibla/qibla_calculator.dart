import 'dart:math' as math;

abstract final class QiblaCalculator {
  // Centre of the Kaaba, expressed in WGS84 decimal degrees.
  static const kaabaLatitude = 21.4225241;
  static const kaabaLongitude = 39.8261818;

  static double bearing({required double latitude, required double longitude}) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw const FormatException('Invalid geographic coordinate');
    }

    final fromLatitude = _radians(latitude);
    final toLatitude = _radians(kaabaLatitude);
    final longitudeDelta = _radians(kaabaLongitude - longitude);
    final y = math.sin(longitudeDelta) * math.cos(toLatitude);
    final x =
        math.cos(fromLatitude) * math.sin(toLatitude) -
        math.sin(fromLatitude) *
            math.cos(toLatitude) *
            math.cos(longitudeDelta);
    return normalizeDegrees(_degrees(math.atan2(y, x)));
  }

  static double relativeAngle({
    required double qiblaBearing,
    required double deviceHeading,
  }) => normalizeDegrees(qiblaBearing - deviceHeading);

  static double signedRelativeAngle({
    required double qiblaBearing,
    required double deviceHeading,
  }) {
    final normalized = relativeAngle(
      qiblaBearing: qiblaBearing,
      deviceHeading: deviceHeading,
    );
    return normalized > 180 ? normalized - 360 : normalized;
  }

  static double normalizeDegrees(double value) {
    final normalized = value % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  static double shortestDelta(double from, double to) {
    final delta = normalizeDegrees(to) - normalizeDegrees(from);
    if (delta > 180) return delta - 360;
    if (delta < -180) return delta + 360;
    return delta;
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
  static double _degrees(double radians) => radians * 180 / math.pi;
}
