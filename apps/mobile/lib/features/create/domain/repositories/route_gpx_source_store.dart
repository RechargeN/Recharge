import 'dart:typed_data';

import 'route_gpx_repository.dart';

abstract interface class RouteGpxSourceStore {
  Future<RouteSafeFileRef> register({
    required String displayName,
    required String mediaType,
    required Uint8List bytes,
  });

  Future<Uint8List> read(RouteSafeFileRef file);

  Future<void> remove(String token);
}
