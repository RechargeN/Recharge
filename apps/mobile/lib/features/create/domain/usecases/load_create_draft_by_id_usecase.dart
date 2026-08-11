import '../entities/create_draft_entity.dart';
import '../repositories/create_draft_collection_repository.dart';

class LoadCreateDraftByIdUseCase {
  const LoadCreateDraftByIdUseCase(this._repository);

  final CreateDraftCollectionRepository _repository;

  Future<CreateDraftEntity?> call({
    required String ownerId,
    required String draftId,
  }) => _repository.loadDraftById(ownerId: ownerId, draftId: draftId);
}
