import 'package:flutter/material.dart';

import '../../../application/scenario_transit_disclosure.dart';
import '../../../../../core/localization/l10n_context.dart';

class ScenarioTransitDisclosureCard extends StatelessWidget {
  const ScenarioTransitDisclosureCard({
    required this.disclosure,
    this.compact = false,
    super.key,
  });

  final ScenarioTransitDisclosure disclosure;
  final bool compact;

  @override
  Widget build(BuildContext context) => Card.outlined(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                disclosure.isOfficial
                    ? Icons.verified_outlined
                    : Icons.edit_note_outlined,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      disclosure.title ??
                          context.l10n.scenarioTransitPlannedTransport,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      context.l10n.scenarioTransitStatus(
                        disclosure.freshness.name,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (disclosure.providerLabel != null)
            _Line(
              label: context.l10n.createScenarioProvider,
              value: disclosure.providerLabel!,
            ),
          if (disclosure.serviceDateLabel != null)
            _Line(
              label: context.l10n.createScenarioServiceDate,
              value: disclosure.serviceDateLabel!,
            ),
          _Line(
            label: context.l10n.createScenarioPlannedTime,
            value:
                '${disclosure.departureLabel ?? 'unknown'} → '
                '${disclosure.arrivalLabel ?? 'unknown'}',
          ),
          if (!compact) ...<Widget>[
            _Line(
              label: context.l10n.createScenarioStops,
              value:
                  '${disclosure.originLabel ?? 'unknown'} → '
                  '${disclosure.destinationLabel ?? 'unknown'}',
            ),
            if (disclosure.licenseLabel != null)
              _Line(
                label: context.l10n.createScenarioLicence,
                value: disclosure.licenseLabel!,
              ),
            _Line(
              label: context.l10n.createScenarioFeedRetrieved2,
              value: disclosure.retrievedAtLabel ?? 'unknown',
            ),
            _Line(
              label: context.l10n.createScenarioFeedSha256,
              value: disclosure.digestLabel ?? 'unknown',
              selectable: true,
            ),
          ],
          const SizedBox(height: 8),
          ...disclosure.warnings.map(
            (warning) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.info_outline, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.l10n.scenarioTransitWarning(warning.name),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final text = '$label: $value';
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: selectable ? SelectableText(text) : Text(text),
    );
  }
}
