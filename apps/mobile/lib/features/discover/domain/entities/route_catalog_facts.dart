import '../../../../shared/primitives/geo/geo_point.dart';

/// DTL-RTE-02 RD-11: the publisher kind only; the Catalog carries no public
/// name, and the publisher id never reaches the client model.
enum RouteCatalogPublisherKind { personal, page }

/// One drawn piece of a published Route. [connected] is false for the first
/// segment and after every explicit gap: gaps are never joined (RD-03).
/// [direct] is known only for the full track in Details (intentional or
/// fallback direct segments); the preview line carries no source kinds.
final class RouteCatalogSegment {
  RouteCatalogSegment({
    required Iterable<GeoPoint> points,
    required this.connected,
    this.direct = false,
  }) : points = List<GeoPoint>.unmodifiable(points);

  final List<GeoPoint> points;
  final bool connected;
  final bool direct;
}

/// A public waypoint of the trimmed track (RTE-PUB-01 RP-09).
final class RouteCatalogWaypoint {
  const RouteCatalogWaypoint({
    required this.typeId,
    required this.point,
    required this.distanceFromStartMeters,
    this.title,
    this.safetyNote,
  });

  final String typeId;
  final String? title;
  final String? safetyNote;
  final GeoPoint point;
  final double distanceFromStartMeters;
}

/// DTL-RTE-02 RD-01: the read-only public facts of one published Route as the
/// server Catalog projects it (`catalog-route-projection-v1`). Nothing here is
/// stored or written by the client. There is no duration and no bounds — the
/// public snapshot has neither, and they are never invented. Optional
/// metrics stay `null` instead of becoming zero (RD-12).
final class RouteCatalogFacts {
  RouteCatalogFacts({
    required this.publishedRevisionId,
    required this.shape,
    required this.profileId,
    required this.distanceMeters,
    required this.segmentCount,
    required this.gapCount,
    required this.directSegmentCount,
    required this.start,
    required Iterable<RouteCatalogSegment> preview,
    required this.publisherKind,
    this.ascentMeters,
    this.descentMeters,
    this.minElevationMeters,
    this.maxElevationMeters,
    this.fullDescription = '',
    Iterable<RouteCatalogSegment>? track,
    Iterable<RouteCatalogWaypoint>? waypoints,
  }) : preview = List<RouteCatalogSegment>.unmodifiable(preview),
       track = track == null
           ? null
           : List<RouteCatalogSegment>.unmodifiable(track),
       waypoints = waypoints == null
           ? null
           : List<RouteCatalogWaypoint>.unmodifiable(waypoints);

  final String publishedRevisionId;
  final String shape;
  final String profileId;
  final double distanceMeters;
  final double? ascentMeters;
  final double? descentMeters;
  final double? minElevationMeters;
  final double? maxElevationMeters;
  final int segmentCount;
  final int gapCount;
  final int directSegmentCount;

  /// First point of the trimmed track — never the private start.
  final GeoPoint start;

  /// The `route-preview-dp-v1` line for cards and the Map (≤ 256 points).
  final List<RouteCatalogSegment> preview;
  final RouteCatalogPublisherKind publisherKind;
  final String fullDescription;

  /// Details only: the full trimmed track and its waypoints; `null` on cards.
  final List<RouteCatalogSegment>? track;
  final List<RouteCatalogWaypoint>? waypoints;

  bool get hasFullTrack => track != null;
}
