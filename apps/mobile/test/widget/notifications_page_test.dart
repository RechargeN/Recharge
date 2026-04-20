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
import 'package:recharge/features/notifications/application/controllers/notifications_controller.dart';
import 'package:recharge/features/notifications/application/notifications_providers.dart';
import 'package:recharge/features/notifications/domain/entities/notification_item_entity.dart';
import 'package:recharge/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:recharge/features/notifications/domain/usecases/get_notifications_usecase.dart';
import 'package:recharge/features/notifications/domain/usecases/mark_notification_read_usecase.dart';
import 'package:recharge/features/notifications/presentation/pages/notifications_page.dart';

void main() {
  testWidgets('marks notification as read', (tester) async {
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

    final notificationsController = NotificationsController(
      getNotificationsUseCase: GetNotificationsUseCase(_FakeNotificationsRepository()),
      markNotificationReadUseCase: MarkNotificationReadUseCase(
        _FakeNotificationsRepository(),
      ),
      analyticsService: _NoopAnalyticsService(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          notificationsControllerProvider.overrideWith((ref) => notificationsController),
        ],
        child: const MaterialApp(home: NotificationsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Новые активности рядом'), findsOneWidget);
    expect(find.byTooltip('Отметить как прочитанное'), findsOneWidget);

    await tester.tap(find.byTooltip('Отметить как прочитанное').first);
    await tester.pumpAndSettle();

    expect(find.text('Прочитано'), findsNWidgets(2));
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
        capabilities: <String>['discover.read'],
        profileStatus: 'active',
      ),
    );
  }

  @override
  Future<void> signOut() async {}
}

class _FakeNotificationsRepository implements NotificationsRepository {
  final List<NotificationItemEntity> _items = <NotificationItemEntity>[
    NotificationItemEntity(
      id: 'n1',
      title: 'Новые активности рядом',
      body: 'Попробуйте подборку возле вас',
      type: NotificationType.activity,
      createdAtUtc: DateTime.parse('2026-04-20T10:00:00Z'),
      isRead: false,
      targetRoute: null,
    ),
    NotificationItemEntity(
      id: 'n2',
      title: 'Системное обновление',
      body: 'Мы улучшили приложение',
      type: NotificationType.system,
      createdAtUtc: DateTime.parse('2026-04-20T08:00:00Z'),
      isRead: true,
      targetRoute: null,
    ),
  ];

  @override
  Future<List<NotificationItemEntity>> getNotifications({
    required String userId,
  }) async {
    return List<NotificationItemEntity>.from(_items);
  }

  @override
  Future<void> markNotificationRead({
    required String userId,
    required String notificationId,
  }) async {
    final int index =
        _items.indexWhere((NotificationItemEntity item) => item.id == notificationId);
    if (index < 0) return;
    _items[index] = _items[index].copyWith(isRead: true);
  }
}
