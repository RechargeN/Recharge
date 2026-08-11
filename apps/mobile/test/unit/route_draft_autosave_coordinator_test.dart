import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/route_draft_autosave_coordinator.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/route_draft_save_result.dart';
import 'package:recharge/features/create/domain/repositories/route_draft_persistence_repository.dart';

import '../support/route_domain_fixtures.dart';

void main() {
  CreateDraftEntity draftAt(int revision) =>
      CreateDraftEntity.defaults(
        organizerId: 'user-1',
        organizerEmail: 'owner@example.test',
        organizerName: 'Owner',
      ).copyWith(
        id: '01ROUTEDRAFT000000000000001',
        objectType: CreateObjectType.route,
        clearEventData: true,
        routeData: routeFixture(revision: revision),
      );

  test('queues accepted revisions in request order', () async {
    final repository = _RecordingRouteRepository();
    final coordinator = RouteDraftAutosaveCoordinator(repository);

    final first = coordinator.save(
      userId: 'user-1',
      draft: draftAt(1),
      expectedRevision: 0,
    );
    final second = coordinator.save(
      userId: 'user-1',
      draft: draftAt(2),
      expectedRevision: 1,
    );

    expect((await first).isSaved, isTrue);
    expect((await second).isSaved, isTrue);
    expect(repository.savedRevisions, <int>[1, 2]);
  });

  test(
    'rejects an older request after a newer revision was accepted',
    () async {
      final repository = _RecordingRouteRepository();
      final coordinator = RouteDraftAutosaveCoordinator(repository);

      await coordinator.save(
        userId: 'user-1',
        draft: draftAt(3),
        expectedRevision: 2,
      );
      final stale = await coordinator.save(
        userId: 'user-1',
        draft: draftAt(2),
        expectedRevision: 1,
      );

      expect(stale.status, RouteDraftSaveStatus.superseded);
      expect(repository.savedRevisions, <int>[3]);
    },
  );

  test('does not send a non-Route draft to persistence', () async {
    final repository = _RecordingRouteRepository();
    final coordinator = RouteDraftAutosaveCoordinator(repository);
    final invalid = CreateDraftEntity.defaults(
      organizerId: 'user-1',
      organizerEmail: 'owner@example.test',
      organizerName: 'Owner',
    );

    final result = await coordinator.save(
      userId: 'user-1',
      draft: invalid,
      expectedRevision: null,
    );

    expect(result.status, RouteDraftSaveStatus.invalidDraft);
    expect(repository.savedRevisions, isEmpty);
  });

  test('allows retrying the same revision after a CAS conflict', () async {
    final repository = _ConflictOnceRouteRepository();
    final coordinator = RouteDraftAutosaveCoordinator(repository);

    final conflict = await coordinator.save(
      userId: 'user-1',
      draft: draftAt(4),
      expectedRevision: 2,
    );
    final retry = await coordinator.save(
      userId: 'user-1',
      draft: draftAt(4),
      expectedRevision: 3,
    );

    expect(conflict.status, RouteDraftSaveStatus.conflict);
    expect(retry.status, RouteDraftSaveStatus.saved);
    expect(repository.calls, 2);
  });

  test('waitForIdle waits for the last queued repository write', () async {
    final repository = _BlockingRouteRepository();
    final coordinator = RouteDraftAutosaveCoordinator(repository);
    final save = coordinator.save(
      userId: 'user-1',
      draft: draftAt(5),
      expectedRevision: 4,
    );
    var idleCompleted = false;
    final idle = coordinator.waitForIdle().then((_) {
      idleCompleted = true;
    });

    await Future<void>.delayed(Duration.zero);
    expect(idleCompleted, isFalse);

    repository.complete();
    expect((await save).isSaved, isTrue);
    await idle;
    expect(idleCompleted, isTrue);
  });
}

class _RecordingRouteRepository implements RouteDraftPersistenceRepository {
  final List<int> savedRevisions = <int>[];

  @override
  Future<RouteDraftSaveResult> saveRouteDraft({
    required String userId,
    required CreateDraftEntity draft,
    required int? expectedRevision,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final revision = draft.routeData!.revision;
    savedRevisions.add(revision);
    return RouteDraftSaveResult(
      status: RouteDraftSaveStatus.saved,
      requestedRevision: revision,
      persistedRevision: revision,
    );
  }
}

class _ConflictOnceRouteRepository implements RouteDraftPersistenceRepository {
  int calls = 0;

  @override
  Future<RouteDraftSaveResult> saveRouteDraft({
    required String userId,
    required CreateDraftEntity draft,
    required int? expectedRevision,
  }) async {
    calls += 1;
    return RouteDraftSaveResult(
      status: calls == 1
          ? RouteDraftSaveStatus.conflict
          : RouteDraftSaveStatus.saved,
      requestedRevision: draft.routeData!.revision,
      persistedRevision: calls == 1 ? 3 : 4,
    );
  }
}

class _BlockingRouteRepository implements RouteDraftPersistenceRepository {
  final Completer<void> _release = Completer<void>();

  void complete() => _release.complete();

  @override
  Future<RouteDraftSaveResult> saveRouteDraft({
    required String userId,
    required CreateDraftEntity draft,
    required int? expectedRevision,
  }) async {
    await _release.future;
    final revision = draft.routeData!.revision;
    return RouteDraftSaveResult(
      status: RouteDraftSaveStatus.saved,
      requestedRevision: revision,
      persistedRevision: revision,
    );
  }
}
