import 'package:flutter/material.dart';

import '../../../application/controllers/create_controller.dart';
import '../../../application/scenario_transit_disclosure.dart';
import '../../../application/state/create_state.dart';
import '../../../domain/entities/scenario_draft_data.dart';
import '../../../domain/entities/scenario_item_draft.dart';
import '../../../domain/entities/scenario_validation_issue.dart';
import '../../../domain/usecases/evaluate_scenario_readiness_usecase.dart';
import 'scenario_transit_disclosure_card.dart';

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
      return const Text('Scenario data is unavailable.');
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
              label: 'Active stops',
              value: '${readiness.totals.activeItemCount}',
            ),
            _Metric(
              label: 'Activity',
              value: '${readiness.totals.activityMinutes} min',
            ),
            _Metric(
              label: 'Time blocks',
              value: '${readiness.totals.plannedBlockMinutes} min',
            ),
            _Metric(
              label: 'Private / local travel',
              value: '${readiness.totals.localTravelMinutes} min',
            ),
            _Metric(
              label: 'Planned transport',
              value: '${readiness.totals.plannedTransportMinutes} min',
            ),
            _Metric(
              label: 'Unknown travel',
              value: '${readiness.totals.unresolvedLegCount}',
            ),
            _Metric(
              label: 'Warnings',
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
                ? 'Ready for My Scenarios'
                : '${blocking.length} blocking issue(s)',
          ),
          subtitle: const Text(
            'This action saves a personal Scenario. It does not publish it to the catalog.',
          ),
        ),
        if (plannedTransport.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          const DecoratedBox(
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
                      'Planned schedule · not live. Recheck departures, delays and cancellations before travel.',
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
                  title: Text(issue.message),
                  subtitle: Text(issue.path),
                ),
              ),
        const SizedBox(height: 8),
        const DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFFF3F5F4),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Public and unlisted Scenario publishing remains disabled until '
              'publisher capabilities and moderation are implemented.',
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
