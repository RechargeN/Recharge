import '../geo/geo_point.dart';
import 'map_scene.dart';

class AuthoringMapScene {
  AuthoringMapScene({
    required this.viewport,
    Iterable<MapMarkerData> markers = const <MapMarkerData>[],
    Iterable<MapPolylineData> polylines = const <MapPolylineData>[],
    Iterable<MapPolylineData> graphEdges = const <MapPolylineData>[],
  }) : markers = List<MapMarkerData>.unmodifiable(markers),
       polylines = List<MapPolylineData>.unmodifiable(polylines),
       graphEdges = List<MapPolylineData>.unmodifiable(graphEdges);

  final MapViewport viewport;
  final List<MapMarkerData> markers;
  final List<MapPolylineData> polylines;
  final List<MapPolylineData> graphEdges;
}

sealed class AuthoringMapIntent {
  const AuthoringMapIntent();
}

class AuthoringMapTapIntent extends AuthoringMapIntent {
  const AuthoringMapTapIntent(this.position);

  final GeoPoint position;
}

class AuthoringMapDragIntent extends AuthoringMapIntent {
  const AuthoringMapDragIntent({
    required this.subjectId,
    required this.position,
  });

  final String subjectId;
  final GeoPoint position;
}

class AuthoringMapSelectIntent extends AuthoringMapIntent {
  const AuthoringMapSelectIntent(this.subjectId);

  final String subjectId;
}

class AuthoringMapSplitTargetIntent extends AuthoringMapIntent {
  const AuthoringMapSplitTargetIntent({
    required this.segmentId,
    required this.position,
  });

  final String segmentId;
  final GeoPoint position;
}

class AuthoringMapViewportChangedIntent extends AuthoringMapIntent {
  const AuthoringMapViewportChangedIntent(this.viewport);

  final MapViewport viewport;
}

abstract interface class AuthoringMapSurface {
  Stream<AuthoringMapIntent> get intents;

  Future<void> render(AuthoringMapScene scene);
}
