import 'package:flutter/material.dart';

import '../../../application/controllers/create_controller.dart';
import '../../../application/scenario_transit_disclosure.dart';
import '../../../application/state/create_state.dart';
import '../../../domain/entities/scenario_draft_data.dart';
import '../../../domain/entities/scenario_item_draft.dart';
import '../../../domain/entities/scenario_validation_issue.dart';
import '../../../domain/usecases/evaluate_scenario_readiness_usecase.dart';
import 'scenario_transit_disclosure_card.dart';
import '../create_texts.dart';
import '../../../../../core/localization/l10n_context.dart';

class ScenarioReviewSection extends StatelessWidget {
  const ScenarioReviewSection({
    required this.controller,
    required this.state,
    super.key,
  });

  final CreateController controller;
  final CreateState state;

  @override
  Widget build(BuildContext context) {
    final ScenarioReadinessResult? readiness = controller.scenarioReadiness;
    if (readiness == null) {
      return Text(context.l10n.createScenarioScenarioDataUnavailable);
    }
    final ScenarioDraftData data = state.draft.scenarioData!;
    final List<ScenarioItemDraft> plannedTransport = data.items
        .where(
          (ScenarioItemDraft item) =>
              item.source is ScenarioPlannedTransportSourceDraft,
        )
        .toList(growable: false);
    final blocking = readiness.validation.issues
        .where(
          (ScenarioValidationIssue issue) =>
              issue.severity == ScenarioValidationSeverity.error,
        )
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _Metric(
              label: context.l10n.createScenarioActiveStops,
              value: '${readiness.totals.activeItemCount}',
            ),
            _Metric(
              label: context.l10n.createScenarioActivity,
              value: '${readiness.totals.activityMinutes} min',
            ),
            _Metric(
              label: context.l10n.createScenarioTimeBlocks,
              value: '${readiness.totals.plannedBlockMinutes} min',
            ),
            _Metric(
              label: context.l10n.createScenarioPrivateLocalTravel,
              value: '${readiness.totals.localTravelMinutes} min',
            ),
            _Metric(
              label: context.l10n.createScenarioPlannedTransport,
              value: '${readiness.totals.plannedTransportMinutes} min',
            ),
            _Metric(
              label: context.l10n.createScenarioUnknownTravel,
              value: '${readiness.totals.unresolvedLegCount}',
            ),
            _Metric(
              label: context.l10n.createScenarioWarnings,
              value: '${readiness.validation.warningCount}',
            ),
          ],
        ),
        const SizedBox(height: 14),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            readiness.canSaveToMyScenarios
                ? Icons.check_circle
                : Icons.error_outline,
            color: readiness.canSaveToMyScenarios ? Colors.green : Colors.red,
          ),
          title: Text(
            readiness.canSaveToMyScenarios
                ? context.l10n.createScenarioReadyMyScenarios
                : context.l10n.createScenarioBlockingIssues(blocking.length),
          ),
          subtitle: Text(
            context.l10n.createScenarioActionSavesPersonalScenarioDoesNot,
          ),
        ),
        if (plannedTransport.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFFFF5D9),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.schedule_outlined),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context
                          .l10n
                          .createScenarioPlannedScheduleNotLiveRecheckDepartures,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...plannedTransport.map((ScenarioItemDraft item) {
            final source = item.source as ScenarioPlannedTransportSourceDraft;
            return ScenarioTransitDisclosureCard(
              key: ValueKey<String>('scenario-transit-review-${item.id}'),
              disclosure: const BuildScenarioTransitDisclosure()(source),
            );
          }),
        ],
        if (blocking.isNotEmpty)
          ...blocking
              .take(8)
              .map(
                (ScenarioValidationIssue issue) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.chevron_right),
                  title: Text(CreateTexts.scenario(context.l10n, issue.code)),
                  subtitle: Text(issue.path),
                ),
              ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFFF3F5F4),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              context
                  .l10n
                  .createScenarioPublicUnlistedScenarioPublishingRemainsDisabled,
            ),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: const Icon(Icons.analytics_outlined, size: 18),
    label: Text('$label: $value'),
  );
}
