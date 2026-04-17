import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/explore/application/controllers/explore_controller.dart';
import 'package:recharge/features/explore/application/state/explore_state.dart';
import 'package:recharge/features/explore/domain/entities/profile_editable_entity.dart';
import 'package:recharge/features/explore/domain/entities/settings_entity.dart';
import 'package:recharge/features/explore/domain/repositories/explore_repository.dart';
import 'package:recharge/features/explore/domain/usecases/load_profile_editable_usecase.dart';
import 'package:recharge/features/explore/domain/usecases/load_settings_usecase.dart';
import 'package:recharge/features/explore/domain/usecases/save_profile_editable_usecase.dart';
import 'package:recharge/features/explore/domain/usecases/save_settings_usecase.dart';

void main() {
  late _FakeExploreRepository repository;
  late ExploreController controller;

  setUp(() {
    repository = _FakeExploreRepository();
    controller = ExploreController(
      loadProfileEditableUseCase: LoadProfileEditableUseCase(repository),
      saveProfileEditableUseCase: SaveProfileEditableUseCase(repository),
      loadSettingsUseCase: LoadSettingsUseCase(repository),
      saveSettingsUseCase: SaveSettingsUseCase(repository),
      analyticsService: _NoopAnalyticsService(),
    );
  });

  test('ensureLoaded -> ready with defaults', () async {
    await controller.ensureLoaded(
      userId: 'usr_1',
      email: 'user@example.com',
      role: 'user',
      favoritesCount: 2,
    );

    expect(controller.state.status, ExploreStatus.ready);
    expect(controller.state.userId, 'usr_1');
    expect(controller.state.email, 'user@example.com');
    expect(controller.state.favoritesCount, 2);
    expect(controller.state.profile.displayName, 'user');
  });

  test('saveProfile persists edited fields', () async {
    await controller.ensureLoaded(
      userId: 'usr_1',
      email: 'user@example.com',
      role: 'user',
      favoritesCount: 0,
    );
    controller.updateDisplayName('RechargeN');
    controller.updateCity('Riga');

    await controller.saveProfile();

    final ProfileEditableEntity? stored =
        await repository.loadProfileEditable('usr_1');
    expect(stored, isNotNull);
    expect(stored!.displayName, 'RechargeN');
    expect(stored.city, 'Riga');
  });

  test('updateSettings persists values', () async {
    await controller.ensureLoaded(
      userId: 'usr_1',
      email: 'user@example.com',
      role: 'user',
      favoritesCount: 0,
    );

    await controller.updateLanguage('en');
    await controller.updateCurrency('USD');
    await controller.updateNotifications(false);

    final SettingsEntity? stored = await repository.loadSettings('usr_1');
    expect(stored, isNotNull);
    expect(stored!.language, 'en');
    expect(stored.currency, 'USD');
    expect(stored.notificationsEnabled, isFalse);
  });
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _FakeExploreRepository implements ExploreRepository {
  final Map<String, ProfileEditableEntity> _profiles = <String, ProfileEditableEntity>{};
  final Map<String, SettingsEntity> _settings = <String, SettingsEntity>{};

  @override
  Future<ProfileEditableEntity?> loadProfileEditable(String userId) async {
    return _profiles[userId];
  }

  @override
  Future<SettingsEntity?> loadSettings(String userId) async {
    return _settings[userId];
  }

  @override
  Future<void> saveProfileEditable(
    String userId,
    ProfileEditableEntity profile,
  ) async {
    _profiles[userId] = profile;
  }

  @override
  Future<void> saveSettings(
    String userId,
    SettingsEntity settings,
  ) async {
    _settings[userId] = settings;
  }
}
