import '../../features/create/domain/entities/create_draft_entity.dart';
import '../../features/create/domain/repositories/create_draft_collection_repository.dart';
import '../di/service_locator.dart';

ScenarioLibraryFacade? scenarioLibraryFacadeOrNull() {
  if (!sl.isRegistered<CreateDraftCollectionRepository>()) return null;
  return ScenarioLibraryFacade(sl<CreateDraftCollectionRepository>());
}

class ScenarioLibraryItem {
  const ScenarioLibraryItem({
    required this.id,
    required this.title,
    required this.completed,
    required this.updatesEnabled,
  });

  final String id;
  final String title;
  final bool completed;
  final bool updatesEnabled;
}

/// App-level boundary used by Profile without coupling Explore to Create.
class ScenarioLibraryFacade {
  const ScenarioLibraryFacade(this._repository);

  final CreateDraftCollectionRepository _repository;

  Future<List<ScenarioLibraryItem>> list({
    required String ownerId,
    required DateTime nowUtc,
  }) async {
    final drafts = await _repository.listDrafts(
      ownerId: ownerId,
      type: CreateObjectType.scenario,
    );
    return drafts
        .map(
          (draft) => ScenarioLibraryItem(
            id: draft.id,
            title: draft.title,
            completed: draft.isCompletedOn(nowUtc),
            updatesEnabled: draft.scenarioUpdatesEnabled ?? true,
          ),
        )
        .toList(growable: false);
  }

  Future<bool> setUpdatesEnabled({
    required String ownerId,
    required String scenarioDraftId,
    required bool enabled,
  }) async {
    final draft = await _repository.loadDraftById(
      ownerId: ownerId,
      draftId: scenarioDraftId,
    );
    final scenario = draft?.scenarioData;
    if (draft == null || scenario == null) return false;
    final result = await _repository.saveIfRevision(
      ownerId: ownerId,
      draft: draft.copyWith(
        scenarioData: scenario.copyWith(
          revision: scenario.revision + 1,
          updatesEnabled: enabled,
        ),
        updatedAtUtc: DateTime.now().toUtc(),
      ),
      expectedScenarioRevision: scenario.revision,
      idempotencyKey:
          'scenario-updates:$scenarioDraftId:${scenario.revision}:$enabled',
    );
    return result.status == CreateDraftCollectionSaveStatus.saved ||
        result.status == CreateDraftCollectionSaveStatus.replayed;
  }
}
