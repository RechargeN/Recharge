import '../entities/settings_entity.dart';
import '../repositories/explore_repository.dart';

class LoadSettingsUseCase {
  LoadSettingsUseCase(this._repository);

  final ExploreRepository _repository;

  Future<SettingsEntity?> call(String userId) {
    return _repository.loadSettings(userId);
  }
}
