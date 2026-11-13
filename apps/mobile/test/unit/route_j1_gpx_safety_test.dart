import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/adapters/route_gpx_file_selector_adapter.dart';
import 'package:recharge/core/geo/geo_point.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/data/gpx/route_gpx_exporter.dart';
import 'package:recharge/features/create/data/gpx/route_gpx_importer.dart';
import 'package:recharge/features/create/data/gpx/route_gpx_inspector.dart';
import 'package:recharge/features/create/data/models/route_canonical_codec.dart';
import 'package:recharge/features/create/domain/entities/route_draft_data.dart';
import 'package:recharge/features/create/domain/entities/route_edit_command.dart';
import 'package:recharge/features/create/domain/entities/route_sync_data.dart';
import 'package:recharge/features/create/domain/repositories/route_gpx_repository.dart';
import 'package:recharge/features/create/domain/usecases/apply_route_edit_command_usecase.dart';

import '../support/route_domain_fixtures.dart';

const _max = RouteGpxImportConfig();

RouteGpxInspection _inspect(
  Object source, {
  RouteGpxImportConfig config = const RouteGpxImportConfig(),
  String name = 'route.gpx',
}) {
  final bytes = source is Uint8List
      ? source
      : Uint8List.fromList(utf8.encode(source as String));
  return RouteGpxInspector(config: config).inspect(
    file: RouteSafeFileRef(
      token: 'token',
      displayName: name,
      sizeBytes: bytes.length,
      mediaType: 'application/gpx+xml',
    ),
    bytes: bytes,
  );
}

Matcher _code(String code) => throwsA(
  isA<RouteGpxException>().having((error) => error.code, 'code', code),
);

String _track(String body, {String extra = ''}) =>
    '<gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1"$extra>'
    '$body<trk><trkseg><trkpt lat="56.95" lon="24.10"/>'
    '<trkpt lat="56.96" lon="24.11"/></trkseg></trk></gpx>';

String _points(int count) =>
    '<gpx version="1.1"><trk><trkseg>'
    '${List<String>.filled(count, '<trkpt lat="1" lon="1"/>').join()}'
    '</trkseg></trk></gpx>';

/// Runs [body] with every file and network API replaced by a tripwire.
T _withoutIo<T>(T Function() body) => IOOverrides.runZoned(
  () => HttpOverrides.runZoned(
    body,
    createHttpClient: (_) {
      throw StateError('network access attempted');
    },
  ),
  createFile: (String path) => throw StateError('file access: $path'),
  createDirectory: (String path) => throw StateError('dir access: $path'),
);

void main() {
  test('SYSTEM/PUBLIC in ordinary text, CDATA and attributes are safe', () {
    for (final body in <String>[
      "<metadata><desc>SYSTEM \"ordinary\" PUBLIC 'quoted'</desc></metadata>",
      '<metadata><desc><![CDATA[SYSTEM "ordinary" PUBLIC "text"]]></desc></metadata>',
      '<metadata><link href="https://example.invalid"><text>PUBLIC "park"</text></link></metadata>',
    ]) {
      _withoutIo(() => _inspect(_track(body)));
    }
    _withoutIo(
      () => _inspect(
        _track('', extra: " creator=\"SYSTEM 'ordinary' PUBLIC 'text'\""),
      ),
    );
  });

  group('hostile XML', () {
    late Directory temp;
    late File secret;
    late HttpServer server;
    var connections = 0;

    setUpAll(() async {
      temp = await Directory.systemTemp.createTemp('j1-gpx-');
      secret = File('${temp.path}/secret.txt')
        ..writeAsStringSync('J1-SECRET-SENTINEL');
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) {
        connections++;
        request.response
          ..write('<!ENTITY x "J1-NETWORK-SENTINEL">')
          ..close();
      });
    });
    tearDownAll(() async {
      await server.close(force: true);
      await temp.delete(recursive: true);
    });

    test(
      'XXE, DTD, entity expansion and XInclude are refused without IO',
      () async {
        final url = 'http://127.0.0.1:${server.port}/x';
        final file = secret.uri.toString();
        final hostile = <String, String>{
          'file entity':
              '<?xml version="1.0"?><!DOCTYPE gpx [<!ENTITY x SYSTEM "$file">]>'
              '${_track('<wpt lat="1" lon="1"><name>&x;</name></wpt>')}',
          'network entity':
              '<!DOCTYPE gpx [<!ENTITY x SYSTEM "$url">]>${_track('')}',
          'parameter entity':
              '<!DOCTYPE gpx [<!ENTITY % p SYSTEM "$url"> %p;]>${_track('')}',
          'public id': '<!DOCTYPE gpx PUBLIC "-//x" "$url">${_track('')}',
          'billion laughs':
              '<!DOCTYPE gpx [<!ENTITY a "aaaaaaaaaa">'
              '<!ENTITY b "&a;&a;&a;&a;&a;&a;&a;&a;&a;&a;">'
              '<!ENTITY c "&b;&b;&b;&b;&b;&b;&b;&b;&b;&b;">]>'
              '${_track('<wpt lat="1" lon="1"><name>&c;</name></wpt>')}',
          'lowercase doctype': '<!doctype gpx>${_track('')}',
        };
        for (final entry in hostile.entries) {
          expect(
            () => _withoutIo(() => _inspect(entry.value)),
            _code('gpx_dtd_or_entity_forbidden'),
            reason: entry.key,
          );
        }
        for (final href in <String>[url, file]) {
          expect(
            () => _withoutIo(
              () => _inspect(
                _track(
                  '<xi:include href="$href" parse="text"/>',
                  extra: ' xmlns:xi="http://www.w3.org/2001/XInclude"',
                ),
              ),
            ),
            _code('gpx_xinclude_forbidden'),
          );
        }
        expect(
          () => _inspect('<?xml-stylesheet href="$url"?>${_track('')}'),
          _code('gpx_processing_instruction_forbidden'),
        );
        // Remote references in ordinary attributes are data: never fetched.
        final inert = _withoutIo(
          () => _inspect(
            _track(
              '<metadata><link href="$url"/></metadata>',
              extra:
                  ' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
                  ' xsi:schemaLocation="http://www.topografix.com/GPX/1/1 $url"',
            ),
          ),
        );
        expect(inert.candidates, hasLength(1));
        // An undeclared entity is never expanded: refused or kept literal.
        try {
          final literal = _inspect(
            _track('<wpt lat="1" lon="1"><name>&undefined;</name></wpt>'),
          );
          expect(literal.waypoints.single.name, isNot(contains('SENTINEL')));
        } on RouteGpxException catch (error) {
          expect(error.code, 'gpx_xml_malformed');
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(connections, 0);
      },
    );

    test('bytes decide: archives, other encodings and non-XML are refused', () {
      final gpx = utf8.encode(_track(''));
      for (final magic in <List<int>>[
        <int>[0x1F, 0x8B, 0x08],
        <int>[0x50, 0x4B, 0x03, 0x04],
        <int>[0x42, 0x5A, 0x68],
        <int>[0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00],
        <int>[0x28, 0xB5, 0x2F, 0xFD],
        <int>[0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C],
      ]) {
        expect(
          () => _inspect(Uint8List.fromList(<int>[...magic, ...gpx])),
          _code('gpx_compressed_forbidden'),
        );
      }
      expect(
        () => _inspect(
          Uint8List.fromList(<int>[
            0xFF,
            0xFE,
            ...utf8.encode(_track('')).expand((b) => <int>[b, 0]),
          ]),
        ),
        _code('gpx_encoding_invalid'),
      );
      expect(() => _inspect('hello ${_track('')}'), _code('gpx_not_xml'));
      expect(() => _inspect(Uint8List(0)), _code('gpx_file_empty'));
      expect(
        () => _inspect(_track(''), name: 'route.gpx.gz'),
        _code('gpx_file_type_unsupported'),
      );
    });

    test(
      'malformed, truncated, unsupported and multiple roots are refused',
      () {
        final valid = _track('');
        for (var cut = 10; cut < valid.length; cut += 17) {
          expect(
            () => _inspect(valid.substring(0, cut)),
            throwsA(isA<RouteGpxException>()),
            reason: 'cut at $cut',
          );
        }
        expect(
          () => _inspect(valid.replaceFirst('1.1', '1.2')),
          _code('gpx_version_unsupported'),
        );
        expect(
          () => _inspect(valid.replaceFirst(' version="1.1"', '')),
          _code('gpx_version_unsupported'),
        );
        expect(
          () => _inspect('$valid$valid'),
          throwsA(isA<RouteGpxException>()),
        );
        expect(
          () => _inspect('<gpx version="1.1"><trkpt lat="1" lon="1"/></gpx>'),
          _code('gpx_track_point_outside_segment'),
        );
      },
    );

    test('numbers: lexical decimals, ranges, NaN/Infinity and elevation', () {
      String point(String lat, String lon, [String? ele]) =>
          '<gpx version="1.1"><trk><trkseg>'
          '<trkpt lat="$lat" lon="$lon">${ele == null ? '' : '<ele>$ele</ele>'}'
          '</trkpt><trkpt lat="1" lon="1"/></trkseg></trk></gpx>';
      for (final bad in <String>[
        'NaN',
        'Infinity',
        '-Infinity',
        '1e2',
        '0x10',
        '',
        ' ',
        '1,5',
        '++1',
      ]) {
        expect(
          () => _inspect(point(bad, '24')),
          _code('gpx_number_invalid'),
          reason: bad,
        );
      }
      expect(
        () => _inspect(point('90.0000001', '24')),
        _code('gpx_coordinate_invalid'),
      );
      expect(
        () => _inspect(point('1', '-180.0000001')),
        _code('gpx_coordinate_invalid'),
      );
      expect(_inspect(point('-90', '180')).pointCount, 2);
      expect(_inspect(point('+56.9', '.5')).pointCount, 2);
      expect(
        _inspect(point('1', '1', '-500')).candidates.single.hasElevation,
        isTrue,
      );
      expect(_inspect(point('1', '1', '9000')).pointCount, 2);
      expect(
        () => _inspect(point('1', '1', '9000.1')),
        _code('gpx_elevation_invalid'),
      );
      expect(
        () => _inspect(point('1', '1', '-500.1')),
        _code('gpx_elevation_invalid'),
      );
      expect(
        () => _inspect(point('1', '1', 'NaN')),
        _code('gpx_number_invalid'),
      );
      expect(
        () =>
            _inspect(_track('<wpt lat="1" lon="1"><name>a&#1;b</name></wpt>')),
        throwsA(isA<RouteGpxException>()),
      );
    });
  });

  group('limits: the exact bound passes, the next value is refused', () {
    test('raw bytes with the default 5 MiB limit', () {
      String padded(int size) {
        const head = '<gpx version="1.1"><metadata><extensions>';
        const tail =
            '</extensions></metadata><trk><trkseg><trkpt lat="56.95" lon="24.10"/>'
            '<trkpt lat="56.96" lon="24.11"/></trkseg></trk></gpx>';
        final chunk = '<p>${'x' * 9000}</p>';
        final buffer = StringBuffer(head);
        // Leaves a final pad shorter than one chunk, below the text limit.
        while (buffer.length + chunk.length + tail.length + 7 <= size) {
          buffer.write(chunk);
        }
        final rest = size - buffer.length - tail.length - '<p></p>'.length;
        buffer
          ..write('<p>${'y' * rest}</p>')
          ..write(tail);
        return buffer.toString();
      }

      final exact = padded(_max.maximumFileBytes);
      expect(utf8.encode(exact).length, _max.maximumFileBytes);
      expect(_inspect(exact).pointCount, 2);
      final over = padded(_max.maximumFileBytes + 1);
      expect(utf8.encode(over).length, _max.maximumFileBytes + 1);
      expect(() => _inspect(over), _code('gpx_file_too_large'));
    });

    test('source points at the default 200 000', () {
      expect(_inspect(_points(_max.maximumSourcePoints)).pointCount, 200000);
      expect(
        () => _inspect(_points(_max.maximumSourcePoints + 1)),
        _code('gpx_point_limit_exceeded'),
      );
    });

    test('XML events at the default 1 000 000 (wide structure)', () {
      String wide(int extra) =>
          '<gpx version="1.1"><metadata><extensions>'
          '${List<String>.filled(extra, '<x/>').join()}'
          '</extensions></metadata><trk><trkseg><trkpt lat="1" lon="1"/>'
          '<trkpt lat="2" lon="2"/></trkseg></trk></gpx>';
      // 12 structural events plus the padding elements.
      expect(_inspect(wide(_max.maximumXmlEvents - 12)).pointCount, 2);
      expect(
        () => _inspect(wide(_max.maximumXmlEvents - 11)),
        _code('gpx_xml_event_limit_exceeded'),
      );
    });

    test('depth, attributes, text, waypoints, segments and candidates', () {
      String deep(int depth) =>
          '<gpx version="1.1"><trk><trkseg><trkpt lat="1" lon="1"><extensions>'
          '${'<a>' * (depth - 5)}${'</a>' * (depth - 5)}'
          '</extensions></trkpt><trkpt lat="2" lon="2"/></trkseg></trk></gpx>';
      expect(_inspect(deep(_max.maximumXmlDepth)).pointCount, 2);
      expect(
        () => _inspect(deep(_max.maximumXmlDepth + 1)),
        _code('gpx_xml_depth_limit_exceeded'),
      );
      String attributes(int count, int length) =>
          '<gpx version="1.1"><trk><trkseg><trkpt lat="1" lon="1" '
          '${List<String>.generate(count - 2, (i) => 'a$i="${'v' * length}"').join(' ')}/>'
          '<trkpt lat="2" lon="2"/></trkseg></trk></gpx>';
      expect(_inspect(attributes(32, 1)).pointCount, 2);
      expect(
        () => _inspect(attributes(33, 1)),
        _code('gpx_attribute_limit_exceeded'),
      );
      expect(_inspect(attributes(3, 2048)).pointCount, 2);
      expect(
        () => _inspect(attributes(3, 2049)),
        _code('gpx_attribute_limit_exceeded'),
      );
      String named(int length) =>
          _track('<wpt lat="1" lon="1"><name>${'n' * length}</name></wpt>');
      expect(_inspect(named(10000)).waypoints.single.name, hasLength(10000));
      expect(() => _inspect(named(10001)), _code('gpx_text_limit_exceeded'));
      // Uncaptured extension text is bounded too.
      expect(
        () =>
            _inspect(_track('<extensions><e>${'e' * 10001}</e></extensions>')),
        _code('gpx_text_limit_exceeded'),
      );
      String waypoints(int count) =>
          _track(List<String>.filled(count, '<wpt lat="1" lon="1"/>').join());
      expect(_inspect(waypoints(10000)).waypointCount, 10000);
      expect(
        () => _inspect(waypoints(10001)),
        _code('gpx_waypoint_limit_exceeded'),
      );
      String segments(int empty) =>
          '<gpx version="1.1"><trk>${'<trkseg/>' * empty}<trkseg>'
          '<trkpt lat="1" lon="1"/><trkpt lat="2" lon="2"/></trkseg></trk></gpx>';
      expect(_inspect(segments(4999)).candidates.single.segmentCount, 1);
      expect(
        () => _inspect(segments(5000)),
        _code('gpx_segment_limit_exceeded'),
      );
      String routes(int count) =>
          '<gpx version="1.1">'
          '${List<String>.filled(count, '<rte><rtept lat="1" lon="1"/></rte>').join()}'
          '</gpx>';
      expect(_inspect(routes(1000)).candidates, hasLength(1000));
      expect(
        () => _inspect(routes(1001)),
        _code('gpx_candidate_limit_exceeded'),
      );
    });

    test(
      'the picker checks size before reading and stops at the limit',
      () async {
        final big = _SizedFile(reported: _max.maximumFileBytes + 1);
        await expectLater(
          readBoundedGpx(big, _max.maximumFileBytes),
          throwsA(
            isA<RouteGpxException>().having(
              (e) => e.code,
              'code',
              'gpx_file_too_large',
            ),
          ),
        );
        expect(big.reads, 0);
        // A source that lies about its size is cut off while streaming.
        final liar = _SizedFile(
          reported: 10,
          actual: _max.maximumFileBytes + 1,
        );
        await expectLater(
          readBoundedGpx(liar, _max.maximumFileBytes),
          throwsA(isA<RouteGpxException>()),
        );
        expect(
          liar.delivered,
          lessThanOrEqualTo(_max.maximumFileBytes + 65536),
        );
        final exact = _SizedFile(
          reported: _max.maximumFileBytes,
          actual: _max.maximumFileBytes,
        );
        expect(
          (await readBoundedGpx(exact, _max.maximumFileBytes)).length,
          _max.maximumFileBytes,
        );
      },
    );
  });

  group('import, canonical round trip and export', () {
    const inspector = RouteGpxInspector(config: RouteGpxImportConfig());
    const importer = RouteGpxImporter(inspector: inspector);
    final source = utf8.encode('''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Private Device 9000" xmlns="http://www.topografix.com/GPX/1/1"
 xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3">
  <metadata><author><name>Private Author</name></author><time>2026-07-25T09:00:00Z</time></metadata>
  <wpt lat="56.95005" lon="24.10005"><name>Gate &lt;north&gt; &amp; "tap"</name><type>water</type>
    <extensions><gpxx:Secret>EXT-SENTINEL</gpxx:Secret></extensions></wpt>
  <trk><name>Private track name</name>
    <trkseg>
      <trkpt lat="56.9500000" lon="24.1000000"><ele>10.0</ele><time>2026-07-25T09:00:00Z</time></trkpt>
      <trkpt lat="56.9500000" lon="24.1000000"><ele>10.0</ele></trkpt>
      <trkpt lat="56.9510001" lon="24.1010001"><ele>11.04</ele></trkpt>
    </trkseg>
    <trkseg>
      <trkpt lat="56.9520000" lon="24.1020000"/>
      <trkpt lat="56.9530000" lon="24.1030000"><ele>12.5</ele></trkpt>
    </trkseg>
    <extensions><gpxx:TrackExtension><gpxx:DisplayColor>EXT-COLOR</gpxx:DisplayColor></gpxx:TrackExtension></extensions>
  </trk>
</gpx>
''');
    final file = RouteSafeFileRef(
      token: 'token',
      displayName: 'C:/Users/private/route.gpx',
      sizeBytes: source.length,
      mediaType: 'application/gpx+xml',
    );

    RouteDraftData imported() {
      final result = importer.import(
        selection: RouteGpxImportSelection(
          file: file,
          candidateKeys: const <String>['track:0'],
          mergeTracks: false,
          importWaypoints: true,
          stripTimestamps: true,
          stripPrivateMetadata: true,
          gapResolutions: const <String, RouteGpxGapResolution>{
            'track:0:gap:0:1': RouteGpxGapResolution.direct,
          },
          waypointDecisions: const <int, RouteGpxWaypointDecision>{
            0: RouteGpxWaypointDecision.keepOffTrack,
          },
        ),
        bytes: Uint8List.fromList(source),
        nowUtc: DateTime.utc(2026, 10, 20),
      );
      expect(
        result.sourceIssues.map((issue) => issue.code),
        containsAll(<String>[
          'gpx_direct_gap_confirmed',
          'gpx_duplicates_removed',
        ]),
      );
      final applied = ApplyRouteEditCommandUseCase(idGenerator: _Sequence())
          .call(
            routeFixture(),
            ApplyRouteGpxImport(
              result: result,
              confirmGeometryReplacement: true,
            ),
            nowUtc: DateTime.utc(2026, 10, 20),
            maximumAnchors: 100,
            maximumSegments: 120,
            maximumWaypoints: 250,
            maximumGeometryPoints: 10000,
          );
      expect(applied.accepted, isTrue);
      return applied.draft;
    }

    test('single/multi-segment import keeps order, gaps and provenance', () {
      final draft = imported();
      final segments = draft.orderedSegments;
      expect(segments.map((s) => s.source), <RouteSegmentSource>[
        RouteSegmentSource.importedGpx,
        RouteSegmentSource.intentionalDirect,
        RouteSegmentSource.importedGpx,
      ]);
      // Exactly one duplicate removed and counted; no other point changed.
      expect(segments[0].geometry.points.map((p) => p.latitude), <double>[
        56.95,
        56.9510001,
      ]);
      expect(segments[2].geometry.points.first.elevationMeters, isNull);
      expect(segments[2].geometry.points.last.elevationMeters, 12.5);
      expect(segments[0].provenance.algorithmVersion, 'gpx-import-v2');
      expect(segments[0].provenance.sourceId, startsWith('gpx-'));
      // Nothing private survives the import into the draft.
      final text = draft.waypoints.map((w) => '${w.title}|${w.note}').join();
      expect(text, isNot(contains('EXT-')));
      expect(draft.waypoints.single.title, 'Gate <north> & "tap"');
    });

    test('canonical encode/decode is an identity after one quantization', () {
      final draft = imported();
      final ids = <String, String>{};
      var next = 0;
      String idFor(String local) => ids.putIfAbsent(
        local,
        () =>
            '00000000-0000-4000-8000-${(next++).toRadixString(16).padLeft(12, '0')}',
      );
      final dto = RouteCanonicalCodec.encode(draft, title: 'T', idFor: idFor);
      final decoded = RouteCanonicalCodec.decode(
        dto,
        template: draft,
        updatedAtUtc: DateTime.utc(2026, 10, 20),
      );
      final again = RouteCanonicalCodec.encode(
        decoded,
        title: 'T',
        idFor: idFor,
      );
      expect(jsonEncode(again), jsonEncode(dto));
      // Same local IDs map to the same permanent IDs on every save.
      expect(
        jsonEncode(RouteCanonicalCodec.encode(draft, title: 'T', idFor: idFor)),
        jsonEncode(dto),
      );
      final original = draft.orderedSegments[0].geometry.points[1];
      final roundTrip = decoded.orderedSegments[0].geometry.points[1];
      expect(
        (original.latitude - roundTrip.latitude).abs(),
        lessThanOrEqualTo(5e-8),
      );
      expect(
        (original.elevationMeters! - roundTrip.elevationMeters!).abs(),
        lessThanOrEqualTo(0.05),
      );
      final json = jsonEncode(dto);
      for (final secret in <String>[
        'Private',
        'EXT-',
        '2026-07-25',
        'route.gpx',
        'C:/Users',
        'time',
        'extensions',
      ]) {
        expect(json, isNot(contains(secret)), reason: secret);
      }
    });

    test('canonical encoder refuses provider geometry, local IDs and excess', () {
      final base = imported();
      final routed = base.copyWith(
        segments: base.segments
            .map((s) => s.copyWith(source: RouteSegmentSource.routed))
            .toList(),
      );
      expect(
        () => RouteCanonicalCodec.encode(routed, title: '', idFor: (id) => id),
        throwsA(
          isA<RouteCanonicalFailure>().having(
            (e) => e.code,
            'code',
            'license_blocked',
          ),
        ),
      );
      expect(
        () => RouteCanonicalCodec.encode(base, title: '', idFor: (id) => id),
        throwsA(
          isA<RouteCanonicalFailure>().having(
            (e) => e.code,
            'code',
            'route_ids_invalid',
          ),
        ),
      );
      final many = base.copyWith(
        segments: <RouteSegmentDraft>[
          base.orderedSegments.first.copyWith(
            geometry: RouteGeometryDraft.fromPoints(
              List<GeoPoint>.generate(
                10001,
                (i) => GeoPoint(latitude: 56.9, longitude: 24 + i * 1e-5),
              ),
            ),
          ),
        ],
      );
      var n = 0;
      expect(
        () => RouteCanonicalCodec.encode(
          many,
          title: '',
          idFor: (_) =>
              '00000000-0000-4000-8000-${(n++).toRadixString(16).padLeft(12, '0')}',
        ),
        throwsA(
          isA<RouteCanonicalFailure>().having(
            (e) => e.code,
            'code',
            'point_limit_exceeded',
          ),
        ),
      );
    });

    test(
      'export escapes text, keeps gaps as trkseg and drops private data',
      () {
        final draft = imported();
        final ordered = draft.orderedSegments;
        // Break the chain explicitly: a gap must not be bridged in the export.
        final gapped = draft.copyWith(
          segments: <RouteSegmentDraft>[
            ordered[0],
            ordered[2].copyWith(order: 1, fromAnchorId: 'loc_gap_anchor'),
          ],
        );
        final bytes = const RouteGpxExporter().export(
          RouteGpxExportRequest(
            routeId: 'private-route-id',
            routeVersionId: 'v',
            route: gapped,
            includeElevation: true,
            includeWaypoints: true,
          ),
        );
        final xml = utf8.decode(bytes);
        expect(RegExp('<trkseg>').allMatches(xml), hasLength(2));
        expect(xml, contains('Gate &lt;north'));
        expect(xml, isNot(contains('<north')));
        for (final secret in <String>[
          'private-route-id',
          'Private',
          'EXT-',
          '<time>',
          '<extensions>',
          '<bounds',
          'route.gpx',
        ]) {
          expect(xml, isNot(contains(secret)), reason: secret);
        }
        final reread = _inspect(Uint8List.fromList(bytes));
        expect(reread.waypoints.single.name, 'Gate <north> & "tap"');
        expect(reread.candidates.single.segmentCount, 2);
      },
    );

    test('trimmed export contains only the view, never the draft', () {
      final view = RouteTrimmedView(
        routeId: 'r',
        revision: 3,
        trim: const RoutePrivacyTrim(startMeters: 100, endMeters: 0),
        variantHash: 'h',
        segments: <RouteTrimmedSegment>[
          RouteTrimmedSegment(
            points: const <GeoPoint>[
              GeoPoint(latitude: 56.96, longitude: 24.11),
              GeoPoint(latitude: 56.97, longitude: 24.12),
            ],
            connected: false,
          ),
          RouteTrimmedSegment(
            points: const <GeoPoint>[
              GeoPoint(latitude: 56.98, longitude: 24.13),
              GeoPoint(latitude: 56.99, longitude: 24.14),
            ],
            connected: false,
          ),
        ],
        waypoints: const <RouteTrimmedWaypoint>[
          RouteTrimmedWaypoint(
            position: GeoPoint(latitude: 56.97, longitude: 24.12),
            typeId: 'viewpoint',
            title: '</name><evil attr="x">&',
          ),
        ],
        summary: const RouteSyncSummary(
          pointCount: 4,
          segmentCount: 2,
          gapCount: 1,
          distanceMeters: 1,
        ),
        reenteredStart: false,
        reenteredEnd: false,
      );
      final xml = utf8.decode(
        const RouteGpxExporter().exportTrimmed(
          view,
          includeElevation: true,
          includeWaypoints: true,
        ),
      );
      expect(RegExp('<trkpt ').allMatches(xml), hasLength(4));
      expect(RegExp('<trkseg>').allMatches(xml), hasLength(2));
      expect(xml, contains('&lt;/name'));
      expect(xml, contains('&amp;'));
      expect(xml, isNot(contains('<evil')));
      final reread = _inspect(xml);
      expect(reread.waypoints.single.name, '</name><evil attr="x">&');
    });
  });
}

class _Sequence implements IdGenerator {
  int _next = 0;
  @override
  String generate() => (_next++).toString().padLeft(26, '0');
}

class _SizedFile extends XFile {
  _SizedFile({required this.reported, int? actual})
    : actual = actual ?? reported,
      super('j1-sized.gpx');

  final int reported;
  final int actual;
  int reads = 0;
  int delivered = 0;

  @override
  Future<int> length() async => reported;

  @override
  Stream<Uint8List> openRead([int? start, int? end]) async* {
    reads++;
    const chunk = 65536;
    while (delivered < actual) {
      final size = (actual - delivered).clamp(0, chunk);
      delivered += size;
      yield Uint8List(size)..fillRange(0, size, 0x20);
    }
  }
}
