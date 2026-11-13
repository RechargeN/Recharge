import 'package:flutter/material.dart';

import '../../../../../core/localization/l10n_context.dart';
import '../../../domain/entities/scenario_transit_mutation.dart';
import '../create_form_texts.dart';

Future<bool> showScenarioTransitRecheckSheet(
  BuildContext context,
  ScenarioTransitRecheckResult result,
) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) =>
          _ScenarioTransitRecheckSheet(result: result),
    ) ??
    false;

class _ScenarioTransitRecheckSheet extends StatelessWidget {
  const _ScenarioTransitRecheckSheet({required this.result});

  final ScenarioTransitRecheckResult result;

  @override
  Widget build(BuildContext context) {
    final candidate = result.candidate;
    return FractionallySizedBox(
      heightFactor: result.canReplace ? 0.78 : 0.48,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    context.l10n.createScenarioScheduleRecheck,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.createScenarioCloseScheduleRecheck,
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            _StatusCard(result: result),
            if (result.canReplace && candidate != null) ...<Widget>[
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: <Widget>[
                    Text(
                      context.l10n.createScenarioChangesCachedOfficialSchedule,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ...result.differences.map(
                      (difference) => ListTile(
                        key: ValueKey<String>(
                          'scenario-transit-diff-${difference.fieldCode}',
                        ),
                        dense: true,
                        title: Text(
                          _fieldLabel(context.l10n, difference.fieldCode),
                        ),
                        subtitle: Text(
                          '${_diffValue(difference, difference.before)} → '
                          '${_diffValue(difference, difference.after)}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${candidate.departure.hhmm} → '
                      '${candidate.arrival.hhmm} · '
                      '${candidate.durationMinutes} min',
                    ),
                    Text(
                      '${candidate.manifest.providerDisplayName} · '
                      '${createOptionText(context.l10n, candidate.manifest.freshness)}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context
                          .l10n
                          .createScenarioPlannedScheduleNotLiveReplaceChanges,
                    ),
                  ],
                ),
              ),
              FilledButton(
                key: const ValueKey<String>('scenario-transit-confirm-replace'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.l10n.createScenarioReplaceSavedSchedule),
              ),
            ] else ...<Widget>[
              const Spacer(),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.createScenarioClose),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.result});

  final ScenarioTransitRecheckResult result;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: _statusText(context.l10n, result.status),
    child: Card.outlined(
      key: const ValueKey<String>('scenario-transit-recheck-status'),
      child: ListTile(
        leading: Icon(_statusIcon(result.status)),
        title: Text(_statusTitle(context.l10n, result.status)),
        subtitle: Text(_statusText(context.l10n, result.status)),
      ),
    ),
  );
}

String _statusTitle(
  AppLocalizations l10n,
  ScenarioTransitRecheckStatus status,
) => switch (status) {
  ScenarioTransitRecheckStatus.unchanged =>
    l10n.createScenarioNoScheduleChangesFound,
  ScenarioTransitRecheckStatus.changed => l10n.createScenarioServiceChanged,
  ScenarioTransitRecheckStatus.notFound => l10n.createScenarioServiceNotFound,
  ScenarioTransitRecheckStatus.unavailable =>
    l10n.createScenarioRecheckUnavailable,
  ScenarioTransitRecheckStatus.invalidSnapshot =>
    l10n.createScenarioSavedDataIncomplete,
};

String _statusText(
  AppLocalizations l10n,
  ScenarioTransitRecheckStatus status,
) => switch (status) {
  ScenarioTransitRecheckStatus.unchanged =>
    l10n.createScenarioCachedOfficialScheduleMatchesSavedSnapshot,
  ScenarioTransitRecheckStatus.changed =>
    l10n.createScenarioReviewEveryDifferenceBeforeReplacingSaved,
  ScenarioTransitRecheckStatus.notFound =>
    l10n.createScenarioSavedItemWasKeptUnchangedRecheck,
  ScenarioTransitRecheckStatus.unavailable =>
    l10n.createScenarioSavedItemWasKeptUnchangedBecause,
  ScenarioTransitRecheckStatus.invalidSnapshot =>
    l10n.createScenarioSavedItemWasKeptUnchangedCannot,
};

IconData _statusIcon(ScenarioTransitRecheckStatus status) => switch (status) {
  ScenarioTransitRecheckStatus.unchanged => Icons.check_circle_outline,
  ScenarioTransitRecheckStatus.changed => Icons.difference_outlined,
  ScenarioTransitRecheckStatus.notFound => Icons.search_off_outlined,
  ScenarioTransitRecheckStatus.unavailable => Icons.cloud_off_outlined,
  ScenarioTransitRecheckStatus.invalidSnapshot => Icons.warning_amber_outlined,
};

String _fieldLabel(AppLocalizations l10n, String code) => switch (code) {
  'route' => l10n.createScenarioRouteLabel,
  'service' => l10n.createScenarioServiceCalendar,
  'origin_stop' => l10n.createScenarioOriginStop,
  'destination_stop' => l10n.createScenarioDestinationStop,
  'departure' => l10n.createScenarioDepartureTime,
  'arrival' => l10n.createScenarioArrivalTime,
  'carrier' => l10n.createScenarioCarrierLabel,
  'label' => l10n.createScenarioServiceLabel,
  'feed_hash' => l10n.createScenarioFeedVersion,
  'freshness' => l10n.createScenarioFreshnessLabel,
  'retrieved_at' => l10n.createScenarioFeedRetrievedAt,
  _ => code,
};

String _diffValue(ScenarioTransitSnapshotDiff difference, String? value) {
  if (value == null || value.isEmpty) return 'unknown';
  if (difference.fieldCode == 'departure' ||
      difference.fieldCode == 'arrival') {
    final seconds = int.tryParse(value);
    if (seconds != null && seconds >= 0) {
      final dayOffset = seconds ~/ Duration.secondsPerDay;
      final withinDay = seconds % Duration.secondsPerDay;
      final hour = withinDay ~/ Duration.secondsPerHour;
      final minute =
          (withinDay % Duration.secondsPerHour) ~/ Duration.secondsPerMinute;
      return '${hour.toString().padLeft(2, '0')}:'
          '${minute.toString().padLeft(2, '0')}'
          '${dayOffset == 0 ? '' : ' +$dayOffset day'}';
    }
  }
  if (difference.fieldCode == 'feed_hash' && value.length > 12) {
    return value.substring(0, 12);
  }
  final date = DateTime.tryParse(value);
  if (difference.fieldCode == 'retrieved_at' && date != null) {
    return date.toUtc().toIso8601String();
  }
  return value;
}
