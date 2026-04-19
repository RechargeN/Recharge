import '../entities/create_draft_entity.dart';

abstract class CreateRepository {
  Future<CreateDraftEntity?> loadDraft(String userId);
  Future<void> saveDraft(String userId, CreateDraftEntity draft);
  Future<CreateDraftEntity> publishDraft(String userId, CreateDraftEntity draft);
}
