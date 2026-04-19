import '../entities/create_draft_entity.dart';
import '../repositories/create_repository.dart';

class PublishCreateDraftUseCase {
  PublishCreateDraftUseCase(this._repository);

  final CreateRepository _repository;

  Future<CreateDraftEntity> call({
    required String userId,
    required CreateDraftEntity draft,
  }) {
    return _repository.publishDraft(userId, draft);
  }
}
