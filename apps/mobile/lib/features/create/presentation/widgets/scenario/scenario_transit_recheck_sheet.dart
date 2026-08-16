import 'package:flutter/material.dart';

import '../../../domain/entities/scenario_transit_mutation.dart';

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
                    'Schedule recheck',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close schedule recheck',
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
                      'Changes in the cached official schedule',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ...result.differences.map(
                      (difference) => ListTile(
                        key: ValueKey<String>(
                          'scenario-transit-diff-${difference.fieldCode}',
                        ),
                        dense: true,
                        title: Text(_fieldLabel(difference.fieldCode)),
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
                      '${candidate.manifest.freshness.name}',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Planned schedule · not live. Replace changes only the '
                      'saved snapshot after explicit confirmation.',
                    ),
                  ],
                ),
              ),
              FilledButton(
                key: const ValueKey<String>('scenario-transit-confirm-replace'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Replace saved schedule'),
              ),
            ] else ...<Widget>[
              const Spacer(),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Close'),
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
    label: _statusText(result.status),
    child: Card.outlined(
      key: const ValueKey<String>('scenario-transit-recheck-status'),
      child: ListTile(
        leading: Icon(_statusIcon(result.status)),
        title: Text(_statusTitle(result.status)),
        subtitle: Text(_statusText(result.status)),
      ),
    ),
  );
}

String _statusTitle(ScenarioTransitRecheckStatus status) => switch (status) {
  ScenarioTransitRecheckStatus.unchanged => 'No schedule changes found',
  ScenarioTransitRecheckStatus.changed => 'A changed service was found',
  ScenarioTransitRecheckStatus.notFound => 'Service not found',
  ScenarioTransitRecheckStatus.unavailable => 'Recheck unavailable',
  ScenarioTransitRecheckStatus.invalidSnapshot => 'Saved data is incomplete',
};

String _statusText(ScenarioTransitRecheckStatus status) => switch (status) {
  ScenarioTransitRecheckStatus.unchanged =>
    'The cached official schedule matches the saved snapshot. It is still not live.',
  ScenarioTransitRecheckStatus.changed =>
    'Review every difference before replacing the saved snapshot.',
  ScenarioTransitRecheckStatus.notFound =>
    'The saved item was kept unchanged. Recheck later or enter transport manually.',
  ScenarioTransitRecheckStatus.unavailable =>
    'The saved item was kept unchanged because cached schedule data is unavailable.',
  ScenarioTransitRecheckStatus.invalidSnapshot =>
    'The saved item was kept unchanged and cannot be rechecked automatically.',
};

IconData _statusIcon(ScenarioTransitRecheckStatus status) => switch (status) {
  ScenarioTransitRecheckStatus.unchanged => Icons.check_circle_outline,
  ScenarioTransitRecheckStatus.changed => Icons.difference_outlined,
  ScenarioTransitRecheckStatus.notFound => Icons.search_off_outlined,
  ScenarioTransitRecheckStatus.unavailable => Icons.cloud_off_outlined,
  ScenarioTransitRecheckStatus.invalidSnapshot => Icons.warning_amber_outlined,
};

String _fieldLabel(String code) => switch (code) {
  'route' => 'Route',
  'service' => 'Service calendar',
  'origin_stop' => 'Origin stop',
  'destination_stop' => 'Destination stop',
  'departure' => 'Departure time',
  'arrival' => 'Arrival time',
  'carrier' => 'Carrier',
  'label' => 'Service label',
  'feed_hash' => 'Feed version',
  'freshness' => 'Freshness',
  'retrieved_at' => 'Feed retrieved at',
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
