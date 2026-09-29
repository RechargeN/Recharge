import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recharge/app/router/route_names.dart';
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

import 'widget_test_viewport.dart';

void main() {
  fullPageTestWidgets('marks notification as read', (tester) async {
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
      getNotificationsUseCase: GetNotificationsUseCase(
        _FakeNotificationsRepository(),
      ),
      markNotificationReadUseCase: MarkNotificationReadUseCase(
        _FakeNotificationsRepository(),
      ),
      analyticsService: _NoopAnalyticsService(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          notificationsControllerProvider.overrideWith(
            (ref) => notificationsController,
          ),
        ],
        child: const MaterialApp(home: NotificationsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Новые активности рядом'), findsWidgets);
    expect(notificationsController.state.unreadCount, 1);

    await tester.tap(find.text('Новые активности рядом').first);
    await tester.pumpAndSettle();

    expect(notificationsController.state.unreadCount, 0);
    expect(find.byTooltip('Read all'), findsNothing);
  });

  fullPageTestWidgets('mark all read clears unread inbox actions', (
    tester,
  ) async {
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

    final repository = _FakeNotificationsRepository();
    final notificationsController = NotificationsController(
      getNotificationsUseCase: GetNotificationsUseCase(repository),
      markNotificationReadUseCase: MarkNotificationReadUseCase(repository),
      analyticsService: _NoopAnalyticsService(),
    );

    Widget app() {
      return ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          notificationsControllerProvider.overrideWith(
            (ref) => notificationsController,
          ),
        ],
        child: const MaterialApp(home: NotificationsPage()),
      );
    }

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Read all'), findsOneWidget);

    await tester.tap(find.byTooltip('Read all'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Read all'), findsNothing);
    expect(notificationsController.state.unreadCount, 0);
  });

  fullPageTestWidgets('filters notification feed by status and type', (
    tester,
  ) async {
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

    final repository = _FakeNotificationsRepository(
      initial: <NotificationItemEntity>[
        NotificationItemEntity(
          id: 'route',
          title: 'Готов спокойный маршрут',
          body: 'Кофе и прогулка рядом с вами.',
          type: NotificationType.activity,
          createdAtUtc: DateTime.parse('2026-04-20T12:00:00Z'),
          isRead: false,
          targetRoute:
              '${RouteNames.legacyScenarioBuilder}?mood=calm&duration=90&free=1'
              '&walking=1&steps=food_drinks.coffee',
        ),
        NotificationItemEntity(
          id: 'creator',
          title: 'Листинг отправлен на модерацию',
          body: 'Статус проверки доступен в creator workspace.',
          type: NotificationType.activity,
          createdAtUtc: DateTime.parse('2026-04-20T11:00:00Z'),
          isRead: false,
          targetRoute:
              '${RouteNames.create}?source=publish&status=pendingReview',
        ),
        NotificationItemEntity(
          id: 'action',
          title: 'Напоминание о событии',
          body: 'Через 2 часа начинается сохраненное событие.',
          type: NotificationType.reminder,
          createdAtUtc: DateTime.parse('2026-04-20T10:00:00Z'),
          isRead: false,
          targetRoute: RouteNames.favorites,
        ),
        NotificationItemEntity(
          id: 'other',
          title: 'Системное обновление',
          body: 'Мы улучшили приложение.',
          type: NotificationType.system,
          createdAtUtc: DateTime.parse('2026-04-20T09:00:00Z'),
          isRead: true,
          targetRoute: null,
        ),
      ],
    );
    final notificationsController = NotificationsController(
      getNotificationsUseCase: GetNotificationsUseCase(repository),
      markNotificationReadUseCase: MarkNotificationReadUseCase(repository),
      analyticsService: _NoopAnalyticsService(),
    );

    Widget app() {
      return ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          notificationsControllerProvider.overrideWith(
            (ref) => notificationsController,
          ),
        ],
        child: const MaterialApp(home: NotificationsPage()),
      );
    }

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Reminders'), findsOneWidget);
    expect(find.text('Updates'), findsOneWidget);
    expect(find.text('Готов спокойный маршрут'), findsOneWidget);
    expect(find.text('Листинг отправлен на модерацию'), findsOneWidget);
    expect(find.text('Напоминание о событии'), findsOneWidget);
    expect(find.text('Системное обновление'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('notifications-search')),
      'кофе прогулка',
    );
    await tester.pumpAndSettle();

    expect(find.text('Готов спокойный маршрут'), findsOneWidget);
    expect(find.text('Листинг отправлен на модерацию'), findsNothing);
    expect(find.text('Напоминание о событии'), findsNothing);
    expect(find.text('Системное обновление'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('notifications-search')),
      'маршурт',
    );
    await tester.pumpAndSettle();

    expect(find.text('Готов спокойный маршрут'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('notifications-search')),
      'авиабилет',
    );
    await tester.pumpAndSettle();

    expect(find.text('По вашему запросу ничего не найдено'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();

    expect(find.text('Системное обновление'), findsNothing);
    expect(find.text('Готов спокойный маршрут'), findsOneWidget);
    expect(find.text('Листинг отправлен на модерацию'), findsOneWidget);
    expect(find.text('Напоминание о событии'), findsOneWidget);

    await tester.tap(find.text('Reminders'));
    await tester.pumpAndSettle();

    expect(find.text('Напоминание о событии'), findsOneWidget);
    expect(find.text('Готов спокойный маршрут'), findsNothing);
    expect(find.text('Листинг отправлен на модерацию'), findsNothing);

    await tester.tap(find.text('Updates'));
    await tester.pumpAndSettle();

    expect(find.text('Системное обновление'), findsOneWidget);
    expect(find.text('Готов спокойный маршрут'), findsOneWidget);
    expect(find.text('Листинг отправлен на модерацию'), findsOneWidget);
    expect(find.text('Напоминание о событии'), findsNothing);
  });

  fullPageTestWidgets('opens route notification action and marks it read', (
    tester,
  ) async {
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

    final repository = _FakeNotificationsRepository(
      initial: <NotificationItemEntity>[
        NotificationItemEntity(
          id: 'scenario_route',
          title: 'Готов спокойный маршрут',
          body: 'Кофе, прогулка и тихая точка рядом с вами.',
          type: NotificationType.activity,
          createdAtUtc: DateTime.parse('2026-04-20T11:00:00Z'),
          isRead: false,
          targetRoute:
              '${RouteNames.legacyScenarioBuilder}?mood=calm&duration=90&free=1'
              '&walking=1'
              '&steps=food_drinks.coffee,wellness_recharge.calm_walk',
        ),
      ],
    );
    final notificationsController = NotificationsController(
      getNotificationsUseCase: GetNotificationsUseCase(repository),
      markNotificationReadUseCase: MarkNotificationReadUseCase(repository),
      analyticsService: _NoopAnalyticsService(),
    );

    Widget app() {
      return ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          notificationsControllerProvider.overrideWith(
            (ref) => notificationsController,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: RouteNames.notifications,
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.notifications,
                builder: (context, state) => const NotificationsPage(),
              ),
              GoRoute(
                path: RouteNames.legacyScenarioBuilder,
                builder: (context, state) => Scaffold(
                  body: Column(
                    children: <Widget>[
                      const Text('Scenario builder target'),
                      Text(state.uri.queryParameters['steps'] ?? ''),
                    ],
                  ),
                ),
              ),
              GoRoute(
                path: RouteNames.discoverMap,
                builder: (context, state) => Scaffold(
                  body: Column(
                    children: <Widget>[
                      const Text('Map route target'),
                      Text(state.uri.queryParameters['mode'] ?? ''),
                      Text(state.uri.queryParameters['steps'] ?? ''),
                    ],
                  ),
                ),
              ),
              GoRoute(
                path: RouteNames.create,
                builder: (context, state) => Scaffold(
                  body: Column(
                    children: <Widget>[
                      const Text('Create route target'),
                      Text(state.uri.queryParameters['source'] ?? ''),
                      Text(state.uri.queryParameters['type'] ?? ''),
                      Text(state.uri.queryParameters['category'] ?? ''),
                      Text(state.uri.queryParameters['title'] ?? ''),
                      Text(state.uri.queryParameters['q'] ?? ''),
                      Text(state.uri.queryParameters['steps'] ?? ''),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Legacy notification'), findsOneWidget);
    await tester.tap(find.byTooltip('Notification actions').first);
    await tester.pumpAndSettle();
    expect(find.text('Map route'), findsNothing);
    expect(find.text('Create route'), findsNothing);
    expect(find.text('Open'), findsOneWidget);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Scenario builder target'), findsOneWidget);
    expect(
      find.text('food_drinks.coffee,wellness_recharge.calm_walk'),
      findsOneWidget,
    );
    expect(notificationsController.state.items.single.isRead, isTrue);
  });

  fullPageTestWidgets('opens creator publish notifications', (tester) async {
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

    final repository = _FakeNotificationsRepository(
      initial: <NotificationItemEntity>[
        NotificationItemEntity(
          id: 'creator_profile',
          title: 'Листинг отправлен на модерацию',
          body: 'Статус проверки доступен в creator workspace.',
          type: NotificationType.activity,
          createdAtUtc: DateTime.parse('2026-04-20T12:00:00Z'),
          isRead: false,
          targetRoute: RouteNames.profile,
        ),
        NotificationItemEntity(
          id: 'creator_create',
          title: 'Проверьте черновик публикации',
          body: 'Museum evening route готов к уточнению перед релизом.',
          type: NotificationType.activity,
          createdAtUtc: DateTime.parse('2026-04-20T11:00:00Z'),
          isRead: false,
          targetRoute:
              '${RouteNames.create}?source=publish&status=pendingReview'
              '&title=Museum%20evening%20route',
        ),
      ],
    );
    final notificationsController = NotificationsController(
      getNotificationsUseCase: GetNotificationsUseCase(repository),
      markNotificationReadUseCase: MarkNotificationReadUseCase(repository),
      analyticsService: _NoopAnalyticsService(),
    );

    Widget app() {
      return ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          notificationsControllerProvider.overrideWith(
            (ref) => notificationsController,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: RouteNames.notifications,
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.notifications,
                builder: (context, state) => const NotificationsPage(),
              ),
              GoRoute(
                path: RouteNames.profile,
                builder: (context, state) =>
                    const Scaffold(body: Text('Profile target')),
              ),
              GoRoute(
                path: RouteNames.create,
                builder: (context, state) => Scaffold(
                  body: Column(
                    children: <Widget>[
                      const Text('Create target'),
                      Text(state.uri.queryParameters['source'] ?? ''),
                      Text(state.uri.queryParameters['status'] ?? ''),
                      Text(state.uri.queryParameters['title'] ?? ''),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Creator profile'), findsOneWidget);
    expect(find.text('Publish status'), findsOneWidget);

    await tester.tap(find.byTooltip('Notification actions').first);
    await tester.pumpAndSettle();
    expect(find.text('Open profile'), findsOneWidget);
    await tester.tap(find.text('Open profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile target'), findsOneWidget);
    expect(notificationsController.state.items.first.isRead, isTrue);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notification actions').last);
    await tester.pumpAndSettle();
    expect(find.text('Open listing'), findsOneWidget);
    await tester.tap(find.text('Open listing'));
    await tester.pumpAndSettle();
    expect(find.text('Create target'), findsOneWidget);
    expect(find.text('publish'), findsOneWidget);
    expect(find.text('pendingReview'), findsOneWidget);
    expect(find.text('Museum evening route'), findsOneWidget);
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
  _FakeNotificationsRepository({List<NotificationItemEntity>? initial})
    : _items = List<NotificationItemEntity>.from(initial ?? _defaultItems());

  final List<NotificationItemEntity> _items;

  static List<NotificationItemEntity> _defaultItems() {
    return <NotificationItemEntity>[
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
      NotificationItemEntity(
        id: 'creator_publish',
        title: 'Листинг отправлен на модерацию',
        body: 'Статус проверки доступен в creator workspace.',
        type: NotificationType.activity,
        createdAtUtc: DateTime.parse('2026-04-20T07:00:00Z'),
        isRead: true,
        targetRoute: RouteNames.profile,
      ),
    ];
  }

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
    final int index = _items.indexWhere(
      (NotificationItemEntity item) => item.id == notificationId,
    );
    if (index < 0) return;
    _items[index] = _items[index].copyWith(isRead: true);
  }
}
