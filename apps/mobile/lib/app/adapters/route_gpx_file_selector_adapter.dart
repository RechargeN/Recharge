import 'dart:ui';

import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/create/domain/repositories/route_gpx_file_picker_port.dart';
import '../../features/create/domain/repositories/route_gpx_repository.dart';
import '../../features/create/domain/repositories/route_gpx_source_store.dart';

class RouteGpxFileSelectorAdapter implements RouteGpxFilePickerPort {
  const RouteGpxFileSelectorAdapter(this._sourceStore);

  final RouteGpxSourceStore _sourceStore;

  static const XTypeGroup _gpxType = XTypeGroup(
    label: 'GPX route',
    extensions: <String>['gpx'],
    mimeTypes: <String>['application/gpx+xml', 'application/xml'],
    uniformTypeIdentifiers: <String>['com.topografix.gpx'],
    webWildCards: <String>['.gpx', 'application/gpx+xml'],
  );

  @override
  Future<RouteSafeFileRef?> pickForImport() async {
    final selected = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_gpxType],
    );
    if (selected == null) return null;
    final bytes = await selected.readAsBytes();
    return _sourceStore.register(
      displayName: selected.name,
      mediaType: selected.mimeType ?? 'application/gpx+xml',
      bytes: bytes,
    );
  }

  @override
  Future<bool> saveExport(RouteSafeFileRef file) async {
    try {
      final location = await getSaveLocation(
        suggestedName: file.displayName,
        acceptedTypeGroups: const <XTypeGroup>[_gpxType],
      );
      if (location == null) return false;
      final bytes = await _sourceStore.read(file);
      await XFile.fromData(
        bytes,
        mimeType: file.mediaType,
        name: file.displayName,
      ).saveTo(location.path);
      return true;
    } on UnimplementedError {
      return _shareExport(file);
    } on UnsupportedError {
      return _shareExport(file);
    }
  }

  Future<bool> _shareExport(RouteSafeFileRef file) async {
    final bytes = await _sourceStore.read(file);
    final result = await Share.shareXFiles(
      <XFile>[
        XFile.fromData(
          bytes,
          mimeType: file.mediaType,
          name: file.displayName,
        ),
      ],
      subject: 'Recharge Route GPX',
      fileNameOverrides: <String>[file.displayName],
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
    );
    return result.status != ShareResultStatus.unavailable &&
        result.status != ShareResultStatus.dismissed;
  }
}
