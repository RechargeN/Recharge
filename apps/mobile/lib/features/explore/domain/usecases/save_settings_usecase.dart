import '../entities/settings_entity.dart';
import '../repositories/explore_repository.dart';

class SaveSettingsUseCase {
  SaveSettingsUseCase(this._repository);

  final ExploreRepository _repository;

  Future<void> call({
    required String userId,
    required SettingsEntity settings,
  }) {
    return _repository.saveSettings(userId, settings);
  }
}
