import '../domain/entities/create_draft_entity.dart';

class ScenarioConversionHandoffStore {
  final Map<String, CreateDraftEntity> _drafts = <String, CreateDraftEntity>{};

  String put(CreateDraftEntity draft) {
    _drafts[draft.id] = draft;
    return draft.id;
  }

  CreateDraftEntity? take(String scenarioId) => _drafts.remove(scenarioId);

  bool contains(String scenarioId) => _drafts.containsKey(scenarioId);
}
