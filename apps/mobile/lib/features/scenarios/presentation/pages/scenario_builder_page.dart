import '../../../../core/localization/l10n_context.dart';
import '../../../../core/localization/recharge_formats.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/config/recharge_taxonomy.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../../app/application/planning_conversion_providers.dart';
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

class QuickPlanPage extends ConsumerStatefulWidget {
  const QuickPlanPage({
    super.key,
    this.seedParameters = const <String, String>{},
  });

  final Map<String, String> seedParameters;

  @override
  ConsumerState<QuickPlanPage> createState() => _QuickPlanPageState();
}

typedef ScenarioBuilderPage = QuickPlanPage;

class _QuickPlanPageState extends ConsumerState<QuickPlanPage>
    with WidgetsBindingObserver {
  Timer? _accessTimer;
  ScenarioBuilderController? _pageController;
  bool _checkingAccess = false;
  bool _foreground = true;
  String? _seedKey;
  bool _intentLoadScheduled = false;
  String? _storedPlanId;
  late bool _previewMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _previewMode = widget.seedParameters['preview'] == '1';
  }

  void _startAccessTimer() {
    if (_accessTimer != null) return;
    _accessTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final c = ref.read(scenarioBuilderControllerProvider);
      if (!c.invitedMode ||
          _checkingAccess ||
          !_foreground ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      _checkingAccess = true;
      try {
        await c.sync();
      } finally {
        _checkingAccess = false;
      }
    });
  }

  @override
  void dispose() {
    _accessTimer?.cancel();
    _pageController?.clearInvitedOnExit();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    final c = ref.read(scenarioBuilderControllerProvider);
    if (c.invitedMode) {
      c.hideInvitedContent();
      if (state == AppLifecycleState.resumed) unawaited(c.sync());
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScenarioBuilderController controller = ref.watch(
      scenarioBuilderControllerProvider,
    );
    _pageController = controller;
    ref.listen(authControllerProvider.select((c) => c.state.user?.id), (
      previous,
      next,
    ) {
      if (previous != null &&
          previous != next &&
          controller.persistenceEnabled) {
        controller.clearOwner();
      }
    });
    final storedPlanId = widget.seedParameters['quickPlanId'];
    if (controller.persistenceEnabled &&
        storedPlanId != null &&
        storedPlanId != _storedPlanId) {
      _storedPlanId = storedPlanId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.openStoredPlan(storedPlanId);
      });
    }
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
    if (controller.invitedMode) {
      _startAccessTimer();
      return _invitedView(controller);
    }
    _accessTimer?.cancel();
    _accessTimer = null;
    _scheduleSeed();
    _scheduleIntentLoad();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _previewMode
              ? context.l10n.quickPlanMyQuickPlan
              : context.l10n.quickPlanQuickPlan,
        ),
        actions: <Widget>[
          if (controller.persistenceEnabled)
            IconButton(
              tooltip: context.l10n.quickPlanInvitationsAccess,
              icon: const Icon(Icons.group_outlined),
              onPressed: () => _showAccess(controller),
            ),
          if (controller.persistenceEnabled)
            IconButton(
              tooltip: context.l10n.quickPlanRefresh,
              onPressed: controller.syncBusy ? null : () => controller.sync(),
              icon: const Icon(Icons.refresh),
            ),
          if (_previewMode)
            TextButton.icon(
              onPressed: () => setState(() => _previewMode = false),
              icon: const Icon(Icons.edit_outlined),
              label: Text(context.l10n.quickPlanEdit),
            )
          else
            IconButton(
              tooltip: context.l10n.quickPlanReset,
              onPressed: controller.reset,
              icon: const Icon(Icons.restart_alt),
            ),
        ],
      ),
      body: _previewMode
          ? _ScenarioPreview(
              title:
                  widget.seedParameters['title'] ??
                  context.l10n.quickPlanYourPlan,
              draft: draft,
              routeFit: state.routeFit,
              onEdit: () => setState(() => _previewMode = false),
              onMap: () => context.go(_mapRouteForScenario(draft)),
              onSave: () => _saveScenario(draft),
              onExpand: () => _expandToScenario(draft),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: <Widget>[
                _ScenarioHero(
                  draft: draft,
                  onMap: () => context.go(_mapRouteForScenario(draft)),
                  onSearch: () => context.go(RouteNames.search),
                  onCreate: () =>
                      context.go(_createRouteForScenario(context.l10n, draft)),
                  onSave: () => _saveScenario(draft),
                  onCopy: () => _copyScenario(draft),
                ),
                const SizedBox(height: 12),
                _ExpandToScenarioCard(
                  stopCount: draft.steps.length,
                  onExpand: draft.steps.isEmpty
                      ? null
                      : () => _expandToScenario(draft),
                ),
                const SizedBox(height: 14),
                if (savedSearches.isNotEmpty ||
                    smartSearchHistory.isNotEmpty) ...<Widget>[
                  _ScenarioSavedIntentPanel(
                    savedSearches: savedSearches,
                    smartSearchHistory: smartSearchHistory,
                    onApplySaved: (SavedSearchEntity search) => context.go(
                      _quickPlanRouteForSavedSearch(draft.id, search),
                    ),
                    onMapSaved: (SavedSearchEntity search) =>
                        context.go(_mapRouteForSavedSearch(search)),
                    onCreateSaved: (SavedSearchEntity search) =>
                        context.go(_createRouteForSavedSearch(search)),
                    onApplySmart: (SmartSearchHistoryEntity item) => context.go(
                      _quickPlanRouteForSmartSearch(draft.id, item),
                    ),
                    onMapSmart: (SmartSearchHistoryEntity item) =>
                        context.go(_mapRouteForSmartSearch(item)),
                    onCreateSmart: (SmartSearchHistoryEntity item) => context
                        .go(_createRouteForSmartSearch(context.l10n, item)),
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
                  onCreate: () =>
                      context.go(_createRouteForScenario(context.l10n, draft)),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.quickPlanRouteSteps,
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

  Widget _invitedView(ScenarioBuilderController c) {
    final p = c.invitedPlan;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.quickPlanInvitedPlan),
        actions: [
          IconButton(
            tooltip: context.l10n.quickPlanCloseInvited,
            onPressed: c.closeInvited,
            icon: const Icon(Icons.close),
          ),
          IconButton(
            tooltip: context.l10n.quickPlanRefreshAccess,
            onPressed: () => c.sync(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(context.l10n.quickPlanReadOnlyOnline),
          // The sync error is a technical object; the reader gets the fact.
          if (c.syncError != null)
            Text(context.l10n.quickPlanAccessUnavailable),
          if (p == null)
            Text(context.l10n.quickPlanContentHidden)
          else ...[
            Text(p.sourcePrompt),
            for (final step in p.steps)
              ListTile(title: Text(step.title), subtitle: Text(step.subtitle)),
          ],
          OutlinedButton(
            onPressed: () => c.actOnInvitation('leave', c.selectedInvitation!),
            child: Text(context.l10n.quickPlanLeavePlan),
          ),
        ],
      ),
    );
  }

  Future<String?> _askText(String title) async {
    final input = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: TextField(controller: input, maxLines: 4),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.quickPlanCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, input.text.trim()),
              child: Text(context.l10n.quickPlanContinue),
            ),
          ],
        ),
      );
    } finally {
      input.dispose();
    }
  }

  Future<void> _showAccess(ScenarioBuilderController c) async {
    await c.loadInvitations();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => ListenableBuilder(
        listenable: c,
        builder: (context, _) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .75,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(context.l10n.quickPlanInvitations),
                Text(context.l10n.quickPlanUseKnownUserId),
                if (c.syncError != null)
                  Text(context.l10n.quickPlanNotConfirmed),
                TextButton(
                  onPressed: c.loadInvitations,
                  child: Text(context.l10n.quickPlanRetryPending),
                ),
                TextButton(
                  onPressed: () async {
                    final id = await _askText(
                      context.l10n.quickPlanInviteUserId,
                    );
                    if (id != null && id.isNotEmpty) await c.inviteUser(id);
                  },
                  child: Text(context.l10n.quickPlanInviteToSaved),
                ),
                TextButton(
                  onPressed: () async {
                    final source = await _askText(
                      context.l10n.quickPlanImportJson,
                    );
                    if (source != null && source.isNotEmpty) {
                      await c.importPlan(source);
                    }
                  },
                  child: Text(context.l10n.quickPlanImportPersonal),
                ),
                TextButton(
                  onPressed: c.deletePlan,
                  child: Text(context.l10n.quickPlanDeletePersonal),
                ),
                for (final g in c.invitations)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ids are shown as published; the status is a code.
                          Text(
                            '${context.l10n.quickPlanPlanLabel} ${g.planId} · '
                            '${context.l10n.quickPlanGrantStatus(g.status)}',
                          ),
                          Text(
                            c.ownsInvitation(g)
                                ? '${context.l10n.quickPlanInvitee} ${g.inviteeId}'
                                : '${context.l10n.quickPlanOwner} ${g.ownerId}',
                          ),
                          Wrap(
                            children: [
                              if (c.ownsInvitation(g)) ...[
                                if (g.status == 'pending')
                                  TextButton(
                                    onPressed: () =>
                                        c.actOnInvitation('cancel', g),
                                    child: Text(
                                      context.l10n.quickPlanCancelInvite,
                                    ),
                                  ),
                                if (g.status == 'accepted')
                                  TextButton(
                                    onPressed: () =>
                                        c.actOnInvitation('revoke', g),
                                    child: Text(context.l10n.quickPlanRevoke),
                                  ),
                                if (!['pending', 'accepted'].contains(g.status))
                                  TextButton(
                                    onPressed: () =>
                                        c.inviteUser(g.inviteeId, previous: g),
                                    child: Text(context.l10n.quickPlanReinvite),
                                  ),
                              ] else ...[
                                if (g.status == 'pending') ...[
                                  TextButton(
                                    onPressed: () =>
                                        c.actOnInvitation('accept', g),
                                    child: Text(context.l10n.quickPlanAccept),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        c.actOnInvitation('decline', g),
                                    child: Text(context.l10n.quickPlanDecline),
                                  ),
                                ],
                                if (g.status == 'accepted') ...[
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(sheetContext);
                                      c.openInvited(g);
                                    },
                                    child: Text(
                                      context.l10n.quickPlanOpenReadOnly,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        c.actOnInvitation('leave', g),
                                    child: Text(context.l10n.quickPlanLeave),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
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
      final String origin = Uri.encodeComponent(
        RouteNames.quickPlanFor(draft.id),
      );
      context.push(
        '${RouteNames.signIn}?originRoute=$origin' // l10n-ignore: query string
        '&sourceScreen=quick_plan&sourceAction=save_quick_plan', // l10n-ignore: query string
      );
      return;
    }

    final controller = ref.read(scenarioBuilderControllerProvider);
    if (controller.persistenceEnabled) {
      if (controller.syncBusy) return;
      await controller.sync(save: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            controller.syncError == null
                ? context.l10n.quickPlanSaved
                : context.l10n.quickPlanNotSynced,
          ),
        ),
      );
      return;
    }
    final FavoriteItemEntity favorite = _favoriteFromScenario(
      context.l10n,
      draft,
    );
    await ref
        .read(favoritesControllerProvider)
        .addFavorite(favorite, sourceScreen: 'quick_plan');
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.quickPlanSaved)));
  }

  Future<void> _copyScenario(ScenarioDraftEntity draft) async {
    await Clipboard.setData(
      ClipboardData(text: _scenarioSummary(context.l10n, draft)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.quickPlanCopied)));
  }

  Future<void> _expandToScenario(ScenarioDraftEntity draft) async {
    final authState = ref.read(authControllerProvider).state;
    final user = authState.user;
    if (user == null) {
      final String origin = Uri.encodeComponent(
        RouteNames.quickPlanFor(draft.id),
      );
      context.go('${RouteNames.signIn}?origin=$origin');
      return;
    }
    final _ExpandQuickPlanSelection? selection =
        await _showExpandQuickPlanDialog(context, draft);
    if (selection == null || !mounted) return;

    final String title =
        widget.seedParameters['title']?.trim().isNotEmpty == true
        ? widget.seedParameters['title']!.trim()
        : 'Expanded Quick Plan'; // l10n-ignore: default title of the new Scenario, edited by its author
    PlanningConversionOutcome outcome = await ref
        .read(planningConversionFacadeProvider)
        .expand(
          ExpandLegacyQuickPlanRequest(
            draft: draft,
            selectedStopIds: selection.selectedStopIds,
            copyPrivateNotes: selection.copyPrivateNotes,
            requesterId: user.id,
            requesterEmail: user.email,
            requesterName: user.email.split('@').first,
            scenarioTitle: title,
          ),
        );
    if (!mounted) return;
    if (outcome.requiresRevisionConfirmation) {
      final bool continueWithLatest =
          await _confirmLatestQuickPlanRevision(context) ?? false;
      if (!continueWithLatest || !mounted) return;
      outcome = await ref
          .read(planningConversionFacadeProvider)
          .expand(
            ExpandLegacyQuickPlanRequest(
              draft: draft,
              selectedStopIds: selection.selectedStopIds,
              copyPrivateNotes: selection.copyPrivateNotes,
              requesterId: user.id,
              requesterEmail: user.email,
              requesterName: user.email.split('@').first,
              scenarioTitle: title,
              continueWithLatestSnapshot: true,
            ),
          );
    }
    if (!mounted) return;
    final String? handoffId = outcome.handoffId;
    if (handoffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.quickPlanExpandFailed)),
      );
      return;
    }
    context.go(
      Uri(
        path: RouteNames.create,
        queryParameters: <String, String>{'scenarioHandoffId': handoffId},
      ).toString(),
    );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.quickPlanTemplateApplied(template.label(context.l10n)),
        ),
      ),
    );
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
    required this.onExpand,
  });

  final String title;
  final ScenarioDraftEntity draft;
  final ScenarioRouteFit routeFit;
  final VoidCallback onEdit;
  final VoidCallback onMap;
  final Future<void> Function() onSave;
  final Future<void> Function() onExpand;

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
                        context.l10n.quickPlanFitLevel(routeFit.level.name),
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
                  context.l10n.quickPlanMoodReady(draft.mood.name),
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
                      value: draft.totalPriceAmount.minorUnits == 0
                          ? context.l10n.discoverFree
                          : RechargeFormats.money(
                              draft.totalPriceAmount,
                              context.l10n.localeName,
                            ),
                      label: 'budget',
                    ),
                    _PreviewStat(
                      icon: Icons.directions_walk_outlined,
                      value: context.l10n.discoverDistanceKm(
                        RechargeFormats.decimal(
                          draft.totalDistanceKm,
                          context.l10n.localeName,
                          maxFractionDigits: 1,
                        ),
                      ),
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
          context.l10n.quickPlanYourRoute,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (draft.steps.isEmpty)
          Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(context.l10n.quickPlanNoStopsFit),
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
                label: Text(context.l10n.quickPlanEditPlan),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                key: const Key('scenario-preview-map'),
                onPressed: onMap,
                icon: const Icon(Icons.map_outlined),
                label: Text(context.l10n.quickPlanOpenMap),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => onSave(),
          icon: const Icon(Icons.bookmark_add_outlined),
          label: Text(context.l10n.quickPlanSavePlan),
        ),
        const SizedBox(height: 4),
        FilledButton.tonalIcon(
          key: const Key('quick-plan-expand-to-scenario'),
          onPressed: draft.steps.isEmpty ? null : () => onExpand(),
          icon: const Icon(Icons.account_tree_outlined),
          label: Text(context.l10n.quickPlanExpandToScenario),
        ),
      ],
    );
  }
}

class _ExpandToScenarioCard extends StatelessWidget {
  const _ExpandToScenarioCard({
    required this.stopCount,
    required this.onExpand,
  });

  final int stopCount;
  final Future<void> Function()? onExpand;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              context.l10n.quickPlanNeedLargerPlan,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(context.l10n.quickPlanCopyStopsHint),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              key: const Key('quick-plan-expand-to-scenario'),
              onPressed: onExpand == null ? null : () => onExpand!(),
              icon: const Icon(Icons.account_tree_outlined),
              label: Text(context.l10n.quickPlanExpandStops(stopCount)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandQuickPlanSelection {
  const _ExpandQuickPlanSelection({
    required this.selectedStopIds,
    required this.copyPrivateNotes,
  });

  final Set<String> selectedStopIds;
  final bool copyPrivateNotes;
}

Future<_ExpandQuickPlanSelection?> _showExpandQuickPlanDialog(
  BuildContext context,
  ScenarioDraftEntity draft,
) {
  final Set<String> selected = draft.steps
      .map((ScenarioStepEntity step) => step.id)
      .toSet();
  var copyPrivateNotes = false;
  return showDialog<_ExpandQuickPlanSelection>(
    context: context,
    builder: (BuildContext context) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) => AlertDialog(
        title: Text(context.l10n.quickPlanExpandToScenario),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(context.l10n.quickPlanIndependentHint),
                const SizedBox(height: 10),
                Text(
                  context.l10n.quickPlanLegacyStopsHint,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final ScenarioStepEntity step in draft.steps)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selected.contains(step.id),
                    title: Text(step.title),
                    subtitle: Text(
                      context.l10n.discoverMinutes(step.durationMinutes),
                    ),
                    onChanged: (bool? value) {
                      setState(() {
                        value == true
                            ? selected.add(step.id)
                            : selected.remove(step.id);
                      });
                    },
                  ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: copyPrivateNotes,
                  title: Text(context.l10n.quickPlanCopyNotes),
                  subtitle: Text(context.l10n.quickPlanNoNotes),
                  onChanged: null,
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.quickPlanCancel),
          ),
          FilledButton(
            key: const Key('confirm-expand-to-scenario'),
            onPressed: selected.isEmpty
                ? null
                : () => Navigator.pop(
                    context,
                    _ExpandQuickPlanSelection(
                      selectedStopIds: Set<String>.unmodifiable(selected),
                      copyPrivateNotes: copyPrivateNotes,
                    ),
                  ),
            child: Text(context.l10n.quickPlanCreateIndependent),
          ),
        ],
      ),
    ),
  );
}

Future<bool?> _confirmLatestQuickPlanRevision(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(context.l10n.quickPlanChanged),
      content: Text(context.l10n.quickPlanRefreshOrContinue),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.quickPlanRefresh),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.quickPlanContinueSnapshot),
        ),
      ],
    ),
  );
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
              child: Text(
                context.l10n.quickPlanRoutePreview,
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
                      _TimelinePill(
                        context.l10n.discoverMinutes(step.durationMinutes),
                      ),
                      _TimelinePill(
                        context.l10n.discoverDistanceKm(
                          RechargeFormats.decimal(
                            step.distanceKm,
                            context.l10n.localeName,
                            maxFractionDigits: 1,
                          ),
                        ),
                      ),
                      _TimelinePill(
                        step.isFree
                            ? context.l10n.discoverFree
                            : RechargeFormats.money(
                                step.priceAmount,
                                context.l10n.localeName,
                              ),
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
                Expanded(
                  child: Text(
                    context.l10n.quickPlanBuildRechargeRoute,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${context.l10n.quickPlanMoodPlan(draft.mood.name)} · '
              '${context.l10n.discoverStops(draft.steps.length)}',
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
                    // The prompt is the reader's own text, shown as is.
                    label:
                        '${context.l10n.quickPlanIntentLabel}: '
                        '${_shortPrompt(draft.sourcePrompt)}',
                  ),
                _HeroPill(
                  label: context.l10n.discoverMinutes(
                    draft.totalDurationMinutes,
                  ),
                ),
                _HeroPill(
                  label: context.l10n.discoverDistanceKm(
                    RechargeFormats.decimal(
                      draft.totalDistanceKm,
                      context.l10n.localeName,
                      maxFractionDigits: 1,
                    ),
                  ),
                ),
                _HeroPill(
                  label: draft.totalPriceAmount.minorUnits == 0
                      ? context.l10n.discoverFree
                      : RechargeFormats.money(
                          draft.totalPriceAmount,
                          context.l10n.localeName,
                        ),
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
                    label: Text(context.l10n.quickPlanSave),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      onCopy();
                    },
                    icon: const Icon(Icons.copy),
                    label: Text(context.l10n.quickPlanCopy),
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
                    label: Text(context.l10n.quickPlanMap),
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
                    label: Text(context.l10n.quickPlanSearch),
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
              label: Text(context.l10n.quickPlanPublishRoute),
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
            Expanded(
              child: Text(
                context.l10n.quickPlanReadyIdeas,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
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
                      template.label(context.l10n),
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
                template.subtitle(context.l10n),
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
                    label: context.l10n.discoverMinutes(
                      template.durationMinutes,
                    ),
                  ),
                  _MetaChip(
                    icon: Icons.directions_walk,
                    label: template.walkingOnly
                        ? context.l10n.discoverWalkable
                        : context.l10n.discoverFlexibleTime,
                  ),
                  _MetaChip(
                    icon: Icons.payments_outlined,
                    label: template.freeOnly
                        ? context.l10n.discoverFree
                        : context.l10n.discoverMixedPrice,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Tooltip(
                message: context.l10n.quickPlanApplyTemplate(
                  template.label(context.l10n),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onApply,
                    icon: Icon(isActive ? Icons.check : Icons.route),
                    label: Text(
                      isActive
                          ? context.l10n.quickPlanApplied
                          : context.l10n.quickPlanUse,
                    ),
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
              context.l10n.quickPlanBuildFromSaved,
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
            typeLabel: context.l10n.quickPlanSavedConditions,
            title: search.title,
            subtitle: search.subtitle,
            query: search.query,
            applyTooltip: context.l10n.quickPlanApplySavedToBuilder,
            mapTooltip: context.l10n.quickPlanOpenSavedOnMap,
            createTooltip: context.l10n.quickPlanListingFromSaved,
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
            typeLabel: context.l10n.quickPlanSmartSearch,
            title: item.prompt.trim().isEmpty
                ? _titleForQuery(context.l10n, item.query)
                : item.prompt.trim(),
            subtitle: _smartSearchIntentSubtitle(item),
            query: item.query,
            chips: _smartSearchIntentChips(context.l10n, item),
            applyTooltip: context.l10n.quickPlanApplySmartToBuilder,
            mapTooltip: context.l10n.quickPlanOpenSmartOnMap,
            createTooltip: context.l10n.quickPlanListingFromSmart,
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
              children: (chips ?? _intentChips(context.l10n, query))
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
          context.l10n.quickPlanConditions,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        SegmentedButton<ScenarioMood>(
          segments: <ButtonSegment<ScenarioMood>>[
            ButtonSegment<ScenarioMood>(
              value: ScenarioMood.calm,
              icon: Icon(Icons.self_improvement),
              label: Text(context.l10n.quickPlanMoodCalm),
            ),
            ButtonSegment<ScenarioMood>(
              value: ScenarioMood.social,
              icon: Icon(Icons.groups),
              label: Text(context.l10n.quickPlanMoodSocial),
            ),
            ButtonSegment<ScenarioMood>(
              value: ScenarioMood.active,
              icon: Icon(Icons.directions_run),
              label: Text(context.l10n.quickPlanMoodActive),
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
          title: Text(context.l10n.quickPlanFreeOnly),
          value: draft.freeOnly,
          onChanged: onFreeOnlyChanged,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.quickPlanWalkingRoute),
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
                    context.l10n.quickPlanRouteFit,
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
              context.l10n.quickPlanFitLevel(routeFit.level.name),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              context.l10n.quickPlanFitSummary(routeFit.level.name),
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
                      '${context.l10n.discoverMinutes(draft.maxDurationMinutes)}',
                ),
                _MetaChip(
                  icon: Icons.directions_walk,
                  label: draft.walkingOnly
                      ? context.l10n.discoverWalkable
                      : context.l10n.discoverFlexibleTime,
                ),
                _MetaChip(
                  icon: Icons.payments_outlined,
                  label: draft.freeOnly
                      ? context.l10n.quickPlanFreeOnly
                      : draft.totalPriceAmount.minorUnits == 0
                      ? context.l10n.discoverFree
                      : RechargeFormats.money(
                          draft.totalPriceAmount,
                          context.l10n.localeName,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: routeFit.insights
                  .map(
                    (ScenarioFitInsight insight) => _MetaChip(
                      icon: Icons.check_circle_outline,
                      label: _fitInsightText(context.l10n, insight),
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
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(context.l10n.quickPlanOptimize),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMap,
                    icon: const Icon(Icons.map_outlined),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(context.l10n.quickPlanMapRoute),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: context.l10n.quickPlanPublishOptimized,
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
                        label: context.l10n.discoverMinutes(
                          step.durationMinutes,
                        ),
                      ),
                      _MetaChip(
                        icon: Icons.near_me,
                        label: context.l10n.discoverDistanceKm(
                          RechargeFormats.decimal(
                            step.distanceKm,
                            context.l10n.localeName,
                            maxFractionDigits: 1,
                          ),
                        ),
                      ),
                      _MetaChip(
                        icon: Icons.payments,
                        label: step.isFree
                            ? context.l10n.discoverFree
                            : RechargeFormats.money(
                                step.priceAmount,
                                context.l10n.localeName,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      IconButton.outlined(
                        tooltip: context.l10n.quickPlanMoveUp,
                        onPressed: canMoveUp ? onMoveUp : null,
                        icon: const Icon(Icons.keyboard_arrow_up),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: context.l10n.quickPlanMoveDown,
                        onPressed: canMoveDown ? onMoveDown : null,
                        icon: const Icon(Icons.keyboard_arrow_down),
                      ),
                      const Spacer(),
                      IconButton.outlined(
                        tooltip: context.l10n.quickPlanRemoveStop,
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
          context.l10n.quickPlanSuggestedStops,
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
                    '${context.l10n.discoverMinutes(step.durationMinutes)}',
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
              label: Text(context.l10n.quickPlanAdd),
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
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
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
          Text(context.l10n.quickPlanNoStopsMatch),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onReset,
            child: Text(context.l10n.quickPlanResetBuilder),
          ),
        ],
      ),
    );
  }
}

final List<_ScenarioRouteTemplate>
_scenarioTemplates = <_ScenarioRouteTemplate>[
  _ScenarioRouteTemplate(
    label: (AppLocalizations l10n) => l10n.quickPlanTplCoffee,
    subtitle: (AppLocalizations l10n) => l10n.quickPlanTplCoffeeHint,
    icon: Icons.local_cafe_outlined,
    mood: ScenarioMood.calm,
    durationMinutes: 90,
    freeOnly: false,
    walkingOnly: true,
    prompt:
        'coffee reset walk', // l10n-ignore: search prompt text built from the saved query, not UI copy
    stepCategories: <String>[
      'food_drinks.coffee',
      'wellness_recharge.calm_walk',
    ],
  ),
  _ScenarioRouteTemplate(
    label: (AppLocalizations l10n) => l10n.quickPlanTplFreeCity,
    subtitle: (AppLocalizations l10n) => l10n.quickPlanTplFreeCityHint,
    icon: Icons.self_improvement,
    mood: ScenarioMood.calm,
    durationMinutes: 90,
    freeOnly: true,
    walkingOnly: true,
    prompt:
        'free calm city walk', // l10n-ignore: search prompt text built from the saved query, not UI copy
    stepCategories: <String>['wellness_recharge.calm_walk'],
  ),
  _ScenarioRouteTemplate(
    label: (AppLocalizations l10n) => l10n.quickPlanTplSocial,
    subtitle: (AppLocalizations l10n) => l10n.quickPlanTplSocialHint,
    icon: Icons.groups_outlined,
    mood: ScenarioMood.social,
    durationMinutes: 150,
    freeOnly: false,
    walkingOnly: true,
    prompt:
        'social evening near me', // l10n-ignore: search prompt text built from the saved query, not UI copy
    stepCategories: <String>[
      'games_indoor.board_games',
      'music_nightlife.afterwork_drinks',
    ],
  ),
  _ScenarioRouteTemplate(
    label: (AppLocalizations l10n) => l10n.quickPlanTplActive,
    subtitle: (AppLocalizations l10n) => l10n.quickPlanTplActiveHint,
    icon: Icons.directions_run,
    mood: ScenarioMood.active,
    durationMinutes: 120,
    freeOnly: false,
    walkingOnly: true,
    prompt:
        'active tennis and walk', // l10n-ignore: search prompt text built from the saved query, not UI copy
    stepCategories: <String>[
      'sport.tennis',
      'outdoor_nature_walking.city_walk',
    ],
  ),
];

class _ScenarioRouteTemplate {
  const _ScenarioRouteTemplate({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.mood,
    required this.durationMinutes,
    required this.freeOnly,
    required this.walkingOnly,
    required this.prompt,
    required this.stepCategories,
  });

  /// Label and subtitle in the reader's language.
  final String Function(AppLocalizations l10n) label;
  final String Function(AppLocalizations l10n) subtitle;
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
    ScenarioMood.calm => 'Calm', // l10n-ignore: Create seed prefill data
    ScenarioMood.social => 'Social', // l10n-ignore: Create seed prefill data
    ScenarioMood.active => 'Active', // l10n-ignore: Create seed prefill data
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

FavoriteItemEntity _favoriteFromScenario(
  AppLocalizations l10n,
  ScenarioDraftEntity draft,
) {
  final DateTime now = DateTime.now().toUtc();
  final String categoryKey = draft.steps
      .map((ScenarioStepEntity step) => step.category.replaceAll('.', '_'))
      .join('_');
  return FavoriteItemEntity(
    id: 'quick_plan_${draft.id}_$categoryKey',
    title: l10n.quickPlanMoodQuickPlan(draft.mood.name),
    subtitle:
        '${l10n.discoverStops(draft.steps.length)} · '
        '${l10n.discoverMinutes(draft.totalDurationMinutes)}',
    city: 'Riga', // l10n-ignore: market city name
    category: 'quick_plan',
    startsAtUtc: now,
    distanceKm: draft.totalDistanceKm,
    priceAmount: draft.totalPriceAmount,
    isFree: draft.totalPriceAmount.minorUnits == 0,
    savedAtUtc: now,
    targetRoute: _targetRouteForScenario(draft),
    planningTargetKind: FavoritePlanningTargetKind.quickPlan,
    planningTargetId: draft.id,
  );
}

String _targetRouteForScenario(ScenarioDraftEntity draft) {
  return Uri(
    path: RouteNames.quickPlanFor(draft.id),
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
      'mode': 'route',
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

String _createRouteForScenario(
  AppLocalizations l10n,
  ScenarioDraftEntity draft,
) {
  final String steps = draft.steps
      .map((ScenarioStepEntity step) => step.category)
      .join(',');
  final String prompt = draft.sourcePrompt.trim().isEmpty
      ? '${_moodLabel(draft.mood)} route with ${draft.steps.length} stops' // l10n-ignore: Create seed prefill data
      : draft.sourcePrompt.trim();
  return Uri(
    path: RouteNames.create,
    queryParameters: <String, String>{
      'source': 'quick_plan_route_seed',
      'type': 'route',
      'title':
          '${_moodLabel(draft.mood)} recharge route', // l10n-ignore: Create seed prefill data
      'subtitle':
          '${draft.steps.length} stops · ' // l10n-ignore: Create seed prefill data
          '${draft.totalDurationMinutes} min · ' // l10n-ignore: Create seed prefill data
          '${draft.totalDistanceKm.toStringAsFixed(1)} km', // l10n-ignore: Create seed prefill data
      'q': prompt,
      'category': 'route',
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

String _createRouteForSmartSearch(
  AppLocalizations l10n,
  SmartSearchHistoryEntity item,
) {
  final SmartSearchParseResult? parseResult = _smartRouteParseForSmartSearch(
    item,
  );
  if (parseResult != null) {
    final SmartRouteIntent routeIntent = parseResult.routeIntent!;
    return Uri(
      path: RouteNames.create,
      queryParameters: <String, String>{
        ..._smartRouteParameters(parseResult, includeMode: false),
        'source': 'smart_route_seed',
        'type': 'route',
        'title':
            '${_capitalized(routeIntent.mood)} recharge route', // l10n-ignore: Create seed prefill data
        'subtitle':
            '${routeIntent.stepCategories.length} stops · ' // l10n-ignore: Create seed prefill data
            '${routeIntent.durationMinutes} min · smart route', // l10n-ignore: Create seed prefill data
        'q': parseResult.originalText.trim(),
        'category': 'route',
      },
    ).toString();
  }
  return _createRouteForQuery(
    item.query,
    source: 'smart_search',
    title: _titleForQuery(l10n, item.query),
    subtitle: item.prompt,
  );
}

String _quickPlanRouteForSavedSearch(
  String quickPlanId,
  SavedSearchEntity search,
) {
  return _quickPlanRouteForQuery(
    quickPlanId,
    search.query,
    prompt: _promptForQuery(search.query),
  );
}

String _quickPlanRouteForSmartSearch(
  String quickPlanId,
  SmartSearchHistoryEntity item,
) {
  final SmartSearchParseResult? parseResult = _smartRouteParseForSmartSearch(
    item,
  );
  if (parseResult != null) {
    return Uri(
      path: RouteNames.quickPlanFor(quickPlanId),
      queryParameters: _smartRouteParameters(parseResult, includeMode: false),
    ).toString();
  }
  final String prompt = item.prompt.trim().isEmpty
      ? _promptForQuery(item.query)
      : item.prompt.trim();
  return _quickPlanRouteForQuery(quickPlanId, item.query, prompt: prompt);
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
    if (includeMode) 'mode': 'route',
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

String _quickPlanRouteForQuery(
  String quickPlanId,
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
    path: RouteNames.quickPlanFor(quickPlanId),
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
    if (query.budgetMax != null)
      'under ${query.budgetMax!.toStringAsFixed(0)}', // l10n-ignore: search prompt text built from the saved query, not UI copy
    query.unlimitedRadius
        ? 'any area' // l10n-ignore: search prompt text built from the saved query, not UI copy
        : 'near ${(query.radiusMeters / 1000).round()} km', // l10n-ignore: search prompt text built from the saved query, not UI copy
  ];
  return parts.join(' · ');
}

String _titleForQuery(AppLocalizations l10n, DiscoverQuery query) {
  final String queryText = query.queryText.trim();
  if (queryText.isNotEmpty) {
    return queryText[0].toUpperCase() + queryText.substring(1);
  }
  if (query.selectedCategoryIds.isNotEmpty) {
    return '${query.selectedCategoryIds.first} idea';
  }
  return l10n.quickPlanRechargeIdea;
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

List<_IntentChipData> _smartSearchIntentChips(
  AppLocalizations l10n,
  SmartSearchHistoryEntity item,
) {
  final SmartSearchParseResult? parseResult = _smartRouteParseForSmartSearch(
    item,
  );
  final List<_IntentChipData> queryChips = _intentChips(l10n, item.query);
  if (parseResult == null) return queryChips;
  final SmartRouteIntent routeIntent = parseResult.routeIntent!;
  return <_IntentChipData>[
    _IntentChipData(
      icon: Icons.route_outlined,
      label: l10n.quickPlanSmartRoute,
    ),
    _IntentChipData(
      icon: Icons.timer_outlined,
      label: l10n.discoverMinutes(routeIntent.durationMinutes),
    ),
    _IntentChipData(
      icon: Icons.flag_outlined,
      label: '${routeIntent.stepCategories.length} stops',
    ),
    ...queryChips,
  ];
}

List<_IntentChipData> _intentChips(AppLocalizations l10n, DiscoverQuery query) {
  return <_IntentChipData>[
    _IntentChipData(
      icon: Icons.category_outlined,
      label: query.selectedCategoryIds.isEmpty
          ? l10n.quickPlanAllCategories
          : query.selectedCategoryIds.first,
    ),
    _IntentChipData(
      icon: Icons.payments_outlined,
      label: query.freeOnly
          ? l10n.discoverFree
          : query.budgetMax == null
          ? l10n.quickPlanAnyPrice
          : l10n.discoverUnder(
              RechargeFormats.money(query.budgetMax!, l10n.localeName),
            ),
    ),
    _IntentChipData(
      icon: Icons.radar,
      label: query.unlimitedRadius
          ? l10n.quickPlanAnyArea
          : l10n.discoverDistanceKm('${(query.radiusMeters / 1000).round()}'),
    ),
  ];
}

class _IntentChipData {
  const _IntentChipData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

String _scenarioSummary(AppLocalizations l10n, ScenarioDraftEntity draft) {
  final List<String> lines = <String>[
    l10n.discoverMoodRechargeScenario(draft.mood.name),
    '${l10n.discoverStops(draft.steps.length)} · '
        '${l10n.discoverMinutes(draft.totalDurationMinutes)} · '
        '${l10n.discoverDistanceKm(RechargeFormats.decimal(draft.totalDistanceKm, l10n.localeName, maxFractionDigits: 1))}',
    draft.totalPriceAmount.minorUnits == 0
        ? l10n.discoverFree
        : RechargeFormats.money(draft.totalPriceAmount, l10n.localeName),
    '',
    ...List<String>.generate(draft.steps.length, (int index) {
      final ScenarioStepEntity step = draft.steps[index];
      return '${index + 1}. ${step.title} - '
          '${createTaxonomyLabelForPath(step.category)}, '
          '${l10n.discoverMinutes(step.durationMinutes)}';
    }),
  ];
  return lines.join('\n');
}

String _fitInsightText(
  AppLocalizations l10n,
  ScenarioFitInsight insight,
) => switch (insight.kind) {
  ScenarioFitInsightKind.noStops => l10n.quickPlanFitNoStops,
  ScenarioFitInsightKind.trimMinutes => l10n.quickPlanFitTrim(insight.minutes),
  ScenarioFitInsightKind.fitsMinutes => l10n.quickPlanFitFits(insight.minutes),
  ScenarioFitInsightKind.roomForStop => l10n.quickPlanFitRoom,
  ScenarioFitInsightKind.removePaidStops => l10n.quickPlanFitRemovePaid,
  ScenarioFitInsightKind.freeRoute => l10n.quickPlanFitFreeRoute,
  ScenarioFitInsightKind.totalPrice => l10n.quickPlanFitTotalPrice(
    RechargeFormats.money(insight.price!, l10n.localeName),
  ),
  ScenarioFitInsightKind.shortenTransfers => l10n.quickPlanFitShortenTransfers,
  ScenarioFitInsightKind.totalDistance => l10n.quickPlanFitTotalDistance(
    RechargeFormats.decimal(
      insight.distanceKm,
      l10n.localeName,
      maxFractionDigits: 1,
    ),
  ),
};
