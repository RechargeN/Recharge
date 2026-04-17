import '../entities/profile_editable_entity.dart';
import '../repositories/explore_repository.dart';

class LoadProfileEditableUseCase {
  LoadProfileEditableUseCase(this._repository);

  final ExploreRepository _repository;

  Future<ProfileEditableEntity?> call(String userId) {
    return _repository.loadProfileEditable(userId);
  }
}
