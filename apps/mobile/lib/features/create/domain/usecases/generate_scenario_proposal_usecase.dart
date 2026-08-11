import '../entities/scenario_generation_proposal.dart';
import '../repositories/scenario_proposal_generator_port.dart';

enum ScenarioGenerationFailureCode {
  emptyPrompt,
  promptTooLong,
  invalidProposal,
}

class ScenarioGenerationFailure implements Exception {
  const ScenarioGenerationFailure(this.code, this.message);

  final ScenarioGenerationFailureCode code;
  final String message;

  @override
  String toString() => 'ScenarioGenerationFailure($code, $message)';
}

class GenerateScenarioProposalUseCase {
  const GenerateScenarioProposalUseCase(this._generator);

  static const int maximumPromptLength = 500;
  static const int maximumProposalItems = 3;

  final ScenarioProposalGeneratorPort _generator;

  Future<ScenarioGenerationProposal> call(
    ScenarioGenerationRequest request,
  ) async {
    final String prompt = request.prompt.trim();
    if (prompt.isEmpty) {
      throw const ScenarioGenerationFailure(
        ScenarioGenerationFailureCode.emptyPrompt,
        'Describe the plan you want to build.',
      );
    }
    if (prompt.length > maximumPromptLength) {
      throw const ScenarioGenerationFailure(
        ScenarioGenerationFailureCode.promptTooLong,
        'Keep the request under 500 characters.',
      );
    }

    final ScenarioGenerationProposal proposal = await _generator.generate(
      ScenarioGenerationRequest(
        prompt: prompt,
        marketCityId: request.marketCityId,
        timezoneId: request.timezoneId,
        currencyCode: request.currencyCode,
        sourceRevision: request.sourceRevision,
        format: request.format,
        peopleCount: request.peopleCount,
        partyKind: request.partyKind,
        pace: request.pace,
        travelMode: request.travelMode,
        existingCatalogObjectIds: request.existingCatalogObjectIds,
      ),
    );
    _validate(request, proposal);
    return proposal;
  }

  void _validate(
    ScenarioGenerationRequest request,
    ScenarioGenerationProposal proposal,
  ) {
    final Set<String> ids = <String>{};
    final bool invalid =
        proposal.id.trim().isEmpty ||
        proposal.mode != ScenarioGenerationMode.localDemo ||
        proposal.sourceRevision != request.sourceRevision ||
        proposal.items.length > maximumProposalItems ||
        proposal.activityMinutes < 0 ||
        proposal.items.any(
          (ScenarioGeneratedCatalogItem item) =>
              item.objectId.trim().isEmpty ||
              item.title.trim().isEmpty ||
              item.durationMinutes <= 0 ||
              request.existingCatalogObjectIds.contains(item.objectId) ||
              !ids.add(item.objectId),
        );
    if (invalid) {
      throw const ScenarioGenerationFailure(
        ScenarioGenerationFailureCode.invalidProposal,
        'The local generator returned an invalid proposal.',
      );
    }
  }
}
