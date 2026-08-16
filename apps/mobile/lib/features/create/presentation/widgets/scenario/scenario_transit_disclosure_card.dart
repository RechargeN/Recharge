import 'package:flutter/material.dart';

import '../../../application/scenario_transit_disclosure.dart';

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
                      disclosure.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(disclosure.statusLabel),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (disclosure.providerLabel != null)
            _Line(label: 'Provider', value: disclosure.providerLabel!),
          if (disclosure.serviceDateLabel != null)
            _Line(label: 'Service date', value: disclosure.serviceDateLabel!),
          _Line(
            label: 'Planned time',
            value:
                '${disclosure.departureLabel ?? 'unknown'} → '
                '${disclosure.arrivalLabel ?? 'unknown'}',
          ),
          if (!compact) ...<Widget>[
            _Line(
              label: 'Stops',
              value:
                  '${disclosure.originLabel ?? 'unknown'} → '
                  '${disclosure.destinationLabel ?? 'unknown'}',
            ),
            if (disclosure.licenseLabel != null)
              _Line(label: 'Licence', value: disclosure.licenseLabel!),
            _Line(
              label: 'Feed retrieved',
              value: disclosure.retrievedAtLabel ?? 'unknown',
            ),
            _Line(
              label: 'Feed SHA-256',
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
                  Expanded(child: Text(warning)),
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
