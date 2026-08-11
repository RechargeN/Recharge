import 'dart:typed_data';

import '../../../../core/id/id_generator.dart';
import '../../domain/repositories/route_gpx_repository.dart';
import '../../domain/repositories/route_gpx_source_store.dart';

class RouteGpxMemorySourceStore implements RouteGpxSourceStore {
  RouteGpxMemorySourceStore({
    required IdGenerator idGenerator,
    required RouteGpxImportConfig config,
  }) : _idGenerator = idGenerator,
       _config = config.validated();

  final IdGenerator _idGenerator;
  final RouteGpxImportConfig _config;
  final Map<String, Uint8List> _files = <String, Uint8List>{};

  @override
  Future<RouteSafeFileRef> register({
    required String displayName,
    required String mediaType,
    required Uint8List bytes,
  }) async {
    if (displayName.trim().isEmpty || bytes.isEmpty) {
      throw const RouteGpxException('gpx_file_invalid');
    }
    if (bytes.length > _config.maximumFileBytes) {
      throw const RouteGpxException('gpx_file_too_large');
    }
    final safeDisplayName = displayName
        .trim()
        .replaceAll('\\', '/')
        .split('/')
        .last;
    final token = _idGenerator.generate();
    _files[token] = Uint8List.fromList(bytes);
    return RouteSafeFileRef(
      token: token,
      displayName: safeDisplayName,
      sizeBytes: bytes.length,
      mediaType: mediaType.trim().toLowerCase(),
    );
  }

  @override
  Future<Uint8List> read(RouteSafeFileRef file) async {
    final bytes = _files[file.token];
    if (bytes == null) {
      throw const RouteGpxException('gpx_file_not_found');
    }
    if (bytes.length != file.sizeBytes) {
      throw const RouteGpxException('gpx_file_changed');
    }
    return Uint8List.fromList(bytes);
  }

  @override
  Future<void> remove(String token) async {
    _files.remove(token);
  }
}
