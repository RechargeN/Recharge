import '../entities/profile_editable_entity.dart';
import '../repositories/explore_repository.dart';

class SaveProfileEditableUseCase {
  SaveProfileEditableUseCase(this._repository);

  final ExploreRepository _repository;

  Future<void> call({
    required String userId,
    required ProfileEditableEntity profile,
  }) {
    return _repository.saveProfileEditable(userId, profile);
  }
}
