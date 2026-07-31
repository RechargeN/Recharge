import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/geo/geo_bounds.dart';
import 'package:recharge/core/geo/geo_point.dart';
import 'package:recharge/core/map/authoring_map_surface.dart';
import 'package:recharge/core/map/consumer_map_renderer.dart';
import 'package:recharge/core/map/map_scene.dart';

void main() {
  const camera = MapCameraState(
    target: GeoPoint(latitude: 56.9496, longitude: 24.1052),
    zoom: 13,
  );
  const viewport = MapViewport(
    bounds: GeoBounds(
      southwest: GeoPoint(latitude: 56.9, longitude: 24.0),
      northeast: GeoPoint(latitude: 57.0, longitude: 24.2),
    ),
    camera: camera,
  );

  test(
    'authoring surface emits edit intents and accepts graph layers',
    () async {
      final surface = _RecordingAuthoringSurface();
      final scene = AuthoringMapScene(
        viewport: viewport,
        graphEdges: <MapPolylineData>[
          MapPolylineData(
            id: 'edge-1',
            layerId: 'demo-graph',
            points: const <GeoPoint>[
              GeoPoint(latitude: 56.95, longitude: 24.10),
              GeoPoint(latitude: 56.96, longitude: 24.11),
            ],
          ),
        ],
      );

      await surface.render(scene);
      surface.emit(
        const AuthoringMapTapIntent(
          GeoPoint(latitude: 56.955, longitude: 24.105),
        ),
      );

      expect(surface.lastScene, same(scene));
      expect(await surface.intents.first, isA<AuthoringMapTapIntent>());
      await surface.close();
    },
  );

  test('consumer renderer accepts saved geometry only', () async {
    final renderer = _RecordingConsumerRenderer();
    final scene = ConsumerMapScene(
      camera: camera,
      savedPolylines: <MapPolylineData>[
        MapPolylineData(
          id: 'published-route',
          points: const <GeoPoint>[
            GeoPoint(latitude: 56.95, longitude: 24.10),
            GeoPoint(latitude: 56.96, longitude: 24.11),
          ],
        ),
      ],
    );

    await renderer.render(scene);

    expect(renderer.lastScene, same(scene));
    expect(renderer.lastScene!.savedPolylines, hasLength(1));
  });

  test('map scene collections cannot be mutated by adapters', () {
    final markers = <MapMarkerData>[
      const MapMarkerData(
        id: 'anchor',
        position: GeoPoint(latitude: 56.95, longitude: 24.10),
      ),
    ];
    final scene = ConsumerMapScene(camera: camera, markers: markers);
    markers.clear();

    expect(scene.markers, hasLength(1));
    expect(
      () => scene.markers.add(
        const MapMarkerData(
          id: 'other',
          position: GeoPoint(latitude: 56.96, longitude: 24.11),
        ),
      ),
      throwsUnsupportedError,
    );
  });
}

class _RecordingAuthoringSurface implements AuthoringMapSurface {
  final StreamController<AuthoringMapIntent> _controller =
      StreamController<AuthoringMapIntent>();

  AuthoringMapScene? lastScene;

  @override
  Stream<AuthoringMapIntent> get intents => _controller.stream;

  @override
  Future<void> render(AuthoringMapScene scene) async {
    lastScene = scene;
  }

  void emit(AuthoringMapIntent intent) => _controller.add(intent);

  Future<void> close() => _controller.close();
}

class _RecordingConsumerRenderer implements ConsumerMapRenderer {
  ConsumerMapScene? lastScene;

  @override
  Future<void> render(ConsumerMapScene scene) async {
    lastScene = scene;
  }
}
