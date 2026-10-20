import '../../../../shared/primitives/geo/geo_point.dart';

/// Server-derived summary of one canonical Route revision (or its trim).
class RouteSyncSummary {
  const RouteSyncSummary({
    required this.pointCount,
    required this.segmentCount,
    required this.gapCount,
    required this.distanceMeters,
    this.ascentMeters,
    this.descentMeters,
    this.minimumElevationMeters,
    this.maximumElevationMeters,
  });

  final int pointCount;
  final int segmentCount;
  final int gapCount;
  final double distanceMeters;
  final double? ascentMeters;
  final double? descentMeters;
  final double? minimumElevationMeters;
  final double? maximumElevationMeters;
}

class RoutePrivacyTrim {
  const RoutePrivacyTrim({required this.startMeters, required this.endMeters});

  static const int maximumMeters = 2000;

  final int startMeters;
  final int endMeters;

  bool get isValid =>
      startMeters >= 0 &&
      endMeters >= 0 &&
      startMeters <= maximumMeters &&
      endMeters <= maximumMeters;
}

/// One synced owner Route. `localId` is the Create draft that produced it on
/// this installation, when known; the server never sees it.
class RouteSyncEntry {
  const RouteSyncEntry({
    required this.routeId,
    required this.revision,
    required this.deleted,
    required this.title,
    required this.updatedAtUtc,
    this.route,
    this.privacyTrim,
    this.origin,
    this.summary,
  });

  final String routeId;
  final int revision;
  final bool deleted;
  final String title;
  final DateTime updatedAtUtc;
  final Object? route;
  final RoutePrivacyTrim? privacyTrim;
  final String? origin;
  final RouteSyncSummary? summary;
}

class RouteTrimmedSegment {
  RouteTrimmedSegment({
    required Iterable<GeoPoint> points,
    required this.connected,
  }) : points = List<GeoPoint>.unmodifiable(points);

  final List<GeoPoint> points;
  final bool connected;
}

class RouteTrimmedWaypoint {
  const RouteTrimmedWaypoint({
    required this.position,
    required this.typeId,
    this.title,
  });

  final GeoPoint position;
  final String typeId;
  final String? title;
}

/// The only Route shape an export or preview may use: pinned to one server
/// revision and one trim variant, without anchors, IDs, notes or bounds.
class RouteTrimmedView {
  RouteTrimmedView({
    required this.routeId,
    required this.revision,
    required this.trim,
    required this.variantHash,
    required Iterable<RouteTrimmedSegment> segments,
    required Iterable<RouteTrimmedWaypoint> waypoints,
    required this.summary,
    required this.reenteredStart,
    required this.reenteredEnd,
  }) : segments = List<RouteTrimmedSegment>.unmodifiable(segments),
       waypoints = List<RouteTrimmedWaypoint>.unmodifiable(waypoints);

  final String routeId;
  final int revision;
  final RoutePrivacyTrim trim;
  final String variantHash;
  final List<RouteTrimmedSegment> segments;
  final List<RouteTrimmedWaypoint> waypoints;
  final RouteSyncSummary summary;
  final bool reenteredStart;
  final bool reenteredEnd;
}
