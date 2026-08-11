import '../domain/entities/scenario_draft_data.dart';
import '../domain/entities/scenario_generation_proposal.dart';
import '../domain/entities/scenario_item_draft.dart';
import '../domain/repositories/catalog_object_picker_port.dart';
import '../domain/usecases/evaluate_scenario_readiness_usecase.dart';
import '../domain/usecases/generate_scenario_proposal_usecase.dart';
import 'scenario_create_coordinator.dart';

class ScenarioGenerationPreview {
  const ScenarioGenerationPreview({
    required this.proposal,
    required this.readiness,
  });

  final ScenarioGenerationProposal proposal;
  final ScenarioReadinessResult readiness;
}

class ScenarioGenerationStaleFailure implements Exception {
  const ScenarioGenerationStaleFailure();

  @override
  String toString() =>
      'ScenarioGenerationStaleFailure(source revision changed)';
}

class ScenarioGenerationCoordinator {
  const ScenarioGenerationCoordinator({
    required GenerateScenarioProposalUseCase generateProposal,
    required ScenarioCreateCoordinator scenarioCreateCoordinator,
  }) : _generateProposal = generateProposal,
       _scenarioCreateCoordinator = scenarioCreateCoordinator;

  final GenerateScenarioProposalUseCase _generateProposal;
  final ScenarioCreateCoordinator _scenarioCreateCoordinator;

  Future<ScenarioGenerationPreview> generate({
    required String prompt,
    required String marketCityId,
    required ScenarioDraftData draft,
  }) async {
    final Set<String> existingObjectIds = _existingCatalogObjectIds(draft);
    final ScenarioGenerationProposal proposal = await _generateProposal(
      ScenarioGenerationRequest(
        prompt: prompt,
        marketCityId: marketCityId,
        timezoneId: draft.defaultTimezoneId,
        currencyCode: draft.displayCurrencyCode,
        sourceRevision: draft.revision,
        format: draft.format,
        peopleCount: draft.party.peopleCount,
        partyKind: draft.party.kind,
        pace: draft.constraints.pace,
        travelMode: draft.constraints.primaryTravelMode,
        existingCatalogObjectIds: existingObjectIds,
      ),
    );
    final ScenarioDraftData previewDraft = _materialize(draft, proposal);
    return ScenarioGenerationPreview(
      proposal: proposal,
      readiness: _scenarioCreateCoordinator.evaluate(previewDraft),
    );
  }

  ScenarioDraftData apply(
    ScenarioDraftData draft,
    ScenarioGenerationProposal proposal,
  ) {
    if (draft.revision != proposal.sourceRevision) {
      throw const ScenarioGenerationStaleFailure();
    }
    return _materialize(draft, proposal);
  }

  ScenarioDraftData _materialize(
    ScenarioDraftData draft,
    ScenarioGenerationProposal proposal,
  ) {
    var next = draft;
    final Set<String> knownIds = _existingCatalogObjectIds(next);
    for (final ScenarioGeneratedCatalogItem item in proposal.items) {
      if (!knownIds.add(item.objectId)) continue;
      next = _scenarioCreateCoordinator.addCatalogItem(
        next,
        ScenarioCatalogObjectCandidate(
          id: item.objectId,
          objectType: item.objectType,
          title: item.title,
          subtitle: item.subtitle,
          durationMinutes: item.durationMinutes,
          coverMediaId: item.coverMediaId,
          publisherId: item.publisherId,
        ),
      );
    }
    return next;
  }

  Set<String> _existingCatalogObjectIds(ScenarioDraftData draft) => draft.items
      .map((ScenarioItemDraft item) => item.source)
      .whereType<ScenarioCatalogObjectSourceDraft>()
      .map((ScenarioCatalogObjectSourceDraft source) => source.objectId)
      .toSet();
}
