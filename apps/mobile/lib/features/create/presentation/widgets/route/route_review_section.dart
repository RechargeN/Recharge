import 'package:flutter/material.dart';

import '../../../../../core/geo/geo_bounds.dart';
import '../../../../../core/geo/geo_point.dart';
import '../../../../../core/map/map_scene.dart';
import '../../../application/state/route_create_state.dart';
import '../../../domain/entities/route_quality_data.dart';
import '../../../domain/entities/route_validation_issue.dart';
import 'route_map_builder.dart';

class RouteReviewSection extends StatelessWidget {
  const RouteReviewSection({
    super.key,
    required this.state,
    required this.bounds,
    required this.graphEdges,
    required this.attribution,
    required this.onSave,
    required this.onRestore,
    required this.canSubmit,
    required this.publishesDirectly,
    required this.onPublish,
  });

  final RouteCreateState state;
  final GeoBounds bounds;
  final List<MapPolylineData> graphEdges;
  final String attribution;
  final VoidCallback onSave;
  final VoidCallback onRestore;
  final bool canSubmit;
  final bool publishesDirectly;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final route = state.route;
    final demoProviderOnly = state.issues.any(
      (issue) => issue.code == 'provider_license_disallows_publish',
    );
    final blocking = state.issues
        .where(
          (RouteValidationIssue issue) =>
              issue.severity == RouteValidationSeverity.blocking &&
              issue.code != 'provider_license_disallows_publish',
        )
        .toList(growable: false);
    final warnings = state.issues
        .where(
          (RouteValidationIssue issue) =>
              issue.severity == RouteValidationSeverity.warning,
        )
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        RouteMapBuilder(
          bounds: bounds,
          graphEdges: graphEdges,
          route: route,
          attribution: attribution,
          interactive: false,
          onPointAdded: (GeoPoint _) {},
          onFreehandCompleted: (List<GeoPoint> _) {},
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _Metric(
              icon: Icons.straighten,
              label:
                  '${(route.metrics.distanceMeters / 1000).toStringAsFixed(2)} km',
            ),
            _Metric(
              icon: Icons.schedule,
              label: _duration(route.metrics.effectiveDurationSeconds),
            ),
            _Metric(icon: Icons.route, label: route.shape.name),
            _Metric(
              icon: Icons.place_outlined,
              label: '${route.waypoints.length} POI',
            ),
          ],
        ),
        if (route.quality case final quality?) ...<Widget>[
          const SizedBox(height: 12),
          _RouteQualityPanel(quality: quality),
        ],
        const SizedBox(height: 12),
        _IssuePanel(
          title: blocking.isEmpty
              ? 'Route draft is structurally ready'
              : '${blocking.length} blocking checks',
          issues: blocking,
          color: blocking.isEmpty
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
        ),
        if (warnings.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _IssuePanel(
            title: '${warnings.length} warnings to review',
            issues: warnings,
            color: Theme.of(context).colorScheme.tertiary,
          ),
        ],
        const SizedBox(height: 12),
        if (demoProviderOnly)
          Text(
            'Investor demo: this version uses the bundled offline trail graph '
            'and is marked demo-only. No paid routing call is made.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey<String>('route-save-draft'),
          onPressed: state.hasPendingOperations ? null : onSave,
          icon: const Icon(Icons.save_outlined),
          label: Text(
            state.hasPendingOperations ? 'Routing in progress…' : 'Save draft',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onRestore,
          icon: const Icon(Icons.restore),
          label: const Text('Restore last saved revision'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey<String>('route-publish'),
          onPressed:
              state.hasPendingOperations || blocking.isNotEmpty || !canSubmit
              ? null
              : onPublish,
          icon: Icon(
            publishesDirectly
                ? Icons.publish_outlined
                : Icons.rate_review_outlined,
          ),
          label: Text(
            publishesDirectly ? 'Publish Route' : 'Submit Route for review',
          ),
        ),
        if (!canSubmit) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            'Your profile does not have permission to submit this Route.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  static String _duration(int seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60} h ${minutes % 60} min';
  }
}

class _RouteQualityPanel extends StatelessWidget {
  const _RouteQualityPanel({required this.quality});

  final RouteQualityDraft quality;

  @override
  Widget build(BuildContext context) {
    final elevation = quality.elevation;
    final verified = quality.verifications
        .where((record) => record.geometryRevision == quality.geometryRevision)
        .toList(growable: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Route quality',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _Metric(
                  icon: Icons.landscape_outlined,
                  label: elevation.availability.name,
                ),
                if (elevation.ascentMeters != null)
                  _Metric(
                    icon: Icons.trending_up,
                    label: '+${elevation.ascentMeters!.round()} m',
                  ),
                if (elevation.descentMeters != null)
                  _Metric(
                    icon: Icons.trending_down,
                    label: '-${elevation.descentMeters!.round()} m',
                  ),
                _Metric(
                  icon: Icons.speed_outlined,
                  label: quality.difficulty.recommendedDifficultyId,
                ),
                _Metric(
                  icon: Icons.layers_outlined,
                  label:
                      '${quality.unknownSurfaceDistanceMeters.round()} m unknown',
                ),
                _Metric(
                  icon: Icons.verified_outlined,
                  label: '${verified.length} verified',
                ),
              ],
            ),
            if (quality.difficulty.differsFromAuthorSelection) ...<Widget>[
              const SizedBox(height: 8),
              const Text(
                'The selected difficulty differs from the calculated '
                'recommendation and requires review.',
              ),
            ],
            if (elevation.attribution case final attribution?) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                attribution,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) =>
      Chip(avatar: Icon(icon, size: 18), label: Text(label));
}

class _IssuePanel extends StatelessWidget {
  const _IssuePanel({
    required this.title,
    required this.issues,
    required this.color,
  });

  final String title;
  final List<RouteValidationIssue> issues;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      border: Border.all(color: color.withValues(alpha: 0.35)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          for (final issue in issues.take(8))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '• ${issue.code} — ${issue.location.sectionId}',
                key: ValueKey<String>('route-issue-${issue.stableId}'),
              ),
            ),
        ],
      ),
    ),
  );
}
