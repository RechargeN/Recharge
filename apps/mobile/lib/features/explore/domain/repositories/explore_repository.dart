import '../entities/profile_editable_entity.dart';
import '../entities/settings_entity.dart';

abstract class ExploreRepository {
  Future<ProfileEditableEntity?> loadProfileEditable(String userId);
  Future<void> saveProfileEditable(
    String userId,
    ProfileEditableEntity profile,
  );

  Future<SettingsEntity?> loadSettings(String userId);
  Future<void> saveSettings(
    String userId,
    SettingsEntity settings,
  );
}
