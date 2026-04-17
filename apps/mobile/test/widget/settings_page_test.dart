import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/auth/application/auth_providers.dart';
import 'package:recharge/features/auth/application/controllers/auth_controller.dart';
import 'package:recharge/features/auth/domain/entities/auth_result_entity.dart';
import 'package:recharge/features/auth/domain/entities/auth_session_entity.dart';
import 'package:recharge/features/auth/domain/entities/auth_user_entity.dart';
import 'package:recharge/features/auth/domain/repositories/auth_repository.dart';
import 'package:recharge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/restore_session_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:recharge/features/explore/application/controllers/explore_controller.dart';
import 'package:recharge/features/explore/application/explore_providers.dart';
import 'package:recharge/features/explore/domain/entities/profile_editable_entity.dart';
import 'package:recharge/features/explore/domain/entities/settings_entity.dart';
import 'package:recharge/features/explore/domain/repositories/explore_repository.dart';
import 'package:recharge/features/explore/domain/usecases/load_profile_editable_usecase.dart';
import 'package:recharge/features/explore/domain/usecases/load_settings_usecase.dart';
import 'package:recharge/features/explore/domain/usecases/save_profile_editable_usecase.dart';
import 'package:recharge/features/explore/domain/usecases/save_settings_usecase.dart';
import 'package:recharge/features/explore/presentation/pages/settings_page.dart';

void main() {
  testWidgets('renders settings controls for authenticated user', (tester) async {
    final authController = AuthController(
      signInUseCase: SignInUseCase(_NoopAuthRepository()),
      restoreSessionUseCase: RestoreSessionUseCase(_NoopAuthRepository()),
      signOutUseCase: SignOutUseCase(_NoopAuthRepository()),
      getCurrentUserUseCase: GetCurrentUserUseCase(_NoopAuthRepository()),
      analyticsService: _NoopAnalyticsService(),
    );
    await authController.signIn(
      email: 'user@example.com',
      password: 'password123',
      sourceScreen: 'test',
      sourceAction: 'seed',
    );

    final exploreRepository = _FakeExploreRepository();
    final exploreController = ExploreController(
      loadProfileEditableUseCase: LoadProfileEditableUseCase(exploreRepository),
      saveProfileEditableUseCase: SaveProfileEditableUseCase(exploreRepository),
      loadSettingsUseCase: LoadSettingsUseCase(exploreRepository),
      saveSettingsUseCase: SaveSettingsUseCase(exploreRepository),
      analyticsService: _NoopAnalyticsService(),
    );
    await exploreController.ensureLoaded(
      userId: 'u',
      email: 'user@example.com',
      role: 'user',
      favoritesCount: 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          exploreControllerProvider.overrideWith((ref) => exploreController),
        ],
        child: const MaterialApp(
          home: SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Currency'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Support / Help'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.text('Выйти'), findsOneWidget);
  });
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _NoopAuthRepository implements AuthRepository {
  @override
  Future<AuthUserEntity?> getCurrentUser() async => null;

  @override
  Future<AuthResultEntity?> restoreSession() async => null;

  @override
  Future<AuthResultEntity> signIn({
    required String email,
    required String password,
    required String deviceName,
    required String platform,
    required String appVersion,
  }) async {
    return AuthResultEntity(
      session: AuthSessionEntity(
        accessToken: 'acc',
        refreshToken: 'ref',
        sessionId: 'sess',
        expiresAtUtc: DateTime.now().toUtc(),
      ),
      user: const AuthUserEntity(
        id: 'u',
        email: 'user@example.com',
        role: 'user',
        capabilities: <String>['profile.read', 'profile.update'],
        profileStatus: 'active',
      ),
    );
  }

  @override
  Future<void> signOut() async {}
}

class _FakeExploreRepository implements ExploreRepository {
  @override
  Future<ProfileEditableEntity?> loadProfileEditable(String userId) async => null;

  @override
  Future<SettingsEntity?> loadSettings(String userId) async => null;

  @override
  Future<void> saveProfileEditable(
    String userId,
    ProfileEditableEntity profile,
  ) async {}

  @override
  Future<void> saveSettings(
    String userId,
    SettingsEntity settings,
  ) async {}
}
