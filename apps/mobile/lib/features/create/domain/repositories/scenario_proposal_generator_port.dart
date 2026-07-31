import '../entities/scenario_generation_proposal.dart';

abstract class ScenarioProposalGeneratorPort {
  Future<ScenarioGenerationProposal> generate(
    ScenarioGenerationRequest request,
  );
}
