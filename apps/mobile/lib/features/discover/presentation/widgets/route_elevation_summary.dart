import 'package:flutter/material.dart';

import '../../domain/entities/published_route_discovery_entity.dart';

/// Honest elevation summary — **not a graph**
/// (`docs/product/DTL_RTE_01_ROUTE_DETAILS_SLICE_SPEC.md` "Что изменилось
/// относительно v0.1", п.1): `PublishedRouteDiscoveryEntity` carries only
/// `elevationAvailability` + ascent/descent totals, never per-point
/// samples, so no graph can honestly be drawn from it. This renders those
/// same fields as a first-class section instead of a `Wrap` pill inside a
/// generic card, with the exact same degrade copy the pre-slice
/// `_PublishedRouteCard` used for partial/unavailable data.
class RouteElevationSummary extends StatelessWidget {
  const RouteElevationSummary({super.key, required this.route});

  final PublishedRouteDiscoveryEntity route;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Elevation',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ElevationStat(
                    icon: Icons.trending_up,
                    label: 'Ascent',
                    value: _metersLabel(route.ascentMeters),
                  ),
                ),
                Expanded(
                  child: _ElevationStat(
                    icon: Icons.trending_down,
                    label: 'Descent',
                    value: _metersLabel(route.descentMeters),
                  ),
                ),
              ],
            ),
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
          ],
        ),
      ),
    );
  }
}

class _ElevationStat extends StatelessWidget {
  const _ElevationStat({
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
    return Row(
      children: <Widget>[
        Icon(icon, color: colorScheme.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _metersLabel(double? value) =>
    value == null ? '—' : '${value.round()} m';
