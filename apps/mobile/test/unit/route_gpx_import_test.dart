import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/data/gpx/route_gpx_importer.dart';
import 'package:recharge/features/create/data/gpx/route_gpx_inspector.dart';
import 'package:recharge/features/create/domain/entities/route_draft_data.dart';
import 'package:recharge/features/create/domain/entities/route_edit_command.dart';
import 'package:recharge/features/create/domain/repositories/route_gpx_repository.dart';
import 'package:recharge/features/create/domain/usecases/apply_route_edit_command_usecase.dart';

import '../support/route_domain_fixtures.dart';

void main() {
  const inspector = RouteGpxInspector(config: RouteGpxImportConfig());
  const importer = RouteGpxImporter(inspector: inspector);

  test('gap and waypoint decisions create one normalized import', () {
    final source = _source();
    final result = importer.import(
      selection: RouteGpxImportSelection(
        file: source.file,
        candidateKeys: const <String>['track:0'],
        mergeTracks: true,
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
      bytes: source.bytes,
      nowUtc: DateTime.utc(2026, 7, 25),
    );

    expect(result.tracks, hasLength(1));
    expect(result.tracks.single, hasLength(4));
    expect(result.waypoints.single.typeId, 'water');
    expect(
      result.waypoints.single.trackState,
      RouteWaypointTrackState.offTrackConfirmed,
    );
    expect(result.sourceIssues.single.code, 'gpx_direct_gap_confirmed');
    expect(result.provenance.sourceId, startsWith('gpx-'));
  });

  test('ambiguous gap is rejected and separate decision keeps two tracks', () {
    final source = _source();
    RouteGpxImportSelection selection(RouteGpxGapResolution? resolution) =>
        RouteGpxImportSelection(
          file: source.file,
          candidateKeys: const <String>['track:0'],
          mergeTracks: false,
          importWaypoints: false,
          stripTimestamps: true,
          stripPrivateMetadata: true,
          gapResolutions: resolution == null
              ? const <String, RouteGpxGapResolution>{}
              : <String, RouteGpxGapResolution>{'track:0:gap:0:1': resolution},
        );

    expect(
      () => importer.import(
        selection: selection(null),
        bytes: source.bytes,
        nowUtc: DateTime.utc(2026, 7, 25),
      ),
      _throwsCode('gpx_gap_decision_required'),
    );
    final separate = importer.import(
      selection: selection(RouteGpxGapResolution.separate),
      bytes: source.bytes,
      nowUtc: DateTime.utc(2026, 7, 25),
    );
    expect(separate.tracks, hasLength(2));
  });

  test('privacy stripping is mandatory', () {
    final source = _source();
    expect(
      () => importer.import(
        selection: RouteGpxImportSelection(
          file: source.file,
          candidateKeys: const <String>['track:0'],
          mergeTracks: true,
          importWaypoints: false,
          stripTimestamps: false,
          stripPrivateMetadata: true,
          gapResolutions: const <String, RouteGpxGapResolution>{
            'track:0:gap:0:1': RouteGpxGapResolution.direct,
          },
        ),
        bytes: source.bytes,
        nowUtc: DateTime.utc(2026, 7, 25),
      ),
      _throwsCode('gpx_privacy_stripping_required'),
    );
  });

  test('waypoint decisions are ignored when waypoint import is disabled', () {
    final source = _source();
    final result = importer.import(
      selection: RouteGpxImportSelection(
        file: source.file,
        candidateKeys: const <String>['track:0'],
        mergeTracks: false,
        importWaypoints: false,
        stripTimestamps: true,
        stripPrivateMetadata: true,
        gapResolutions: const <String, RouteGpxGapResolution>{
          'track:0:gap:0:1': RouteGpxGapResolution.direct,
        },
        waypointDecisions: const <int, RouteGpxWaypointDecision>{
          0: RouteGpxWaypointDecision.keepOffTrack,
        },
      ),
      bytes: source.bytes,
      nowUtc: DateTime.utc(2026, 7, 25),
    );

    expect(result.waypoints, isEmpty);
  });

  test('GPX apply is atomic and requires replacement confirmation', () {
    final source = _source();
    final imported = importer.import(
      selection: RouteGpxImportSelection(
        file: source.file,
        candidateKeys: const <String>['track:0'],
        mergeTracks: true,
        importWaypoints: true,
        stripTimestamps: true,
        stripPrivateMetadata: true,
        gapResolutions: const <String, RouteGpxGapResolution>{
          'track:0:gap:0:1': RouteGpxGapResolution.direct,
        },
      ),
      bytes: source.bytes,
      nowUtc: DateTime.utc(2026, 7, 25),
    );
    final draft = routeFixture();
    final apply = ApplyRouteEditCommandUseCase(
      idGenerator: _SequenceIdGenerator(),
    );
    final rejected = apply(
      draft,
      ApplyRouteGpxImport(result: imported),
      nowUtc: DateTime.utc(2026, 7, 25),
      maximumAnchors: 100,
      maximumSegments: 120,
      maximumWaypoints: 250,
      maximumGeometryPoints: 10000,
    );
    expect(rejected.accepted, isFalse);
    expect(rejected.draft, same(draft));

    final accepted = apply(
      draft,
      ApplyRouteGpxImport(result: imported, confirmGeometryReplacement: true),
      nowUtc: DateTime.utc(2026, 7, 25),
      maximumAnchors: 100,
      maximumSegments: 120,
      maximumWaypoints: 250,
      maximumGeometryPoints: 10000,
    );
    expect(accepted.accepted, isTrue);
    expect(accepted.draft.creationMethod, RouteCreationMethod.importedGpx);
    expect(
      accepted.draft.segments.single.source,
      RouteSegmentSource.importedGpx,
    );
    expect(accepted.draft.revision, draft.revision + 1);
    expect(accepted.draft.geometryRevision, draft.geometryRevision + 1);
  });
}

({RouteSafeFileRef file, Uint8List bytes}) _source() {
  final bytes = Uint8List.fromList(
    utf8.encode('''
<gpx version="1.1" creator="device">
  <wpt lat="56.9505" lon="24.1005"><name>Tap</name><type>water</type></wpt>
  <trk><name>Two segments</name>
    <trkseg>
      <trkpt lat="56.9500" lon="24.1000"/>
      <trkpt lat="56.9510" lon="24.1010"/>
    </trkseg>
    <trkseg>
      <trkpt lat="56.9520" lon="24.1020"/>
      <trkpt lat="56.9530" lon="24.1030"/>
    </trkseg>
  </trk>
</gpx>
'''),
  );
  return (
    file: RouteSafeFileRef(
      token: 'source-token',
      displayName: 'route.gpx',
      sizeBytes: bytes.length,
      mediaType: 'application/gpx+xml',
    ),
    bytes: bytes,
  );
}

Matcher _throwsCode(String code) => throwsA(
  isA<RouteGpxException>().having((error) => error.code, 'code', code),
);

class _SequenceIdGenerator implements IdGenerator {
  int _next = 0;

  @override
  String generate() => (_next++).toString().padLeft(26, '0');
}
