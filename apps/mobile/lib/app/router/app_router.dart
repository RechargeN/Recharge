import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/telemetry/analytics_service.dart';
import '../di/service_locator.dart';
import '../observers/app_route_observer.dart';
import '../presentation/recharge_app_shell.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/presentation/pages/discover_hub_page.dart';
import '../../features/auth/presentation/pages/sign_in_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/create/presentation/pages/create_page.dart';
import '../../features/create/presentation/pages/create_success_page.dart';
import '../../features/discover/presentation/pages/discover_details_page.dart';
import '../../features/discover/presentation/pages/discover_map_page.dart';
import '../../features/discover/presentation/pages/discover_results_page.dart';
import '../../features/discover/presentation/pages/search_page.dart';
import '../../features/discover/presentation/pages/smart_search_page.dart';
import '../../features/explore/presentation/pages/profile_page.dart';
import '../../features/explore/presentation/pages/settings_page.dart';
import '../../features/favorites/presentation/pages/favorites_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/scenarios/presentation/pages/scenario_builder_page.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authController = ref.read(authControllerProvider);
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
      ShellRoute(
        builder: (context, state, child) =>
            RechargeAppShell(currentLocation: state.uri.path, child: child),
        routes: <RouteBase>[
          GoRoute(
            name: 'discover',
            path: RouteNames.discover,
            builder: (context, state) => DiscoverHubPage(
              favoriteApplied:
                  state.uri.queryParameters['favoriteApplied'] == '1',
            ),
          ),
          GoRoute(
            name: 'search',
            path: RouteNames.search,
            builder: (context, state) => const SearchPage(),
          ),
          GoRoute(
            name: 'smart_search',
            path: RouteNames.smartSearch,
            builder: (context, state) =>
                SmartSearchPage(seedParameters: state.uri.queryParameters),
          ),
          GoRoute(
            name: 'discover_map',
            path: RouteNames.discoverMap,
            builder: (context, state) =>
                DiscoverMapPage(seedParameters: state.uri.queryParameters),
          ),
          GoRoute(
            name: 'discover_results',
            path: RouteNames.discoverResults,
            builder: (context, state) =>
                DiscoverResultsPage(seedParameters: state.uri.queryParameters),
          ),
          GoRoute(
            name: 'scenario_builder',
            path: RouteNames.scenarioBuilder,
            builder: (context, state) =>
                ScenarioBuilderPage(seedParameters: state.uri.queryParameters),
          ),
          GoRoute(
            name: 'favorites',
            path: RouteNames.favorites,
            builder: (context, state) => const FavoritesPage(),
          ),
          GoRoute(
            name: 'notifications',
            path: RouteNames.notifications,
            builder: (context, state) => const NotificationsPage(),
          ),
          GoRoute(
            name: 'profile',
            path: RouteNames.profile,
            builder: (context, state) => const ProfilePage(),
          ),
          GoRoute(
            name: 'profile_workspace',
            path: RouteNames.profileWorkspace,
            builder: (context, state) => const ProfileWorkspacePage(),
          ),
        ],
      ),
      GoRoute(
        name: 'discover_details',
        path: '${RouteNames.discoverDetails}/:itemId',
        builder: (context, state) => DiscoverDetailsPage(
          itemId: state.pathParameters['itemId'] ?? '',
          favoriteApplied: state.uri.queryParameters['favoriteApplied'] == '1',
        ),
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
        name: 'create',
        path: RouteNames.create,
        builder: (context, state) =>
            CreatePage(seedParameters: state.uri.queryParameters),
      ),
      GoRoute(
        name: 'settings',
        path: RouteNames.settings,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        name: 'create_success',
        path: RouteNames.createSuccess,
        builder: (context, state) => const CreateSuccessPage(),
      ),
    ],
    redirect: (context, state) {
      final isProtected =
          state.matchedLocation == RouteNames.profile ||
          state.matchedLocation == RouteNames.profileWorkspace ||
          state.matchedLocation == RouteNames.create ||
          state.matchedLocation == RouteNames.favorites ||
          state.matchedLocation == RouteNames.notifications ||
          state.matchedLocation == RouteNames.settings ||
          state.matchedLocation == RouteNames.createSuccess;

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
