import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/config/recharge_taxonomy.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../create/application/create_taxonomy.dart';
import '../../../discover/application/controllers/discover_feed_controller.dart';
import '../../../discover/application/discover_providers.dart';
import '../../../discover/domain/entities/discover_query.dart';
import '../../../discover/application/smart_search_parser.dart';
import '../../../discover/domain/entities/saved_search_entity.dart';
import '../../../discover/domain/entities/smart_search_history_entity.dart';
import '../../../favorites/application/favorites_providers.dart';
import '../../../favorites/domain/entities/favorite_item_entity.dart';
import '../../application/controllers/scenario_builder_controller.dart';
import '../../application/scenario_builder_providers.dart';
import '../../application/state/scenario_builder_state.dart';
import '../../domain/entities/scenario_draft_entity.dart';

class ScenarioBuilderPage extends ConsumerStatefulWidget {
  const ScenarioBuilderPage({
    super.key,
    this.seedParameters = const <String, String>{},
  });

  final Map<String, String> seedParameters;

  @override
  ConsumerState<ScenarioBuilderPage> createState() =>
      _ScenarioBuilderPageState();
}

class _ScenarioBuilderPageState extends ConsumerState<ScenarioBuilderPage> {
  String? _seedKey;
  bool _intentLoadScheduled = false;
  late bool _previewMode;

  @override
  void initState() {
    super.initState();
    _previewMode = widget.seedParameters['preview'] == '1';
  }

  @override
  Widget build(BuildContext context) {
    final ScenarioBuilderController controller = ref.watch(
      scenarioBuilderControllerProvider,
    );
    final ScenarioBuilderState state = controller.state;
    final ScenarioDraftEntity draft = state.draft;
    final List<ScenarioStepEntity> suggestedSteps = controller.suggestedSteps;
    final DiscoverFeedController discoverController = ref.watch(
      discoverFeedControllerProvider,
    );
    final List<SavedSearchEntity> savedSearches =
        discoverController.state.savedSearches;
    final List<SmartSearchHistoryEntity> smartSearchHistory =
        discoverController.state.smartSearchHistory;
    _scheduleSeed();
    _scheduleIntentLoad();

    return Scaffold(
      appBar: AppBar(
        title: Text(_previewMode ? 'My plan' : 'Scenario Builder'),
        actions: <Widget>[
          if (_previewMode)
            TextButton.icon(
              onPressed: () => setState(() => _previewMode = false),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            )
          else
            IconButton(
              tooltip: 'Reset',
              onPressed: controller.reset,
              icon: const Icon(Icons.restart_alt),
            ),
        ],
      ),
      body: _previewMode
          ? _ScenarioPreview(
              title: widget.seedParameters['title'] ?? 'Your recharge plan',
              draft: draft,
              routeFit: state.routeFit,
              onEdit: () => setState(() => _previewMode = false),
              onMap: () => context.go(_mapRouteForScenario(draft)),
              onSave: () => _saveScenario(draft),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: <Widget>[
                _ScenarioHero(
                  draft: draft,
                  onMap: () => context.go(_mapRouteForScenario(draft)),
                  onSearch: () => context.go(RouteNames.search),
                  onCreate: () => context.go(_createRouteForScenario(draft)),
                  onSave: () => _saveScenario(draft),
                  onCopy: () => _copyScenario(draft),
                ),
                const SizedBox(height: 14),
                if (savedSearches.isNotEmpty ||
                    smartSearchHistory.isNotEmpty) ...<Widget>[
                  _ScenarioSavedIntentPanel(
                    savedSearches: savedSearches,
                    smartSearchHistory: smartSearchHistory,
                    onApplySaved: (SavedSearchEntity search) =>
                        context.go(_scenarioBuilderRouteForSavedSearch(search)),
                    onMapSaved: (SavedSearchEntity search) =>
                        context.go(_mapRouteForSavedSearch(search)),
                    onCreateSaved: (SavedSearchEntity search) =>
                        context.go(_createRouteForSavedSearch(search)),
                    onApplySmart: (SmartSearchHistoryEntity item) =>
                        context.go(_scenarioBuilderRouteForSmartSearch(item)),
                    onMapSmart: (SmartSearchHistoryEntity item) =>
                        context.go(_mapRouteForSmartSearch(item)),
                    onCreateSmart: (SmartSearchHistoryEntity item) =>
                        context.go(_createRouteForSmartSearch(item)),
                  ),
                  const SizedBox(height: 16),
                ],
                _ScenarioTemplateRail(
                  templates: _scenarioTemplates,
                  draft: draft,
                  onApply: _applyTemplate,
                ),
                const SizedBox(height: 16),
                _BuilderControls(
                  draft: draft,
                  onMoodChanged: controller.setMood,
                  onDurationChanged: controller.setMaxDurationMinutes,
                  onFreeOnlyChanged: controller.setFreeOnly,
                  onWalkingOnlyChanged: controller.setWalkingOnly,
                ),
                const SizedBox(height: 16),
                _RouteFitPanel(
                  draft: draft,
                  routeFit: state.routeFit,
                  onOptimize: controller.optimizeRoute,
                  onMap: () => context.go(_mapRouteForScenario(draft)),
                  onCreate: () => context.go(_createRouteForScenario(draft)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Route steps',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (draft.steps.isEmpty)
                  _EmptyScenario(onReset: controller.reset)
                else
                  ...List<Widget>.generate(
                    draft.steps.length,
                    (int index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ScenarioStepCard(
                        index: index,
                        step: draft.steps[index],
                        canMoveUp: index > 0,
                        canMoveDown: index < draft.steps.length - 1,
                        onMoveUp: () => controller.moveStepUp(index),
                        onMoveDown: () => controller.moveStepDown(index),
                        onRemove: () => controller.removeStepAt(index),
                      ),
                    ),
                  ),
                if (suggestedSteps.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  _SuggestedStopsSection(
                    steps: suggestedSteps,
                    onAdd: controller.addSuggestedStep,
                  ),
                ],
              ],
            ),
    );
  }

  void _scheduleSeed() {
    if (widget.seedParameters.isEmpty) return;
    final List<MapEntry<String, String>> entries =
        widget.seedParameters.entries.toList()..sort(
          (MapEntry<String, String> a, MapEntry<String, String> b) =>
              a.key.compareTo(b.key),
        );
    final String nextKey = entries
        .map((MapEntry<String, String> entry) => '${entry.key}:${entry.value}')
        .join('|');
    if (_seedKey == nextKey) return;
    _seedKey = nextKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(scenarioBuilderControllerProvider)
          .applySeed(
            mood: _moodFromParam(widget.seedParameters['mood']),
            maxDurationMinutes: int.tryParse(
              widget.seedParameters['duration'] ?? '',
            ),
            freeOnly: _boolFromParam(widget.seedParameters['free']),
            walkingOnly: _boolFromParam(widget.seedParameters['walking']),
            sourcePrompt: widget.seedParameters['prompt'],
            stepCategories: _stepsFromParam(widget.seedParameters['steps']),
          );
    });
  }

  void _scheduleIntentLoad() {
    if (_intentLoadScheduled) return;
    _intentLoadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final DiscoverFeedController controller = ref.read(
        discoverFeedControllerProvider,
      );
      controller.ensureSavedSearchesLoaded();
      controller.ensureSmartSearchHistoryLoaded();
    });
  }

  Future<void> _saveScenario(ScenarioDraftEntity draft) async {
    final authState = ref.read(authControllerProvider).state;
    if (authState.user == null) {
      final String origin = Uri.encodeComponent(RouteNames.scenarioBuilder);
      context.push(
        '${RouteNames.signIn}?originRoute=$origin'
        '&sourceScreen=scenario_builder&sourceAction=save_scenario',
      );
      return;
    }

    final FavoriteItemEntity favorite = _favoriteFromScenario(draft);
    await ref
        .read(favoritesControllerProvider)
        .addFavorite(favorite, sourceScreen: 'scenario_builder');
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Scenario saved')));
  }

  Future<void> _copyScenario(ScenarioDraftEntity draft) async {
    await Clipboard.setData(ClipboardData(text: _scenarioSummary(draft)));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Scenario copied')));
  }

  void _applyTemplate(_ScenarioRouteTemplate template) {
    ref
        .read(scenarioBuilderControllerProvider)
        .applySeed(
          mood: template.mood,
          maxDurationMinutes: template.durationMinutes,
          freeOnly: template.freeOnly,
          walkingOnly: template.walkingOnly,
          sourcePrompt: template.prompt,
          stepCategories: template.stepCategories,
        );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${template.title} applied')));
  }
}

class _ScenarioPreview extends StatelessWidget {
  const _ScenarioPreview({
    required this.title,
    required this.draft,
    required this.routeFit,
    required this.onEdit,
    required this.onMap,
    required this.onSave,
  });

  final String title;
  final ScenarioDraftEntity draft;
  final ScenarioRouteFit routeFit;
  final VoidCallback onEdit;
  final VoidCallback onMap;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: colors.onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.onPrimary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        routeFit.label,
                        style: TextStyle(
                          color: colors.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_moodLabel(draft.mood)} route, ready to follow or adjust.',
                  style: TextStyle(
                    color: colors.onPrimary.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    _PreviewStat(
                      icon: Icons.place_outlined,
                      value: '${draft.steps.length}',
                      label: 'stops',
                    ),
                    _PreviewStat(
                      icon: Icons.schedule_outlined,
                      value: _durationLabel(draft.totalDurationMinutes),
                      label: 'total',
                    ),
                    _PreviewStat(
                      icon: Icons.payments_outlined,
                      value: draft.totalPriceAmount == 0
                          ? 'Free'
                          : '€${draft.totalPriceAmount.toStringAsFixed(0)}',
                      label: 'budget',
                    ),
                    _PreviewStat(
                      icon: Icons.directions_walk_outlined,
                      value: '${draft.totalDistanceKm.toStringAsFixed(1)} km',
                      label: 'route',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _ScenarioMapPreview(steps: draft.steps),
        const SizedBox(height: 20),
        Text(
          'Your route',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (draft.steps.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'No stops fit these conditions yet. Edit the plan to add one.',
              ),
            ),
          )
        else
          for (int index = 0; index < draft.steps.length; index++)
            _PreviewTimelineStep(
              index: index,
              step: draft.steps[index],
              isLast: index == draft.steps.length - 1,
            ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('scenario-preview-edit'),
                onPressed: onEdit,
                icon: const Icon(Icons.tune_outlined),
                label: const Text('Edit plan'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                key: const Key('scenario-preview-map'),
                onPressed: onMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Open map'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => onSave(),
          icon: const Icon(Icons.bookmark_add_outlined),
          label: const Text('Save this plan'),
        ),
      ],
    );
  }
}

class _PreviewStat extends StatelessWidget {
  const _PreviewStat({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color foreground = Theme.of(context).colorScheme.onPrimary;
    return Expanded(
      child: Column(
        children: <Widget>[
          Icon(icon, size: 18, color: foreground),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: TextStyle(
              color: foreground.withValues(alpha: 0.68),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioMapPreview extends StatelessWidget {
  const _ScenarioMapPreview({required this.steps});
  final List<ScenarioStepEntity> steps;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      height: 176,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(painter: _PreviewMapPainter(colors)),
          ),
          for (int index = 0; index < steps.length && index < 4; index++)
            Positioned(
              left: 34.0 + (index * 82),
              top: index.isEven ? 38 : 96,
              child: CircleAvatar(
                radius: 17,
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          Positioned(
            right: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Route preview',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewMapPainter extends CustomPainter {
  const _PreviewMapPainter(this.colors);
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint street = Paint()
      ..color = colors.surface.withValues(alpha: 0.72)
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke;
    final Paint route = Paint()
      ..color = colors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(-10, size.height * 0.72)
        ..quadraticBezierTo(
          size.width * 0.35,
          size.height * 0.25,
          size.width + 12,
          size.height * 0.5,
        ),
      street,
    );
    canvas.drawPath(
      Path()
        ..moveTo(50, 55)
        ..cubicTo(100, 126, 178, 72, 292, 112),
      route,
    );
  }

  @override
  bool shouldRepaint(covariant _PreviewMapPainter oldDelegate) => false;
}

class _PreviewTimelineStep extends StatelessWidget {
  const _PreviewTimelineStep({
    required this.index,
    required this.step,
    required this.isLast,
  });
  final int index;
  final ScenarioStepEntity step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 38,
            child: Column(
              children: <Widget>[
                CircleAvatar(
                  radius: 14,
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  child: Text('${index + 1}'),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: colors.primary.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    step.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    children: <Widget>[
                      _TimelinePill('${step.durationMinutes} min'),
                      _TimelinePill('${step.distanceKm.toStringAsFixed(1)} km'),
                      _TimelinePill(
                        step.isFree
                            ? 'Free'
                            : '€${step.priceAmount.toStringAsFixed(0)}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelinePill extends StatelessWidget {
  const _TimelinePill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(label, style: Theme.of(context).textTheme.labelSmall),
  );
}

String _durationLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  final int hours = minutes ~/ 60;
  final int rest = minutes % 60;
  return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
}

class _ScenarioHero extends StatelessWidget {
  const _ScenarioHero({
    required this.draft,
    required this.onMap,
    required this.onSearch,
    required this.onCreate,
    required this.onSave,
    required this.onCopy,
  });

  final ScenarioDraftEntity draft;
  final VoidCallback onMap;
  final VoidCallback onSearch;
  final VoidCallback onCreate;
  final Future<void> Function() onSave;
  final Future<void> Function() onCopy;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
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
            Row(
              children: <Widget>[
                Icon(Icons.route, color: colorScheme.onPrimary),
                const SizedBox(width: 8),
                Text(
                  'Build a recharge route',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${_moodLabel(draft.mood)} plan with ${draft.steps.length} stops',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (draft.sourcePrompt.isNotEmpty)
                  _HeroPill(
                    label: 'Intent: ${_shortPrompt(draft.sourcePrompt)}',
                  ),
                _HeroPill(label: '${draft.totalDurationMinutes} min'),
                _HeroPill(
                  label: '${draft.totalDistanceKm.toStringAsFixed(1)} km',
                ),
                _HeroPill(
                  label: draft.totalPriceAmount == 0
                      ? 'Free'
                      : '${draft.totalPriceAmount.toStringAsFixed(0)} EUR',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      onSave();
                    },
                    icon: const Icon(Icons.bookmark_add),
                    label: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      onCopy();
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.onPrimary,
                      side: BorderSide(
                        color: colorScheme.onPrimary.withValues(alpha: 0.48),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMap,
                    icon: const Icon(Icons.map),
                    label: const Text('Map'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.onPrimary,
                      side: BorderSide(
                        color: colorScheme.onPrimary.withValues(alpha: 0.48),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSearch,
                    icon: const Icon(Icons.search),
                    label: const Text('Search'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.onPrimary,
                      side: BorderSide(
                        color: colorScheme.onPrimary.withValues(alpha: 0.48),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('Publish route'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ScenarioTemplateRail extends StatelessWidget {
  const _ScenarioTemplateRail({
    required this.templates,
    required this.draft,
    required this.onApply,
  });

  final List<_ScenarioRouteTemplate> templates;
  final ScenarioDraftEntity draft;
  final ValueChanged<_ScenarioRouteTemplate> onApply;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.view_carousel_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Ready route ideas',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final _ScenarioRouteTemplate template
                  in templates) ...<Widget>[
                _ScenarioTemplateCard(
                  template: template,
                  isActive: _templateMatchesDraft(template, draft),
                  onApply: () => onApply(template),
                ),
                const SizedBox(width: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ScenarioTemplateCard extends StatelessWidget {
  const _ScenarioTemplateCard({
    required this.template,
    required this.isActive,
    required this.onApply,
  });

  final _ScenarioRouteTemplate template;
  final bool isActive;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 252,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isActive
              ? colorScheme.primaryContainer.withValues(alpha: 0.48)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? colorScheme.primary.withValues(alpha: 0.54)
                : colorScheme.outline.withValues(alpha: 0.16),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(template.icon, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      template.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                template.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  _MetaChip(
                    icon: Icons.schedule,
                    label: '${template.durationMinutes} min',
                  ),
                  _MetaChip(
                    icon: Icons.directions_walk,
                    label: template.walkingOnly ? 'Walkable' : 'Flexible',
                  ),
                  _MetaChip(
                    icon: Icons.payments_outlined,
                    label: template.freeOnly ? 'Free' : 'Mixed',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Tooltip(
                message: 'Apply ${template.title} template',
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onApply,
                    icon: Icon(isActive ? Icons.check : Icons.route),
                    label: Text(isActive ? 'Applied' : 'Use'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScenarioSavedIntentPanel extends StatelessWidget {
  const _ScenarioSavedIntentPanel({
    required this.savedSearches,
    required this.smartSearchHistory,
    required this.onApplySaved,
    required this.onMapSaved,
    required this.onCreateSaved,
    required this.onApplySmart,
    required this.onMapSmart,
    required this.onCreateSmart,
  });

  final List<SavedSearchEntity> savedSearches;
  final List<SmartSearchHistoryEntity> smartSearchHistory;
  final ValueChanged<SavedSearchEntity> onApplySaved;
  final ValueChanged<SavedSearchEntity> onMapSaved;
  final ValueChanged<SavedSearchEntity> onCreateSaved;
  final ValueChanged<SmartSearchHistoryEntity> onApplySmart;
  final ValueChanged<SmartSearchHistoryEntity> onMapSmart;
  final ValueChanged<SmartSearchHistoryEntity> onCreateSmart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.auto_awesome,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Build from saved intent',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final SavedSearchEntity search in savedSearches.take(
          2,
        )) ...<Widget>[
          _ScenarioIntentCard(
            icon: Icons.bookmark_border,
            typeLabel: 'Saved conditions',
            title: search.title,
            subtitle: search.subtitle,
            query: search.query,
            applyTooltip: 'Apply saved conditions to builder',
            mapTooltip: 'Open saved conditions on map',
            createTooltip: 'Create listing from saved conditions',
            onApply: () => onApplySaved(search),
            onMap: () => onMapSaved(search),
            onCreate: () => onCreateSaved(search),
          ),
          const SizedBox(height: 10),
        ],
        for (final SmartSearchHistoryEntity item in smartSearchHistory.take(
          2,
        )) ...<Widget>[
          _ScenarioIntentCard(
            icon: Icons.mic_none,
            typeLabel: 'Smart search',
            title: item.prompt.trim().isEmpty
                ? _titleForQuery(item.query)
                : item.prompt.trim(),
            subtitle: _smartSearchIntentSubtitle(item),
            query: item.query,
            chips: _smartSearchIntentChips(item),
            applyTooltip: 'Apply smart search to builder',
            mapTooltip: 'Open smart search on map',
            createTooltip: 'Create listing from smart search',
            onApply: () => onApplySmart(item),
            onMap: () => onMapSmart(item),
            onCreate: () => onCreateSmart(item),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ScenarioIntentCard extends StatelessWidget {
  const _ScenarioIntentCard({
    required this.icon,
    required this.typeLabel,
    required this.title,
    required this.subtitle,
    required this.query,
    this.chips,
    required this.applyTooltip,
    required this.mapTooltip,
    required this.createTooltip,
    required this.onApply,
    required this.onMap,
    required this.onCreate,
  });

  final IconData icon;
  final String typeLabel;
  final String title;
  final String subtitle;
  final DiscoverQuery query;
  final List<_IntentChipData>? chips;
  final String applyTooltip;
  final String mapTooltip;
  final String createTooltip;
  final VoidCallback onApply;
  final VoidCallback onMap;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colorScheme.primaryContainer.withValues(
                    alpha: 0.72,
                  ),
                  child: Icon(icon, size: 20, color: colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        typeLabel,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(
                          subtitle.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (chips ?? _intentChips(query))
                  .map(
                    (_IntentChipData chip) =>
                        _MetaChip(icon: chip.icon, label: chip.label),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                IconButton.outlined(
                  tooltip: applyTooltip,
                  onPressed: onApply,
                  icon: const Icon(Icons.route),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: mapTooltip,
                  onPressed: onMap,
                  icon: const Icon(Icons.map_outlined),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: createTooltip,
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_business_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BuilderControls extends StatelessWidget {
  const _BuilderControls({
    required this.draft,
    required this.onMoodChanged,
    required this.onDurationChanged,
    required this.onFreeOnlyChanged,
    required this.onWalkingOnlyChanged,
  });

  final ScenarioDraftEntity draft;
  final ValueChanged<ScenarioMood> onMoodChanged;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<bool> onFreeOnlyChanged;
  final ValueChanged<bool> onWalkingOnlyChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Conditions',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        SegmentedButton<ScenarioMood>(
          segments: const <ButtonSegment<ScenarioMood>>[
            ButtonSegment<ScenarioMood>(
              value: ScenarioMood.calm,
              icon: Icon(Icons.self_improvement),
              label: Text('Calm'),
            ),
            ButtonSegment<ScenarioMood>(
              value: ScenarioMood.social,
              icon: Icon(Icons.groups),
              label: Text('Social'),
            ),
            ButtonSegment<ScenarioMood>(
              value: ScenarioMood.active,
              icon: Icon(Icons.directions_run),
              label: Text('Active'),
            ),
          ],
          selected: <ScenarioMood>{draft.mood},
          onSelectionChanged: (Set<ScenarioMood> values) {
            onMoodChanged(values.first);
          },
        ),
        const SizedBox(height: 12),
        _DurationPicker(
          selected: draft.maxDurationMinutes,
          onChanged: onDurationChanged,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Free only'),
          value: draft.freeOnly,
          onChanged: onFreeOnlyChanged,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Walking route'),
          value: draft.walkingOnly,
          onChanged: onWalkingOnlyChanged,
        ),
      ],
    );
  }
}

class _DurationPicker extends StatelessWidget {
  const _DurationPicker({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const List<int> options = <int>[90, 150, 240];
    return Wrap(
      spacing: 8,
      children: options
          .map(
            (int minutes) => ChoiceChip(
              label: Text('${minutes ~/ 60}h ${minutes % 60}m'),
              selected: selected == minutes,
              onSelected: (_) => onChanged(minutes),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _RouteFitPanel extends StatelessWidget {
  const _RouteFitPanel({
    required this.draft,
    required this.routeFit,
    required this.onOptimize,
    required this.onMap,
    required this.onCreate,
  });

  final ScenarioDraftEntity draft;
  final ScenarioRouteFit routeFit;
  final VoidCallback onOptimize;
  final VoidCallback onMap;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.34),
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
                Icon(Icons.rule_outlined, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Route fit',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${routeFit.score}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              routeFit.label,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              routeFit.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _MetaChip(
                  icon: Icons.schedule,
                  label:
                      '${draft.totalDurationMinutes}/'
                      '${draft.maxDurationMinutes} min',
                ),
                _MetaChip(
                  icon: Icons.directions_walk,
                  label: draft.walkingOnly ? 'Walkable' : 'Flexible',
                ),
                _MetaChip(
                  icon: Icons.payments_outlined,
                  label: draft.freeOnly
                      ? 'Free only'
                      : draft.totalPriceAmount == 0
                      ? 'Free'
                      : '${draft.totalPriceAmount.toStringAsFixed(0)} EUR',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: routeFit.insights
                  .map(
                    (String insight) => _MetaChip(
                      icon: Icons.check_circle_outline,
                      label: insight,
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onOptimize,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Optimize'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMap,
                    icon: const Icon(Icons.map_outlined),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Map route'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Publish optimized route',
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_business_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioStepCard extends StatelessWidget {
  const _ScenarioStepCard({
    required this.index,
    required this.step,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final int index;
  final ScenarioStepEntity step;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(radius: 18, child: Text('${index + 1}')),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    step.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(step.subtitle),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _MetaChip(
                        icon: Icons.category,
                        label: createTaxonomyLabelForPath(step.category),
                      ),
                      _MetaChip(
                        icon: Icons.schedule,
                        label: '${step.durationMinutes} min',
                      ),
                      _MetaChip(
                        icon: Icons.near_me,
                        label: '${step.distanceKm.toStringAsFixed(1)} km',
                      ),
                      _MetaChip(
                        icon: Icons.payments,
                        label: step.isFree
                            ? 'Free'
                            : '${step.priceAmount.toStringAsFixed(0)} EUR',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      IconButton.outlined(
                        tooltip: 'Move up',
                        onPressed: canMoveUp ? onMoveUp : null,
                        icon: const Icon(Icons.keyboard_arrow_up),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: 'Move down',
                        onPressed: canMoveDown ? onMoveDown : null,
                        icon: const Icon(Icons.keyboard_arrow_down),
                      ),
                      const Spacer(),
                      IconButton.outlined(
                        tooltip: 'Remove stop',
                        onPressed: onRemove,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
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

class _SuggestedStopsSection extends StatelessWidget {
  const _SuggestedStopsSection({required this.steps, required this.onAdd});

  final List<ScenarioStepEntity> steps;
  final ValueChanged<ScenarioStepEntity> onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Suggested stops',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        ...steps.map(
          (ScenarioStepEntity step) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SuggestedStopCard(step: step, onAdd: () => onAdd(step)),
          ),
        ),
      ],
    );
  }
}

class _SuggestedStopCard extends StatelessWidget {
  const _SuggestedStopCard({required this.step, required this.onAdd});

  final ScenarioStepEntity step;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Icon(Icons.add_location_alt, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    step.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${createTaxonomyLabelForPath(step.category)} · '
                    '${step.durationMinutes} min',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.62),
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

class _EmptyScenario extends StatelessWidget {
  const _EmptyScenario({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: <Widget>[
          const Icon(Icons.route, size: 36),
          const SizedBox(height: 10),
          const Text('No stops match these conditions'),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onReset,
            child: const Text('Reset builder'),
          ),
        ],
      ),
    );
  }
}

const List<_ScenarioRouteTemplate> _scenarioTemplates =
    <_ScenarioRouteTemplate>[
      _ScenarioRouteTemplate(
        title: 'Coffee reset',
        subtitle: 'Start gently, then take a low-pressure city walk.',
        icon: Icons.local_cafe_outlined,
        mood: ScenarioMood.calm,
        durationMinutes: 90,
        freeOnly: false,
        walkingOnly: true,
        prompt: 'coffee reset walk',
        stepCategories: <String>[
          'food_drinks.coffee',
          'wellness_recharge.calm_walk',
        ],
      ),
      _ScenarioRouteTemplate(
        title: 'Free city reset',
        subtitle: 'A simple free route for a calm recharge window.',
        icon: Icons.self_improvement,
        mood: ScenarioMood.calm,
        durationMinutes: 90,
        freeOnly: true,
        walkingOnly: true,
        prompt: 'free calm city walk',
        stepCategories: <String>['wellness_recharge.calm_walk'],
      ),
      _ScenarioRouteTemplate(
        title: 'Social evening',
        subtitle: 'Meet people first, then keep the evening moving nearby.',
        icon: Icons.groups_outlined,
        mood: ScenarioMood.social,
        durationMinutes: 150,
        freeOnly: false,
        walkingOnly: true,
        prompt: 'social evening near me',
        stepCategories: <String>[
          'games_indoor.board_games',
          'music_nightlife.afterwork_drinks',
        ],
      ),
      _ScenarioRouteTemplate(
        title: 'Active boost',
        subtitle: 'Move first, cool down outside, then keep energy steady.',
        icon: Icons.directions_run,
        mood: ScenarioMood.active,
        durationMinutes: 120,
        freeOnly: false,
        walkingOnly: true,
        prompt: 'active tennis and walk',
        stepCategories: <String>[
          'sport.tennis',
          'outdoor_nature_walking.city_walk',
        ],
      ),
    ];

class _ScenarioRouteTemplate {
  const _ScenarioRouteTemplate({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.mood,
    required this.durationMinutes,
    required this.freeOnly,
    required this.walkingOnly,
    required this.prompt,
    required this.stepCategories,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final ScenarioMood mood;
  final int durationMinutes;
  final bool freeOnly;
  final bool walkingOnly;
  final String prompt;
  final List<String> stepCategories;
}

bool _templateMatchesDraft(
  _ScenarioRouteTemplate template,
  ScenarioDraftEntity draft,
) {
  final List<String> draftCategories = draft.steps
      .map((ScenarioStepEntity step) => step.category)
      .toList(growable: false);
  if (draft.mood != template.mood ||
      draft.maxDurationMinutes != template.durationMinutes ||
      draft.freeOnly != template.freeOnly ||
      draft.walkingOnly != template.walkingOnly ||
      draftCategories.length != template.stepCategories.length) {
    return false;
  }
  for (var index = 0; index < draftCategories.length; index += 1) {
    if (draftCategories[index] != template.stepCategories[index]) {
      return false;
    }
  }
  return true;
}

String _moodLabel(ScenarioMood mood) {
  return switch (mood) {
    ScenarioMood.calm => 'Calm',
    ScenarioMood.social => 'Social',
    ScenarioMood.active => 'Active',
  };
}

ScenarioMood? _moodFromParam(String? value) {
  return switch (value) {
    'calm' => ScenarioMood.calm,
    'social' => ScenarioMood.social,
    'active' => ScenarioMood.active,
    _ => null,
  };
}

bool? _boolFromParam(String? value) {
  if (value == '1' || value == 'true') return true;
  if (value == '0' || value == 'false') return false;
  return null;
}

String _shortPrompt(String prompt) {
  final String trimmed = prompt.trim();
  if (trimmed.length <= 28) return trimmed;
  return '${trimmed.substring(0, 25)}...';
}

List<String>? _stepsFromParam(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return value
      .split(',')
      .map((String step) => step.trim())
      .where((String step) => step.isNotEmpty)
      .toList(growable: false);
}

FavoriteItemEntity _favoriteFromScenario(ScenarioDraftEntity draft) {
  final DateTime now = DateTime.now().toUtc();
  final String categoryKey = draft.steps
      .map((ScenarioStepEntity step) => step.category.replaceAll('.', '_'))
      .join('_');
  return FavoriteItemEntity(
    id: 'scenario_${draft.mood.name}_$categoryKey',
    title: '${_moodLabel(draft.mood)} recharge scenario',
    subtitle: '${draft.steps.length} stops · ${draft.totalDurationMinutes} min',
    city: 'Riga',
    category: 'scenario',
    startsAtUtc: now,
    distanceKm: draft.totalDistanceKm,
    priceAmount: draft.totalPriceAmount,
    isFree: draft.totalPriceAmount == 0,
    savedAtUtc: now,
    targetRoute: _targetRouteForScenario(draft),
  );
}

String _targetRouteForScenario(ScenarioDraftEntity draft) {
  return Uri(
    path: RouteNames.scenarioBuilder,
    queryParameters: <String, String>{
      'mood': draft.mood.name,
      'duration': draft.maxDurationMinutes.toString(),
      'free': draft.freeOnly ? '1' : '0',
      'walking': draft.walkingOnly ? '1' : '0',
      if (draft.sourcePrompt.trim().isNotEmpty)
        'prompt': draft.sourcePrompt.trim(),
      'steps': draft.steps
          .map((ScenarioStepEntity step) => step.category)
          .join(','),
    },
  ).toString();
}

String _mapRouteForScenario(ScenarioDraftEntity draft) {
  return Uri(
    path: RouteNames.discoverMap,
    queryParameters: <String, String>{
      'mode': 'scenario',
      'mood': draft.mood.name,
      'duration': draft.maxDurationMinutes.toString(),
      'free': draft.freeOnly ? '1' : '0',
      'walking': draft.walkingOnly ? '1' : '0',
      if (draft.sourcePrompt.trim().isNotEmpty)
        'prompt': draft.sourcePrompt.trim(),
      'steps': draft.steps
          .map((ScenarioStepEntity step) => step.category)
          .join(','),
    },
  ).toString();
}

String _createRouteForScenario(ScenarioDraftEntity draft) {
  final String steps = draft.steps
      .map((ScenarioStepEntity step) => step.category)
      .join(',');
  final String prompt = draft.sourcePrompt.trim().isEmpty
      ? '${_moodLabel(draft.mood)} route with ${draft.steps.length} stops'
      : draft.sourcePrompt.trim();
  return Uri(
    path: RouteNames.create,
    queryParameters: <String, String>{
      'source': 'scenario',
      'type': 'event',
      'title': '${_moodLabel(draft.mood)} recharge route',
      'subtitle':
          '${draft.steps.length} stops · '
          '${draft.totalDurationMinutes} min · '
          '${draft.totalDistanceKm.toStringAsFixed(1)} km',
      'q': prompt,
      'category': 'scenario',
      'mood': draft.mood.name,
      'duration': draft.maxDurationMinutes.toString(),
      'free': draft.freeOnly ? '1' : '0',
      'walking': draft.walkingOnly ? '1' : '0',
      if (draft.sourcePrompt.trim().isNotEmpty)
        'prompt': draft.sourcePrompt.trim(),
      if (steps.isNotEmpty) 'steps': steps,
    },
  ).toString();
}

String _mapRouteForSavedSearch(SavedSearchEntity search) {
  return _discoverRouteForQuery(RouteNames.discoverMap, search.query);
}

String _mapRouteForSmartSearch(SmartSearchHistoryEntity item) {
  final SmartSearchParseResult? parseResult = _smartRouteParseForSmartSearch(
    item,
  );
  if (parseResult != null) {
    return Uri(
      path: RouteNames.discoverMap,
      queryParameters: _smartRouteParameters(parseResult, includeMode: true),
    ).toString();
  }
  return _discoverRouteForQuery(RouteNames.discoverMap, item.query);
}

String _createRouteForSavedSearch(SavedSearchEntity search) {
  return _createRouteForQuery(
    search.query,
    source: 'saved_search',
    title: search.title,
    subtitle: search.subtitle,
  );
}

String _createRouteForSmartSearch(SmartSearchHistoryEntity item) {
  final SmartSearchParseResult? parseResult = _smartRouteParseForSmartSearch(
    item,
  );
  if (parseResult != null) {
    final SmartRouteIntent routeIntent = parseResult.routeIntent!;
    return Uri(
      path: RouteNames.create,
      queryParameters: <String, String>{
        ..._smartRouteParameters(parseResult, includeMode: false),
        'source': 'scenario',
        'type': 'event',
        'title': '${_capitalized(routeIntent.mood)} recharge route',
        'subtitle':
            '${routeIntent.stepCategories.length} stops · '
            '${routeIntent.durationMinutes} min · smart route',
        'q': parseResult.originalText.trim(),
        'category': 'scenario',
      },
    ).toString();
  }
  return _createRouteForQuery(
    item.query,
    source: 'smart_search',
    title: _titleForQuery(item.query),
    subtitle: item.prompt,
  );
}

String _scenarioBuilderRouteForSavedSearch(SavedSearchEntity search) {
  return _scenarioBuilderRouteForQuery(
    search.query,
    prompt: _promptForQuery(search.query),
  );
}

String _scenarioBuilderRouteForSmartSearch(SmartSearchHistoryEntity item) {
  final SmartSearchParseResult? parseResult = _smartRouteParseForSmartSearch(
    item,
  );
  if (parseResult != null) {
    return Uri(
      path: RouteNames.scenarioBuilder,
      queryParameters: _smartRouteParameters(parseResult, includeMode: false),
    ).toString();
  }
  final String prompt = item.prompt.trim().isEmpty
      ? _promptForQuery(item.query)
      : item.prompt.trim();
  return _scenarioBuilderRouteForQuery(item.query, prompt: prompt);
}

SmartSearchParseResult? _smartRouteParseForSmartSearch(
  SmartSearchHistoryEntity item,
) {
  final SmartSearchParseResult parseResult = parseSmartSearch(item.prompt);
  if (parseResult.routeIntent == null) return null;
  return parseResult;
}

Map<String, String> _smartRouteParameters(
  SmartSearchParseResult parseResult, {
  required bool includeMode,
}) {
  final SmartRouteIntent routeIntent = parseResult.routeIntent!;
  return <String, String>{
    if (includeMode) 'mode': 'scenario',
    'mood': routeIntent.mood,
    'duration': routeIntent.durationMinutes.toString(),
    'free': routeIntent.freeOnly ? '1' : '0',
    'walking': routeIntent.walkingOnly ? '1' : '0',
    if (parseResult.originalText.trim().isNotEmpty)
      'prompt': parseResult.originalText.trim(),
    if (routeIntent.stepCategories.isNotEmpty)
      'steps': routeIntent.stepCategories.join(','),
  };
}

String _discoverRouteForQuery(String path, DiscoverQuery query) {
  return Uri(
    path: path,
    queryParameters: _queryParametersForQuery(query),
  ).toString();
}

String _createRouteForQuery(
  DiscoverQuery query, {
  required String source,
  required String title,
  required String subtitle,
}) {
  final Map<String, String> params = <String, String>{
    ..._queryParametersForQuery(query),
    'source': source,
    'type': 'event',
    'title': title,
    if (subtitle.trim().isNotEmpty) 'subtitle': subtitle.trim(),
  };
  return Uri(path: RouteNames.create, queryParameters: params).toString();
}

String _scenarioBuilderRouteForQuery(
  DiscoverQuery query, {
  required String prompt,
}) {
  final Map<String, String> params = <String, String>{
    'mood': _scenarioMoodForQuery(query),
    'duration': query.radiusMeters <= 5000 ? '120' : '180',
    'walking': query.unlimitedRadius ? '0' : '1',
    if (query.freeOnly) 'free': '1',
    if (prompt.trim().isNotEmpty) 'prompt': prompt.trim(),
  };
  return Uri(
    path: RouteNames.scenarioBuilder,
    queryParameters: params,
  ).toString();
}

Map<String, String> _queryParametersForQuery(DiscoverQuery query) {
  return <String, String>{
    'q': query.queryText.trim(),
    'category': query.selectedCategoryIds.join(','),
    'free': query.freeOnly ? '1' : '0',
    if (query.budgetMax != null)
      'budgetMax': query.budgetMax!.toStringAsFixed(0),
    if (query.dateFrom != null) 'dateFrom': query.dateFrom!.toIso8601String(),
    if (query.dateTo != null) 'dateTo': query.dateTo!.toIso8601String(),
    'radius': query.radiusMeters.round().toString(),
    'unlimited': query.unlimitedRadius ? '1' : '0',
  };
}

String _scenarioMoodForQuery(DiscoverQuery query) {
  final String queryText = query.queryText.toLowerCase();
  final Set<String> normalizedCategories = query.selectedCategoryIds
      .map(normalizeRechargeContentGroupId)
      .toSet();
  if (queryText.contains('run') ||
      queryText.contains('sport') ||
      queryText.contains('tennis') ||
      normalizedCategories.contains('sport') ||
      normalizedCategories.contains('outdoor_nature_walking')) {
    return 'active';
  }
  if (normalizedCategories.contains('art_culture_museums') ||
      normalizedCategories.contains('music_nightlife') ||
      normalizedCategories.contains('family_kids')) {
    return 'social';
  }
  return 'calm';
}

String _promptForQuery(DiscoverQuery query) {
  final List<String> parts = <String>[
    if (query.queryText.trim().isNotEmpty) query.queryText.trim(),
    if (query.selectedCategoryIds.isNotEmpty) query.selectedCategoryIds.first,
    if (query.freeOnly) 'free',
    if (query.budgetMax != null) 'under ${query.budgetMax!.toStringAsFixed(0)}',
    query.unlimitedRadius
        ? 'any area'
        : 'near ${(query.radiusMeters / 1000).round()} km',
  ];
  return parts.join(' · ');
}

String _titleForQuery(DiscoverQuery query) {
  final String queryText = query.queryText.trim();
  if (queryText.isNotEmpty) {
    return queryText[0].toUpperCase() + queryText.substring(1);
  }
  if (query.selectedCategoryIds.isNotEmpty) {
    return '${query.selectedCategoryIds.first} idea';
  }
  return 'Recharge idea';
}

String _capitalized(String value) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}

String _smartSearchIntentSubtitle(SmartSearchHistoryEntity item) {
  final SmartSearchParseResult? parseResult = _smartRouteParseForSmartSearch(
    item,
  );
  if (parseResult == null) return _promptForQuery(item.query);
  return parseResult.routeIntent!.stepCategories
      .map(createTaxonomyLabelForPath)
      .join(' · ');
}

List<_IntentChipData> _smartSearchIntentChips(SmartSearchHistoryEntity item) {
  final SmartSearchParseResult? parseResult = _smartRouteParseForSmartSearch(
    item,
  );
  final List<_IntentChipData> queryChips = _intentChips(item.query);
  if (parseResult == null) return queryChips;
  final SmartRouteIntent routeIntent = parseResult.routeIntent!;
  return <_IntentChipData>[
    const _IntentChipData(icon: Icons.route_outlined, label: 'Smart route'),
    _IntentChipData(
      icon: Icons.timer_outlined,
      label: '${routeIntent.durationMinutes} min',
    ),
    _IntentChipData(
      icon: Icons.flag_outlined,
      label: '${routeIntent.stepCategories.length} stops',
    ),
    ...queryChips,
  ];
}

List<_IntentChipData> _intentChips(DiscoverQuery query) {
  return <_IntentChipData>[
    _IntentChipData(
      icon: Icons.category_outlined,
      label: query.selectedCategoryIds.isEmpty
          ? 'All categories'
          : query.selectedCategoryIds.first,
    ),
    _IntentChipData(
      icon: Icons.payments_outlined,
      label: query.freeOnly
          ? 'Free'
          : query.budgetMax == null
          ? 'Any price'
          : 'Under ${query.budgetMax!.toStringAsFixed(0)} EUR',
    ),
    _IntentChipData(
      icon: Icons.radar,
      label: query.unlimitedRadius
          ? 'Any area'
          : '${(query.radiusMeters / 1000).round()} km',
    ),
  ];
}

class _IntentChipData {
  const _IntentChipData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

String _scenarioSummary(ScenarioDraftEntity draft) {
  final List<String> lines = <String>[
    '${_moodLabel(draft.mood)} recharge scenario',
    '${draft.steps.length} stops · ${draft.totalDurationMinutes} min · '
        '${draft.totalDistanceKm.toStringAsFixed(1)} km',
    draft.totalPriceAmount == 0
        ? 'Free'
        : '${draft.totalPriceAmount.toStringAsFixed(0)} EUR',
    '',
    ...List<String>.generate(draft.steps.length, (int index) {
      final ScenarioStepEntity step = draft.steps[index];
      return '${index + 1}. ${step.title} - '
          '${createTaxonomyLabelForPath(step.category)}, '
          '${step.durationMinutes} min';
    }),
  ];
  return lines.join('\n');
}
