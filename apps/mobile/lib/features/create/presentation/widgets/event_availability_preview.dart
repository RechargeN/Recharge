import 'package:flutter/material.dart';

import '../../application/event_inventory_section.dart';
import '../../domain/entities/event_availability_projection.dart';
import '../../domain/entities/event_inventory.dart';

class EventAvailabilityPreview extends StatelessWidget {
  const EventAvailabilityPreview({
    super.key,
    required this.state,
    required this.onRefresh,
  });

  final EventInventorySectionState state;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (!state.mockPreviewEnabled) return const SizedBox.shrink();
    final EventAvailabilityProjection projection = state.availabilityPreview;
    return Semantics(
      container: true,
      label: 'Local mock availability preview',
      child: Card(
        key: const Key('event-availability-preview'),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Local mock preview — not live availability',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'State: ${_label(projection.state.name)} · '
                '${_label(projection.freshness.name)}',
                key: const Key('event-availability-state'),
              ),
              for (final MapEntry<InventoryChannel, EventAvailabilityState>
                  entry
                  in projection.channelStates.entries)
                Text('${_label(entry.key.name)}: ${_label(entry.value.name)}'),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const Key('event-availability-refresh'),
                  onPressed: state.refreshingPreview ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    state.refreshingPreview
                        ? 'Checking local fixture…'
                        : 'Refresh preview',
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

String _label(String value) => value
    .replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    )
    .replaceAll('_', ' ')
    .toLowerCase();
