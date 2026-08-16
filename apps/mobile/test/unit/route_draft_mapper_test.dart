import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/data/models/route_draft_mapper.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/route_draft_data.dart';

import '../support/route_domain_fixtures.dart';

void main() {
  group('RouteDraftMapper', () {
    test('round-trips every canonical Route section', () {
      final source = routeFixture(revision: 4);

      final json = RouteDraftMapper.toJson(source);
      final restored = RouteDraftMapper.fromJson(json);
      final restoredJson = RouteDraftMapper.toJson(restored);

      expect(restored.revision, 4);
      expect(restored.geometryRevision, source.geometryRevision);
      expect(restored.shape, source.shape);
      expect(restored.profile.id, source.profile.id);
      expect(restored.anchors.length, source.anchors.length);
      expect(
        restored.segments.single.geometry.geometryHash,
        source.segments.single.geometry.geometryHash,
      );
      expect(
        restored.waypoints.single.segmentId,
        source.waypoints.single.segmentId,
      );
      expect(restored.metrics.distanceMeters, source.metrics.distanceMeters);
      expect(restoredJson, json);
    });

    test('round-trips an optional segment profile override', () {
      const override = RouteProfileRef(id: 'hiking', version: 3);
      final base = routeFixture();
      final source = base.copyWith(
        segments: <RouteSegmentDraft>[
          base.segments.single.copyWith(profileOverride: override),
        ],
      );

      final restored = RouteDraftMapper.fromJson(
        RouteDraftMapper.toJson(source),
      );

      expect(restored.segments.single.profileOverride?.id, 'hiking');
      expect(restored.segments.single.profileOverride?.version, 3);
    });

    test('preserves unknown root and nested fields across known writes', () {
      final json = RouteDraftMapper.toJson(routeFixture());
      json['futureRoot'] = <String, Object?>{'enabled': true};
      final segments = json['segments']! as List<Object?>;
      final firstSegment = segments.first! as Map<String, Object?>;
      firstSegment['futureSegmentField'] = 'keep-me';
      final geometry = firstSegment['geometry']! as Map<String, Object?>;
      geometry['futureGeometryField'] = 42;

      final restored = RouteDraftMapper.fromJson(json).nextRevision();
      final encoded = RouteDraftMapper.toJson(restored);
      final encodedSegment =
          (encoded['segments']! as List<Object?>).first!
              as Map<String, Object?>;
      final encodedGeometry =
          encodedSegment['geometry']! as Map<String, Object?>;

      expect(encoded['futureRoot'], <String, Object?>{'enabled': true});
      expect(encodedSegment['futureSegmentField'], 'keep-me');
      expect(encodedGeometry['futureGeometryField'], 42);
      expect(encoded['revision'], 1);
    });

    test('rejects future major schema and malformed required fields', () {
      final future = RouteDraftMapper.toJson(routeFixture())
        ..['schemaVersion'] = RouteDraftData.currentSchemaVersion + 1;
      final malformed = RouteDraftMapper.toJson(routeFixture())
        ..remove('segments');

      expect(
        () => RouteDraftMapper.fromJson(future),
        throwsA(isA<UnsupportedRouteSchemaException>()),
      );
      expect(
        () => RouteDraftMapper.fromJson(malformed),
        throwsA(isA<RouteDraftFormatException>()),
      );
    });
  });

  group('Create envelope v9', () {
    test('stores typed routeData without runtime geometry duplication', () {
      final route = routeFixture(revision: 2);
      final draft =
          CreateDraftEntity.defaults(
            organizerId: 'user-1',
            organizerEmail: 'owner@example.test',
            organizerName: 'Owner',
          ).copyWith(
            objectType: CreateObjectType.route,
            clearEventData: true,
            routeData: route,
            sectionData: const <String, Object?>{
              'route_map': {'expanded': true},
            },
          );

      final model = CreateDraftModel.fromEntity(draft);
      final restored = model.toEntity();

      expect(model.schemaVersion, 9);
      expect(model.sectionData['route_details'], isA<Map>());
      expect(restored.routeData?.revision, 2);
      expect(restored.sectionData.containsKey('route_details'), isFalse);
      expect(restored.sectionData['route_map'], <String, Object?>{
        'expanded': true,
      });
    });

    test('keeps an unsupported payload recoverable and opaque', () {
      final draft =
          CreateDraftEntity.defaults(
            organizerId: 'user-1',
            organizerEmail: 'owner@example.test',
            organizerName: 'Owner',
          ).copyWith(
            objectType: CreateObjectType.route,
            clearEventData: true,
            routeData: routeFixture(),
          );
      final json = CreateDraftModel.fromEntity(draft).toJson();
      final sections = json['sectionData']! as Map<String, dynamic>;
      final routeJson = sections['route_details']! as Map<String, Object?>;
      routeJson['schemaVersion'] = 999;
      routeJson['futurePayload'] = 'untouched';

      final restored = CreateDraftModel.fromJson(
        json,
        activeCurrency: 'EUR',
      ).toEntity();

      expect(restored.routeData, isNull);
      expect(
        (restored.sectionData['route_details']! as Map)['futurePayload'],
        'untouched',
      );
      expect(
        CreateDraftModel.fromEntity(restored).sectionData['route_details'],
        routeJson,
      );
    });
  });

  test('replaces temporary Route ids and every relation consistently', () {
    final first = routeAnchor('loc_a', 56.94, 24.10);
    final second = routeAnchor('loc_b', 56.95, 24.11);
    final segment = routeSegment(
      id: 'loc_segment',
      order: 0,
      from: first,
      to: second,
    );
    final source = routeFixture(
      anchors: <RouteAnchorDraft>[first, second],
      segments: <RouteSegmentDraft>[segment],
      waypoints: <RouteWaypointDraft>[
        RouteWaypointDraft(
          id: 'loc_waypoint',
          anchorId: first.id,
          segmentId: segment.id,
          position: first.position,
          typeId: 'start.v1',
          trackState: RouteWaypointTrackState.onTrack,
          distanceFromStartMeters: 0,
          distanceFromTrackMeters: 0,
        ),
      ],
    );
    var sequence = 0;

    final replaced = source.replaceLocalIds(() => '01PERM${sequence++}');

    expect(
      replaced.nestedIds.any((String id) => id.startsWith('loc_')),
      isFalse,
    );
    expect(replaced.segments.single.fromAnchorId, replaced.anchors.first.id);
    expect(replaced.segments.single.toAnchorId, replaced.anchors.last.id);
    expect(replaced.waypoints.single.anchorId, replaced.anchors.first.id);
    expect(replaced.waypoints.single.segmentId, replaced.segments.single.id);
  });
}
