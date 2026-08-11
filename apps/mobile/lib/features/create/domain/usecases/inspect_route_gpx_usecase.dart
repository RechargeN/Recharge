import '../repositories/route_gpx_repository.dart';

class InspectRouteGpxUseCase {
  const InspectRouteGpxUseCase(this._repository);

  final RouteGpxRepository _repository;

  Future<RouteGpxInspection> call(RouteSafeFileRef file) =>
      _repository.inspect(file);
}
