import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/config/recharge_taxonomy.dart';
import '../../../../core/telemetry/analytics_service.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../auth/application/controllers/auth_controller.dart';
import '../../../auth/presentation/widgets/auth_gate_sheet.dart';
import '../../../create/application/create_taxonomy.dart';
import '../../../favorites/application/controllers/favorites_controller.dart';
import '../../../favorites/application/favorites_providers.dart';
import '../../../favorites/domain/entities/favorite_item_entity.dart';
import '../../application/discover_providers.dart';
import '../../domain/entities/discover_item_entity.dart';
import '../../domain/entities/time_fit_evaluation.dart';

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

    return details.when(
      data: (DiscoverItemEntity item) {
        _trackViewOnce(item);
        _tryAutoApplyFavorite(
          item: item,
          isAuthenticated: isAuthenticated,
          favoritesController: favoritesController,
        );
        return Scaffold(
          appBar: AppBar(
            title: const Text('RECHARGE'),
            actions: <Widget>[
              IconButton(
                tooltip: isFavorite ? 'Unsave' : 'Save',
                onPressed: () async {
                  await _onFavoriteTap(
                    item: item,
                    isAuthenticated: isAuthenticated,
                    authController: authController,
                    favoritesController: favoritesController,
                  );
                },
                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
              ),
              IconButton(
                tooltip: 'Share',
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: 'recharge://discover/details/${item.id}',
                    ),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ссылка скопирована')),
                  );
                },
                icon: const Icon(Icons.ios_share_rounded),
              ),
            ],
          ),
          body: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              _DetailsHero(item: item),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _SummaryCard(item: item),
                    const SizedBox(height: 12),
                    _DetailsActionHub(
                      item: item,
                      isFavorite: isFavorite,
                      ctaSubmitted: _ctaSubmitted,
                      onFavoriteTap: () async {
                        await _onFavoriteTap(
                          item: item,
                          isAuthenticated: isAuthenticated,
                          authController: authController,
                          favoritesController: favoritesController,
                        );
                      },
                      onMap: () => context.push(_mapLocationForDetails(item)),
                      onRouteMap: () {
                        context.push(_scenarioMapLocationForDetails(item));
                      },
                      onScenario: () {
                        context.push(_scenarioLocationForDetails(item));
                      },
                      onSearch: () {
                        context.push(_searchLocationForDetails(item));
                      },
                      onCreateSimilar: () {
                        context.push(_createLocationForDetails(item));
                      },
                      onCreateRoute: () {
                        context.push(_createRouteLocationForDetails(item));
                      },
                      onCtaTap: () => _onCtaTap(item),
                    ),
                    const SizedBox(height: 12),
                    _OrganizerCard(item: item),
                    const SizedBox(height: 12),
                    _InfoGrid(item: item),
                    const SizedBox(height: 12),
                    _HighlightsCard(item: item),
                    const SizedBox(height: 12),
                    _LocationCard(
                      item: item,
                      onOpenMap: () =>
                          context.push(_mapLocationForDetails(item)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: _DetailsBottomBar(
            item: item,
            isFavorite: isFavorite,
            ctaSubmitted: _ctaSubmitted,
            onFavoriteTap: () async {
              await _onFavoriteTap(
                item: item,
                isAuthenticated: isAuthenticated,
                authController: authController,
                favoritesController: favoritesController,
              );
            },
            onCtaTap: () => _onCtaTap(item),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Details')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) {
        _trackErrorOnce();
        return Scaffold(
          appBar: AppBar(title: const Text('Details')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('Не удалось загрузить details'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      _errorTracked = false;
                      ref.invalidate(discoverDetailsProvider(widget.itemId));
                    },
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
        originRoute: '${RouteNames.discoverDetails}/${item.id}',
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
      SnackBar(content: Text('${_ctaLabel(item)}: заявка отправлена')),
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

class _DetailsHero extends StatelessWidget {
  const _DetailsHero({required this.item});

  final DiscoverItemEntity item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 1.35,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (item.coverImageUrl.isNotEmpty)
                Image.network(
                  item.coverImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _CoverFallback(item: item),
                )
              else
                _CoverFallback(item: item),
              Positioned(
                left: 12,
                top: 12,
                child: _CategoryBadge(
                  label: rechargeTaxonomyLabel(item.category).toUpperCase(),
                ),
              ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(color: RechargeTheme.travelGreen),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_dateTimeLabel(item.startsAtUtc)} · ${_priceLabel(item)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.item});

  final DiscoverItemEntity item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: RechargeTheme.travelGreenDark),
      child: Center(
        child: Icon(
          _categoryIcon(item.category),
          color: Colors.white,
          size: 72,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.item});

  final DiscoverItemEntity item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              item.subtitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MetricTile(
                    icon: Icons.payments_outlined,
                    label: 'Price',
                    value: _priceLabel(item),
                  ),
                ),
                Expanded(
                  child: _MetricTile(
                    icon: Icons.group_outlined,
                    label: 'People',
                    value: _participantsLabel(item),
                  ),
                ),
                Expanded(
                  child: _MetricTile(
                    icon: Icons.schedule_outlined,
                    label: 'Duration',
                    value: _durationLabel(item),
                  ),
                ),
              ],
            ),
            if (item.timeFitEvaluation case final evaluation?) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _DetailsPill(label: _detailsTimeFitLabel(evaluation)),
                  _DetailsPill(label: _detailsOpeningLabel(evaluation)),
                  if (evaluation.travelMinutes != null)
                    _DetailsPill(
                      label:
                          '${evaluation.travelMinutes} min travel'
                          '${evaluation.quality == TravelEstimateQuality.fallback || evaluation.quality == TravelEstimateQuality.modeled ? ' · estimated' : ''}',
                    ),
                  if (evaluation.selectedSlotId != null)
                    _DetailsPill(label: 'Slot ${evaluation.selectedSlotId}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        Icon(icon, color: colorScheme.primary),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DetailsActionHub extends StatelessWidget {
  const _DetailsActionHub({
    required this.item,
    required this.isFavorite,
    required this.ctaSubmitted,
    required this.onFavoriteTap,
    required this.onMap,
    required this.onRouteMap,
    required this.onScenario,
    required this.onSearch,
    required this.onCreateSimilar,
    required this.onCreateRoute,
    required this.onCtaTap,
  });

  final DiscoverItemEntity item;
  final bool isFavorite;
  final bool ctaSubmitted;
  final Future<void> Function() onFavoriteTap;
  final VoidCallback onMap;
  final VoidCallback onRouteMap;
  final VoidCallback onScenario;
  final VoidCallback onSearch;
  final VoidCallback onCreateSimilar;
  final VoidCallback onCreateRoute;
  final VoidCallback onCtaTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final _DetailsRoutePlan routePlan = _routePlanForDetails(item);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.route, color: RechargeTheme.travelGreenDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Plan this recharge',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: RechargeTheme.travelGreenDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _DetailsPill(label: isFavorite ? 'Saved' : 'Not saved'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Turn this activity into a route, compare similar options, or save it for later.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _DetailsPill(label: rechargeTaxonomyLabel(item.category)),
                _DetailsPill(label: _priceLabel(item)),
                _DetailsPill(label: _participantsLabel(item)),
              ],
            ),
            const SizedBox(height: 12),
            _DetailsRoutePreview(
              plan: routePlan,
              onRouteMap: onRouteMap,
              onCreateRoute: onCreateRoute,
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: ctaSubmitted ? null : onCtaTap,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      ctaSubmitted ? 'Request sent' : _ctaLabel(item),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.outlined(
                  tooltip: isFavorite ? 'Unsave' : 'Save',
                  onPressed: () async {
                    await onFavoriteTap();
                  },
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.82,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              children: <Widget>[
                _DetailsActionTile(
                  icon: Icons.map_outlined,
                  title: 'Map',
                  subtitle: 'Open nearby context',
                  onTap: onMap,
                ),
                _DetailsActionTile(
                  icon: Icons.auto_awesome,
                  title: 'Build route',
                  subtitle: 'Seed Scenario Builder',
                  onTap: onScenario,
                ),
                _DetailsActionTile(
                  icon: Icons.search,
                  title: 'Find similar',
                  subtitle: 'Search with this category',
                  onTap: onSearch,
                ),
                _DetailsActionTile(
                  icon: Icons.add_circle_outline,
                  title: 'Create similar',
                  subtitle: 'Open Create Hub',
                  onTap: onCreateSimilar,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsActionTile extends StatelessWidget {
  const _DetailsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Ink(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: RechargeTheme.travelPanel,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: RechargeTheme.travelLine),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: RechargeTheme.travelGreenDark),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsRoutePreview extends StatelessWidget {
  const _DetailsRoutePreview({
    required this.plan,
    required this.onRouteMap,
    required this.onCreateRoute,
  });

  final _DetailsRoutePlan plan;
  final VoidCallback onRouteMap;
  final VoidCallback onCreateRoute;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RechargeTheme.travelPanel,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: RechargeTheme.travelLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.alt_route,
                  color: RechargeTheme.travelGreenDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Route from this',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: RechargeTheme.travelGreenDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _DetailsPill(label: '${plan.stepCategories.length} stops'),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _DetailsPill(label: plan.mood),
                _DetailsPill(label: '${plan.durationMinutes} min'),
                if (plan.freeOnly) const _DetailsPill(label: 'Free'),
                if (plan.walkingOnly) const _DetailsPill(label: 'Walking'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              plan.stepLabels.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRouteMap,
                    icon: const Icon(Icons.map_outlined),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Route map'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCreateRoute,
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Create route'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsPill extends StatelessWidget {
  const _DetailsPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RechargeTheme.travelPanel,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: RechargeTheme.travelLine),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _OrganizerCard extends StatelessWidget {
  const _OrganizerCard({required this.item});

  final DiscoverItemEntity item;

  @override
  Widget build(BuildContext context) {
    final String organizerName = item.organizerName.isEmpty
        ? 'Recharge ${item.category}'
        : item.organizerName;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 24,
              backgroundColor: RechargeTheme.travelPanel,
              child: Text(
                organizerName[0].toUpperCase(),
                style: TextStyle(
                  color: RechargeTheme.travelGreenDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Organizer',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    organizerName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (item.organizerHandle.isNotEmpty)
                    Text(
                      item.organizerHandle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: RechargeTheme.travelGreenDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.verified_rounded,
              color: RechargeTheme.travelGreen,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.item});

  final DiscoverItemEntity item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: <Widget>[
            _InfoRow(
              icon: Icons.calendar_month_outlined,
              label: 'Date and time',
              value: _dateTimeLabel(item.startsAtUtc),
            ),
            const Divider(height: 20),
            _InfoRow(
              icon: Icons.place_outlined,
              label: 'Location',
              value: _venueLabel(item),
            ),
            const Divider(height: 20),
            _InfoRow(
              icon: Icons.near_me_outlined,
              label: 'Distance',
              value: '${item.distanceKm.toStringAsFixed(1)} км from you',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: RechargeTheme.travelGreenDark),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HighlightsCard extends StatelessWidget {
  const _HighlightsCard({required this.item});

  final DiscoverItemEntity item;

  @override
  Widget build(BuildContext context) {
    final List<String> highlights = item.highlights.isEmpty
        ? <String>[
            'Clear meeting point and timing',
            'Organizer details available before joining',
            'Save the activity for later',
          ]
        : item.highlights;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'What awaits you',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ...highlights.map(
              (String highlight) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.check_circle_rounded,
                      color: RechargeTheme.travelGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(highlight)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.item, required this.onOpenMap});

  final DiscoverItemEntity item;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenMap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: RechargeTheme.travelPanel,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: RechargeTheme.travelLine),
                ),
                child: Icon(
                  Icons.map_outlined,
                  color: RechargeTheme.travelGreenDark,
                  size: 34,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.venueName.isEmpty ? item.city : item.venueName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.addressLine.isEmpty ? item.city : item.addressLine,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Show on map',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: RechargeTheme.travelGreenDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: RechargeTheme.travelGreenDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsBottomBar extends StatelessWidget {
  const _DetailsBottomBar({
    required this.item,
    required this.isFavorite,
    required this.ctaSubmitted,
    required this.onFavoriteTap,
    required this.onCtaTap,
  });

  final DiscoverItemEntity item;
  final bool isFavorite;
  final bool ctaSubmitted;
  final Future<void> Function() onFavoriteTap;
  final VoidCallback onCtaTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: RechargeTheme.travelLine)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: ctaSubmitted ? null : onCtaTap,
                  child: Text(
                    ctaSubmitted ? 'Заявка отправлена' : _ctaLabel(item),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: isFavorite ? 'Unsave' : 'Save',
                onPressed: () async {
                  await onFavoriteTap();
                },
                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: RechargeTheme.travelLine),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: RechargeTheme.travelGreenDark,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

String _dateTimeLabel(DateTime value) {
  final DateTime local = value.toLocal();
  final String day = local.day.toString().padLeft(2, '0');
  final String month = local.month.toString().padLeft(2, '0');
  final String hour = local.hour.toString().padLeft(2, '0');
  final String minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.${local.year} · $hour:$minute';
}

String _priceLabel(DiscoverItemEntity item) {
  if (item.isFree) return 'Free';
  return '${item.priceAmount.toStringAsFixed(0)} €';
}

String _detailsTimeFitLabel(TimeFitEvaluation evaluation) =>
    switch (evaluation.timeFitStatus) {
      TimeFitStatus.fits => 'Fits your time',
      TimeFitStatus.partial => 'Partial attendance possible',
      TimeFitStatus.doesNotFit => 'Does not fit',
      TimeFitStatus.unknown => 'Time not confirmed',
    };

String _detailsOpeningLabel(TimeFitEvaluation evaluation) =>
    switch (evaluation.openingStatus) {
      OpeningStatus.open => 'Open',
      OpeningStatus.closed => 'Closed',
      OpeningStatus.unknown => 'Opening hours unknown',
    };

String _participantsLabel(DiscoverItemEntity item) {
  if (item.capacity == null) return 'Capacity unknown';
  if (item.participantsCount == null) return 'Participants unknown';
  return '${item.participantsCount}/${item.capacity}';
}

String _durationLabel(DiscoverItemEntity item) {
  final int? duration = item.durationMinutes;
  if (duration == null) return 'Flexible';
  if (duration < 60) return '$duration min';
  final int hours = duration ~/ 60;
  final int minutes = duration % 60;
  if (minutes == 0) return '$hours h';
  return '$hours h $minutes min';
}

String _venueLabel(DiscoverItemEntity item) {
  if (item.venueName.isNotEmpty && item.addressLine.isNotEmpty) {
    return '${item.venueName}, ${item.addressLine}';
  }
  if (item.venueName.isNotEmpty) return item.venueName;
  if (item.addressLine.isNotEmpty) return item.addressLine;
  return item.city;
}

class _DetailsRoutePlan {
  const _DetailsRoutePlan({
    required this.mood,
    required this.durationMinutes,
    required this.freeOnly,
    required this.walkingOnly,
    required this.prompt,
    required this.stepCategories,
  });

  final String mood;
  final int durationMinutes;
  final bool freeOnly;
  final bool walkingOnly;
  final String prompt;
  final List<String> stepCategories;

  List<String> get stepLabels {
    return stepCategories
        .map(createTaxonomyLabelForPath)
        .toList(growable: false);
  }
}

_DetailsRoutePlan _routePlanForDetails(DiscoverItemEntity item) {
  return _DetailsRoutePlan(
    mood: _scenarioMoodForDetails(item),
    durationMinutes: (item.durationMinutes ?? 0) > 120
        ? item.durationMinutes!
        : 120,
    freeOnly: item.isFree,
    walkingOnly: true,
    prompt: '${item.title} · ${item.category} · ${item.city}',
    stepCategories: _routeStepCategoriesForDetails(item),
  );
}

List<String> _routeStepCategoriesForDetails(DiscoverItemEntity item) {
  final String normalizedTitle = item.title.toLowerCase();
  if (normalizedTitle.contains('tennis')) {
    return const <String>['sport.tennis', 'outdoor_nature_walking.city_walk'];
  }

  switch (normalizeRechargeContentGroupId(item.category)) {
    case 'outdoor_nature_walking':
      return const <String>[
        'outdoor_nature_walking.city_walk',
        'food_drinks.coffee',
      ];
    case 'art_culture_museums':
      return const <String>['art_culture_museums.museum', 'food_drinks.coffee'];
    case 'music_nightlife':
      return const <String>[
        'music_nightlife.live_music',
        'music_nightlife.afterwork_drinks',
      ];
    case 'family_kids':
      return const <String>['games_indoor.board_games', 'food_drinks.brunch'];
    case 'wellness_recharge':
      return const <String>[
        'wellness_recharge.calm_walk',
        'food_drinks.coffee',
      ];
    default:
      return const <String>[
        'food_drinks.coffee',
        'wellness_recharge.calm_walk',
      ];
  }
}

Map<String, String> _routeSeedForDetails(
  DiscoverItemEntity item, {
  required bool includeMode,
}) {
  final _DetailsRoutePlan plan = _routePlanForDetails(item);
  return <String, String>{
    if (includeMode) 'mode': 'scenario',
    'mood': plan.mood,
    'duration': plan.durationMinutes.toString(),
    'free': plan.freeOnly ? '1' : '0',
    'walking': plan.walkingOnly ? '1' : '0',
    'prompt': plan.prompt,
    'steps': plan.stepCategories.join(','),
  };
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

String _scenarioLocationForDetails(DiscoverItemEntity item) {
  return Uri(
    path: RouteNames.scenarioBuilder,
    queryParameters: _routeSeedForDetails(item, includeMode: false),
  ).toString();
}

String _scenarioMapLocationForDetails(DiscoverItemEntity item) {
  return Uri(
    path: RouteNames.discoverMap,
    queryParameters: _routeSeedForDetails(item, includeMode: true),
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
  final _DetailsRoutePlan plan = _routePlanForDetails(item);
  return Uri(
    path: RouteNames.create,
    queryParameters: <String, String>{
      ..._routeSeedForDetails(item, includeMode: false),
      'source': 'scenario',
      'type': 'event',
      'title': '${item.title} route',
      'subtitle':
          '${plan.stepCategories.length} stops · '
          '${plan.durationMinutes} min · from details',
      'q': plan.prompt,
      'category': 'scenario',
      'city': item.city,
      'venue': item.venueName,
      'address': item.addressLine,
      'cover': item.coverImageUrl,
    },
  ).toString();
}

String _scenarioMoodForDetails(DiscoverItemEntity item) {
  final String category = normalizeRechargeContentGroupId(item.category);
  if (category == 'outdoor_nature_walking' || category == 'sport') {
    return 'active';
  }
  if (category == 'music_nightlife' ||
      category == 'art_culture_museums' ||
      category == 'family_kids') {
    return 'social';
  }
  return 'calm';
}

String _ctaLabel(DiscoverItemEntity item) {
  if (item.ctaLabel.isNotEmpty) return item.ctaLabel;
  if (item.isFree) return 'Join activity';
  return 'Book for ${_priceLabel(item)}';
}

IconData _categoryIcon(String category) {
  switch (normalizeRechargeContentGroupId(category)) {
    case 'wellness_recharge':
      return Icons.self_improvement_rounded;
    case 'outdoor_nature_walking':
      return Icons.park_outlined;
    case 'art_culture_museums':
      return Icons.palette_outlined;
    case 'music_nightlife':
      return Icons.music_note_rounded;
    case 'family_kids':
      return Icons.family_restroom_rounded;
    default:
      return Icons.local_activity_outlined;
  }
}
