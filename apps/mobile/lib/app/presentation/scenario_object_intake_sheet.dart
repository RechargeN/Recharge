import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/id/id_generator.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/application/controllers/auth_controller.dart';
import '../../features/auth/presentation/widgets/auth_gate_sheet.dart';
import '../../features/create/domain/entities/scenario_item_draft.dart';
import '../../features/create/domain/entities/scenario_object_intake.dart';
import '../../features/create/domain/repositories/create_draft_collection_repository.dart';
import '../../features/discover/domain/entities/discover_item_entity.dart';
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
        const SnackBar(content: Text('Add to Scenario is unavailable.')),
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
  } on FormatException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    }
    return null;
  }
  final telemetry = ref.read(scenarioObjectIntakeTelemetryProvider);
  telemetry.track(
    intent: intent,
    action: ScenarioObjectIntakeTelemetryAction.open,
    result: ScenarioObjectIntakeTelemetryResult.success,
  );
  final controller = ScenarioObjectIntakeController(
    intent: intent,
    facade: ref.read(scenarioObjectIntakeFacadeProvider),
    organizerEmail: requesterEmail,
    organizerName: requesterName,
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
    final step = switch (stage) {
      ScenarioObjectIntakeStage.target => '1 of 3 · Scenario',
      ScenarioObjectIntakeStage.placement => '2 of 3 · Placement',
      ScenarioObjectIntakeStage.review => '3 of 3 · Review',
      ScenarioObjectIntakeStage.success => 'Complete',
      ScenarioObjectIntakeStage.applying => 'Saving',
      _ => 'Preparing',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Add to Scenario',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(step, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close Add to Scenario',
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
          'Choose a personal Scenario',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text('Only your editable private drafts are shown.'),
        const SizedBox(height: 12),
        if (state.targets.isEmpty)
          const _Notice(
            icon: Icons.inbox_outlined,
            text: 'No saved Scenario yet. Create one below.',
          ),
        for (final target in state.targets)
          RadioListTile<String>(
            value: target.id,
            groupValue: state.newTargetSelected ? null : state.selectedTargetId,
            onChanged: (value) {
              if (value != null) controller.selectTarget(value);
            },
            title: Text(
              target.title.trim().isEmpty ? 'Untitled' : target.title,
            ),
            subtitle: Text(_targetSummary(target)),
          ),
        if (controller.canCreateNewTarget) ...<Widget>[
          const Divider(),
          RadioListTile<bool>(
            value: true,
            groupValue: state.newTargetSelected ? true : null,
            onChanged: (_) => controller.selectNewTarget(),
            title: const Text('Create new Scenario'),
            subtitle: const Text(
              'Private · one Day 1 · saved only with the stop',
            ),
          ),
        ],
        if (state.newTargetSelected)
          TextFormField(
            key: ValueKey<String>(state.newTargetTitle),
            initialValue: state.newTargetTitle,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Scenario title'),
            onChanged: controller.updateNewTargetTitle,
          ),
        if (state.message != null) _ErrorText(state.message!),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: controller.continueFromTarget,
          child: const Text('Continue to placement'),
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
          state.selectedTargetTitle ?? 'Scenario',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: state.selectedDayId ?? '__unscheduled__',
          decoration: const InputDecoration(labelText: 'Day'),
          items: <DropdownMenuItem<String>>[
            for (final day in state.days)
              DropdownMenuItem<String>(
                value: day.id,
                child: Text(
                  '${day.title}${day.dateLabel == null ? '' : ' · ${day.dateLabel}'}',
                ),
              ),
            const DropdownMenuItem<String>(
              value: '__unscheduled__',
              child: Text('Unscheduled'),
            ),
          ],
          onChanged: (value) =>
              controller.setDay(value == '__unscheduled__' ? null : value),
        ),
        if (state.selectedDayId != null) ...<Widget>[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: state.afterItemId ?? '__end__',
            decoration: const InputDecoration(labelText: 'Insert'),
            items: <DropdownMenuItem<String>>[
              const DropdownMenuItem<String>(
                value: '__end__',
                child: Text('At end'),
              ),
              for (final anchor in state.anchors)
                DropdownMenuItem<String>(
                  value: anchor.id,
                  child: Text('After ${anchor.title}'),
                ),
            ],
            onChanged: (value) =>
                controller.setAfterItem(value == '__end__' ? null : value),
          ),
        ],
        const SizedBox(height: 16),
        Text('Role', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<ScenarioItemRole>(
          segments: const <ButtonSegment<ScenarioItemRole>>[
            ButtonSegment<ScenarioItemRole>(
              value: ScenarioItemRole.mandatory,
              label: Text('Mandatory'),
            ),
            ButtonSegment<ScenarioItemRole>(
              value: ScenarioItemRole.optional,
              label: Text('Optional'),
            ),
          ],
          selected: <ScenarioItemRole>{state.role},
          onSelectionChanged: (value) => controller.setRole(value.single),
        ),
        if (state.message != null) _ErrorText(state.message!),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: controller.back,
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: controller.continueToReview,
                child: const Text('Review'),
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
              '${state.selectedTargetTitle} · '
              '${state.selectedDayId == null
                  ? 'Unscheduled'
                  : state.afterItemId == null
                  ? 'At end'
                  : 'After selected stop'}',
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
            title: const Text('Add another occurrence'),
            subtitle: const Text(
              'This exact catalog object already exists in the Scenario.',
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        if (controller.unavailableConfirmationRequired)
          CheckboxListTile(
            value: state.confirmUnavailable,
            onChanged: (value) => controller.confirmUnavailable(value ?? false),
            title: const Text('Use saved unavailable snapshot'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        if (controller.scheduleAdjustmentConfirmationRequired)
          CheckboxListTile(
            value: state.confirmScheduleAdjustment,
            onChanged: (value) =>
                controller.confirmScheduleAdjustment(value ?? false),
            title: const Text('Use as a flexible template stop'),
            subtitle: const Text(
              'The source has a fixed date, but this Scenario is a template.',
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        const _Notice(
          icon: Icons.route_outlined,
          text:
              'Logistics are not recalculated live. Existing unlocked boundary estimates will be invalidated safely.',
        ),
        if (state.message != null) _ErrorText(state.message!),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: controller.back,
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () =>
                    controller.apply(authenticated: isRequesterAuthenticated()),
                icon: const Icon(Icons.playlist_add_check),
                label: Text('Add ${state.orderedRefs.length}'),
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
    return Semantics(
      label:
          'Selected stop ${index + 1} of ${candidate.snapshot.title}. '
          '${candidate.sourceStatus.name}.',
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
                      '${candidate.ref.objectType.name} · '
                      '${duration == null ? 'Duration unknown' : '$duration min'} · '
                      '${candidate.sourceStatus.name}',
                    ),
                    if (fixed is ScenarioDatedPlannedTimeDraft &&
                        fixed.fixedStartAtUtc != null)
                      Text(
                        'Fixed ${fixed.fixedStartAtUtc!.toUtc().toIso8601String()}',
                      ),
                  ],
                ),
              ),
              Column(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Move up',
                    onPressed: canMoveUp ? onMoveUp : null,
                    icon: const Icon(Icons.keyboard_arrow_up),
                  ),
                  IconButton(
                    tooltip: 'Move down',
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
        ? 'Adding selected stops to Scenario'
        : 'Loading your Scenarios',
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(applying ? 'Adding to Scenario…' : 'Loading your Scenarios…'),
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
        'Success. Added ${state.successItemCount} stops to '
        '${state.selectedTargetTitle}.',
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'Added ${state.successItemCount} to ${state.selectedTargetTitle}',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (state.replayed) ...<Widget>[
              const SizedBox(height: 8),
              const Text('Already saved · no duplicate was created.'),
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
              child: const Text('Stay here'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: onOpen,
              child: const Text('Open Scenario'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ErrorStep extends StatelessWidget {
  const _ErrorStep({required this.message, required this.onRetry});

  final String? message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: message ?? 'Could not prepare Add to Scenario.',
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message ?? 'Could not prepare Add to Scenario.'),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
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

String _targetSummary(CreateDraftSummary target) {
  final dateLabel = target.scenarioDateMode?.name == 'template'
      ? 'Template'
      : target.scenarioFirstDate?.iso8601 ?? 'Dated';
  return '${target.scenarioFormat?.name ?? 'scenario'} · $dateLabel · '
      '${target.scenarioDayCount ?? 0} days · '
      '${target.scenarioActiveItemCount ?? 0} active items';
}
