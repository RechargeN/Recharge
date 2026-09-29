import '../entities/create_draft_entity.dart';

enum ScenarioCopySourceKind { publicScenario, template }

class ScenarioCopySourceSummary {
  const ScenarioCopySourceSummary({
    required this.id,
    required this.title,
    required this.kind,
  });

  final String id;
  final String title;
  final ScenarioCopySourceKind kind;
}

abstract interface class ScenarioCopySourceRepository {
  Future<List<ScenarioCopySourceSummary>> listAvailable();

  Future<CreateDraftEntity?> loadSource(String sourceScenarioId);
}

class EmptyScenarioCopySourceRepository
    implements ScenarioCopySourceRepository {
  const EmptyScenarioCopySourceRepository();

  @override
  Future<List<ScenarioCopySourceSummary>> listAvailable() async =>
      const <ScenarioCopySourceSummary>[];

  @override
  Future<CreateDraftEntity?> loadSource(String sourceScenarioId) async => null;
}
