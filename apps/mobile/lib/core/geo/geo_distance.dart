import 'dart:math' as math;

import 'geo_point.dart';

/// Provider-neutral distance calculations over WGS 84 coordinates.
abstract final class GeoDistance {
  static const double meanEarthRadiusMeters = 6371008.8;

  static double haversineMeters(GeoPoint from, GeoPoint to) {
    from.validated();
    to.validated();

    final latitudeDelta = _toRadians(to.latitude - from.latitude);
    final longitudeDelta = _toRadians(to.longitude - from.longitude);
    final fromLatitude = _toRadians(from.latitude);
    final toLatitude = _toRadians(to.latitude);

    final sinLatitude = math.sin(latitudeDelta / 2);
    final sinLongitude = math.sin(longitudeDelta / 2);
    final haversine =
        sinLatitude * sinLatitude +
        math.cos(fromLatitude) *
            math.cos(toLatitude) *
            sinLongitude *
            sinLongitude;
    final centralAngle =
        2 *
        math.atan2(math.sqrt(haversine), math.sqrt(math.max(0, 1 - haversine)));

    return meanEarthRadiusMeters * centralAngle;
  }

  static double polylineLengthMeters(Iterable<GeoPoint> points) {
    final iterator = points.iterator;
    if (!iterator.moveNext()) {
      return 0;
    }

    var previous = iterator.current;
    previous.validated();
    var distance = 0.0;

    while (iterator.moveNext()) {
      final current = iterator.current;
      distance += haversineMeters(previous, current);
      previous = current;
    }

    return distance;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
}
