import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/data/datasources/route_gpx_memory_source_store.dart';
import 'package:recharge/features/create/data/gpx/route_gpx_inspector.dart';
import 'package:recharge/features/create/data/gpx/route_gpx_importer.dart';
import 'package:recharge/features/create/data/gpx/route_gpx_exporter.dart';
import 'package:recharge/features/create/data/repositories/route_gpx_repository_impl.dart';
import 'package:recharge/features/create/domain/repositories/route_gpx_repository.dart';

void main() {
  group('safe GPX inspection', () {
    test('enumerates tracks, routes, gaps, waypoints and private metadata', () {
      final inspection = _inspect('''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Garmin device"
 xmlns="http://www.topografix.com/GPX/1/1"
 xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3">
  <metadata><author><name>Private author</name></author></metadata>
  <wpt lat="56.9500" lon="24.1000">
    <ele>12.5</ele><time>2026-07-25T09:00:00Z</time>
    <name>Water</name><type>water</type>
  </wpt>
  <trk>
    <name>Forest loop</name>
    <trkseg>
      <trkpt lat="56.9500" lon="24.1000">
        <ele>10</ele><time>2026-07-25T09:00:00Z</time>
      </trkpt>
      <trkpt lat="56.9510" lon="24.1010">
        <ele>15</ele><time>2026-07-25T09:01:00Z</time>
      </trkpt>
    </trkseg>
    <trkseg>
      <trkpt lat="56.9520" lon="24.1020"><ele>16</ele></trkpt>
      <trkpt lat="56.9530" lon="24.1030"><ele>17</ele></trkpt>
    </trkseg>
    <extensions><gpxx:TrackExtension /></extensions>
  </trk>
  <rte>
    <name>Return</name>
    <rtept lat="56.9530" lon="24.1030" />
    <rtept lat="56.9540" lon="24.1040" />
  </rte>
</gpx>
''');

      expect(inspection.gpxVersion, '1.1');
      expect(inspection.candidates, hasLength(2));
      expect(inspection.pointCount, 6);
      expect(inspection.waypointCount, 1);
      expect(inspection.containsPrivateMetadata, isTrue);
      expect(inspection.contentSha256, hasLength(64));
      expect(
        inspection.unsupportedExtensionNames,
        contains('gpxx:TrackExtension'),
      );

      final track = inspection.candidates.first;
      expect(track.kind, RouteGpxCandidateKind.track);
      expect(track.selectionKey, 'track:0');
      expect(track.name, 'Forest loop');
      expect(track.segmentCount, 2);
      expect(track.gapCount, 1);
      expect(track.pointCount, 4);
      expect(track.distanceMeters, greaterThan(200));
      expect(track.durationSeconds, 60);
      expect(track.hasElevation, isTrue);
      expect(track.hasTimestamps, isTrue);

      final route = inspection.candidates.last;
      expect(route.kind, RouteGpxCandidateKind.route);
      expect(route.selectionKey, 'route:0');
      expect(route.segmentCount, 1);
      expect(route.pointCount, 2);
      expect(inspection.waypoints.single.name, 'Water');
      expect(inspection.waypoints.single.type, 'water');
      expect(inspection.waypoints.single.position.elevationMeters, 12.5);
    });

    test('rejects DTD and entity declarations before XML parsing', () {
      expect(
        () => _inspect('''
<!DOCTYPE gpx [<!ENTITY secret SYSTEM "file:///etc/passwd">]>
<gpx version="1.1"><trk><trkseg>
<trkpt lat="56.95" lon="24.10"/><trkpt lat="56.96" lon="24.11"/>
</trkseg></trk></gpx>
'''),
        _throwsCode('gpx_dtd_or_entity_forbidden'),
      );
    });

    test('rejects malformed, non-GPX and empty-candidate documents', () {
      expect(
        () => _inspect('<gpx version="1.1"><trk>'),
        _throwsCode('gpx_xml_malformed'),
      );
      expect(
        () => _inspect('<root/>'),
        _throwsCode('gpx_root_invalid'),
      );
      expect(
        () => _inspect('<gpx version="1.1"><trk/></gpx>'),
        _throwsCode('gpx_candidate_empty'),
      );
    });

    test('rejects invalid coordinates and non-finite numbers', () {
      expect(
        () => _inspect('''
<gpx version="1.1"><trk><trkseg>
<trkpt lat="91" lon="24.10"/><trkpt lat="56.96" lon="24.11"/>
</trkseg></trk></gpx>
'''),
        _throwsCode('gpx_coordinate_invalid'),
      );
      expect(
        () => _inspect('''
<gpx version="1.1"><trk><trkseg>
<trkpt lat="NaN" lon="24.10"/><trkpt lat="56.96" lon="24.11"/>
</trkseg></trk></gpx>
'''),
        _throwsCode('gpx_number_invalid'),
      );
    });

    test('enforces file, point, segment, depth and text limits', () {
      expect(
        () => _inspect(
          '<gpx version="1.1"><trk><trkseg>'
          '<trkpt lat="1" lon="1"/><trkpt lat="2" lon="2"/>'
          '</trkseg></trk></gpx>',
          config: const RouteGpxImportConfig(maximumFileBytes: 20),
        ),
        _throwsCode('gpx_file_too_large'),
      );
      expect(
        () => _inspect(
          '<gpx version="1.1"><trk><trkseg>'
          '<trkpt lat="1" lon="1"/><trkpt lat="2" lon="2"/>'
          '<trkpt lat="3" lon="3"/></trkseg></trk></gpx>',
          config: const RouteGpxImportConfig(maximumSourcePoints: 2),
        ),
        _throwsCode('gpx_point_limit_exceeded'),
      );
      expect(
        () => _inspect(
          '<gpx version="1.1"><trk><trkseg/><trkseg/></trk></gpx>',
          config: const RouteGpxImportConfig(maximumSegments: 1),
        ),
        _throwsCode('gpx_segment_limit_exceeded'),
      );
      expect(
        () => _inspect(
          '<gpx version="1.1"><trk><name>Too long</name><trkseg>'
          '<trkpt lat="1" lon="1"/><trkpt lat="2" lon="2"/>'
          '</trkseg></trk></gpx>',
          config: const RouteGpxImportConfig(maximumTextCharacters: 3),
        ),
        _throwsCode('gpx_text_limit_exceeded'),
      );
      expect(
        () => _inspect(
          '<gpx version="1.1"><trk><trkseg>'
          '<trkpt lat="1" lon="1"><extensions><a><b/></a></extensions>'
          '</trkpt><trkpt lat="2" lon="2"/></trkseg></trk></gpx>',
          config: const RouteGpxImportConfig(maximumXmlDepth: 4),
        ),
        _throwsCode('gpx_xml_depth_limit_exceeded'),
      );
    });

    test('builds antimeridian-aware bounds', () {
      final inspection = _inspect('''
<gpx version="1.1"><trk><trkseg>
<trkpt lat="10" lon="179.5"/><trkpt lat="11" lon="-179.5"/>
</trkseg></trk></gpx>
''');
      expect(inspection.candidates.single.bounds.crossesAntimeridian, isTrue);
    });

    test('flags timestamp anomalies without rejecting safe geometry', () {
      final inspection = _inspect('''
<gpx version="1.1"><trk><trkseg>
<trkpt lat="56.95" lon="24.10"><time>2026-07-25T10:00:00Z</time></trkpt>
<trkpt lat="56.96" lon="24.11"><time>2026-07-25T09:00:00Z</time></trkpt>
</trkseg></trk></gpx>
''');
      expect(
        inspection.candidates.single.issueCodes,
        contains('gpx_timestamp_non_monotonic'),
      );
    });
  });

  test('opaque memory source is copied, inspected and removable', () async {
    final store = RouteGpxMemorySourceStore(
      idGenerator: _SequenceIdGenerator(),
      config: const RouteGpxImportConfig(),
    );
    final original = _bytes('''
<gpx version="1.1"><trk><trkseg>
<trkpt lat="56.95" lon="24.10"/><trkpt lat="56.96" lon="24.11"/>
</trkseg></trk></gpx>
''');
    final file = await store.register(
      displayName: r'C:\private\route.gpx',
      mediaType: 'application/gpx+xml',
      bytes: original,
    );
    original.fillRange(0, original.length, 0);
    final repository = RouteGpxRepositoryImpl(
      sourceStore: store,
      inspector: const RouteGpxInspector(config: RouteGpxImportConfig()),
      importer: const RouteGpxImporter(
        inspector: RouteGpxInspector(config: RouteGpxImportConfig()),
      ),
      exporter: const RouteGpxExporter(),
    );

    final inspection = await repository.inspect(file);
    expect(file.displayName, 'route.gpx');
    expect(inspection.candidates.single.pointCount, 2);
    await store.remove(file.token);
    expect(
      () => repository.inspect(file),
      _throwsCode('gpx_file_not_found'),
    );
  });
}

RouteGpxInspection _inspect(
  String source, {
  RouteGpxImportConfig config = const RouteGpxImportConfig(),
}) {
  final bytes = _bytes(source);
  return RouteGpxInspector(config: config).inspect(
    file: RouteSafeFileRef(
      token: 'file-token',
      displayName: 'route.gpx',
      sizeBytes: bytes.length,
      mediaType: 'application/gpx+xml',
    ),
    bytes: bytes,
  );
}

Uint8List _bytes(String value) => Uint8List.fromList(utf8.encode(value));

Matcher _throwsCode(String code) => throwsA(
  isA<RouteGpxException>().having((error) => error.code, 'code', code),
);

class _SequenceIdGenerator implements IdGenerator {
  int _next = 0;

  @override
  String generate() {
    final suffix = (_next++).toString().padLeft(12, '0');
    return '00000000-0000-4000-8000-$suffix';
  }
}
