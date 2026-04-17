import '../../domain/entities/profile_editable_entity.dart';
import '../../domain/entities/settings_entity.dart';
import '../../domain/repositories/explore_repository.dart';
import '../datasources/explore_local_datasource.dart';
import '../models/profile_editable_model.dart';
import '../models/settings_model.dart';

class ExploreRepositoryImpl implements ExploreRepository {
  ExploreRepositoryImpl({
    required ExploreLocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  final ExploreLocalDataSource _localDataSource;

  @override
  Future<ProfileEditableEntity?> loadProfileEditable(String userId) async {
    final ProfileEditableModel? model =
        await _localDataSource.loadProfileEditable(userId);
    return model?.toEntity();
  }

  @override
  Future<void> saveProfileEditable(
    String userId,
    ProfileEditableEntity profile,
  ) {
    return _localDataSource.saveProfileEditable(
      userId,
      ProfileEditableModel.fromEntity(profile),
    );
  }

  @override
  Future<SettingsEntity?> loadSettings(String userId) async {
    final SettingsModel? model = await _localDataSource.loadSettings(userId);
    return model?.toEntity();
  }

  @override
  Future<void> saveSettings(
    String userId,
    SettingsEntity settings,
  ) {
    return _localDataSource.saveSettings(
      userId,
      SettingsModel.fromEntity(settings),
    );
  }
}
