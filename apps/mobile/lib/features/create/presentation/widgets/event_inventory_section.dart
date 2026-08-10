import 'package:flutter/material.dart';

import '../../application/controllers/create_controller.dart';
import '../../application/event_inventory_section.dart';
import '../../domain/entities/event_inventory.dart';
import 'event_availability_preview.dart';

class EventInventorySection extends StatelessWidget {
  const EventInventorySection({
    super.key,
    required this.state,
    required this.controller,
  });

  final EventInventorySectionState state;
  final CreateController controller;

  @override
  Widget build(BuildContext context) {
    if (!state.enabled) return const SizedBox.shrink();
    final EventInventoryConfiguration? value = state.configuration;
    return Semantics(
      container: true,
      label: 'Event inventory configuration',
      child: Column(
        key: const Key('event-inventory-section'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Divider(height: 32),
          Text(
            'Capacity & inventory',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Capacity is a declared limit. It is not a live participant count '
            'or transactional inventory balance.',
          ),
          const SizedBox(height: 12),
          _EnumField<EventCapacityMode>(
            key: const Key('event-access-capacity-mode'),
            label: 'Event capacity',
            value: state.capacityMode,
            values: EventCapacityMode.values,
            error: state.errorFor('capacity'),
            onChanged: (mode) => controller.updateEventCapacity(
              mode,
              capacity: mode == EventCapacityMode.known ? state.capacity : null,
            ),
          ),
          if (state.capacityMode == EventCapacityMode.known)
            TextFormField(
              key: const Key('event-access-capacity'),
              initialValue: state.capacity?.toString() ?? '',
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Maximum participants *',
                errorText: state.errorFor('capacity'),
              ),
              onChanged: (raw) => controller.updateEventCapacity(
                EventCapacityMode.known,
                capacity: int.tryParse(raw),
              ),
            ),
          const SizedBox(height: 12),
          _EnumField<InventoryAuthority>(
            key: const Key('event-inventory-authority'),
            label: 'Inventory authority',
            value: value?.authority,
            values: InventoryAuthority.values,
            error: state.errorFor('inventoryAuthority'),
            onChanged: controller.selectEventInventoryAuthority,
          ),
          if (value != null &&
              value.authority != InventoryAuthority.none) ...<Widget>[
            _EnumField<InventoryShape>(
              key: const Key('event-inventory-primary-shape'),
              label: 'Primary inventory shape *',
              value: value.primaryShape,
              values: InventoryShape.values,
              error: state.errorFor('inventoryPrimaryShape'),
              onChanged: (shape) => controller.selectEventInventoryShapes(
                primaryShape: shape,
                additionalShapes: value.additionalShapes,
              ),
            ),
            if (value.primaryShape != null) ...<Widget>[
              Text(
                'Additional views of the same inventory',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: InventoryShape.values
                    .where((shape) => shape != value.primaryShape)
                    .map((shape) {
                      final bool selected = value.additionalShapes.contains(
                        shape,
                      );
                      return FilterChip(
                        key: Key('event-inventory-additional-${shape.name}'),
                        selected: selected,
                        label: Text(_label(shape.name)),
                        onSelected: (next) {
                          final Set<InventoryShape> shapes = <InventoryShape>{
                            ...value.additionalShapes,
                          };
                          next ? shapes.add(shape) : shapes.remove(shape);
                          controller.selectEventInventoryShapes(
                            primaryShape: value.primaryShape!,
                            additionalShapes: shapes,
                          );
                        },
                      );
                    })
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 12),
            _PoolComposer(
              defaultShape:
                  value.primaryShape ?? InventoryShape.generalCapacity,
              controller: controller,
            ),
            const SizedBox(height: 12),
            Text(
              'Pools · onsite ${state.channelSummary.onsitePoolCount} · '
              'online ${state.channelSummary.onlinePoolCount} · '
              'any ${state.channelSummary.anyPoolCount}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (int index = 0; index < value.pools.length; index++)
              _PoolEditor(
                pool: value.pools[index],
                index: index,
                total: value.pools.length,
                controller: controller,
              ),
          ],
          if (state.errorFor('inventoryPools') case final error?)
            _IssueText(error),
          for (final disclosure in state.disclosures)
            _Disclosure(
              message: disclosure.message,
              blocking: disclosure.blocking,
            ),
          const SizedBox(height: 12),
          EventAvailabilityPreview(
            state: state,
            onRefresh: controller.refreshEventMockAvailabilityPreview,
          ),
        ],
      ),
    );
  }
}

class _PoolComposer extends StatefulWidget {
  const _PoolComposer({required this.defaultShape, required this.controller});

  final InventoryShape defaultShape;
  final CreateController controller;

  @override
  State<_PoolComposer> createState() => _PoolComposerState();
}

class _PoolComposerState extends State<_PoolComposer> {
  final TextEditingController _labelController = TextEditingController();
  InventoryChannel _channel = InventoryChannel.onsite;
  EventCapacityMode _capacityMode = EventCapacityMode.known;
  int? _capacity;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card.outlined(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Add pool', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            key: const Key('event-pool-new-label'),
            controller: _labelController,
            decoration: const InputDecoration(labelText: 'Public pool label'),
          ),
          const SizedBox(height: 8),
          _EnumField<InventoryChannel>(
            label: 'Channel',
            value: _channel,
            values: InventoryChannel.values,
            onChanged: (next) => setState(() => _channel = next),
          ),
          _EnumField<EventCapacityMode>(
            label: 'Pool capacity',
            value: _capacityMode,
            values: EventCapacityMode.values,
            onChanged: (next) => setState(() {
              _capacityMode = next;
              if (next != EventCapacityMode.known) _capacity = null;
            }),
          ),
          if (_capacityMode == EventCapacityMode.known)
            TextField(
              key: const Key('event-pool-new-capacity'),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Capacity'),
              onChanged: (raw) => _capacity = int.tryParse(raw),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              key: const Key('event-pool-add'),
              onPressed: () {
                widget.controller.addEventInventoryPool(
                  label: _labelController.text,
                  shape: widget.defaultShape,
                  channel: _channel,
                  capacityMode: _capacityMode,
                  capacity: _capacity,
                );
                _labelController.clear();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add pool'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PoolEditor extends StatelessWidget {
  const _PoolEditor({
    required this.pool,
    required this.index,
    required this.total,
    required this.controller,
  });

  final EventInventoryPoolDraft pool;
  final int index;
  final int total;
  final CreateController controller;

  @override
  Widget build(BuildContext context) => Card.outlined(
    key: Key('event-pool-${pool.id}'),
    child: ExpansionTile(
      title: Text(pool.label.isEmpty ? 'Unnamed pool' : pool.label),
      subtitle: Text(
        '${_label(pool.channel.name)} · ${_label(pool.shape.name)}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: <Widget>[
        TextFormField(
          key: Key('event-pool-label-${pool.id}'),
          initialValue: pool.label,
          decoration: const InputDecoration(labelText: 'Public pool label'),
          onChanged: (text) => controller.updateEventInventoryPool(
            pool.copyWith(label: text.trim()),
          ),
        ),
        const SizedBox(height: 8),
        _EnumField<InventoryShape>(
          label: 'Shape',
          value: pool.shape,
          values: InventoryShape.values,
          onChanged: (shape) =>
              controller.updateEventInventoryPool(pool.copyWith(shape: shape)),
        ),
        _EnumField<InventoryChannel>(
          label: 'Channel',
          value: pool.channel,
          values: InventoryChannel.values,
          onChanged: (channel) => controller.updateEventInventoryPool(
            pool.copyWith(channel: channel),
          ),
        ),
        _EnumField<EventCapacityMode>(
          label: 'Capacity mode',
          value: pool.capacityMode,
          values: EventCapacityMode.values,
          onChanged: (mode) => controller.updateEventInventoryPool(
            pool.copyWith(
              capacityMode: mode,
              clearCapacity: mode != EventCapacityMode.known,
            ),
          ),
        ),
        if (pool.capacityMode == EventCapacityMode.known)
          TextFormField(
            key: Key('event-pool-capacity-${pool.id}'),
            initialValue: pool.capacity?.toString() ?? '',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Capacity'),
            onChanged: (raw) => controller.updateEventInventoryPool(
              pool.copyWith(capacity: int.tryParse(raw)),
            ),
          ),
        if (pool.shape == InventoryShape.participantRoles ||
            pool.shape == InventoryShape.roleBalancedSlots)
          TextFormField(
            key: Key('event-pool-roles-${pool.id}'),
            initialValue: pool.roleIds.join(', '),
            decoration: const InputDecoration(
              labelText: 'Neutral role IDs, comma-separated',
            ),
            onChanged: (raw) => controller.updateEventInventoryPool(
              pool.copyWith(
                roleIds: raw
                    .split(',')
                    .map((value) => value.trim())
                    .where((value) => value.isNotEmpty)
                    .toList(growable: false),
              ),
            ),
          ),
        if (pool.shape == InventoryShape.zones ||
            pool.shape == InventoryShape.tableInventory)
          TextFormField(
            key: Key('event-pool-zone-${pool.id}'),
            initialValue: pool.zoneRef ?? '',
            decoration: const InputDecoration(
              labelText: 'Zone/table reference',
            ),
            onChanged: (raw) => controller.updateEventInventoryPool(
              pool.copyWith(
                zoneRef: raw.trim(),
                clearZoneRef: raw.trim().isEmpty,
              ),
            ),
          ),
        Row(
          children: <Widget>[
            IconButton(
              tooltip: 'Move pool up',
              onPressed: index == 0
                  ? null
                  : () =>
                        controller.reorderEventInventoryPool(index, index - 1),
              icon: const Icon(Icons.arrow_upward),
            ),
            IconButton(
              tooltip: 'Move pool down',
              onPressed: index == total - 1
                  ? null
                  : () =>
                        controller.reorderEventInventoryPool(index, index + 1),
              icon: const Icon(Icons.arrow_downward),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Remove pool',
              onPressed: () => controller.removeEventInventoryPool(pool.id),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ],
    ),
  );
}

class _EnumField<T extends Enum> extends StatelessWidget {
  const _EnumField({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
    this.error,
  });

  final String label;
  final T? value;
  final List<T> values;
  final ValueChanged<T> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: DropdownButtonFormField<T>(
      value: values.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, errorText: error),
      items: values
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(_label(item.name)),
            ),
          )
          .toList(growable: false),
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    ),
  );
}

class _Disclosure extends StatelessWidget {
  const _Disclosure({required this.message, required this.blocking});

  final String message;
  final bool blocking;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          blocking ? Icons.lock_outline : Icons.info_outline,
          size: 18,
          color: blocking ? Theme.of(context).colorScheme.error : null,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

class _IssueText extends StatelessWidget {
  const _IssueText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}

String _label(String value) => value
    .replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    )
    .replaceAll('_', ' ')
    .toLowerCase();
