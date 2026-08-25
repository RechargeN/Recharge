import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/telemetry/analytics_service.dart';
import '../../shared/models/catalog_object_ref.dart';
import '../di/service_locator.dart';
import '../adapters/legacy_planning_link_classifier.dart';
import '../application/details_resolution_providers.dart';
import '../application/planning_navigation_intent.dart';
import '../application/planning_navigation_resolver.dart';
import '../application/resolve_details_usecase.dart';
import '../observers/app_route_observer.dart';
import '../presentation/recharge_app_shell.dart';
import '../presentation/workspace_section_host.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/presentation/pages/discover_hub_page.dart';
import '../../features/auth/presentation/pages/sign_in_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/create/domain/entities/create_draft_entity.dart';
import '../../features/create/presentation/pages/create_hub_page.dart';
import '../../features/create/presentation/pages/create_page.dart';
import '../../features/create/presentation/pages/create_success_page.dart';
import '../../features/create/presentation/pages/route_moderation_page.dart';
import '../../features/discover/domain/entities/published_rental_discovery_entity.dart';
import '../../features/discover/presentation/pages/collection_details_page.dart';
import '../../features/discover/presentation/pages/rental_details_page.dart';
import '../../features/discover/presentation/pages/discover_details_page.dart';
import '../../features/discover/presentation/pages/categories_page.dart';
import '../../features/discover/presentation/pages/category_page.dart';
import '../../features/discover/presentation/pages/discover_map_page.dart';
import '../../features/discover/presentation/pages/discover_results_page.dart';
import '../../features/discover/presentation/pages/search_page.dart';
import '../../features/discover/presentation/pages/smart_search_page.dart';
import '../../features/discover/presentation/shell/details_shell.dart';
import '../../features/explore/presentation/pages/profile_page.dart';
import '../../features/explore/presentation/pages/settings_page.dart';
import '../../features/favorites/presentation/pages/favorites_page.dart';
import '../../features/identity/presentation/pages/professional_page_workspace_page.dart';
import '../../features/identity/presentation/pages/public_professional_page.dart';
import '../../features/identity/domain/usecases/resolve_public_professional_page_usecase.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/scenarios/presentation/pages/scenario_builder_page.dart';
import '../../features/visited/presentation/pages/visited_places_page.dart';
import 'details_route_parser.dart';
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
        builder: (context, state, child) => RechargeAppShell(
          currentLocation: state.uri.path,
          userId: authController.state.user?.id ?? '',
          child: child,
        ),
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
            name: 'categories',
            path: RouteNames.categories,
            builder: (context, state) => const CategoriesPage(),
          ),
          GoRoute(
            name: 'category',
            path: '${RouteNames.categories}/:categoryId',
            builder: (context, state) => CategoryPage(
              categoryId: state.pathParameters['categoryId'] ?? '',
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
            name: 'quick_plan',
            path: '${RouteNames.quickPlan}/:quickPlanId',
            builder: (context, state) => QuickPlanPage(
              seedParameters: <String, String>{
                ...state.uri.queryParameters,
                'quickPlanId': state.pathParameters['quickPlanId'] ?? '',
              },
            ),
          ),
          GoRoute(
            name: 'legacy_scenario_builder',
            path: RouteNames.legacyScenarioBuilder,
            redirect: (context, state) {
              final classification = const LegacyPlanningLinkClassifier()
                  .classify(state.uri.toString());
              final id = classification.targetId;
              if (id == null) return null;
              final intent = switch (classification.kind) {
                LegacyPlanningPayloadKind.scenario =>
                  PlanningNavigationIntent.openScenario(id),
                LegacyPlanningPayloadKind.quickPlan =>
                  PlanningNavigationIntent.openQuickPlan(id),
                LegacyPlanningPayloadKind.route =>
                  PlanningNavigationIntent.openRoute(id),
                _ => null,
              };
              return intent == null
                  ? null
                  : const PlanningNavigationResolver().resolve(intent);
            },
            builder: (context, state) => QuickPlanPage(
              seedParameters: <String, String>{
                ...state.uri.queryParameters,
                'legacyCompatibility': '1',
              },
            ),
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
          GoRoute(
            name: 'visited_places',
            path: RouteNames.visitedPlaces,
            builder: (context, state) =>
                VisitedPlacesPage(userId: authController.state.user?.id ?? ''),
          ),
          GoRoute(
            name: 'professional_page',
            path: RouteNames.professionalPage,
            builder: (context, state) => const ProfessionalPageWorkspacePage(
              section: ProfessionalPageSection.overview,
            ),
          ),
          GoRoute(
            name: 'professional_page_content',
            path: RouteNames.professionalPageContent,
            builder: (context, state) => const ProfessionalPageWorkspacePage(
              section: ProfessionalPageSection.content,
            ),
          ),
          GoRoute(
            name: 'professional_page_create',
            path: RouteNames.professionalPageCreate,
            builder: (context, state) {
              final user = authController.state.user;
              return CreateHubPage(
                isAuthenticated: user != null,
                capabilities: user?.capabilities ?? const <String>[],
              );
            },
          ),
          GoRoute(
            name: 'professional_page_account',
            path: RouteNames.professionalPageAccount,
            builder: (context, state) => const ProfessionalPageWorkspacePage(
              section: ProfessionalPageSection.account,
            ),
          ),
          GoRoute(
            name: 'professional_page_preview',
            path: '${RouteNames.professionalPagePreview}/:pageId',
            builder: (context, state) => PublicProfessionalPage(
              reference: state.pathParameters['pageId'] ?? '',
              lookup: PublicProfessionalPageLookup.id,
              userId: authController.state.user?.id ?? '',
              preview: true,
            ),
          ),
        ],
      ),
      GoRoute(
        name: 'public_professional_page_by_id',
        path: '${RouteNames.publicProfessionalPagesById}/:pageId',
        builder: (context, state) => PublicProfessionalPage(
          reference: state.pathParameters['pageId'] ?? '',
          lookup: PublicProfessionalPageLookup.id,
          userId: authController.state.user?.id ?? '',
        ),
      ),
      GoRoute(
        name: 'public_professional_page_by_slug',
        path: '${RouteNames.publicProfessionalPages}/:slug',
        builder: (context, state) => PublicProfessionalPage(
          reference: state.pathParameters['slug'] ?? '',
          lookup: PublicProfessionalPageLookup.slug,
          userId: authController.state.user?.id ?? '',
        ),
      ),
      // Canonical, typed Details route (`DTL-LINK-01`). Registered before
      // the legacy 3-segment route below: go_router matches by literal
      // segment structure, and `:objectType/:objectId` (4 segments) never
      // collides with legacy `:itemId` (3 segments), so both coexist
      // without redirecting or removing the legacy one
      // (`docs/product/DTL_LINK_01_DEEP_LINK_MIGRATION_SLICE_SPEC.md`
      // §1.1.6/§1.2: legacy routes are not removed by this slice).
      GoRoute(
        name: 'discover_details_canonical',
        path: '${RouteNames.discoverDetails}/:objectType/:objectId',
        builder: (context, state) {
          final DetailsRouteTarget? target = parseDetailsRoutePath(
            state.uri.path,
          );
          if (target == null) {
            return const DetailsShell(
              state: DetailsScreenUnavailable(
                reason: DetailsUnavailableReason.notFound,
              ),
            );
          }
          return _ResolvedDetailsRoute(target: target);
        },
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
        name: 'collection_details',
        path: '${RouteNames.collectionDetails}/:collectionId',
        builder: (context, state) => CollectionDetailsPage(
          collectionId: state.pathParameters['collectionId'] ?? '',
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
        name: 'create_object',
        path: '${RouteNames.createObject}/:objectTypeId',
        builder: (context, state) => CreatePage(
          initialObjectType: createObjectTypeFromId(
            state.pathParameters['objectTypeId'] ?? '',
          ),
          seedParameters: state.uri.queryParameters,
        ),
      ),
      GoRoute(
        name: 'create',
        path: RouteNames.create,
        builder: (context, state) {
          if (state.uri.queryParameters.isNotEmpty) {
            return CreatePage(seedParameters: state.uri.queryParameters);
          }
          final user = authController.state.user;
          return CreateHubPage(
            isAuthenticated: user != null,
            capabilities: user?.capabilities ?? const <String>[],
          );
        },
      ),
      GoRoute(
        name: 'settings',
        path: RouteNames.settings,
        builder: (context, state) => SettingsPage(
          workspaceSectionBuilder: (userId) =>
              WorkspaceSectionHost(userId: userId),
        ),
      ),
      GoRoute(
        name: 'create_success',
        path: RouteNames.createSuccess,
        builder: (context, state) => const CreateSuccessPage(),
      ),
      GoRoute(
        name: 'route_moderation',
        path: RouteNames.routeModeration,
        builder: (context, state) {
          final user = authController.state.user;
          return RouteModerationPage(
            userId: user?.id ?? '',
            userEmail: user?.email ?? '',
            capabilities: user?.capabilities ?? const <String>[],
          );
        },
      ),
    ],
    redirect: (context, state) {
      final isProtected =
          state.matchedLocation == RouteNames.profile ||
          state.matchedLocation == RouteNames.profileWorkspace ||
          state.matchedLocation == RouteNames.visitedPlaces ||
          state.matchedLocation == RouteNames.create ||
          state.matchedLocation.startsWith('${RouteNames.createObject}/') ||
          state.matchedLocation == RouteNames.favorites ||
          state.matchedLocation == RouteNames.notifications ||
          state.matchedLocation == RouteNames.settings ||
          state.matchedLocation == RouteNames.professionalPage ||
          state.matchedLocation == RouteNames.professionalPageContent ||
          state.matchedLocation == RouteNames.professionalPageCreate ||
          state.matchedLocation == RouteNames.professionalPageAccount ||
          state.matchedLocation.startsWith(
            '${RouteNames.professionalPagePreview}/',
          ) ||
          state.matchedLocation.startsWith(
            '${RouteNames.publicProfessionalPages}/',
          ) ||
          state.matchedLocation == RouteNames.createSuccess ||
          state.matchedLocation == RouteNames.routeModeration;

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

/// Builds the canonical Details route's content: resolves+verifies
/// [target] via `ResolveDetailsUseCase`, then dispatches to whichever
/// existing page already owns that family's rendering.
///
/// `DTL-FND-01`'s `DetailsShell` is reused here for the loading/unavailable
/// states — this is genuinely the first real production caller of
/// `DetailsUnavailableReason.notFound` (`details_shell.dart`'s own doc
/// comment already anticipated `DTL-LINK-01`/`DTL-OBJ-01` as the first
/// producers). It is **not** used for the `found` case: neither
/// `DiscoverDetailsPage` (Event/Activity/Place/Route) nor
/// `CollectionDetailsPage` (Collection) has been migrated onto a shared
/// `DetailsRenderer` for their content yet — `DiscoverDetailsPage` already
/// composes its own `DetailsShell` internally (`DTL-FND-01`);
/// `CollectionDetailsPage` remains its own `Scaffold` until `DTL-CLG-01`.
/// This widget only ever hands off a bare, already-verified id — it never
/// re-renders content itself.
class _ResolvedDetailsRoute extends ConsumerWidget {
  const _ResolvedDetailsRoute({required this.target});

  final DetailsRouteTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DetailsResolution> resolution = ref.watch(
      resolveDetailsProvider(target),
    );

    return resolution.when(
      loading: () => const DetailsShell(state: DetailsScreenLoading()),
      error: (Object error, StackTrace stackTrace) => DetailsShell(
        state: DetailsScreenUnavailable(
          reason: DetailsUnavailableReason.temporarilyUnavailable,
          onRetry: () => ref.invalidate(resolveDetailsProvider(target)),
        ),
      ),
      data: (DetailsResolution result) {
        final CatalogObjectRef? resolvedRef = result.ref;
        if (result.status == DetailsResolutionStatus.notFound ||
            resolvedRef == null) {
          return const DetailsShell(
            state: DetailsScreenUnavailable(
              reason: DetailsUnavailableReason.notFound,
            ),
          );
        }
        return switch (resolvedRef.objectType) {
          CatalogObjectType.event ||
          CatalogObjectType.activity ||
          CatalogObjectType.place ||
          CatalogObjectType.route => DiscoverDetailsPage(
            itemId: resolvedRef.objectId,
            favoriteApplied: false,
          ),
          CatalogObjectType.collection => CollectionDetailsPage(
            collectionId: resolvedRef.objectId,
          ),
          // DTL-OBJ-01 §4: unlike Collection above, RentalDetailsPage takes
          // the already-resolved projection directly instead of
          // re-fetching it through a second provider by id — the resolver
          // just loaded it one line above via RentalDetailsLookup, so a
          // second fetch would be redundant, not merely a style choice.
          CatalogObjectType.rental => result.projection != null
              ? RentalDetailsPage(
                  projection: result.projection! as PublishedRentalDiscoveryEntity,
                )
              : const DetailsShell(
                  state: DetailsScreenUnavailable(
                    reason: DetailsUnavailableReason.notFound,
                  ),
                ),
          // Unreachable today: detailsLookupRegistryProvider
          // (`app/application/details_resolution_providers.dart`)
          // registers no loader for these four types, so
          // ResolveDetailsUseCase always returns notFound for them first.
          // A later slice that registers one of these must add its own
          // branch here too — this fallback is a safe default, not a
          // silent substitute for that.
          CatalogObjectType.session ||
          CatalogObjectType.scenario ||
          CatalogObjectType.findPeople ||
          CatalogObjectType.classWorkshop => const DetailsShell(
            state: DetailsScreenUnavailable(
              reason: DetailsUnavailableReason.notFound,
            ),
          ),
        };
      },
    );
  }
}
