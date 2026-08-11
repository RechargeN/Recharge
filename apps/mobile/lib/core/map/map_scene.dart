import '../geo/geo_bounds.dart';
import '../geo/geo_point.dart';

class MapCameraState {
  const MapCameraState({
    required this.target,
    required this.zoom,
    this.bearingDegrees = 0,
    this.tiltDegrees = 0,
  });

  final GeoPoint target;
  final double zoom;
  final double bearingDegrees;
  final double tiltDegrees;

  bool get isValid =>
      target.isValid &&
      zoom.isFinite &&
      bearingDegrees.isFinite &&
      tiltDegrees.isFinite;
}

class MapViewport {
  const MapViewport({required this.bounds, required this.camera});

  final GeoBounds bounds;
  final MapCameraState camera;

  bool get isValid => bounds.isValid && camera.isValid;
}

class MapMarkerData {
  const MapMarkerData({required this.id, required this.position, this.label});

  final String id;
  final GeoPoint position;
  final String? label;
}

class MapPolylineData {
  MapPolylineData({
    required this.id,
    required Iterable<GeoPoint> points,
    this.layerId = 'route',
  }) : points = List<GeoPoint>.unmodifiable(points);

  final String id;
  final String layerId;
  final List<GeoPoint> points;
}
