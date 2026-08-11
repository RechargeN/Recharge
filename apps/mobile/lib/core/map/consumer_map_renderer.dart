import 'map_scene.dart';

class ConsumerMapScene {
  ConsumerMapScene({
    required this.camera,
    Iterable<MapMarkerData> markers = const <MapMarkerData>[],
    Iterable<MapPolylineData> savedPolylines = const <MapPolylineData>[],
  }) : markers = List<MapMarkerData>.unmodifiable(markers),
       savedPolylines = List<MapPolylineData>.unmodifiable(savedPolylines);

  final MapCameraState camera;
  final List<MapMarkerData> markers;
  final List<MapPolylineData> savedPolylines;
}

abstract interface class ConsumerMapRenderer {
  Future<void> render(ConsumerMapScene scene);
}
