import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/recharge_taxonomy.dart';
import '../../../create/application/create_taxonomy.dart';
import '../../domain/entities/discover_item_entity.dart';
import '../../domain/entities/time_fit_evaluation.dart';
import '../../domain/repositories/route_safety_reporting_port.dart';
import 'details_renderer.dart';

/// [DetailsRenderer] that reproduces, unchanged, the Details layout that
/// shipped before `DTL-FND-01`: the same hero, summary, published-route
/// card, action hub, organizer, info grid, highlights, location card and
/// bottom bar — for Event, Activity, Place and (still bolted on as before)
/// Route.
///
/// `docs/product/DTL_FND_01_DETAILS_SHELL_SLICE_SPEC.md` §3: this class
/// proves the shell/renderer abstraction works for a real consumer. It
/// does **not** implement the target Object/Offer section matrix
/// (`DISCOVER_DETAILS_SYSTEM_SPEC.md` §5) — that is `DTL-OBJ-01`'s job.
/// Route stays in its today-shape "bolted onto the generic card" form —
/// that is `DTL-RTE-01`'s job to replace, not this class's.
class CompatibilityObjectRenderer implements DetailsRenderer {
  const CompatibilityObjectRenderer({
    required this.item,
    required this.isFavorite,
    required this.ctaSubmitted,
    required this.onFavoriteTap,
    required this.onShareTap,
    required this.onMap,
    required this.onRouteMap,
    required this.onAddToScenario,
    required this.onSearch,
    required this.onCreateSimilar,
    required this.onCreateRoute,
    required this.onMarkVisited,
    required this.onCtaTap,
    required this.onReportRoute,
  });

  final DiscoverItemEntity item;
  final bool isFavorite;
  final bool ctaSubmitted;
  final VoidCallback onFavoriteTap;
  final VoidCallback onShareTap;
  final VoidCallback onMap;
  final VoidCallback onRouteMap;
  final VoidCallback? onAddToScenario;
  final VoidCallback onSearch;
  final VoidCallback onCreateSimilar;
  final VoidCallback onCreateRoute;
  final VoidCallback onMarkVisited;
  final VoidCallback onCtaTap;
  final VoidCallback onReportRoute;

  @override
  List<Widget> buildAppBarActions(BuildContext context) {
    return <Widget>[
      IconButton(
        tooltip: isFavorite ? 'Unsave' : 'Save',
        onPressed: onFavoriteTap,
        icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
      ),
      IconButton(
        tooltip: 'Share',
        onPressed: onShareTap,
        icon: const Icon(Icons.ios_share_rounded),
      ),
    ];
  }

  @override
  Widget buildHero(BuildContext context) => _DetailsHero(item: item);

  @override
  Widget buildBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SummaryCard(item: item),
          if (item.isPublishedRoute) ...<Widget>[
            const SizedBox(height: 12),
            _PublishedRouteCard(item: item, onReport: onReportRoute),
          ],
          const SizedBox(height: 12),
          _DetailsActionHub(
            item: item,
            isFavorite: isFavorite,
            ctaSubmitted: ctaSubmitted,
            onFavoriteTap: onFavoriteTap,
            onMap: onMap,
            onRouteMap: onRouteMap,
            onAddToScenario: onAddToScenario,
            onSearch: onSearch,
            onCreateSimilar: onCreateSimilar,
            onCreateRoute: onCreateRoute,
            onMarkVisited: onMarkVisited,
            onCtaTap: onCtaTap,
          ),
          const SizedBox(height: 12),
          _OrganizerCard(item: item),
          const SizedBox(height: 12),
          _InfoGrid(item: item),
          const SizedBox(height: 12),
          _HighlightsCard(item: item),
          const SizedBox(height: 12),
          _LocationCard(item: item, onOpenMap: onMap),
        ],
      ),
    );
  }

  @override
  Widget? buildStickyAction(BuildContext context) {
    return _DetailsBottomBar(
      item: item,
      isFavorite: isFavorite,
      ctaSubmitted: ctaSubmitted,
      onFavoriteTap: onFavoriteTap,
      onCtaTap: onCtaTap,
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
    final route = item.publishedRoute;
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
                    icon: route == null
                        ? Icons.payments_outlined
                        : Icons.route_outlined,
                    label: route == null ? 'Price' : 'Length',
                    value: route == null
                        ? _priceLabel(item)
                        : '${(route.distanceMeters / 1000).toStringAsFixed(1)} км',
                  ),
                ),
                Expanded(
                  child: _MetricTile(
                    icon: route == null
                        ? Icons.group_outlined
                        : Icons.directions_walk_outlined,
                    label: route == null ? 'People' : 'Profile',
                    value: route == null
                        ? _participantsLabel(item)
                        : _routeProfileLabel(route.routingProfileId),
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

class _PublishedRouteCard extends StatelessWidget {
  const _PublishedRouteCard({required this.item, required this.onReport});

  final DiscoverItemEntity item;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final route = item.publishedRoute!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Published Route',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _DetailsPill(label: _routeProfileLabel(route.routingProfileId)),
                _DetailsPill(label: _routeDifficultyLabel(route.difficultyId)),
                if (route.recommendedDifficultyId.isNotEmpty &&
                    route.recommendedDifficultyId != route.difficultyId)
                  _DetailsPill(
                    label:
                        'Recommended '
                        '${_routeDifficultyLabel(route.recommendedDifficultyId)}',
                  ),
                if (route.ascentMeters != null)
                  _DetailsPill(label: '+${route.ascentMeters!.round()} m'),
                if (route.descentMeters != null)
                  _DetailsPill(label: '-${route.descentMeters!.round()} m'),
                _DetailsPill(label: '${route.waypointCount} POI'),
                if (route.fieldVerifiedAtUtc != null)
                  const _DetailsPill(label: 'Field verified'),
                _DetailsPill(label: 'Version ${route.versionId}'),
                if (route.demoOnly) const _DetailsPill(label: 'Demo data'),
              ],
            ),
            if (route.attributions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                route.attributions.join(' · '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (route.elevationAvailability != 'complete') ...<Widget>[
              const SizedBox(height: 10),
              Text(
                route.elevationAvailability == 'partial'
                    ? 'Elevation data is partial; ascent and descent are not '
                          'presented as complete.'
                    : 'Elevation data is unavailable and is not shown as zero.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (route.unknownSurfaceDistanceMeters > 0) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                '${route.unknownSurfaceDistanceMeters.round()} m of surface '
                'data is unknown.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onReport,
                icon: const Icon(Icons.report_outlined),
                label: const Text('Сообщить о проблеме на маршруте'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Input collected by [RouteSafetyReportDialog].
class RouteSafetyReportInput {
  const RouteSafetyReportInput({
    required this.reasonCode,
    required this.severity,
    this.safeNote,
  });

  final String reasonCode;
  final DiscoverRouteSafetySeverity severity;
  final String? safeNote;
}

/// Dialog used by the page-level `_reportRoute` flow. Public (unlike the
/// other widgets in this file) because it is shown via `showDialog` from
/// `discover_details_page.dart`, outside the renderer's own widget tree.
class RouteSafetyReportDialog extends StatefulWidget {
  const RouteSafetyReportDialog({super.key});

  @override
  State<RouteSafetyReportDialog> createState() =>
      _RouteSafetyReportDialogState();
}

class _RouteSafetyReportDialogState extends State<RouteSafetyReportDialog> {
  final TextEditingController _noteController = TextEditingController();
  String _reasonCode = 'trail_closed';
  DiscoverRouteSafetySeverity _severity = DiscoverRouteSafetySeverity.warning;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Проблема на маршруте'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DropdownButtonFormField<String>(
              initialValue: _reasonCode,
              decoration: const InputDecoration(labelText: 'Что произошло'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(
                  value: 'trail_closed',
                  child: Text('Тропа закрыта'),
                ),
                DropdownMenuItem(
                  value: 'dangerous_surface',
                  child: Text('Опасное покрытие'),
                ),
                DropdownMenuItem(
                  value: 'obstruction',
                  child: Text('Препятствие'),
                ),
                DropdownMenuItem(
                  value: 'incorrect_geometry',
                  child: Text('Неверная линия маршрута'),
                ),
                DropdownMenuItem(value: 'other', child: Text('Другое')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _reasonCode = value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DiscoverRouteSafetySeverity>(
              initialValue: _severity,
              decoration: const InputDecoration(labelText: 'Серьёзность'),
              items: const <DropdownMenuItem<DiscoverRouteSafetySeverity>>[
                DropdownMenuItem(
                  value: DiscoverRouteSafetySeverity.information,
                  child: Text('Информация'),
                ),
                DropdownMenuItem(
                  value: DiscoverRouteSafetySeverity.warning,
                  child: Text('Требует внимания'),
                ),
                DropdownMenuItem(
                  value: DiscoverRouteSafetySeverity.high,
                  child: Text('Опасно'),
                ),
                DropdownMenuItem(
                  value: DiscoverRouteSafetySeverity.critical,
                  child: Text('Критическая опасность'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _severity = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Комментарий (необязательно)',
                hintText: 'Опишите проблему без личных данных',
              ),
            ),
            if (_severity == DiscoverRouteSafetySeverity.critical)
              const Text(
                'Критическую опасность выбирайте только при непосредственном '
                'риске для людей.',
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final note = _noteController.text.trim();
            Navigator.of(context).pop(
              RouteSafetyReportInput(
                reasonCode: _reasonCode,
                severity: _severity,
                safeNote: note.isEmpty ? null : note,
              ),
            );
          },
          child: const Text('Отправить'),
        ),
      ],
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
    required this.onAddToScenario,
    required this.onSearch,
    required this.onCreateSimilar,
    required this.onCreateRoute,
    required this.onMarkVisited,
    required this.onCtaTap,
  });

  final DiscoverItemEntity item;
  final bool isFavorite;
  final bool ctaSubmitted;
  final VoidCallback onFavoriteTap;
  final VoidCallback onMap;
  final VoidCallback onRouteMap;
  final VoidCallback? onAddToScenario;
  final VoidCallback onSearch;
  final VoidCallback onCreateSimilar;
  final VoidCallback onCreateRoute;
  final VoidCallback onMarkVisited;
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
                  onPressed: onFavoriteTap,
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
                if (onAddToScenario != null)
                  _DetailsActionTile(
                    icon: Icons.playlist_add,
                    title: 'Add to Scenario',
                    subtitle: 'Add this stop to a personal plan',
                    onTap: onAddToScenario!,
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
                if (item.objectKind == DiscoverObjectKind.place)
                  _DetailsActionTile(
                    icon: Icons.history_toggle_off,
                    title: 'Mark as visited',
                    subtitle: 'Add to private history',
                    onTap: onMarkVisited,
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
    final route = item.publishedRoute;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: <Widget>[
            if (route == null)
              _InfoRow(
                icon: Icons.calendar_month_outlined,
                label: 'Date and time',
                value: _dateTimeLabel(item.startsAtUtc),
              )
            else
              _InfoRow(
                icon: Icons.route_outlined,
                label: 'Route geometry',
                value:
                    '${(route.distanceMeters / 1000).toStringAsFixed(1)} км · '
                    '${_durationFromSeconds(route.durationSeconds)}',
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
              value: route == null
                  ? '${item.distanceKm.toStringAsFixed(1)} км from you'
                  : 'Start point · ${item.distanceKm.toStringAsFixed(1)} км away',
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
  final VoidCallback onFavoriteTap;
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
                onPressed: onFavoriteTap,
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

String _durationFromSeconds(int seconds) {
  final int minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes min';
  final int hours = minutes ~/ 60;
  final int remainder = minutes % 60;
  return remainder == 0 ? '$hours h' : '$hours h $remainder min';
}

String _routeProfileLabel(String profileId) {
  return switch (profileId.trim().toLowerCase()) {
    'walking' || 'foot' || 'hiking' => 'Walking',
    'cycling' || 'bike' => 'Cycling',
    'car' || 'driving' => 'Driving',
    _ => profileId.isEmpty ? 'Route' : profileId,
  };
}

String _routeDifficultyLabel(String difficultyId) {
  final String normalized = difficultyId.trim().toLowerCase().split('.').first;
  return switch (normalized) {
    'easy' => 'Easy',
    'moderate' || 'medium' => 'Moderate',
    'hard' || 'difficult' => 'Hard',
    _ => difficultyId.isEmpty ? 'Difficulty not set' : difficultyId,
  };
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
    mood: scenarioMoodForDetails(item),
    durationMinutes: (item.durationMinutes ?? 0) > 120
        ? item.durationMinutes!
        : 120,
    freeOnly: item.isFree,
    walkingOnly: true,
    prompt: '${item.title} · ${item.category} · ${item.city}',
    stepCategories: routeStepCategoriesForDetails(item),
  );
}

/// Public: used by `discover_details_page.dart` to build the "Route from
/// this"/"Create route" seed link, exactly as the pre-`DTL-FND-01` page did
/// with its own private helper of the same shape.
List<String> routeStepCategoriesForDetails(DiscoverItemEntity item) {
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

/// Public: seed query parameters for the Route-from-this Map/Create
/// handoff, mirroring the pre-`DTL-FND-01` private helper of the same
/// shape.
Map<String, String> routeSeedForDetails(
  DiscoverItemEntity item, {
  required bool includeMode,
}) {
  final _DetailsRoutePlan plan = _routePlanForDetails(item);
  return <String, String>{
    if (includeMode) 'mode': 'route',
    'mood': plan.mood,
    'duration': plan.durationMinutes.toString(),
    'free': plan.freeOnly ? '1' : '0',
    'walking': plan.walkingOnly ? '1' : '0',
    'prompt': plan.prompt,
    'steps': plan.stepCategories.join(','),
  };
}

/// Public: title/subtitle seed for the Route-from-this Create handoff.
String routeSeedTitle(DiscoverItemEntity item) => '${item.title} route';

String routeSeedSubtitle(DiscoverItemEntity item) {
  final _DetailsRoutePlan plan = _routePlanForDetails(item);
  return '${plan.stepCategories.length} stops · '
      '${plan.durationMinutes} min · from details';
}

String routeSeedPrompt(DiscoverItemEntity item) =>
    _routePlanForDetails(item).prompt;

String scenarioMoodForDetails(DiscoverItemEntity item) {
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

/// Public: shared by `_DetailsBottomBar`/`_DetailsActionHub` in this file
/// and by `discover_details_page.dart`'s CTA-submitted SnackBar copy.
String ctaLabelForDetails(DiscoverItemEntity item) => _ctaLabel(item);

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
