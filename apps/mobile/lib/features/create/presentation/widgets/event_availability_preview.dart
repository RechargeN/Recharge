import 'package:flutter/material.dart';

import '../../../../core/localization/l10n_context.dart';
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
      label: context.l10n.createFormLocalMockAvailabilityPreview,
      child: Card(
        key: const Key('event-availability-preview'),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                context.l10n.createFormLocalMockPreviewNotLiveAvailability,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${context.l10n.createEventAvailabilityLabel}: '
                '${context.l10n.createEventAvailabilityState(projection.state.name)} · '
                '${context.l10n.createEventAvailabilityFreshness(projection.freshness.name)}',
                key: const Key('event-availability-state'),
              ),
              for (final MapEntry<InventoryChannel, EventAvailabilityState>
                  entry
                  in projection.channelStates.entries)
                Text(
                  '${context.l10n.createOption('InventoryChannel_${entry.key.name}')}: '
                  '${context.l10n.createEventAvailabilityState(entry.value.name)}',
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const Key('event-availability-refresh'),
                  onPressed: state.refreshingPreview ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    state.refreshingPreview
                        ? context.l10n.createFormCheckingLocalFixture
                        : context.l10n.createFormRefreshPreview,
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
