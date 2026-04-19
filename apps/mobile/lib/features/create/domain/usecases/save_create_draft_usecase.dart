import '../entities/create_draft_entity.dart';
import '../repositories/create_repository.dart';

class SaveCreateDraftUseCase {
  SaveCreateDraftUseCase(this._repository);

  final CreateRepository _repository;

  Future<void> call({
    required String userId,
    required CreateDraftEntity draft,
  }) {
    return _repository.saveDraft(userId, draft);
  }
}
