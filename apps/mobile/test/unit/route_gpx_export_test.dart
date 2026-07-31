import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/gpx/route_gpx_exporter.dart';
import 'package:recharge/features/create/data/gpx/route_gpx_inspector.dart';
import 'package:recharge/features/create/domain/repositories/route_gpx_repository.dart';

import '../support/route_domain_fixtures.dart';

void main() {
  test('export excludes internal and private fields and round-trips geometry', () {
    final base = routeFixture();
    final route = base.copyWith(
      waypoints: [
        base.waypoints.single.copyWith(
          title: 'Viewpoint',
          note: 'private note',
          safetyNote: 'internal safety note',
        ),
      ],
    );
    final bytes = const RouteGpxExporter().export(
      RouteGpxExportRequest(
        routeId: 'private-route-id',
        routeVersionId: 'private-version-id',
        route: route,
        includeElevation: true,
        includeWaypoints: true,
      ),
    );
    final xml = utf8.decode(bytes);

    expect(xml, contains('Recharge route'));
    expect(xml, contains('Viewpoint'));
    expect(xml, isNot(contains('private-route-id')));
    expect(xml, isNot(contains('private-version-id')));
    expect(xml, isNot(contains('private note')));
    expect(xml, isNot(contains('internal safety note')));
    expect(xml, isNot(contains('<time>')));
    expect(xml, isNot(contains('<ele>')));

    final file = RouteSafeFileRef(
      token: 'export-token',
      displayName: 'recharge-route.gpx',
      sizeBytes: bytes.length,
      mediaType: 'application/gpx+xml',
    );
    final inspection = const RouteGpxInspector(
      config: RouteGpxImportConfig(),
    ).inspect(file: file, bytes: bytes);
    expect(inspection.candidates.single.pointCount, 3);
    expect(inspection.waypoints, hasLength(1));
    expect(inspection.containsPrivateMetadata, isTrue);
  });
}
