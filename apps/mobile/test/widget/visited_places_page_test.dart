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
import 'package:recharge/features/visited/application/controllers/visited_places_controller.dart';
import 'package:recharge/features/visited/application/visited_places_providers.dart';
import 'package:recharge/features/visited/domain/entities/visited_place_entity.dart';
import 'package:recharge/features/visited/domain/repositories/visited_places_repository.dart';
import 'package:recharge/features/visited/domain/usecases/get_visited_places_usecase.dart';
import 'package:recharge/features/visited/presentation/pages/visited_places_page.dart';

void main() {
  testWidgets('shows creator visit history and opens place details', (
    tester,
  ) async {
    final authController = await _signedInAuth(role: 'creator');
    final visitedController = VisitedPlacesController(
      getVisitedPlacesUseCase: GetVisitedPlacesUseCase(
        _FakeVisitedPlacesRepository(items: <VisitedPlaceEntity>[_visit()]),
      ),
      analyticsService: _NoopAnalyticsService(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          visitedPlacesControllerProvider.overrideWith(
            (ref) => visitedController,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: RouteNames.visitedPlaces,
            routes: <RouteBase>[
              GoRoute(
                path: RouteNames.visitedPlaces,
                builder: (context, state) =>
                    const VisitedPlacesPage(userId: 'creator-1'),
              ),
              GoRoute(
                path: '${RouteNames.discoverDetails}/:objectType/:objectId',
                builder: (context, state) => Scaffold(
                  body: Text('Details ${state.pathParameters['objectId']}'),
                ),
              ),
              GoRoute(
                path: '${RouteNames.discoverDetails}/:itemId',
                builder: (context, state) => Scaffold(
                  body: Text('Details ${state.pathParameters['itemId']}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Visit history'), findsWidgets);
    expect(find.text('Lake walk'), findsOneWidget);
    expect(find.textContaining('Jul 20'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Day'), findsOneWidget);

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();

    expect(find.text('Select month'), findsOneWidget);
    await tester.tap(find.textContaining('July 2026'));
    await tester.pumpAndSettle();

    expect(find.text('Clear'), findsOneWidget);

    await tester.tap(find.text('Lake walk'));
    await tester.pumpAndSettle();

    expect(find.text('Details evt_rig_002'), findsOneWidget);
  });

  testWidgets('shows a simple empty state', (tester) async {
    final authController = await _signedInAuth(role: 'creator');
    final visitedController = VisitedPlacesController(
      getVisitedPlacesUseCase: GetVisitedPlacesUseCase(
        _FakeVisitedPlacesRepository(),
      ),
      analyticsService: _NoopAnalyticsService(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          visitedPlacesControllerProvider.overrideWith(
            (ref) => visitedController,
          ),
        ],
        child: const MaterialApp(home: VisitedPlacesPage(userId: 'creator-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No visits yet'), findsOneWidget);
    expect(
      find.text('Places you explicitly mark as visited will appear here.'),
      findsOneWidget,
    );
  });

  testWidgets('shows visit history to a viewer', (tester) async {
    final authController = await _signedInAuth(role: 'user');
    final visitedController = VisitedPlacesController(
      getVisitedPlacesUseCase: GetVisitedPlacesUseCase(
        _FakeVisitedPlacesRepository(items: <VisitedPlaceEntity>[_visit()]),
      ),
      analyticsService: _NoopAnalyticsService(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          visitedPlacesControllerProvider.overrideWith(
            (ref) => visitedController,
          ),
        ],
        child: const MaterialApp(home: VisitedPlacesPage(userId: 'creator-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Visit history'), findsWidgets);
    expect(find.text('Lake walk'), findsOneWidget);
  });
}

Future<AuthController> _signedInAuth({required String role}) async {
  final repository = _FakeAuthRepository(role: role);
  final controller = AuthController(
    signInUseCase: SignInUseCase(repository),
    restoreSessionUseCase: RestoreSessionUseCase(repository),
    signOutUseCase: SignOutUseCase(repository),
    getCurrentUserUseCase: GetCurrentUserUseCase(repository),
    analyticsService: _NoopAnalyticsService(),
  );
  await controller.signIn(
    email: 'creator@example.com',
    password: 'password123',
    sourceScreen: 'test',
    sourceAction: 'seed',
  );
  return controller;
}

VisitedPlaceEntity _visit() {
  return VisitedPlaceEntity(
    id: '4a3d27ad-8185-4b94-a991-9b36b6f62c16',
    userId: 'creator-1',
    placeId: 'evt_rig_002',
    title: 'Lake walk',
    subtitle: 'Five calm kilometres',
    city: 'Riga',
    category: 'outdoor_nature_walking',
    visitedOn: DateTime(2026, 7, 20),
    timezoneId: 'Europe/Riga',
    evidence: VisitEvidence.selfReported,
    recordedAtUtc: DateTime.utc(2026, 7, 20, 12),
  );
}

class _FakeVisitedPlacesRepository implements VisitedPlacesRepository {
  _FakeVisitedPlacesRepository({this.items = const <VisitedPlaceEntity>[]});

  final List<VisitedPlaceEntity> items;

  @override
  Future<List<VisitedPlaceEntity>> getVisitedPlaces({
    required String userId,
  }) async {
    return items;
  }

  @override
  Future<VisitedPlaceEntity> recordVisit(VisitedPlaceEntity visit) async {
    return visit;
  }

  @override
  Future<void> removeVisit({
    required String userId,
    required String visitId,
  }) async {}
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required this.role});

  final String role;

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
        accessToken: 'access',
        refreshToken: 'refresh',
        sessionId: 'session',
        expiresAtUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
      user: AuthUserEntity(
        id: 'creator-1',
        email: email,
        role: role,
        capabilities: role == 'creator'
            ? const <String>['create.place']
            : const <String>[],
        profileStatus: 'active',
      ),
    );
  }

  @override
  Future<void> signOut() async {}
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}
