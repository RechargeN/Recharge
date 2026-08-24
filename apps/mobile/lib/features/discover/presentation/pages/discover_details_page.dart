import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/application/visit_history_providers.dart';
import '../../../../app/presentation/scenario_object_intake_sheet.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/telemetry/analytics_service.dart';
import '../../../../shared/models/catalog_object_ref.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../auth/application/controllers/auth_controller.dart';
import '../../../auth/presentation/widgets/auth_gate_sheet.dart';
import '../../../favorites/application/controllers/favorites_controller.dart';
import '../../../favorites/application/favorites_providers.dart';
import '../../../favorites/domain/entities/favorite_item_entity.dart';
import '../../application/discover_providers.dart';
import '../../domain/entities/discover_item_entity.dart';
import '../renderers/route_details_renderer.dart';
import '../shell/compatibility_object_renderer.dart';
import '../shell/details_renderer.dart';
import '../shell/details_shell.dart';

/// Page-level wiring for the Details flow. Since `DTL-FND-01`, all chrome
/// and content rendering live in [DetailsShell]/[DetailsRenderer]
/// (`../shell/`) — this class only resolves the current load state into a
/// [DetailsScreenState], builds the callbacks a renderer needs, and keeps
/// the side-effecting page-level flows (favorites, visit history, scenario
/// intake, route safety reports) that predate the shell split.
///
/// `docs/product/DTL_FND_01_DETAILS_SHELL_SLICE_SPEC.md` §3: this page was
/// the shell's first real consumer, rendering every item via
/// [CompatibilityObjectRenderer] with zero behavior change from the
/// pre-shell layout. Since `DTL-RTE-01`, `route`-classified items
/// dispatch to [RouteDetailsRenderer] instead — [CompatibilityObjectRenderer]
/// now only ever renders Event/Activity/Place.
class DiscoverDetailsPage extends ConsumerStatefulWidget {
  const DiscoverDetailsPage({
    super.key,
    required this.itemId,
    required this.favoriteApplied,
  });

  final String itemId;
  final bool favoriteApplied;

  @override
  ConsumerState<DiscoverDetailsPage> createState() =>
      _DiscoverDetailsPageState();
}

class _DiscoverDetailsPageState extends ConsumerState<DiscoverDetailsPage> {
  late final AnalyticsService _analyticsService;
  bool _viewTracked = false;
  bool _errorTracked = false;
  bool _favoriteHandled = false;
  bool _ctaSubmitted = false;

  @override
  void initState() {
    super.initState();
    _analyticsService = sl<AnalyticsService>();
    _analyticsService.track(
      'discover_details_load_started',
      params: <String, Object?>{'item_id': widget.itemId},
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(favoritesControllerProvider).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AuthController authController = ref.watch(authControllerProvider);
    final bool isAuthenticated = authController.state.isAuthenticated;
    final FavoritesController favoritesController = ref.watch(
      favoritesControllerProvider,
    );
    final bool isFavorite = favoritesController.isFavorite(widget.itemId);
    final details = ref.watch(discoverDetailsProvider(widget.itemId));
    final intakeEnabled = isScenarioObjectIntakeSurfaceEnabled(
      ref,
      ScenarioObjectIntakeSurface.details,
    );

    final DetailsScreenState state = details.when(
      data: (DiscoverItemEntity item) {
        _trackViewOnce(item);
        _tryAutoApplyFavorite(
          item: item,
          isAuthenticated: isAuthenticated,
          favoritesController: favoritesController,
        );
        // Shared by both renderer families below (DTL-RTE-01): the
        // callback shapes are identical, only which family gets *built*
        // differs, decided by item.catalogObjectType. Local function
        // declarations (not `final VoidCallback x = () {...}`) per
        // `prefer_function_declarations_over_variables`.
        Future<void> onFavoriteTap() async {
          await _onFavoriteTap(
            item: item,
            isAuthenticated: isAuthenticated,
            authController: authController,
            favoritesController: favoritesController,
          );
        }

        Future<void> onShareTap() async {
          final String canonicalPath = RouteNames.discoverDetailsCanonicalFor(
            CatalogObjectRef(
              objectType: item.catalogObjectType,
              objectId: item.id,
            ),
          );
          await Clipboard.setData(
            ClipboardData(text: 'recharge:/$canonicalPath'),
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Ссылка скопирована')));
        }

        void onMap() => context.push(_mapLocationForDetails(item));
        void onRouteMap() {
          context.push(_scenarioMapLocationForDetails(item));
        }

        final VoidCallback? onAddToScenario = intakeEnabled
            ? () => _onAddToScenario(item: item)
            : null;
        void onSearch() {
          context.push(_searchLocationForDetails(item));
        }

        void onCreateSimilar() {
          context.push(_createLocationForDetails(item));
        }

        void onCreateRoute() {
          context.push(_createRouteLocationForDetails(item));
        }

        void onMarkVisited() =>
            _onMarkVisited(item: item, authController: authController);
        void onCtaTap() => _onCtaTap(item);
        void onReportRoute() =>
            _reportRoute(item: item, authController: authController);

        final DetailsRendererRegistry registry = DetailsRendererRegistry(
          <DetailsRendererFamily, DetailsRendererBuilder>{
            DetailsRendererFamily.objectOffer: () =>
                CompatibilityObjectRenderer(
                  item: item,
                  isFavorite: isFavorite,
                  ctaSubmitted: _ctaSubmitted,
                  onFavoriteTap: onFavoriteTap,
                  onShareTap: onShareTap,
                  onMap: onMap,
                  onRouteMap: onRouteMap,
                  onAddToScenario: onAddToScenario,
                  onSearch: onSearch,
                  onCreateSimilar: onCreateSimilar,
                  onCreateRoute: onCreateRoute,
                  onMarkVisited: onMarkVisited,
                  onCtaTap: onCtaTap,
                  onReportRoute: onReportRoute,
                ),
            DetailsRendererFamily.route: () => RouteDetailsRenderer(
              item: item,
              isFavorite: isFavorite,
              ctaSubmitted: _ctaSubmitted,
              onFavoriteTap: onFavoriteTap,
              onShareTap: onShareTap,
              onMap: onMap,
              onRouteMap: onRouteMap,
              onAddToScenario: onAddToScenario,
              onSearch: onSearch,
              onCreateSimilar: onCreateSimilar,
              onCreateRoute: onCreateRoute,
              onMarkVisited: onMarkVisited,
              onCtaTap: onCtaTap,
              onReportRoute: onReportRoute,
            ),
          },
        );
        final DetailsRendererFamily family =
            item.catalogObjectType == CatalogObjectType.route
            ? DetailsRendererFamily.route
            : DetailsRendererFamily.objectOffer;
        return DetailsScreenAvailable(renderer: registry.build(family));
      },
      loading: () => const DetailsScreenLoading(),
      error: (_, __) {
        _trackErrorOnce();
        return DetailsScreenUnavailable(
          reason: DetailsUnavailableReason.temporarilyUnavailable,
          onRetry: () {
            _errorTracked = false;
            ref.invalidate(discoverDetailsProvider(widget.itemId));
          },
        );
      },
    );

    return DetailsShell(state: state);
  }

  void _trackViewOnce(DiscoverItemEntity item) {
    if (_viewTracked) return;
    _viewTracked = true;
    _analyticsService.track(
      'discover_details_viewed',
      params: <String, Object?>{
        'item_id': item.id,
        'category': item.category,
        'city': item.city,
      },
    );
  }

  void _trackErrorOnce() {
    if (_errorTracked) return;
    _errorTracked = true;
    _analyticsService.track(
      'discover_details_load_failed',
      params: <String, Object?>{'item_id': widget.itemId},
    );
  }

  void _tryAutoApplyFavorite({
    required DiscoverItemEntity item,
    required bool isAuthenticated,
    required FavoritesController favoritesController,
  }) {
    if (!widget.favoriteApplied || _favoriteHandled || !isAuthenticated) {
      return;
    }
    _favoriteHandled = true;
    if (favoritesController.isFavorite(item.id)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await favoritesController.addFavorite(
        _toFavorite(item),
        sourceScreen: 'discover_details',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Сохранено в избранное')));
    });
  }

  Future<void> _onFavoriteTap({
    required DiscoverItemEntity item,
    required bool isAuthenticated,
    required AuthController authController,
    required FavoritesController favoritesController,
  }) async {
    if (!isAuthenticated) {
      authController.trackAuthGateViewed(
        sourceScreen: 'discover_details',
        sourceAction: 'favorite_tap',
      );
      await showAuthGateSheet(
        context,
        action: ProtectedAction.favorite,
        sourceScreen: 'discover_details',
        sourceAction: 'favorite_tap',
        originRoute: RouteNames.discoverDetailsCanonicalFor(
          CatalogObjectRef(objectType: item.catalogObjectType, objectId: item.id),
        ),
        onContinueAsGuest: () {
          authController.trackGuestContinueClicked(
            sourceScreen: 'discover_details',
            sourceAction: 'favorite_tap',
          );
        },
      );
      return;
    }

    await favoritesController.toggleFavorite(
      _toFavorite(item),
      sourceScreen: 'discover_details',
    );
  }

  Future<void> _reportRoute({
    required DiscoverItemEntity item,
    required AuthController authController,
  }) async {
    final user = authController.state.user;
    if (user == null) {
      authController.trackAuthGateViewed(
        sourceScreen: 'discover_details',
        sourceAction: 'route_safety_report',
      );
      await showAuthGateSheet(
        context,
        action: ProtectedAction.report,
        sourceScreen: 'discover_details',
        sourceAction: 'route_safety_report',
        originRoute: RouteNames.discoverDetailsCanonicalFor(
          CatalogObjectRef(objectType: item.catalogObjectType, objectId: item.id),
        ),
        onContinueAsGuest: () {
          authController.trackGuestContinueClicked(
            sourceScreen: 'discover_details',
            sourceAction: 'route_safety_report',
          );
        },
      );
      return;
    }

    final input = await showDialog<RouteSafetyReportInput>(
      context: context,
      builder: (context) => const RouteSafetyReportDialog(),
    );
    if (input == null || !mounted) return;

    try {
      await ref.read(submitRouteSafetyReportProvider)(
        routeId: item.id,
        reporterId: user.id,
        reasonCode: input.reasonCode,
        severity: input.severity,
        safeNote: input.safeNote,
      );
      _analyticsService.track(
        'route_safety_report_submitted',
        params: <String, Object?>{
          'route_id': item.id,
          'reason_code': input.reasonCode,
          'severity': input.severity.name,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Спасибо. Сообщение передано на проверку.'),
        ),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось отправить сообщение. Попробуйте ещё раз.'),
        ),
      );
    }
  }

  void _onCtaTap(DiscoverItemEntity item) {
    setState(() {
      _ctaSubmitted = true;
    });
    _analyticsService.track(
      'discover_details_cta_clicked',
      params: <String, Object?>{
        'item_id': item.id,
        'category': item.category,
        'price_amount': item.priceAmount,
      },
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${ctaLabelForDetails(item)}: заявка отправлена')),
    );
  }

  Future<void> _onMarkVisited({
    required DiscoverItemEntity item,
    required AuthController authController,
  }) async {
    final user = authController.state.user;
    if (user == null) {
      authController.trackAuthGateViewed(
        sourceScreen: 'discover_details',
        sourceAction: 'mark_visited',
      );
      await showAuthGateSheet(
        context,
        action: ProtectedAction.visit,
        sourceScreen: 'discover_details',
        sourceAction: 'mark_visited',
        originRoute: RouteNames.discoverDetailsCanonicalFor(
          CatalogObjectRef(objectType: item.catalogObjectType, objectId: item.id),
        ),
        onContinueAsGuest: () {
          authController.trackGuestContinueClicked(
            sourceScreen: 'discover_details',
            sourceAction: 'mark_visited',
          );
        },
      );
      return;
    }

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'When did you visit?',
    );
    if (selected == null || !mounted) return;

    try {
      await ref
          .read(visitHistoryFacadeProvider)
          .recordSelfReported(
            userId: user.id,
            item: item,
            visitedOn: selected,
            today: today,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added to Visit history · '
            '${MaterialLocalizations.of(context).formatMediumDate(selected)}',
          ),
        ),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update Visit history')),
      );
    }
  }

  Future<void> _onAddToScenario({required DiscoverItemEntity item}) async {
    final result = await launchScenarioObjectIntake(
      context: context,
      ref: ref,
      items: <DiscoverItemEntity>[item],
      sourceSurface: ScenarioObjectIntakeSurface.details,
      sourceScreen: 'discover_details',
      sourceAction: 'add_to_scenario',
      originRoute: RouteNames.discoverDetailsCanonicalFor(
        CatalogObjectRef(objectType: item.catalogObjectType, objectId: item.id),
      ),
    );
    if (result == null || !mounted) return;
    if (result.openScenario) {
      final uri = Uri(
        path: '${RouteNames.createObject}/scenario',
        queryParameters: <String, String>{
          'scenarioDraftId': result.targetDraftId,
        },
      );
      await context.push(uri.toString());
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${result.itemCount} item to Scenario')),
    );
  }

  FavoriteItemEntity _toFavorite(DiscoverItemEntity item) {
    return FavoriteItemEntity(
      id: item.id,
      title: item.title,
      subtitle: item.subtitle,
      city: item.city,
      category: item.category,
      startsAtUtc: item.startsAtUtc,
      distanceKm: item.distanceKm,
      priceAmount: item.priceAmount,
      isFree: item.isFree,
      savedAtUtc: DateTime.now().toUtc(),
      targetRoute: null,
      coverImageUrl: item.coverImageUrl,
    );
  }
}

String _mapLocationForDetails(DiscoverItemEntity item) {
  return Uri(
    path: RouteNames.discoverMap,
    queryParameters: <String, String>{
      'q': item.title,
      'category': item.category,
      'free': item.isFree ? '1' : '0',
      'radius': '5000',
      'unlimited': '0',
      'itemId': item.id,
      'itemLat': item.latitude.toStringAsFixed(6),
      'itemLng': item.longitude.toStringAsFixed(6),
      'source': 'route_details',
    },
  ).toString();
}

String _searchLocationForDetails(DiscoverItemEntity item) {
  return Uri(
    path: RouteNames.search,
    queryParameters: <String, String>{
      'q': item.title,
      'category': item.category,
      'free': item.isFree ? '1' : '0',
      'radius': '5000',
      'unlimited': '0',
    },
  ).toString();
}

String _scenarioMapLocationForDetails(DiscoverItemEntity item) {
  return Uri(
    path: RouteNames.discoverMap,
    queryParameters: routeSeedForDetails(item, includeMode: true),
  ).toString();
}

String _createLocationForDetails(DiscoverItemEntity item) {
  return Uri(
    path: RouteNames.create,
    queryParameters: <String, String>{
      'source': 'details',
      'type': 'event',
      'title': item.title,
      'q': item.title,
      'subtitle': item.subtitle,
      'category': item.category,
      'city': item.city,
      'venue': item.venueName,
      'address': item.addressLine,
      'free': item.isFree ? '1' : '0',
      if (!item.isFree) 'budgetMax': item.priceAmount.toStringAsFixed(0),
      'cover': item.coverImageUrl,
      'start': item.startsAtUtc.toIso8601String(),
    },
  ).toString();
}

String _createRouteLocationForDetails(DiscoverItemEntity item) {
  return Uri(
    path: RouteNames.create,
    queryParameters: <String, String>{
      ...routeSeedForDetails(item, includeMode: false),
      'source': 'details_route_seed',
      'type': 'route',
      'title': routeSeedTitle(item),
      'subtitle': routeSeedSubtitle(item),
      'q': routeSeedPrompt(item),
      'category': 'route',
      'city': item.city,
      'venue': item.venueName,
      'address': item.addressLine,
      'cover': item.coverImageUrl,
    },
  ).toString();
}
