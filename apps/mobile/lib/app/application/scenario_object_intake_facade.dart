import '../../core/id/id_generator.dart';
import '../../features/create/application/create_runtime_defaults.dart';
import '../../features/create/application/scenario_create_coordinator.dart';
import '../../features/create/domain/entities/create_draft_entity.dart';
import '../../features/create/domain/entities/scenario_draft_data.dart';
import '../../features/create/domain/entities/scenario_item_draft.dart';
import '../../features/create/domain/entities/scenario_object_intake.dart';
import '../../features/create/domain/entities/scenario_object_intake_session.dart';
import '../../features/create/domain/repositories/create_draft_collection_repository.dart';
import '../../features/create/domain/repositories/scenario_object_intake_intent_repository.dart';
import 'scenario_object_intake_config.dart';

typedef ScenarioObjectIntakeClock = DateTime Function();

enum ScenarioObjectIntakeApplyStatus { applied, rejected, persistenceFailed }

class ScenarioObjectIntakeApplyOutcome {
  const ScenarioObjectIntakeApplyOutcome({
    required this.status,
    this.failure,
    this.targetDraftId,
    this.targetRevision,
    this.createdItemCount = 0,
    this.replayed = false,
  });

  final ScenarioObjectIntakeApplyStatus status;
  final ScenarioIntakeFailure? failure;
  final String? targetDraftId;
  final int? targetRevision;
  final int createdItemCount;
  final bool replayed;

  bool get succeeded => status == ScenarioObjectIntakeApplyStatus.applied;
}

class ScenarioObjectIntakeFacade {
  ScenarioObjectIntakeFacade({
    required ScenarioObjectIntakeIntentRepository intentRepository,
    required CreateDraftCollectionRepository collectionRepository,
    required ScenarioCreateCoordinator scenarioCoordinator,
    required CreateRuntimeDefaults runtimeDefaults,
    required IdGenerator idGenerator,
    ScenarioObjectIntakeClock? clock,
    ScenarioObjectIntakeConfig config = const ScenarioObjectIntakeConfig(),
  }) : _intentRepository = intentRepository,
       _collectionRepository = collectionRepository,
       _scenarioCoordinator = scenarioCoordinator,
       _runtimeDefaults = runtimeDefaults,
       _idGenerator = idGenerator,
       _clock = clock ?? _utcNow,
       config = config.validated();

  final ScenarioObjectIntakeIntentRepository _intentRepository;
  final CreateDraftCollectionRepository _collectionRepository;
  final ScenarioCreateCoordinator _scenarioCoordinator;
  final CreateRuntimeDefaults _runtimeDefaults;
  final IdGenerator _idGenerator;
  final ScenarioObjectIntakeClock _clock;
  final ScenarioObjectIntakeConfig config;

  Duration get intentTtl => config.intentTtl;

  Future<List<CreateDraftSummary>> begin(
    ScenarioObjectIntakeIntent intent,
  ) async {
    if (!config.allowsIntent(intent)) {
      throw StateError('Scenario object intake is disabled.');
    }
    final now = _clock().toUtc();
    await _intentRepository.put(
      ScenarioObjectIntakeSession(
        schemaVersion: ScenarioObjectIntakeSession.currentSchemaVersion,
        intent: intent,
        createdAtUtc: now,
        expiresAtUtc: now.add(intentTtl),
        status: ScenarioObjectIntakeSessionStatus.pending,
      ),
    );
    return listTargets(intent.requesterId);
  }

  Future<List<CreateDraftSummary>> listTargets(String ownerId) =>
      _collectionRepository.listDrafts(
        ownerId: ownerId,
        type: CreateObjectType.scenario,
      );

  Future<CreateDraftEntity?> loadTarget({
    required String ownerId,
    required String targetDraftId,
  }) => _collectionRepository.loadDraftById(
    ownerId: ownerId,
    draftId: targetDraftId,
  );

  CreateDraftEntity materializeNewTarget({
    required ScenarioObjectIntakeIntent intent,
    required String organizerEmail,
    required String organizerName,
    required String title,
  }) {
    if (!config.enabled || !config.createNewTargetEnabled) {
      throw StateError('Creating a new Scenario target is disabled.');
    }
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw const FormatException('Scenario title is required.');
    }
    final sourceRef = intent.candidates.first.ref;
    final originType = switch (intent.sourceSurface) {
      ScenarioIntakeSourceSurface.details => ScenarioOriginType.details,
      ScenarioIntakeSourceSurface.search => ScenarioOriginType.search,
      ScenarioIntakeSourceSurface.map => ScenarioOriginType.mapSelection,
    };
    final scenario = _scenarioCoordinator
        .initial(
          timezoneId: _runtimeDefaults.timezone,
          currencyCode: _runtimeDefaults.currency,
        )
        .copyWith(
          origin: ScenarioOriginDraft(
            type: originType,
            sourceId:
                intent.sourceSurface == ScenarioIntakeSourceSurface.details
                ? sourceRef.objectId
                : null,
          ),
        );
    return CreateDraftEntity.defaults(
      organizerId: intent.requesterId,
      organizerEmail: organizerEmail,
      organizerName: organizerName,
      marketCityId: _runtimeDefaults.marketCityId,
      timezone: _runtimeDefaults.timezone,
      country: _runtimeDefaults.country,
      city: _runtimeDefaults.city,
      currency: _runtimeDefaults.currency,
    ).copyWith(
      id: _idGenerator.generate(),
      objectType: CreateObjectType.scenario,
      title: normalizedTitle,
      clearEventData: true,
      scenarioData: scenario,
      visibility: VisibilityType.private,
    );
  }

  Future<ScenarioObjectIntakeApplyOutcome> apply({
    required String ownerId,
    required String intentId,
    required CreateDraftEntity targetDraft,
    required String? dayId,
    required String? afterItemId,
    required List<ScenarioObjectRef> orderedRefs,
    required Map<ScenarioObjectRef, ScenarioItemRole> roles,
    required Set<ScenarioObjectRef> confirmedDuplicates,
    required Set<ScenarioObjectRef> confirmedUnavailable,
    required Set<ScenarioObjectRef> confirmedScheduleAdjustments,
  }) async {
    if (!config.enabled) {
      return const ScenarioObjectIntakeApplyOutcome(
        status: ScenarioObjectIntakeApplyStatus.rejected,
        failure: ScenarioIntakeFailure.targetUnavailable,
      );
    }
    ScenarioObjectIntakeSession? session;
    try {
      session = await _intentRepository.load(
        ownerId: ownerId,
        intentId: intentId,
      );
    } on Object {
      return const ScenarioObjectIntakeApplyOutcome(
        status: ScenarioObjectIntakeApplyStatus.persistenceFailed,
        failure: ScenarioIntakeFailure.persistenceUnavailable,
      );
    }
    if (session == null || session.isExpiredAt(_clock().toUtc())) {
      return const ScenarioObjectIntakeApplyOutcome(
        status: ScenarioObjectIntakeApplyStatus.rejected,
        failure: ScenarioIntakeFailure.intentExpired,
      );
    }
    if (session.intent.requesterId != ownerId) {
      return const ScenarioObjectIntakeApplyOutcome(
        status: ScenarioObjectIntakeApplyStatus.rejected,
        failure: ScenarioIntakeFailure.accessDenied,
      );
    }
    if (!config.allowsIntent(session.intent)) {
      return const ScenarioObjectIntakeApplyOutcome(
        status: ScenarioObjectIntakeApplyStatus.rejected,
        failure: ScenarioIntakeFailure.targetUnavailable,
      );
    }
    if (session.status == ScenarioObjectIntakeSessionStatus.consumed) {
      return ScenarioObjectIntakeApplyOutcome(
        status: ScenarioObjectIntakeApplyStatus.applied,
        targetDraftId: session.consumedTargetDraftId,
        targetRevision: session.consumedTargetRevision,
        replayed: true,
      );
    }

    final scenario = targetDraft.scenarioData;
    if (scenario == null) {
      return const ScenarioObjectIntakeApplyOutcome(
        status: ScenarioObjectIntakeApplyStatus.rejected,
        failure: ScenarioIntakeFailure.targetNotScenario,
      );
    }
    final mutation = _scenarioCoordinator.applyObjectIntake(
      ApplyScenarioObjectIntakeRequest(
        intent: session.intent,
        targetDraft: targetDraft,
        targetCreateDraftId: targetDraft.id,
        expectedScenarioRevision: scenario.revision,
        placement: ScenarioIntakePlacement(
          dayId: dayId,
          afterItemId: afterItemId,
          orderedRefs: orderedRefs,
          roles: roles,
          confirmedDuplicates: confirmedDuplicates,
          confirmedUnavailable: confirmedUnavailable,
          confirmedScheduleAdjustments: confirmedScheduleAdjustments,
        ),
      ),
    );
    if (mutation is ScenarioIntakeRejected) {
      return ScenarioObjectIntakeApplyOutcome(
        status: ScenarioObjectIntakeApplyStatus.rejected,
        failure: mutation.failure,
        targetDraftId: targetDraft.id,
        targetRevision: mutation.currentTargetRevision,
      );
    }
    final applied = mutation as ScenarioIntakeApplied;
    CreateDraftCollectionSaveResult saved;
    try {
      saved = await _collectionRepository.saveIfRevision(
        ownerId: ownerId,
        draft: applied.draft,
        expectedScenarioRevision: scenario.revision,
        idempotencyKey: intentId,
      );
    } on Object {
      return const ScenarioObjectIntakeApplyOutcome(
        status: ScenarioObjectIntakeApplyStatus.persistenceFailed,
        failure: ScenarioIntakeFailure.persistenceUnavailable,
      );
    }
    if (saved.status == CreateDraftCollectionSaveStatus.conflict) {
      return ScenarioObjectIntakeApplyOutcome(
        status: ScenarioObjectIntakeApplyStatus.rejected,
        failure: ScenarioIntakeFailure.revisionConflict,
        targetDraftId: targetDraft.id,
        targetRevision: saved.persistedRevision,
      );
    }
    if (saved.status != CreateDraftCollectionSaveStatus.saved &&
        saved.status != CreateDraftCollectionSaveStatus.replayed) {
      return const ScenarioObjectIntakeApplyOutcome(
        status: ScenarioObjectIntakeApplyStatus.persistenceFailed,
        failure: ScenarioIntakeFailure.persistenceUnavailable,
      );
    }
    final persistedRevision = saved.persistedRevision ?? applied.targetRevision;
    try {
      await _intentRepository.markConsumed(
        ownerId: ownerId,
        intentId: intentId,
        targetDraftId: targetDraft.id,
        targetRevision: persistedRevision,
      );
    } on Object {
      // The collection receipt remains authoritative for a safe retry.
    }
    return ScenarioObjectIntakeApplyOutcome(
      status: ScenarioObjectIntakeApplyStatus.applied,
      targetDraftId: targetDraft.id,
      targetRevision: persistedRevision,
      createdItemCount: applied.createdItemIds.length,
      replayed: saved.status == CreateDraftCollectionSaveStatus.replayed,
    );
  }

  Future<void> discard({required String ownerId, required String intentId}) =>
      _intentRepository.discard(ownerId: ownerId, intentId: intentId);

  static DateTime _utcNow() => DateTime.now().toUtc();
}
