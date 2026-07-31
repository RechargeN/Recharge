import '../repositories/route_gpx_repository.dart';

class ExportRouteGpxUseCase {
  const ExportRouteGpxUseCase(this._repository);

  final RouteGpxRepository _repository;

  Future<RouteSafeFileRef> call(RouteGpxExportRequest request) =>
      _repository.export(request);
}
