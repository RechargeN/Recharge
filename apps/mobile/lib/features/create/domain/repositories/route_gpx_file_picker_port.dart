import 'route_gpx_repository.dart';

abstract interface class RouteGpxFilePickerPort {
  Future<RouteSafeFileRef?> pickForImport();

  Future<bool> saveExport(RouteSafeFileRef file);
}
