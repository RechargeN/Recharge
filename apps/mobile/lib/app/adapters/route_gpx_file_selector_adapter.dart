import 'dart:typed_data';
import 'dart:ui';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:share_plus/share_plus.dart';

import '../../features/create/domain/repositories/route_gpx_file_picker_port.dart';
import '../../features/create/domain/repositories/route_gpx_repository.dart';
import '../../features/create/domain/repositories/route_gpx_source_store.dart';

/// Reads at most [maximumBytes]: the reported size is checked before any read
/// and the stream is abandoned as soon as it grows past the limit.
Future<Uint8List> readBoundedGpx(XFile file, int maximumBytes) async {
  final reported = await file.length();
  if (reported <= 0) throw const RouteGpxException('gpx_file_empty');
  if (reported > maximumBytes) {
    throw const RouteGpxException('gpx_file_too_large');
  }
  final builder = BytesBuilder(copy: false);
  await for (final chunk in file.openRead()) {
    if (builder.length + chunk.length > maximumBytes) {
      throw const RouteGpxException('gpx_file_too_large');
    }
    builder.add(chunk);
  }
  return builder.takeBytes();
}

/// Whether a picked file is named like a GPX file (`.gpx`, any case); the
/// same rule the inspector applies to the registered file.
bool isGpxFileName(String name) => name.trim().toLowerCase().endsWith('.gpx');

/// The GPX name of a picked file, or null when it cannot be a GPX file.
///
/// file_selector on Android copies the document into the cache as its base
/// name plus the extension of its MIME type, and `XFile.name` is that copy:
/// a `.gpx` typed `application/octet-stream` arrives as `route.bin`, one typed
/// as XML as `route.xml` (B1-device, A34, 2026-11-03). Only that rename is
/// undone; the inspector still accepts the file by its bytes alone.
String? gpxDisplayName(String name, String? mimeType) {
  final trimmed = name.trim();
  if (isGpxFileName(trimmed)) return trimmed;
  final lower = trimmed.toLowerCase();
  final platformExtension = switch (mimeType) {
    'application/octet-stream' => '.bin',
    'application/xml' || 'text/xml' => '.xml',
    _ => null,
  };
  if (platformExtension == null ||
      !lower.endsWith(platformExtension) ||
      trimmed.length == platformExtension.length) {
    return null;
  }
  return '${trimmed.substring(0, trimmed.length - platformExtension.length)}.gpx';
}

class RouteGpxFileSelectorAdapter implements RouteGpxFilePickerPort {
  const RouteGpxFileSelectorAdapter(
    this._sourceStore, {
    RouteGpxImportConfig config = const RouteGpxImportConfig(),
  }) : _config = config;

  final RouteGpxSourceStore _sourceStore;
  final RouteGpxImportConfig _config;

  /// Android filters the system picker by MIME type only, and MediaStore
  /// types a `.gpx` file as `application/octet-stream` (B1-device on a Samsung
  /// A34, 2026-11-03: the file was greyed out). That type is accepted here;
  /// the name is checked before any read and the inspector decides by bytes.
  @visibleForTesting
  static const XTypeGroup gpxTypeGroup = XTypeGroup(
    label:
        'GPX route', // l10n-ignore: file-type filter of the desktop system picker; not shown on Android/iOS
    extensions: <String>['gpx'],
    mimeTypes: <String>[
      'application/gpx+xml',
      'application/xml',
      'text/xml',
      'application/octet-stream',
    ],
    uniformTypeIdentifiers: <String>['com.topografix.gpx'],
    webWildCards: <String>['.gpx', 'application/gpx+xml'],
  );

  @override
  Future<RouteSafeFileRef?> pickForImport() async {
    final selected = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[gpxTypeGroup],
    );
    if (selected == null) return null;
    // The broad Android MIME filter also offers other binary files.
    final displayName = gpxDisplayName(selected.name, selected.mimeType);
    if (displayName == null) {
      throw const RouteGpxException('gpx_file_type_unsupported');
    }
    final bytes = await readBoundedGpx(selected, _config.maximumFileBytes);
    return _sourceStore.register(
      displayName: displayName,
      mediaType: selected.mimeType ?? 'application/gpx+xml',
      bytes: bytes,
    );
  }

  @override
  Future<bool> saveExport(RouteSafeFileRef file) async {
    try {
      final location = await getSaveLocation(
        suggestedName: file.displayName,
        acceptedTypeGroups: const <XTypeGroup>[gpxTypeGroup],
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
        XFile.fromData(bytes, mimeType: file.mediaType, name: file.displayName),
      ],
      subject:
          'Recharge Route GPX', // l10n-ignore: brand and file type in a share subject
      fileNameOverrides: <String>[file.displayName],
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
    );
    return result.status != ShareResultStatus.unavailable &&
        result.status != ShareResultStatus.dismissed;
  }
}
