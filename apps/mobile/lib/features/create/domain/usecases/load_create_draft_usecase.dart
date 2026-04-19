import '../entities/create_draft_entity.dart';
import '../repositories/create_repository.dart';

class LoadCreateDraftUseCase {
  LoadCreateDraftUseCase(this._repository);

  final CreateRepository _repository;

  Future<CreateDraftEntity?> call(String userId) {
    return _repository.loadDraft(userId);
  }
}
