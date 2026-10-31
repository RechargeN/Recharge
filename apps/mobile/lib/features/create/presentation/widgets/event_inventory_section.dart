import 'package:flutter/material.dart';

import '../../application/controllers/create_controller.dart';
import '../../application/event_inventory_section.dart';
import '../../domain/entities/event_inventory.dart';
import 'event_availability_preview.dart';
import '../../../../core/localization/l10n_context.dart';
import 'create_texts.dart';
import 'create_form_texts.dart';

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
      label: context.l10n.createFormEventInventoryConfiguration,
      child: Column(
        key: const Key('event-inventory-section'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Divider(height: 32),
          Text(
            context.l10n.createEventCapacityInventory,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(context.l10n.createFormCapacityDeclaredLimitNotLiveParticipant),
          const SizedBox(height: 12),
          _EnumField<EventCapacityMode>(
            key: const Key('event-access-capacity-mode'),
            label: context.l10n.createFormEventCapacity,
            value: state.capacityMode,
            values: EventCapacityMode.values,
            error: _errorText(context, state, 'capacity'),
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
                labelText: context.l10n.createFormMaximumParticipants2,
                errorText: _errorText(context, state, 'capacity'),
              ),
              onChanged: (raw) => controller.updateEventCapacity(
                EventCapacityMode.known,
                capacity: int.tryParse(raw),
              ),
            ),
          const SizedBox(height: 12),
          _EnumField<InventoryAuthority>(
            key: const Key('event-inventory-authority'),
            label: context.l10n.createFormInventoryAuthority,
            value: value?.authority,
            values: InventoryAuthority.values,
            error: _errorText(context, state, 'inventoryAuthority'),
            onChanged: controller.selectEventInventoryAuthority,
          ),
          if (value != null &&
              value.authority != InventoryAuthority.none) ...<Widget>[
            _EnumField<InventoryShape>(
              key: const Key('event-inventory-primary-shape'),
              label: context.l10n.createFormPrimaryInventoryShape,
              value: value.primaryShape,
              values: InventoryShape.values,
              error: _errorText(context, state, 'inventoryPrimaryShape'),
              onChanged: (shape) => controller.selectEventInventoryShapes(
                primaryShape: shape,
                additionalShapes: value.additionalShapes,
              ),
            ),
            if (value.primaryShape != null) ...<Widget>[
              Text(
                context.l10n.createFormAdditionalViewsSameInventory,
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
                        label: Text(createOptionText(context.l10n, shape)),
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
              '${context.l10n.createEventPoolsLabel} · '
              '${context.l10n.createOption('InventoryChannel_onsite')} ${state.channelSummary.onsitePoolCount} · '
              '${context.l10n.createOption('InventoryChannel_online')} ${state.channelSummary.onlinePoolCount} · '
              '${context.l10n.createOption('InventoryChannel_any')} ${state.channelSummary.anyPoolCount}',
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
          if (_errorText(context, state, 'inventoryPools') case final error?)
            _IssueText(error),
          for (final disclosure in state.disclosures)
            _Disclosure(
              message: context.l10n.eventAccessDisclosure(
                disclosure.topic.name,
              ),
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
          Text(
            context.l10n.createFormAddPool,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('event-pool-new-label'),
            controller: _labelController,
            decoration: InputDecoration(
              labelText: context.l10n.createFormPublicPoolLabel,
            ),
          ),
          const SizedBox(height: 8),
          _EnumField<InventoryChannel>(
            label: context.l10n.createFormChannel,
            value: _channel,
            values: InventoryChannel.values,
            onChanged: (next) => setState(() => _channel = next),
          ),
          _EnumField<EventCapacityMode>(
            label: context.l10n.createFormPoolCapacity,
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
              decoration: InputDecoration(
                labelText: context.l10n.createFormCapacity,
              ),
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
              label: Text(context.l10n.createFormAddPool),
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
      title: Text(
        pool.label.isEmpty ? context.l10n.createFormUnnamedPool : pool.label,
      ),
      subtitle: Text(
        '${createOptionText(context.l10n, pool.channel)} · ${createOptionText(context.l10n, pool.shape)}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: <Widget>[
        TextFormField(
          key: Key('event-pool-label-${pool.id}'),
          initialValue: pool.label,
          decoration: InputDecoration(
            labelText: context.l10n.createFormPublicPoolLabel,
          ),
          onChanged: (text) => controller.updateEventInventoryPool(
            pool.copyWith(label: text.trim()),
          ),
        ),
        const SizedBox(height: 8),
        _EnumField<InventoryShape>(
          label: context.l10n.createFormShape,
          value: pool.shape,
          values: InventoryShape.values,
          onChanged: (shape) =>
              controller.updateEventInventoryPool(pool.copyWith(shape: shape)),
        ),
        _EnumField<InventoryChannel>(
          label: context.l10n.createFormChannel,
          value: pool.channel,
          values: InventoryChannel.values,
          onChanged: (channel) => controller.updateEventInventoryPool(
            pool.copyWith(channel: channel),
          ),
        ),
        _EnumField<EventCapacityMode>(
          label: context.l10n.createFormCapacityMode,
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
            decoration: InputDecoration(
              labelText: context.l10n.createFormCapacity,
            ),
            onChanged: (raw) => controller.updateEventInventoryPool(
              pool.copyWith(capacity: int.tryParse(raw)),
            ),
          ),
        if (pool.shape == InventoryShape.participantRoles ||
            pool.shape == InventoryShape.roleBalancedSlots)
          TextFormField(
            key: Key('event-pool-roles-${pool.id}'),
            initialValue: pool.roleIds.join(', '),
            decoration: InputDecoration(
              labelText: context.l10n.createFormNeutralRoleIdsCommaSeparated,
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
            decoration: InputDecoration(
              labelText: context.l10n.createEventZoneReference,
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
              tooltip: context.l10n.createFormMovePoolUp,
              onPressed: index == 0
                  ? null
                  : () =>
                        controller.reorderEventInventoryPool(index, index - 1),
              icon: const Icon(Icons.arrow_upward),
            ),
            IconButton(
              tooltip: context.l10n.createFormMovePoolDown,
              onPressed: index == total - 1
                  ? null
                  : () =>
                        controller.reorderEventInventoryPool(index, index + 1),
              icon: const Icon(Icons.arrow_downward),
            ),
            const Spacer(),
            IconButton(
              tooltip: context.l10n.createFormRemovePool,
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
      initialValue: values.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, errorText: error),
      items: values
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(createOptionText(context.l10n, item)),
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

/// L4: a section field error, resolved from its message id.
String? _errorText(
  BuildContext context,
  EventInventorySectionState section,
  String fieldId,
) => switch (section.errorIdFor(fieldId)) {
  final String id => CreateTexts.fieldError(context.l10n, id),
  null => null,
};
