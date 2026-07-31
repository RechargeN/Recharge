import '../../domain/repositories/route_gpx_repository.dart';
import '../../domain/repositories/route_gpx_source_store.dart';
import '../gpx/route_gpx_inspector.dart';
import '../gpx/route_gpx_importer.dart';
import '../gpx/route_gpx_exporter.dart';

class RouteGpxRepositoryImpl implements RouteGpxRepository {
  const RouteGpxRepositoryImpl({
    required RouteGpxSourceStore sourceStore,
    required RouteGpxInspector inspector,
    required RouteGpxImporter importer,
    required RouteGpxExporter exporter,
    DateTime Function()? clock,
  }) : _sourceStore = sourceStore,
       _inspector = inspector,
       _importer = importer,
       _exporter = exporter,
       _clock = clock ?? _systemClock;

  final RouteGpxSourceStore _sourceStore;
  final RouteGpxInspector _inspector;
  final RouteGpxImporter _importer;
  final RouteGpxExporter _exporter;
  final DateTime Function() _clock;

  @override
  Future<RouteGpxInspection> inspect(RouteSafeFileRef file) async {
    final bytes = await _sourceStore.read(file);
    return _inspector.inspect(file: file, bytes: bytes);
  }

  @override
  Future<RouteGpxImportResult> import(
    RouteGpxImportSelection selection,
  ) async {
    final bytes = await _sourceStore.read(selection.file);
    return _importer.import(
      selection: selection,
      bytes: bytes,
      nowUtc: _clock().toUtc(),
    );
  }

  @override
  Future<RouteSafeFileRef> export(RouteGpxExportRequest request) async {
    final bytes = _exporter.export(request);
    return _sourceStore.register(
      displayName: 'recharge-route.gpx',
      mediaType: 'application/gpx+xml',
      bytes: bytes,
    );
  }

  @override
  Future<void> discard(RouteSafeFileRef file) =>
      _sourceStore.remove(file.token);

  static DateTime _systemClock() => DateTime.now().toUtc();
}
