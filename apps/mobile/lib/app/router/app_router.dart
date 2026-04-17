import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/telemetry/analytics_service.dart';
import '../di/service_locator.dart';
import '../observers/app_route_observer.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/presentation/pages/create_page.dart';
import '../../features/auth/presentation/pages/discover_hub_page.dart';
import '../../features/auth/presentation/pages/profile_page.dart';
import '../../features/auth/presentation/pages/sign_in_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/discover/presentation/pages/discover_details_page.dart';
import '../../features/discover/presentation/pages/discover_map_page.dart';
import '../../features/discover/presentation/pages/discover_results_page.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authController = ref.watch(authControllerProvider);
  final AnalyticsService analyticsService = sl<AnalyticsService>();

  return GoRouter(
    initialLocation: RouteNames.splash,
    refreshListenable: authController,
    observers: <NavigatorObserver>[
      AppRouteObserver(analyticsService: analyticsService),
    ],
    routes: <RouteBase>[
      GoRoute(
        name: 'splash',
        path: RouteNames.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        name: 'discover',
        path: RouteNames.discover,
        builder: (context, state) => DiscoverHubPage(
          favoriteApplied: state.uri.queryParameters['favoriteApplied'] == '1',
        ),
      ),
      GoRoute(
        name: 'discover_details',
        path: '${RouteNames.discoverDetails}/:itemId',
        builder: (context, state) => DiscoverDetailsPage(
          itemId: state.pathParameters['itemId'] ?? '',
        ),
      ),
      GoRoute(
        name: 'discover_map',
        path: RouteNames.discoverMap,
        builder: (context, state) => const DiscoverMapPage(),
      ),
      GoRoute(
        name: 'discover_results',
        path: RouteNames.discoverResults,
        builder: (context, state) => const DiscoverResultsPage(),
      ),
      GoRoute(
        name: 'sign_in',
        path: RouteNames.signIn,
        builder: (context, state) => SignInPage(
          originRoute: state.uri.queryParameters['originRoute'],
          originAction: state.uri.queryParameters['originAction'],
          sourceScreen: state.uri.queryParameters['sourceScreen'] ?? 'unknown',
          sourceAction: state.uri.queryParameters['sourceAction'] ?? 'manual',
        ),
      ),
      GoRoute(
        name: 'profile',
        path: RouteNames.profile,
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        name: 'create',
        path: RouteNames.create,
        builder: (context, state) => const CreatePage(),
      ),
    ],
    redirect: (context, state) {
      final isProtected = state.matchedLocation == RouteNames.profile ||
          state.matchedLocation == RouteNames.create;

      if (isProtected && !authController.state.isAuthenticated) {
        final encodedOrigin = Uri.encodeComponent(state.matchedLocation);
        return '${RouteNames.signIn}?originRoute=$encodedOrigin';
      }

      if (state.matchedLocation == RouteNames.splash &&
          authController.state.isLoading) {
        return null;
      }

      return null;
    },
  );
});
