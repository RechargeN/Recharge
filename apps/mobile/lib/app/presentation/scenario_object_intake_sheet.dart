import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/id/id_generator.dart';
import '../../core/localization/l10n_context.dart';
import '../../core/localization/recharge_formats.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/application/controllers/auth_controller.dart';
import '../../features/auth/presentation/widgets/auth_gate_sheet.dart';
import '../../features/create/domain/entities/scenario_draft_data.dart';
import '../../features/create/domain/entities/scenario_item_draft.dart';
import '../../features/create/domain/entities/scenario_object_intake.dart';
import '../../features/create/domain/repositories/create_draft_collection_repository.dart';
import '../../features/create/presentation/widgets/create_form_texts.dart';
import '../../features/discover/domain/entities/discover_item_entity.dart';
import '../../features/discover/domain/entities/published_event_discovery_entity.dart';
import '../application/controllers/scenario_object_intake_controller.dart';
import '../application/scenario_object_intake_providers.dart';
import '../application/scenario_object_intake_telemetry.dart';
import '../application/state/scenario_object_intake_state.dart';
import '../di/service_locator.dart';

enum ScenarioObjectIntakeSurface { details, search, map }

ScenarioIntakeSourceSurface _domainSurface(
  ScenarioObjectIntakeSurface surface,
) => switch (surface) {
  ScenarioObjectIntakeSurface.details => ScenarioIntakeSourceSurface.details,
  ScenarioObjectIntakeSurface.search => ScenarioIntakeSourceSurface.search,
  ScenarioObjectIntakeSurface.map => ScenarioIntakeSourceSurface.map,
};

bool isScenarioObjectIntakeSurfaceEnabled(
  WidgetRef ref,
  ScenarioObjectIntakeSurface surface, {
  bool multiSelect = false,
}) {
  final config = ref.watch(scenarioObjectIntakeConfigProvider);
  return config.allowsSurface(_domainSurface(surface)) &&
      (!multiSelect || config.multiSelectEnabled);
}

class ScenarioObjectIntakeSheetResult {
  const ScenarioObjectIntakeSheetResult({
    required this.targetDraftId,
    required this.itemCount,
    required this.openScenario,
  });

  final String targetDraftId;
  final int itemCount;
  final bool openScenario;
}

Future<bool> requireScenarioObjectIntakeAuth({
  required BuildContext context,
  required WidgetRef ref,
  required String sourceScreen,
  required String sourceAction,
  required String originRoute,
}) async {
  final authController = ref.read(authControllerProvider);
  if (authController.state.user != null) return true;
  authController.trackAuthGateViewed(
    sourceScreen: sourceScreen,
    sourceAction: sourceAction,
  );
  await showAuthGateSheet(
    context,
    action: ProtectedAction.create,
    sourceScreen: sourceScreen,
    sourceAction: sourceAction,
    originRoute: originRoute,
    allowGuest: false,
    onContinueAsGuest: () {},
  );
  return false;
}

Future<ScenarioObjectIntakeSheetResult?> launchScenarioObjectIntake({
  required BuildContext context,
  required WidgetRef ref,
  required List<DiscoverItemEntity> items,
  required ScenarioObjectIntakeSurface sourceSurface,
  required String sourceScreen,
  required String sourceAction,
  required String originRoute,
}) async {
  final config = ref.read(scenarioObjectIntakeConfigProvider);
  if (!config.allowsSurface(_domainSurface(sourceSurface)) ||
      items.isEmpty ||
      items.length > config.maxBatchSize ||
      (items.length > 1 && !config.multiSelectEnabled)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.scenarioIntakeUnavailable)),
      );
    }
    return null;
  }
  final authenticated = await requireScenarioObjectIntakeAuth(
    context: context,
    ref: ref,
    sourceScreen: sourceScreen,
    sourceAction: sourceAction,
    originRoute: originRoute,
  );
  if (!authenticated || !context.mounted) return null;
  final user = ref.read(authControllerProvider).state.user;
  if (user == null) return null;
  return showScenarioObjectIntakeSheet(
    context: context,
    ref: ref,
    items: items,
    sourceSurface: sourceSurface,
    requesterId: user.id,
    requesterEmail: user.email,
    requesterName: user.email.split('@').first,
    isRequesterAuthenticated: () =>
        ref.read(authControllerProvider).state.user?.id == user.id,
  );
}

Future<ScenarioObjectIntakeSheetResult?> showScenarioObjectIntakeSheet({
  required BuildContext context,
  required WidgetRef ref,
  required List<DiscoverItemEntity> items,
  required ScenarioObjectIntakeSurface sourceSurface,
  required String requesterId,
  required String requesterEmail,
  required String requesterName,
  required bool Function() isRequesterAuthenticated,
}) async {
  final config = ref.read(scenarioObjectIntakeConfigProvider);
  if (!config.allowsSurface(_domainSurface(sourceSurface)) ||
      items.isEmpty ||
      items.length > config.maxBatchSize ||
      (items.length > 1 && !config.multiSelectEnabled)) {
    return null;
  }
  ScenarioObjectIntakeIntent intent;
  try {
    intent = ref
        .read(discoverScenarioIntakeAdapterProvider)
        .toIntent(
          items: items,
          sourceSurface: _domainSurface(sourceSurface),
          intentId: sl<IdGenerator>().generate(),
          requesterId: requesterId,
          checkedAtUtc: DateTime.now().toUtc(),
        );
  } on FormatException {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
        // The adapter's FormatException text is for developers; the user
        // sees the generic refusal.
      ).showSnackBar(
        SnackBar(content: Text(context.l10n.scenarioIntakeUnavailable)),
      );
    }
    return null;
  }
  if (!context.mounted) return null;
  return _presentScenarioObjectIntakeSheet(
    context: context,
    ref: ref,
    intent: intent,
    organizerEmail: requesterEmail,
    organizerName: requesterName,
    isRequesterAuthenticated: isRequesterAuthenticated,
  );
}

/// `DTL_EVT_01_EVENT_DETAILS_SLICE_SPEC.md` §4.3 — Event's own entry
/// point, parallel to [launchScenarioObjectIntake] but built from
/// [PublishedEventDiscoveryEntity] via
/// `DiscoverScenarioIntakeAdapter.toEventIntent`, never by converting the
/// event back into a [DiscoverItemEntity]. Always single-item/`details`
/// surface — Event Details has no multi-select tray.
Future<ScenarioObjectIntakeSheetResult?> launchScenarioObjectIntakeForEvent({
  required BuildContext context,
  required WidgetRef ref,
  required PublishedEventDiscoveryEntity event,
  required String sourceScreen,
  required String sourceAction,
  required String originRoute,
}) async {
  final config = ref.read(scenarioObjectIntakeConfigProvider);
  if (!config.allowsSurface(ScenarioIntakeSourceSurface.details)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.scenarioIntakeUnavailable)),
      );
    }
    return null;
  }
  final authenticated = await requireScenarioObjectIntakeAuth(
    context: context,
    ref: ref,
    sourceScreen: sourceScreen,
    sourceAction: sourceAction,
    originRoute: originRoute,
  );
  if (!authenticated || !context.mounted) return null;
  final user = ref.read(authControllerProvider).state.user;
  if (user == null) return null;

  ScenarioObjectIntakeIntent intent;
  try {
    intent = ref
        .read(discoverScenarioIntakeAdapterProvider)
        .toEventIntent(
          event: event,
          intentId: sl<IdGenerator>().generate(),
          requesterId: user.id,
          checkedAtUtc: DateTime.now().toUtc(),
        );
  } on FormatException {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
        // The adapter's FormatException text is for developers; the user
        // sees the generic refusal.
      ).showSnackBar(
        SnackBar(content: Text(context.l10n.scenarioIntakeUnavailable)),
      );
    }
    return null;
  }
  if (!context.mounted) return null;
  return _presentScenarioObjectIntakeSheet(
    context: context,
    ref: ref,
    intent: intent,
    organizerEmail: user.email,
    organizerName: user.email.split('@').first,
    isRequesterAuthenticated: () =>
        ref.read(authControllerProvider).state.user?.id == user.id,
  );
}

/// Shared tail: present the sheet for an already-built [intent], track
/// telemetry, and clean up on cancel — used by both the `items`-based
/// (Search/Map, multi-select) and Event (single-item) entry points above.
Future<ScenarioObjectIntakeSheetResult?> _presentScenarioObjectIntakeSheet({
  required BuildContext context,
  required WidgetRef ref,
  required ScenarioObjectIntakeIntent intent,
  required String organizerEmail,
  required String organizerName,
  required bool Function() isRequesterAuthenticated,
}) async {
  final telemetry = ref.read(scenarioObjectIntakeTelemetryProvider);
  telemetry.track(
    intent: intent,
    action: ScenarioObjectIntakeTelemetryAction.open,
    result: ScenarioObjectIntakeTelemetryResult.success,
  );
  final controller = ScenarioObjectIntakeController(
    intent: intent,
    facade: ref.read(scenarioObjectIntakeFacadeProvider),
    organizerEmail: organizerEmail,
    organizerName: organizerName,
    telemetry: telemetry,
  );
  unawaited(controller.initialize());
  final result = await showModalBottomSheet<ScenarioObjectIntakeSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    builder: (context) => _ScenarioObjectIntakeSheet(
      controller: controller,
      isRequesterAuthenticated: isRequesterAuthenticated,
    ),
  );
  if (result == null &&
      controller.state.stage != ScenarioObjectIntakeStage.success) {
    telemetry.track(
      intent: intent,
      action: ScenarioObjectIntakeTelemetryAction.cancel,
      result: ScenarioObjectIntakeTelemetryResult.cancelled,
    );
    await controller.discard();
  }
  controller.dispose();
  return result;
}

class _ScenarioObjectIntakeSheet extends StatelessWidget {
  const _ScenarioObjectIntakeSheet({
    required this.controller,
    required this.isRequesterAuthenticated,
  });

  final ScenarioObjectIntakeController controller;
  final bool Function() isRequesterAuthenticated;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        return PopScope(
          canPop: state.stage != ScenarioObjectIntakeStage.applying,
          child: FractionallySizedBox(
            heightFactor: 0.92,
            child: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Column(
                children: <Widget>[
                  _SheetHeader(
                    stage: state.stage,
                    onClose: state.stage == ScenarioObjectIntakeStage.applying
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: switch (state.stage) {
                      ScenarioObjectIntakeStage.loading ||
                      ScenarioObjectIntakeStage.applying => _LoadingStep(
                        applying:
                            state.stage == ScenarioObjectIntakeStage.applying,
                      ),
                      ScenarioObjectIntakeStage.target => _TargetStep(
                        controller: controller,
                        state: state,
                      ),
                      ScenarioObjectIntakeStage.placement => _PlacementStep(
                        controller: controller,
                        state: state,
                      ),
                      ScenarioObjectIntakeStage.review => _ReviewStep(
                        controller: controller,
                        state: state,
                        isRequesterAuthenticated: isRequesterAuthenticated,
                      ),
                      ScenarioObjectIntakeStage.success => _SuccessStep(
                        state: state,
                      ),
                      ScenarioObjectIntakeStage.error => _ErrorStep(
                        message: state.message,
                        onRetry: controller.retry,
                      ),
                    },
                  ),
                  if (state.stage == ScenarioObjectIntakeStage.success)
                    _SuccessActions(
                      state: state,
                      onStay: () => Navigator.of(context).pop(
                        ScenarioObjectIntakeSheetResult(
                          targetDraftId: state.successTargetId!,
                          itemCount: state.successItemCount,
                          openScenario: false,
                        ),
                      ),
                      onOpen: () {
                        controller.trackOpenTarget();
                        Navigator.of(context).pop(
                          ScenarioObjectIntakeSheetResult(
                            targetDraftId: state.successTargetId!,
                            itemCount: state.successItemCount,
                            openScenario: true,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.stage, required this.onClose});

  final ScenarioObjectIntakeStage stage;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final step = context.l10n.scenarioIntakeStep(stage.name);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.scenarioIntakeTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(step, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.scenarioIntakeClose,
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _TargetStep extends StatelessWidget {
  const _TargetStep({required this.controller, required this.state});

  final ScenarioObjectIntakeController controller;
  final ScenarioObjectIntakeState state;

  @override
  Widget build(BuildContext context) {
    return _StepScroll(
      children: <Widget>[
        Text(
          context.l10n.scenarioIntakeChooseTarget,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(context.l10n.scenarioIntakeOnlyPrivateDrafts),
        const SizedBox(height: 12),
        if (state.targets.isEmpty)
          _Notice(
            icon: Icons.inbox_outlined,
            text: context.l10n.scenarioIntakeNoTargets,
          ),
        if (state.targets.isNotEmpty)
          RadioGroup<String>(
            groupValue: state.newTargetSelected ? null : state.selectedTargetId,
            onChanged: (value) {
              if (value != null) controller.selectTarget(value);
            },
            child: Column(
              children: <Widget>[
                for (final target in state.targets)
                  RadioListTile<String>(
                    value: target.id,
                    title: Text(
                      target.title.trim().isEmpty
                          ? context.l10n.scenarioIntakeUntitled
                          : target.title,
                    ),
                    subtitle: Text(_targetSummary(context, target)),
                  ),
              ],
            ),
          ),
        if (controller.canCreateNewTarget) ...<Widget>[
          const Divider(),
          RadioGroup<bool>(
            groupValue: state.newTargetSelected ? true : null,
            onChanged: (_) => controller.selectNewTarget(),
            child: RadioListTile<bool>(
              value: true,
              title: Text(context.l10n.scenarioIntakeCreateNew),
              subtitle: Text(context.l10n.scenarioIntakeCreateNewHint),
            ),
          ),
        ],
        if (state.newTargetSelected)
          TextFormField(
            key: ValueKey<String>(state.newTargetTitle),
            initialValue: state.newTargetTitle,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: context.l10n.scenarioIntakeTitleField,
            ),
            onChanged: controller.updateNewTargetTitle,
          ),
        if (state.message != null)
          _ErrorText(context.l10n.scenarioIntakeNotice(state.message!.name)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: controller.continueFromTarget,
          child: Text(context.l10n.scenarioIntakeContinue),
        ),
      ],
    );
  }
}

class _PlacementStep extends StatelessWidget {
  const _PlacementStep({required this.controller, required this.state});

  final ScenarioObjectIntakeController controller;
  final ScenarioObjectIntakeState state;

  @override
  Widget build(BuildContext context) {
    return _StepScroll(
      children: <Widget>[
        Text(
          state.selectedTargetTitle ??
              context.l10n.scenarioIntakeScenarioFallback,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: state.selectedDayId ?? '__unscheduled__',
          decoration: InputDecoration(
            labelText: context.l10n.scenarioIntakeDay,
          ),
          items: <DropdownMenuItem<String>>[
            for (final day in state.days)
              DropdownMenuItem<String>(
                value: day.id,
                child: Text(
                  day.dateLabel == null
                      ? day.title
                      : '${day.title} · ${_localDate(context, day.dateLabel!)}',
                ),
              ),
            DropdownMenuItem<String>(
              value: '__unscheduled__',
              child: Text(context.l10n.scenarioIntakeUnscheduled),
            ),
          ],
          onChanged: (value) =>
              controller.setDay(value == '__unscheduled__' ? null : value),
        ),
        if (state.selectedDayId != null) ...<Widget>[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: state.afterItemId ?? '__end__',
            decoration: InputDecoration(
              labelText: context.l10n.scenarioIntakeInsert,
            ),
            items: <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: '__end__',
                child: Text(context.l10n.scenarioIntakeAtEnd),
              ),
              for (final anchor in state.anchors)
                DropdownMenuItem<String>(
                  value: anchor.id,
                  // The stop title is shown as is, after a localized label.
                  child: Text(
                    '${context.l10n.scenarioIntakeAfterLabel} '
                    '${anchor.title ?? createOptionText(context.l10n, anchor.kind)}',
                  ),
                ),
            ],
            onChanged: (value) =>
                controller.setAfterItem(value == '__end__' ? null : value),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          context.l10n.scenarioIntakeRole,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SegmentedButton<ScenarioItemRole>(
          segments: <ButtonSegment<ScenarioItemRole>>[
            ButtonSegment<ScenarioItemRole>(
              value: ScenarioItemRole.mandatory,
              label: Text(context.l10n.scenarioIntakeMandatory),
            ),
            ButtonSegment<ScenarioItemRole>(
              value: ScenarioItemRole.optional,
              label: Text(context.l10n.scenarioIntakeOptional),
            ),
          ],
          selected: <ScenarioItemRole>{state.role},
          onSelectionChanged: (value) => controller.setRole(value.single),
        ),
        if (state.message != null)
          _ErrorText(context.l10n.scenarioIntakeNotice(state.message!.name)),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: controller.back,
                child: Text(context.l10n.scenarioIntakeBack),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: controller.continueToReview,
                child: Text(context.l10n.scenarioIntakeReview),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.controller,
    required this.state,
    required this.isRequesterAuthenticated,
  });

  final ScenarioObjectIntakeController controller;
  final ScenarioObjectIntakeState state;
  final bool Function() isRequesterAuthenticated;

  @override
  Widget build(BuildContext context) {
    final byRef = <ScenarioObjectRef, ScenarioIntakeCandidate>{
      for (final candidate in controller.candidates) candidate.ref: candidate,
    };
    return _StepScroll(
      children: <Widget>[
        _Notice(
          icon: Icons.event_note_outlined,
          text:
              '${state.selectedTargetTitle ?? context.l10n.scenarioIntakeScenarioFallback} · '
              '${context.l10n.scenarioIntakePlacement(state.selectedDayId == null
                  ? 'unscheduled'
                  : state.afterItemId == null
                  ? 'atEnd'
                  : 'afterStop')}',
        ),
        const SizedBox(height: 12),
        for (
          var index = 0;
          index < state.orderedRefs.length;
          index++
        ) ...<Widget>[
          _CandidateCard(
            index: index,
            candidate: byRef[state.orderedRefs[index]]!,
            canMoveUp: index > 0,
            canMoveDown: index < state.orderedRefs.length - 1,
            onMoveUp: () => controller.moveCandidate(index, -1),
            onMoveDown: () => controller.moveCandidate(index, 1),
          ),
          const SizedBox(height: 8),
        ],
        if (controller.duplicateConfirmationRequired)
          CheckboxListTile(
            value: state.confirmDuplicate,
            onChanged: (value) => controller.confirmDuplicate(value ?? false),
            title: Text(context.l10n.scenarioIntakeAddAnother),
            subtitle: Text(context.l10n.scenarioIntakeAddAnotherHint),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        if (controller.unavailableConfirmationRequired)
          CheckboxListTile(
            value: state.confirmUnavailable,
            onChanged: (value) => controller.confirmUnavailable(value ?? false),
            title: Text(context.l10n.scenarioIntakeUseUnavailable),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        if (controller.scheduleAdjustmentConfirmationRequired)
          CheckboxListTile(
            value: state.confirmScheduleAdjustment,
            onChanged: (value) =>
                controller.confirmScheduleAdjustment(value ?? false),
            title: Text(context.l10n.scenarioIntakeUseTemplateStop),
            subtitle: Text(context.l10n.scenarioIntakeUseTemplateStopHint),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        _Notice(
          icon: Icons.route_outlined,
          text: context.l10n.scenarioIntakeLogisticsNotice,
        ),
        if (state.message != null)
          _ErrorText(context.l10n.scenarioIntakeNotice(state.message!.name)),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: controller.back,
                child: Text(context.l10n.scenarioIntakeBack),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () =>
                    controller.apply(authenticated: isRequesterAuthenticated()),
                icon: const Icon(Icons.playlist_add_check),
                label: Text(
                  context.l10n.scenarioIntakeAddCount(state.orderedRefs.length),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.index,
    required this.candidate,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final int index;
  final ScenarioIntakeCandidate candidate;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    final duration = candidate.snapshot.durationMinutes;
    final fixed = candidate.schedule?.planned;
    final String status = context.l10n.scenarioIntakeSourceStatus(
      candidate.sourceStatus.name,
    );
    return Semantics(
      label:
          '${context.l10n.scenarioIntakeCandidateLabel(index + 1)} '
          '${candidate.snapshot.title}. $status.',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(child: Text('${index + 1}')),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      candidate.snapshot.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${context.l10n.scenarioIntakeObjectType(candidate.ref.objectType.name)} · '
                      '${duration == null ? context.l10n.scenarioIntakeDurationUnknown : context.l10n.createScenarioDurationMinutes(duration)} · '
                      '$status',
                    ),
                    if (fixed is ScenarioDatedPlannedTimeDraft &&
                        fixed.fixedStartAtUtc != null)
                      Text(
                        context.l10n.scenarioIntakeFixedStart(
                          RechargeFormats.dateTime(
                            fixed.fixedStartAtUtc!,
                            fixed.startTimezoneId ?? 'UTC',
                            Localizations.localeOf(context).languageCode,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                children: <Widget>[
                  IconButton(
                    tooltip: context.l10n.scenarioIntakeMoveUp,
                    onPressed: canMoveUp ? onMoveUp : null,
                    icon: const Icon(Icons.keyboard_arrow_up),
                  ),
                  IconButton(
                    tooltip: context.l10n.scenarioIntakeMoveDown,
                    onPressed: canMoveDown ? onMoveDown : null,
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingStep extends StatelessWidget {
  const _LoadingStep({required this.applying});

  final bool applying;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: applying
        ? context.l10n.scenarioIntakeApplyingSemantics
        : context.l10n.scenarioIntakeLoadingSemantics,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            applying
                ? context.l10n.scenarioIntakeApplying
                : context.l10n.scenarioIntakeLoading,
          ),
        ],
      ),
    ),
  );
}

class _SuccessStep extends StatelessWidget {
  const _SuccessStep({required this.state});

  final ScenarioObjectIntakeState state;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label:
        '${context.l10n.scenarioIntakeSuccess(state.successItemCount)}: '
        '${state.selectedTargetTitle ?? context.l10n.scenarioIntakeScenarioFallback}',
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              context.l10n.scenarioIntakeSuccess(state.successItemCount),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            // The Scenario title is the author's own text, shown as is.
            Text(
              state.selectedTargetTitle ??
                  context.l10n.scenarioIntakeScenarioFallback,
              textAlign: TextAlign.center,
            ),
            if (state.replayed) ...<Widget>[
              const SizedBox(height: 8),
              Text(context.l10n.scenarioIntakeReplayed),
            ],
          ],
        ),
      ),
    ),
  );
}

class _SuccessActions extends StatelessWidget {
  const _SuccessActions({
    required this.state,
    required this.onStay,
    required this.onOpen,
  });

  final ScenarioObjectIntakeState state;
  final VoidCallback onStay;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton(
              onPressed: onStay,
              child: Text(context.l10n.scenarioIntakeStay),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: onOpen,
              child: Text(context.l10n.scenarioIntakeOpenScenario),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ErrorStep extends StatelessWidget {
  const _ErrorStep({required this.message, required this.onRetry});

  final ScenarioObjectIntakeNotice? message;
  final Future<void> Function() onRetry;

  String _errorText(BuildContext context) => message == null
      ? context.l10n.scenarioIntakePrepareFailed
      : context.l10n.scenarioIntakeNotice(message!.name);

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: _errorText(context),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(_errorText(context)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.l10n.scenarioIntakeRetry),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StepScroll extends StatelessWidget {
  const _StepScroll({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: text,
    child: Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  );
}

String _targetSummary(BuildContext context, CreateDraftSummary target) {
  final l10n = context.l10n;
  final ScenarioLocalDateDraft? firstDate = target.scenarioFirstDate;
  final String dateLabel = target.scenarioDateMode == ScenarioDateMode.template
      ? l10n.scenarioIntakeTemplate
      : firstDate == null
      ? l10n.scenarioIntakeDated
      : _localDate(context, firstDate.iso8601);
  final ScenarioFormat? format = target.scenarioFormat;
  return <String>[
    if (format != null) createOptionText(l10n, format),
    dateLabel,
    l10n.scenarioIntakeTargetCounts(
      target.scenarioDayCount ?? 0,
      target.scenarioActiveItemCount ?? 0,
    ),
  ].join(' · ');
}

/// A calendar date (YYYY-MM-DD) in the reader's language; it has no instant,
/// so no zone is applied.
String _localDate(BuildContext context, String iso8601) {
  final List<int> parts = iso8601
      .split('-')
      .map(int.tryParse)
      .whereType<int>()
      .toList(growable: false);
  if (parts.length != 3) return iso8601;
  return RechargeFormats.date(
    DateTime.utc(parts[0], parts[1], parts[2]),
    'UTC',
    Localizations.localeOf(context).languageCode,
  );
}
