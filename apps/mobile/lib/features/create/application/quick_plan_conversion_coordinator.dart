import '../../../../core/id/id_generator.dart';
import '../domain/entities/create_availability.dart';
import '../domain/entities/create_draft_entity.dart';
import '../domain/entities/quick_plan_conversion.dart';
import '../domain/usecases/expand_quick_plan_to_scenario_usecase.dart';
import 'create_runtime_defaults.dart';

class QuickPlanConversionMaterialization {
  const QuickPlanConversionMaterialization({
    required this.draft,
    required this.issues,
    required this.sourceRevision,
  });

  final CreateDraftEntity? draft;
  final List<QuickPlanConversionIssue> issues;
  final int? sourceRevision;

  bool get succeeded => draft != null;
  bool get requiresRevisionConfirmation => issues.any(
    (QuickPlanConversionIssue issue) =>
        issue.code == QuickPlanConversionIssueCode.sourceRevisionMismatch &&
        issue.severity == QuickPlanConversionIssueSeverity.error,
  );
}

class QuickPlanConversionCoordinator {
  const QuickPlanConversionCoordinator({
    required ExpandQuickPlanToScenarioUseCase expand,
    required IdGenerator idGenerator,
    required CreateRuntimeDefaults runtimeDefaults,
  }) : _expand = expand,
       _idGenerator = idGenerator,
       _runtimeDefaults = runtimeDefaults;

  final ExpandQuickPlanToScenarioUseCase _expand;
  final IdGenerator _idGenerator;
  final CreateRuntimeDefaults _runtimeDefaults;

  Future<QuickPlanConversionMaterialization> expand({
    required String quickPlanId,
    required int expectedQuickPlanRevision,
    required Set<String> selectedStopIds,
    required bool copyPrivateNotes,
    required String requesterId,
    required String requesterEmail,
    required String requesterName,
    required String scenarioTitle,
    bool continueWithLatestSnapshot = false,
  }) async {
    final ExpandQuickPlanToScenarioResult result = await _expand(
      ExpandQuickPlanToScenarioRequest(
        quickPlanId: quickPlanId,
        expectedQuickPlanRevision: expectedQuickPlanRevision,
        selectedStopIds: selectedStopIds,
        copyPrivateNotes: copyPrivateNotes,
        requesterId: requesterId,
        continueWithLatestSnapshot: continueWithLatestSnapshot,
      ),
    );
    if (result.scenario == null) {
      return QuickPlanConversionMaterialization(
        draft: null,
        issues: result.issues,
        sourceRevision: result.sourceRevision,
      );
    }

    final Map<String, Object?> sectionData = <String, Object?>{
      'quick_plan_conversion': <String, Object?>{
        'source_id': quickPlanId,
        'source_revision': result.sourceRevision,
        'copied_stop_count': result.quickPlanStopIdToScenarioItemId.length,
        'issue_codes': result.issues
            .map((QuickPlanConversionIssue issue) => issue.code.name)
            .toList(growable: false),
      },
      if (result.privateNotesByScenarioItemId.isNotEmpty)
        'scenario_personal': <String, Object?>{
          'private_notes_by_item_id': result.privateNotesByScenarioItemId,
        },
    };
    final CreateDraftEntity draft =
        CreateDraftEntity.defaults(
          organizerId: requesterId,
          organizerEmail: requesterEmail,
          organizerName: requesterName,
          marketCityId: _runtimeDefaults.marketCityId,
          timezone: _runtimeDefaults.timezone,
          country: _runtimeDefaults.country,
          city: _runtimeDefaults.city,
          currency: _runtimeDefaults.currency,
        ).copyWith(
          id: _idGenerator.generate(),
          objectType: CreateObjectType.scenario,
          title: scenarioTitle.trim().isEmpty
              ? 'Expanded Quick Plan'
              : scenarioTitle.trim(),
          shortDescription: 'Personal Scenario expanded from a Quick Plan.',
          sectionData: sectionData,
          scenarioData: result.scenario,
          clearEventData: true,
          visibility: VisibilityType.private,
          availabilityKind: CreateAvailabilityKind.none,
          format: result.scenario!.format.name,
          timezone: result.scenario!.defaultTimezoneId,
          currency: result.scenario!.displayCurrencyCode,
          updatedAtUtc: DateTime.now().toUtc(),
        );
    return QuickPlanConversionMaterialization(
      draft: draft,
      issues: result.issues,
      sourceRevision: result.sourceRevision,
    );
  }
}
