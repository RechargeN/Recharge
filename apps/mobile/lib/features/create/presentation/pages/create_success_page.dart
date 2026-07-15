import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/create_providers.dart';
import '../../application/create_taxonomy.dart';
import '../../domain/entities/create_draft_entity.dart';

class CreateSuccessPage extends ConsumerWidget {
  const CreateSuccessPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(createControllerProvider).state.publishedDraft;
    final user = ref.watch(authControllerProvider).state.user;
    final _PublishedScenarioRouteContext? routeContext = draft == null
        ? null
        : _PublishedScenarioRouteContext.fromDraft(draft);

    return Scaffold(
      appBar: AppBar(title: const Text('Publish status')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          _PublishStatusHero(draft: draft),
          const SizedBox(height: 14),
          if (draft != null) ...<Widget>[
            _PublishedDraftCard(draft: draft),
            const SizedBox(height: 14),
          ],
          if (routeContext != null) ...<Widget>[
            _PublishedScenarioRouteCard(
              routeContext: routeContext,
              onEditRoute: () => context.go(routeContext.builderLocation),
              onMapRoute: () => context.go(routeContext.mapLocation),
            ),
            const SizedBox(height: 14),
          ],
          _NextActionsCard(
            draft: draft,
            onHome: () => context.go(RouteNames.discover),
            onProfile: () => context.go(RouteNames.profile),
            onSearch: draft == null
                ? null
                : () => context.go(_searchRouteForDraft(draft)),
            onMap: draft == null
                ? null
                : () => context.go(_mapRouteForDraft(draft)),
            onCreateAnother: user == null
                ? null
                : () {
                    ref
                        .read(createControllerProvider)
                        .resetToFreshDraft(
                          organizerId: user.id,
                          organizerEmail: user.email,
                          organizerName: user.email.split('@').first,
                        );
                    context.go(RouteNames.create);
                  },
          ),
        ],
      ),
    );
  }
}

class _PublishStatusHero extends StatelessWidget {
  const _PublishStatusHero({required this.draft});

  final CreateDraftEntity? draft;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final CreateDraftEntity? publishedDraft = draft;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.check_circle_outline,
              color: colorScheme.onPrimary,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              draft == null ? 'Publish processed' : 'Sent to moderation',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              publishedDraft == null
                  ? 'Your publish action was handled. Create another listing or return to Home.'
                  : '${publishedDraft.title} is now ${publishedDraft.publishStatus.name}.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimary.withValues(alpha: 0.88),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublishedDraftCard extends StatelessWidget {
  const _PublishedDraftCard({required this.draft});

  final CreateDraftEntity draft;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final CreateTaxonomyCategory? category = createTaxonomyCategoryById(
      draft.mainCategory,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              draft.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              draft.shortDescription.isEmpty
                  ? _venueLabel(draft)
                  : draft.shortDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _StatusChip(icon: Icons.layers, label: draft.objectType.name),
                _StatusChip(
                  icon: Icons.verified_outlined,
                  label: draft.publishStatus.name,
                ),
                if (category != null)
                  _StatusChip(icon: Icons.category, label: category.title),
                if (draft.subcategory.isNotEmpty)
                  _StatusChip(
                    icon: Icons.sell_outlined,
                    label: createTaxonomyLabelForPath(
                      '${draft.mainCategory}.${draft.subcategory}',
                    ),
                  ),
                _StatusChip(
                  icon: Icons.payments_outlined,
                  label: draft.isFree
                      ? 'Free'
                      : '${draft.basePrice?.toStringAsFixed(0) ?? '0'} '
                            '${draft.currency}',
                ),
                _StatusChip(icon: Icons.place_outlined, label: draft.city),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PublishedScenarioRouteCard extends StatelessWidget {
  const _PublishedScenarioRouteCard({
    required this.routeContext,
    required this.onEditRoute,
    required this.onMapRoute,
  });

  final _PublishedScenarioRouteContext routeContext;
  final VoidCallback onEditRoute;
  final VoidCallback onMapRoute;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.route, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Published route',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${routeContext.stepCategories.length} stops',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              routeContext.prompt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _StatusChip(icon: Icons.flag, label: routeContext.mood),
                _StatusChip(
                  icon: Icons.schedule,
                  label: '${routeContext.durationMinutes} min',
                ),
                if (routeContext.isFree)
                  const _StatusChip(icon: Icons.payments, label: 'Free'),
                const _StatusChip(
                  icon: Icons.directions_walk,
                  label: 'Walking',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: routeContext.stepCategories
                  .map(
                    (String step) => _StatusChip(
                      icon: Icons.place_outlined,
                      label: createTaxonomyLabelForPath(step),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onEditRoute,
                    icon: const Icon(Icons.edit_location_alt),
                    label: const Text('Edit route'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMapRoute,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Route map'),
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

class _NextActionsCard extends StatelessWidget {
  const _NextActionsCard({
    required this.draft,
    required this.onHome,
    required this.onProfile,
    required this.onSearch,
    required this.onMap,
    required this.onCreateAnother,
  });

  final CreateDraftEntity? draft;
  final VoidCallback onHome;
  final VoidCallback onProfile;
  final VoidCallback? onSearch;
  final VoidCallback? onMap;
  final VoidCallback? onCreateAnother;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Next steps',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onHome,
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Home'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onProfile,
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Profile'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSearch,
                    icon: const Icon(Icons.search),
                    label: const Text('Search similar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMap,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Map area'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onCreateAnother,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Create another'),
            ),
            if (draft == null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Draft summary is unavailable in this session.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: colorScheme.secondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublishedScenarioRouteContext {
  const _PublishedScenarioRouteContext({
    required this.prompt,
    required this.mood,
    required this.durationMinutes,
    required this.isFree,
    required this.stepCategories,
  });

  static _PublishedScenarioRouteContext? fromDraft(CreateDraftEntity draft) {
    if (draft.mainCategory != 'travel_tours' ||
        draft.subcategory != 'walking_tour') {
      return null;
    }
    final List<String> steps = _routeStepsFromDraft(draft);
    if (steps.isEmpty) return null;
    return _PublishedScenarioRouteContext(
      prompt: draft.title.trim().isEmpty ? 'Published route' : draft.title,
      mood: _scenarioMoodForDraft(draft),
      durationMinutes: _scenarioDurationForDraft(draft),
      isFree: draft.isFree,
      stepCategories: steps,
    );
  }

  final String prompt;
  final String mood;
  final int durationMinutes;
  final bool isFree;
  final List<String> stepCategories;

  String get builderLocation {
    return Uri(
      path: RouteNames.scenarioBuilder,
      queryParameters: _routeParameters(includeMode: false),
    ).toString();
  }

  String get mapLocation {
    return Uri(
      path: RouteNames.discoverMap,
      queryParameters: _routeParameters(includeMode: true),
    ).toString();
  }

  Map<String, String> _routeParameters({required bool includeMode}) {
    return <String, String>{
      if (includeMode) 'mode': 'scenario',
      'mood': mood,
      'duration': durationMinutes.toString(),
      'free': isFree ? '1' : '0',
      'walking': '1',
      'prompt': prompt,
      'steps': stepCategories.join(','),
    };
  }
}

String _searchRouteForDraft(CreateDraftEntity draft) {
  return _discoverRouteForDraft(RouteNames.search, draft);
}

String _mapRouteForDraft(CreateDraftEntity draft) {
  return _discoverRouteForDraft(RouteNames.discoverMap, draft);
}

String _discoverRouteForDraft(String path, CreateDraftEntity draft) {
  return Uri(
    path: path,
    queryParameters: <String, String>{
      'q': draft.title,
      'category': _discoverCategoryForDraft(draft.mainCategory),
      'free': draft.isFree ? '1' : '0',
      if (!draft.isFree && draft.basePrice != null)
        'budgetMax': draft.basePrice!.toStringAsFixed(0),
      'radius': '5000',
      'unlimited': '0',
    },
  ).toString();
}

String _discoverCategoryForDraft(String category) {
  switch (category) {
    case 'art_culture_museums':
      return 'art';
    case 'outdoor_nature_walking':
    case 'travel_tours':
      return 'outdoor';
    case 'wellness_recharge':
      return 'wellness';
    case 'food_drinks':
      return 'food';
    case 'family_kids':
      return 'family';
    default:
      return category;
  }
}

List<String> _routeStepsFromDraft(CreateDraftEntity draft) {
  final String marker = 'Route steps: ';
  final int markerIndex = draft.fullDescription.indexOf(marker);
  if (markerIndex >= 0) {
    final int start = markerIndex + marker.length;
    final int end = draft.fullDescription.indexOf('. Review', start);
    final String rawSteps = end > start
        ? draft.fullDescription.substring(start, end)
        : draft.fullDescription.substring(start);
    final List<String> steps = rawSteps
        .split(',')
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    if (steps.isNotEmpty) return steps;
  }
  return const <String>['wellness_recharge.calm_walk'];
}

String _scenarioMoodForDraft(CreateDraftEntity draft) {
  final String value =
      '${draft.title} ${draft.shortDescription} ${draft.fullDescription}'
          .toLowerCase();
  if (value.contains('active') ||
      value.contains('sport') ||
      value.contains('tennis')) {
    return 'active';
  }
  if (value.contains('social') || value.contains('evening')) {
    return 'social';
  }
  return 'calm';
}

int _scenarioDurationForDraft(CreateDraftEntity draft) {
  if (draft.durationMinutes != null && draft.durationMinutes! > 0) {
    return draft.durationMinutes!;
  }
  final RegExpMatch? match = RegExp(
    r'(\d+)\s*min',
  ).firstMatch(draft.shortDescription);
  if (match == null) return 90;
  return int.tryParse(match.group(1) ?? '') ?? 90;
}

String _venueLabel(CreateDraftEntity draft) {
  if (draft.venueName.isNotEmpty && draft.city.isNotEmpty) {
    return '${draft.venueName} · ${draft.city}';
  }
  if (draft.venueName.isNotEmpty) return draft.venueName;
  return draft.city;
}
