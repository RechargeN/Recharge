import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/geo/geo_point.dart';
import 'package:recharge/features/create/data/repositories/route_sync_client.dart';
import 'package:recharge/features/create/domain/entities/route_draft_data.dart';
import 'package:recharge/features/create/domain/entities/route_sync_data.dart';
import 'package:recharge/features/create/domain/repositories/route_sync_repository.dart';

import '../support/route_domain_fixtures.dart';

const _ownerA = '00000000-0000-4000-8000-00000000000a';
const _ownerB = '00000000-0000-4000-8000-00000000000b';

/// Minimal stand-in for the callable pair: CAS, receipts by key, owner scope.
/// Server rules themselves are proven against the Emulator, not here.
class _FakeServer {
  final Map<String, Map<String, Object?>> routes = {};
  final Map<String, Map<String, Object?>> receipts = {};
  final List<Map<String, Object?>> commands = [];
  bool offline = false;
  bool loseNextAnswer = false;
  String? sessionOwner = _ownerA;

  Future<Map<String, Object?>> invoke(
    String surface,
    Map<String, Object?> request,
  ) async {
    if (offline) throw const RouteSyncFailure('unavailable');
    final owner = sessionOwner;
    if (owner == null) {
      return {
        'schemaVersion': 1,
        'kind': 'rejected',
        'code': 'unauthenticated',
      };
    }
    if (surface == 'routeQueryV1') {
      final route = routes['$owner:${request['routeId']}'];
      return {
        'schemaVersion': 1,
        'kind': 'succeeded',
        'ownerId': owner,
        'entry': route,
      };
    }
    commands.add(request);
    if (request['ownerContext'] != owner) {
      return {'schemaVersion': 1, 'kind': 'rejected', 'code': 'owner_changed'};
    }
    final key = '$owner:${request['idempotencyKey']}';
    final result = receipts[key] ??= _apply(owner, request);
    if (loseNextAnswer) {
      loseNextAnswer = false;
      throw const RouteSyncFailure('deadline-exceeded');
    }
    return result;
  }

  Map<String, Object?> _apply(String owner, Map<String, Object?> c) {
    final id = '$owner:${c['routeId']}';
    final current = routes[id];
    final revision = (current?['revision'] as int?) ?? 0;
    if (current?['status'] == 'deleted') {
      return {'schemaVersion': 1, 'kind': 'rejected', 'code': 'deleted'};
    }
    if (c['commandType'] != 'delete' && c['expectedRevision'] != revision) {
      return {
        'schemaVersion': 1,
        'kind': 'rejected',
        'code': 'revision_conflict',
        'serverRevision': revision,
      };
    }
    routes[id] = {
      'routeId': c['routeId'],
      'revision': revision + 1,
      'status': c['commandType'] == 'delete' ? 'deleted' : 'active',
      'updatedAtUtc': '2026-10-20T00:00:00.000Z',
      if (c['commandType'] != 'delete')
        'route': c['route'] ?? current?['route'],
      if (c['commandType'] != 'delete')
        'privacyTrim': c['privacyTrim'] ?? current?['privacyTrim'],
    };
    return {
      'schemaVersion': 1,
      'kind': 'succeeded',
      'routeId': c['routeId'],
      'revision': revision + 1,
    };
  }
}

RouteDraftData _route(double shift) {
  final from = routeAnchor('loc_a', 56.9496, 24.1052 + shift);
  final to = routeAnchor('loc_b', 56.9520, 24.1150 + shift);
  return routeFixture(
    anchors: [from, to],
    segments: [routeSegment(id: 'loc_s', order: 0, from: from, to: to)],
    waypoints: const <RouteWaypointDraft>[],
  );
}

void main() {
  late _FakeServer server;
  late String? owner;
  RouteSyncClient client({int limit = 2 * 1024 * 1024}) => RouteSyncClient(
    invoke: server.invoke,
    storage: const FlutterSecureStorage(),
    installationId: 'install-1',
    currentOwner: () => owner,
    journalByteLimit: limit,
  );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    server = _FakeServer();
    owner = _ownerA;
  });

  test(
    'the intent is durable before dispatch and replays after restart',
    () async {
      final first = client();
      server.offline = true;
      await expectLater(
        first.save(
          localDraftId: 'loc_draft',
          title: 'Walk',
          route: _route(0),
          expectedRevision: 0,
        ),
        throwsA(isA<RouteSyncFailure>()),
      );
      final routeId = first.routeIdFor('loc_draft')!;
      expect(first.hasPending(routeId), isTrue);
      expect(server.commands, isEmpty);
      // Process restart: a new client over the same encrypted storage.
      server.offline = false;
      final second = client();
      await second.restore();
      expect(second.routeIdFor('loc_draft'), routeId);
      await second.flush();
      expect(server.commands, hasLength(1));
      expect(second.cached(routeId)!.revision, 1);
      expect(second.hasPending(routeId), isFalse);
    },
  );

  test(
    'a lost answer is replayed under the same key without a duplicate',
    () async {
      final c = client();
      server.loseNextAnswer = true;
      await expectLater(
        c.save(
          localDraftId: 'loc_draft',
          title: 'Walk',
          route: _route(0),
          expectedRevision: 0,
        ),
        throwsA(isA<RouteSyncFailure>()),
      );
      final routeId = c.routeIdFor('loc_draft')!;
      expect(c.hasPending(routeId), isTrue);
      await c.flush();
      expect(server.commands, hasLength(2));
      expect(
        server.commands.map((cmd) => cmd['idempotencyKey']).toSet(),
        hasLength(1),
      );
      expect(
        server.commands[0]['requestId'],
        isNot(server.commands[1]['requestId']),
      );
      expect(server.routes.values.single['revision'], 1);
      // Saving the very same payload again is the same intent.
      await c.save(
        localDraftId: 'loc_draft',
        title: 'Walk',
        route: _route(0),
        expectedRevision: 0,
      );
      expect(server.routes.values.single['revision'], 1);
    },
  );

  test(
    'refused commands keep their payload until an explicit choice',
    () async {
      final c = client();
      await c.save(
        localDraftId: 'loc_draft',
        title: 'Walk',
        route: _route(0),
        expectedRevision: 0,
      );
      final routeId = c.routeIdFor('loc_draft')!;
      await c.save(
        localDraftId: 'loc_draft',
        title: 'Other device',
        route: _route(0.001),
        expectedRevision: 1,
      );
      await expectLater(
        c.save(
          localDraftId: 'loc_draft',
          title: 'Stale',
          route: _route(0.002),
          expectedRevision: 1,
        ),
        throwsA(
          isA<RouteSyncFailure>().having(
            (e) => e.code,
            'code',
            'revision_conflict',
          ),
        ),
      );
      final conflict = c.conflicts.single;
      expect(conflict.serverRevision, 2);
      expect(
        (c.conflictPayload(conflict.key)!['route'] as Map)['title'],
        'Stale',
      );
      expect(c.cached(routeId)!.title, 'Other device');
      await c.resolveConflict(conflict.key, reapplyLocal: true);
      expect(c.conflicts, isEmpty);
      expect(c.cached(routeId)!.title, 'Stale');
      expect(c.cached(routeId)!.revision, 3);
    },
  );

  test('another account never sees or sends the first owner queue', () async {
    final c = client();
    server.offline = true;
    await expectLater(
      c.setPrivacyTrim(
        routeId: '00000000-0000-4000-8000-000000000001',
        trim: const RoutePrivacyTrim(startMeters: 100, endMeters: 0),
        expectedRevision: 1,
      ),
      throwsA(isA<RouteSyncFailure>()),
    );
    expect(c.hasPending('00000000-0000-4000-8000-000000000001'), isTrue);
    // Logout and login as B: nothing of A is visible or dispatched.
    owner = _ownerB;
    server.sessionOwner = _ownerB;
    server.offline = false;
    expect(c.hasPending('00000000-0000-4000-8000-000000000001'), isFalse);
    expect(c.conflicts, isEmpty);
    await c.restore();
    await c.flush();
    expect(server.commands, isEmpty);
    // A queued command bound to A is refused if a session of B answers.
    owner = _ownerA;
    await c.restore();
    expect(c.hasPending('00000000-0000-4000-8000-000000000001'), isTrue);
    await expectLater(c.flush(), throwsA(isA<RouteSyncFailure>()));
    expect(server.commands, isEmpty);
    // Back as A with A's session: the queue resumes.
    server.sessionOwner = _ownerA;
    await expectLater(
      c.flush(),
      throwsA(
        isA<RouteSyncFailure>().having(
          (e) => e.code,
          'code',
          'revision_conflict',
        ),
      ),
    );
    expect(server.commands, hasLength(1));
  });

  test(
    'expired session keeps the queue; capacity is checked before dispatch',
    () async {
      final c = client();
      server.sessionOwner = null;
      await expectLater(
        c.save(
          localDraftId: 'loc_draft',
          title: 'Walk',
          route: _route(0),
          expectedRevision: 0,
        ),
        throwsA(
          isA<RouteSyncFailure>().having(
            (e) => e.code,
            'code',
            'unauthenticated',
          ),
        ),
      );
      expect(c.hasPending(c.routeIdFor('loc_draft')!), isTrue);
      server.sessionOwner = _ownerA;
      await c.flush();
      expect(server.routes, hasLength(1));
      final tiny = client(limit: 600);
      await expectLater(
        tiny.save(
          localDraftId: 'loc_other',
          title: 'x' * 100,
          route: _route(0),
          expectedRevision: 0,
        ),
        throwsA(
          isA<RouteSyncFailure>().having(
            (e) => e.code,
            'code',
            'journal_capacity_exceeded',
          ),
        ),
      );
      expect(server.commands, hasLength(1));
    },
  );

  test(
    'local IDs map to stable permanent IDs; unused mappings are dropped',
    () async {
      final c = client();
      await c.save(
        localDraftId: 'loc_draft',
        title: 'Walk',
        route: _route(0),
        expectedRevision: 0,
      );
      final routeId = c.routeIdFor('loc_draft')!;
      String segmentIdOnServer() =>
          ((server.routes.values.single['route']! as Map)['segments'] as List)
                  .single['segmentId']
              as String;
      final original = segmentIdOnServer();
      await c.save(
        localDraftId: 'loc_draft',
        title: 'Walk again',
        route: _route(0),
        expectedRevision: 1,
      );
      expect(segmentIdOnServer(), original);
      final edited = _route(0);
      await c.save(
        localDraftId: 'loc_draft',
        title: 'Split',
        route: edited.copyWith(
          segments: <RouteSegmentDraft>[
            edited.segments.single.copyWith(id: 'loc_split'),
          ],
        ),
        expectedRevision: 2,
      );
      expect(segmentIdOnServer(), isNot(original));
      final journal =
          jsonDecode(
                (await const FlutterSecureStorage().readAll()).values.single,
              )
              as Map;
      final nested =
          ((journal['ids'] as Map)['loc_draft'] as Map)['nested'] as Map;
      expect(nested.keys.toSet(), <String>{'loc_a', 'loc_b', 'loc_split'});
      expect(c.routeIdFor('loc_draft'), routeId);
    },
  );

  test('a server Route becomes a draft on another device by ID only', () async {
    final c = client();
    await c.save(
      localDraftId: 'loc_draft',
      title: 'Walk',
      route: _route(0),
      expectedRevision: 0,
    );
    final entry = (await c.refresh(c.routeIdFor('loc_draft')!))!;
    final restored = c.draftFrom(entry, template: _route(0.5));
    expect(
      restored.anchors.map((a) => a.id).every((id) => !id.startsWith('loc_')),
      isTrue,
    );
    expect(
      restored.anchors.first.position,
      const GeoPoint(latitude: 56.9496, longitude: 24.1052),
    );
    expect(restored.segments.single.source, RouteSegmentSource.freehand);
  });
}
