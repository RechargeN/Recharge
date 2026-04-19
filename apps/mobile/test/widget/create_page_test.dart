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
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_providers.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/create/presentation/pages/create_page.dart';

void main() {
  testWidgets('shows cover validation error on publish', (tester) async {
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

    final createRepository = _FakeCreateRepository();
    final createController = CreateController(
      loadCreateDraftUseCase: LoadCreateDraftUseCase(createRepository),
      saveCreateDraftUseCase: SaveCreateDraftUseCase(createRepository),
      publishCreateDraftUseCase: PublishCreateDraftUseCase(createRepository),
      analyticsService: _NoopAnalyticsService(),
    );
    await createController.ensureLoaded(
      userId: 'u',
      organizerEmail: 'user@example.com',
      organizerName: 'user',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          createControllerProvider.overrideWith((ref) => createController),
        ],
        child: const MaterialApp(home: CreatePage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Title *'),
      'Event title',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Main category *'),
      'wellness',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'City *'),
      'Rezekne',
    );
    await tester.scrollUntilVisible(
      find.text('Publish'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();

    expect(find.text('Cover image обязательна'), findsOneWidget);
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
        role: 'creator',
        capabilities: <String>['create.event', 'create.place'],
        profileStatus: 'active',
      ),
    );
  }

  @override
  Future<void> signOut() async {}
}

class _FakeCreateRepository implements CreateRepository {
  CreateDraftEntity? _stored;

  @override
  Future<CreateDraftEntity?> loadDraft(String userId) async => _stored;

  @override
  Future<CreateDraftEntity> publishDraft(
    String userId,
    CreateDraftEntity draft,
  ) async {
    final now = DateTime.now().toUtc();
    _stored = draft.copyWith(
      draftStatus: DraftStatus.pendingReview,
      moderationStatus: ModerationStatus.pending,
      publishStatus: PublishStatus.pendingReview,
      publishedAtUtc: now,
      updatedAtUtc: now,
    );
    return _stored!;
  }

  @override
  Future<void> saveDraft(String userId, CreateDraftEntity draft) async {
    _stored = draft;
  }
}
