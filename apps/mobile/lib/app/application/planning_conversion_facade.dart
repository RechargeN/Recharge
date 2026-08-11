import '../../features/create/application/create_runtime_defaults.dart';
import '../../features/create/application/quick_plan_conversion_coordinator.dart';
import '../../features/create/application/scenario_conversion_handoff_store.dart';
import '../../features/create/data/datasources/quick_plan_conversion_memory_datasource.dart';
import '../../features/scenarios/domain/entities/scenario_draft_entity.dart';
import '../adapters/legacy_quick_plan_conversion_adapter.dart';

class ExpandLegacyQuickPlanRequest {
  const ExpandLegacyQuickPlanRequest({
    required this.draft,
    required this.selectedStopIds,
    required this.copyPrivateNotes,
    required this.requesterId,
    required this.requesterEmail,
    required this.requesterName,
    required this.scenarioTitle,
    this.continueWithLatestSnapshot = false,
  });

  final ScenarioDraftEntity draft;
  final Set<String> selectedStopIds;
  final bool copyPrivateNotes;
  final String requesterId;
  final String requesterEmail;
  final String requesterName;
  final String scenarioTitle;
  final bool continueWithLatestSnapshot;
}

class PlanningConversionOutcome {
  const PlanningConversionOutcome({
    required this.handoffId,
    required this.requiresRevisionConfirmation,
  });

  final String? handoffId;
  final bool requiresRevisionConfirmation;

  bool get succeeded => handoffId != null;
}

/// App-level boundary between the legacy Quick Plan surface and Create.
///
/// Feature UI submits intent here and never handles Create draft types or
/// conversion storage directly.
class PlanningConversionFacade {
  const PlanningConversionFacade({
    required LegacyQuickPlanConversionAdapter adapter,
    required InMemoryQuickPlanConversionSource source,
    required QuickPlanConversionCoordinator coordinator,
    required ScenarioConversionHandoffStore handoffStore,
    required CreateRuntimeDefaults runtimeDefaults,
  }) : _adapter = adapter,
       _source = source,
       _coordinator = coordinator,
       _handoffStore = handoffStore,
       _runtimeDefaults = runtimeDefaults;

  final LegacyQuickPlanConversionAdapter _adapter;
  final InMemoryQuickPlanConversionSource _source;
  final QuickPlanConversionCoordinator _coordinator;
  final ScenarioConversionHandoffStore _handoffStore;
  final CreateRuntimeDefaults _runtimeDefaults;

  Future<PlanningConversionOutcome> expand(
    ExpandLegacyQuickPlanRequest request,
  ) async {
    final snapshot = _adapter.toSnapshot(
      draft: request.draft,
      ownerId: request.requesterId,
      title: request.scenarioTitle,
      timezoneId: _runtimeDefaults.timezone,
      currencyCode: _runtimeDefaults.currency,
    );
    if (!request.continueWithLatestSnapshot) {
      _source.put(snapshot);
    }

    final QuickPlanConversionMaterialization materialization =
        await _coordinator.expand(
          quickPlanId: snapshot.id,
          expectedQuickPlanRevision: snapshot.revision,
          selectedStopIds: request.selectedStopIds,
          copyPrivateNotes: request.copyPrivateNotes,
          requesterId: request.requesterId,
          requesterEmail: request.requesterEmail,
          requesterName: request.requesterName,
          scenarioTitle: request.scenarioTitle,
          continueWithLatestSnapshot: request.continueWithLatestSnapshot,
        );
    final converted = materialization.draft;
    return PlanningConversionOutcome(
      handoffId: converted == null ? null : _handoffStore.put(converted),
      requiresRevisionConfirmation:
          materialization.requiresRevisionConfirmation,
    );
  }
}
