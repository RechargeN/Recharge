import '../domain/entities/create_draft_entity.dart';
import '../domain/entities/route_draft_save_result.dart';
import '../domain/repositories/route_draft_persistence_repository.dart';

class RouteDraftAutosaveCoordinator {
  RouteDraftAutosaveCoordinator(this._repository);

  final RouteDraftPersistenceRepository _repository;
  final Map<String, int> _latestRequestedRevision = <String, int>{};
  final Map<String, RouteDraftSaveStatus> _latestOutcomes =
      <String, RouteDraftSaveStatus>{};
  final Map<String, Future<void>> _queues = <String, Future<void>>{};

  Future<RouteDraftSaveResult> save({
    required String userId,
    required CreateDraftEntity draft,
    required int? expectedRevision,
  }) {
    final route = draft.routeData;
    if (draft.objectType != CreateObjectType.route || route == null) {
      return Future<RouteDraftSaveResult>.value(
        RouteDraftSaveResult(
          status: RouteDraftSaveStatus.invalidDraft,
          requestedRevision: route?.revision ?? -1,
        ),
      );
    }

    final key = '$userId:${draft.id}';
    final latest = _latestRequestedRevision[key];
    final sameRevisionAlreadyFinal =
        latest == route.revision &&
        (_queues.containsKey(key) ||
            _latestOutcomes[key] == RouteDraftSaveStatus.saved);
    if (latest != null &&
        (route.revision < latest || sameRevisionAlreadyFinal)) {
      return Future<RouteDraftSaveResult>.value(
        RouteDraftSaveResult(
          status: RouteDraftSaveStatus.superseded,
          requestedRevision: route.revision,
          persistedRevision: latest,
        ),
      );
    }
    _latestRequestedRevision[key] = route.revision;

    final result = <RouteDraftSaveResult>[];
    final previous = _queues[key] ?? Future<void>.value();
    final operation = previous.catchError((Object _) {}).then((_) async {
      result.add(
        await _repository.saveRouteDraft(
          userId: userId,
          draft: draft,
          expectedRevision: expectedRevision,
        ),
      );
      _latestOutcomes[key] = result.single.status;
    });
    _queues[key] = operation;

    return operation.then((_) {
      if (identical(_queues[key], operation)) {
        _queues.remove(key);
      }
      return result.single;
    });
  }

  Future<void> waitForIdle() async {
    while (_queues.isNotEmpty) {
      await Future.wait<void>(List<Future<void>>.of(_queues.values));
    }
  }
}
