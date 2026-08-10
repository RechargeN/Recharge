import '../entities/create_draft_entity.dart';
import '../entities/scenario_draft_data.dart';
import '../entities/scenario_item_draft.dart';

class CreateDraftSummary {
  const CreateDraftSummary({
    required this.id,
    required this.objectType,
    required this.title,
    required this.updatedAtUtc,
    this.scenarioRevision,
    this.scenarioFormat,
    this.scenarioDateMode,
    this.scenarioDayCount,
    this.scenarioActiveItemCount,
    this.scenarioFirstDate,
    this.scenarioLastDate,
  });

  final String id;
  final CreateObjectType objectType;
  final String title;
  final DateTime updatedAtUtc;
  final int? scenarioRevision;
  final ScenarioFormat? scenarioFormat;
  final ScenarioDateMode? scenarioDateMode;
  final int? scenarioDayCount;
  final int? scenarioActiveItemCount;
  final ScenarioLocalDateDraft? scenarioFirstDate;
  final ScenarioLocalDateDraft? scenarioLastDate;
}

enum CreateDraftCollectionSaveStatus {
  saved,
  replayed,
  conflict,
  invalidDraft,
  invalidExistingData,
}

class CreateDraftCollectionSaveResult {
  const CreateDraftCollectionSaveResult({
    required this.status,
    this.persistedRevision,
  });

  final CreateDraftCollectionSaveStatus status;
  final int? persistedRevision;
}

abstract interface class CreateDraftCollectionRepository {
  Future<List<CreateDraftSummary>> listDrafts({
    required String ownerId,
    required CreateObjectType type,
  });

  Future<CreateDraftEntity?> loadDraftById({
    required String ownerId,
    required String draftId,
  });

  Future<CreateDraftCollectionSaveResult> saveIfRevision({
    required String ownerId,
    required CreateDraftEntity draft,
    required int expectedScenarioRevision,
    required String idempotencyKey,
  });
}
