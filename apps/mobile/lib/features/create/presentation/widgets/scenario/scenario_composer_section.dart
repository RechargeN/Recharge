import 'package:flutter/material.dart';

import '../../../application/controllers/create_controller.dart';
import '../../../application/controllers/scenario_transit_picker_controller.dart';
import '../../../application/scenario_transit_disclosure.dart';
import '../../../application/state/create_state.dart';
import '../../../application/state/scenario_transit_picker_state.dart';
import '../../../domain/entities/scenario_draft_data.dart';
import '../../../domain/entities/scenario_item_draft.dart';
import '../../../domain/entities/scenario_logistics_draft.dart';
import '../../../domain/entities/scenario_transit_mutation.dart';
import '../../../domain/entities/scenario_transit_schedule.dart';
import '../../../domain/repositories/catalog_object_picker_port.dart';
import 'scenario_item_editor_sheet.dart';
import 'scenario_transit_schedule_picker_sheet.dart';
import 'scenario_transit_recheck_sheet.dart';
import 'scenario_transit_disclosure_card.dart';
import 'scenario_transport_editor_sheet.dart';

class ScenarioComposerSection extends StatelessWidget {
  const ScenarioComposerSection({
    required this.controller,
    required this.state,
    this.transitPickerController,
    super.key,
  });

  final CreateController controller;
  final CreateState state;
  final ScenarioTransitPickerController? transitPickerController;

  @override
  Widget build(BuildContext context) {
    final ScenarioDraftData data = state.draft.scenarioData!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Day 1 · ${data.items.length} stops',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Undo',
              onPressed: controller.canUndoScenario
                  ? controller.undoScenario
                  : null,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: 'Redo',
              onPressed: controller.canRedoScenario
                  ? controller.redoScenario
                  : null,
              icon: const Icon(Icons.redo),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey<String>('scenario-catalog-search'),
          decoration: InputDecoration(
            labelText: 'Find a catalog place, event, activity or Route',
            border: const OutlineInputBorder(),
            suffixIcon: state.scenarioCatalogLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
          ),
          onChanged: controller.searchScenarioCatalog,
          onTap: () {
            if (state.scenarioCatalogCandidates.isEmpty) {
              controller.searchScenarioCatalog('');
            }
          },
        ),
        if (state.scenarioCatalogCandidates.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.scenarioCatalogCandidates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (BuildContext context, int index) {
                final ScenarioCatalogObjectCandidate candidate =
                    state.scenarioCatalogCandidates[index];
                return SizedBox(
                  width: 230,
                  child: Card.outlined(
                    child: ListTile(
                      dense: true,
                      title: Text(candidate.title),
                      subtitle: Text(candidate.subtitle),
                      trailing: IconButton(
                        tooltip: 'Add',
                        onPressed: () =>
                            controller.addScenarioCatalogItem(candidate),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final ScenarioCustomStopDraft? result =
                await showScenarioCustomStopEditor(context);
            if (result != null) {
              controller.addScenarioCustomStop(
                title: result.title,
                durationMinutes: result.durationMinutes,
                latitude: result.latitude,
                longitude: result.longitude,
              );
            }
          },
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Add custom stop'),
        ),
        const SizedBox(height: 8),
        _PlannedTransportEntry(
          controller: controller,
          data: data,
          transitPickerController: transitPickerController,
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Bus and train times are stored as planned schedule · not live.',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final ScenarioTimeBlockDraft? result =
                await showScenarioTimeBlockEditor(context);
            if (result != null) {
              controller.addScenarioTimeBlock(
                title: result.title,
                durationMinutes: result.durationMinutes,
              );
            }
          },
          icon: const Icon(Icons.add_alarm_outlined),
          label: const Text('Add custom time block'),
        ),
        const SizedBox(height: 12),
        if (data.items.isEmpty)
          const _EmptyComposer()
        else
          ...List<Widget>.generate(data.items.length, (int index) {
            final String itemId = data.days.first.itemIds[index];
            final ScenarioItemDraft item = data.items.firstWhere(
              (ScenarioItemDraft value) => value.id == itemId,
            );
            final source = item.source;
            final transitDisclosure =
                source is ScenarioPlannedTransportSourceDraft
                ? const BuildScenarioTransitDisclosure()(source)
                : null;
            return Card.outlined(
              key: ValueKey<String>('scenario-item-${item.id}'),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        CircleAvatar(radius: 14, child: Text('${index + 1}')),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _itemTitle(item, data),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${item.durationMinutes ?? 0} min · ${item.kind.name}',
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Move up',
                          onPressed: index == 0 || item.orderLocked
                              ? null
                              : () => controller.moveScenarioItem(item.id, -1),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          tooltip: 'Move down',
                          onPressed:
                              index == data.items.length - 1 || item.orderLocked
                              ? null
                              : () => controller.moveScenarioItem(item.id, 1),
                          icon: const Icon(Icons.arrow_downward),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          onPressed: () =>
                              controller.removeScenarioItem(item.id),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    DropdownButton<ScenarioItemRole>(
                      value: item.role,
                      isExpanded: true,
                      items: const <DropdownMenuItem<ScenarioItemRole>>[
                        DropdownMenuItem<ScenarioItemRole>(
                          value: ScenarioItemRole.mandatory,
                          child: Text('Mandatory'),
                        ),
                        DropdownMenuItem<ScenarioItemRole>(
                          value: ScenarioItemRole.optional,
                          child: Text('Optional'),
                        ),
                      ],
                      onChanged: (ScenarioItemRole? role) {
                        if (role != null) {
                          controller.updateScenarioItem(item.id, role: role);
                        }
                      },
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: <Widget>[
                          FilterChip(
                            label: const Text('Order lock'),
                            selected: item.orderLocked,
                            onSelected: (bool value) =>
                                controller.updateScenarioItem(
                                  item.id,
                                  orderLocked: value,
                                ),
                          ),
                          FilterChip(
                            label: const Text('Time lock'),
                            selected: item.timeLocked,
                            onSelected: (bool value) => controller
                                .updateScenarioItem(item.id, timeLocked: value),
                          ),
                        ],
                      ),
                    ),
                    if (transitDisclosure != null)
                      ScenarioTransitDisclosureCard(
                        key: ValueKey<String>(
                          'scenario-transit-composer-${item.id}',
                        ),
                        disclosure: transitDisclosure,
                        compact: true,
                      ),
                    if (officialTransitSnapshot(item) != null &&
                        transitPickerController != null)
                      _OfficialTransitActions(
                        controller: controller,
                        picker: transitPickerController!,
                        item: item,
                        snapshot: officialTransitSnapshot(item)!,
                        sourceRevision: data.revision,
                      ),
                  ],
                ),
              ),
            );
          }),
        if (data.days.first.itemIds.length > 1) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            'Travel between stops',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Use your primary transport or enter honest manual values.',
          ),
          const SizedBox(height: 8),
          ...List<Widget>.generate(data.days.first.itemIds.length - 1, (
            int index,
          ) {
            final String fromId = data.days.first.itemIds[index];
            final String toId = data.days.first.itemIds[index + 1];
            final ScenarioItemDraft from = data.items.firstWhere(
              (ScenarioItemDraft item) => item.id == fromId,
            );
            final ScenarioItemDraft to = data.items.firstWhere(
              (ScenarioItemDraft item) => item.id == toId,
            );
            ScenarioLegDraft? existing;
            for (final ScenarioLegDraft leg in data.legs) {
              if (leg.fromItemId == fromId && leg.toItemId == toId) {
                existing = leg;
                break;
              }
            }
            return _TransportLegCard(
              controller: controller,
              data: data,
              from: from,
              to: to,
              existing: existing,
            );
          }),
        ],
      ],
    );
  }
}

class _PlannedTransportEntry extends StatelessWidget {
  const _PlannedTransportEntry({
    required this.controller,
    required this.data,
    required this.transitPickerController,
  });

  final CreateController controller;
  final ScenarioDraftData data;
  final ScenarioTransitPickerController? transitPickerController;

  @override
  Widget build(BuildContext context) {
    final picker = transitPickerController;
    if (picker == null || !picker.config.pickerEnabled) {
      return _ManualPlannedTransportButton(
        onPressed: () => _openManual(context),
      );
    }
    return AnimatedBuilder(
      animation: picker,
      builder: (BuildContext context, Widget? child) {
        final selected = picker.state.selectedService;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            OutlinedButton.icon(
              key: const ValueKey<String>('add-planned-transport'),
              onPressed: () => _chooseSource(context, picker),
              icon: const Icon(Icons.directions_transit_outlined),
              label: const Text('Add planned transport'),
            ),
            if (selected != null) ...<Widget>[
              const SizedBox(height: 8),
              Card.outlined(
                key: const ValueKey<String>(
                  'scenario-transit-transient-preview',
                ),
                child: ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: Text(
                    selected.routeLabel ??
                        selected.headsign ??
                        selected.routeId,
                  ),
                  subtitle: Text(
                    '${selected.departure.hhmm} → ${selected.arrival.hhmm} · '
                    'Planned schedule · not live\n'
                    'Selection preview only. Scenario is unchanged.',
                  ),
                  trailing: TextButton(
                    onPressed: () => _openOfficial(context, picker),
                    child: const Text('Review'),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _chooseSource(
    BuildContext context,
    ScenarioTransitPickerController picker,
  ) async {
    final choice = await showScenarioTransitEntryChoice(context);
    if (!context.mounted || choice == null) return;
    if (choice == ScenarioTransitEntryChoice.manual) {
      picker.useManualEntry();
      await _openManual(context);
      return;
    }
    await _openOfficial(context, picker);
  }

  Future<void> _openOfficial(
    BuildContext context,
    ScenarioTransitPickerController picker,
  ) async {
    final sourceRevision = data.revision;
    final day = data.days.first;
    final localDate = day.localDate;
    final preferredStart = day.preferredStartTime;
    final result = await showScenarioTransitSchedulePicker(
      context,
      controller: picker,
      initialServiceDate: localDate == null
          ? null
          : ScenarioTransitLocalDate(
              localDate.year,
              localDate.month,
              localDate.day,
            ),
      initialDepartAfter: preferredStart == null
          ? null
          : ScenarioTransitTime(preferredStart.minuteOfDay * 60),
      dateLocked: data.dateMode == ScenarioDateMode.dated && localDate != null,
    );
    if (!context.mounted || result == null) return;
    if (result == ScenarioTransitPickerSheetResult.manual) {
      picker.useManualEntry();
      await _openManual(context);
      return;
    }
    final selected = picker.state.selectedService;
    if (selected == null) return;
    final applied = controller.applyScenarioTransitSelection(
      expectedRevision: sourceRevision,
      option: selected,
    );
    if (!context.mounted) return;
    if (applied?.accepted == true) {
      picker.clearSelectedServicePreview();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Official schedule added to Scenario.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scenario changed. Review the service and try again.'),
        ),
      );
    }
  }

  Future<void> _openManual(BuildContext context) async {
    final ScenarioPlannedTransportInput? result =
        await showScenarioPlannedTransportEditor(context);
    if (result != null) {
      controller.addScenarioPlannedTransport(
        kind: result.kind,
        carrierName: result.carrierName,
        serviceLabel: result.serviceLabel,
        durationMinutes: result.durationMinutes,
        plannedDeparture: result.plannedDeparture,
        plannedArrival: result.plannedArrival,
      );
    }
  }
}

class _OfficialTransitActions extends StatelessWidget {
  const _OfficialTransitActions({
    required this.controller,
    required this.picker,
    required this.item,
    required this.snapshot,
    required this.sourceRevision,
  });

  final CreateController controller;
  final ScenarioTransitPickerController picker;
  final ScenarioItemDraft item;
  final ScenarioScheduleSnapshotDraft snapshot;
  final int sourceRevision;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: picker,
    builder: (BuildContext context, Widget? child) {
      final loading =
          picker.state.recheckStatus == ScenarioTransitPickerStatus.loading &&
          picker.state.recheckingItemId == item.id;
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: ValueKey<String>('scenario-transit-recheck-${item.id}'),
          onPressed: loading ? null : () => _recheck(context),
          icon: loading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync_outlined),
          label: Text(loading ? 'Rechecking…' : 'Recheck schedule'),
        ),
      );
    },
  );

  Future<void> _recheck(BuildContext context) async {
    final result = await picker.recheckSnapshot(
      itemId: item.id,
      snapshot: snapshot,
    );
    if (!context.mounted) return;
    final replace = await showScenarioTransitRecheckSheet(context, result);
    if (!context.mounted || !replace || !result.canReplace) return;
    final mutation = controller.applyScenarioTransitSelection(
      expectedRevision: sourceRevision,
      option: result.candidate!,
      replaceItemId: item.id,
    );
    if (!context.mounted) return;
    if (mutation?.accepted == true) {
      picker.clearRecheck();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved schedule replaced.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scenario changed. Recheck before replacing.'),
        ),
      );
    }
  }
}

class _ManualPlannedTransportButton extends StatelessWidget {
  const _ManualPlannedTransportButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const ValueKey<String>('add-planned-transport'),
    onPressed: onPressed,
    icon: const Icon(Icons.directions_transit_outlined),
    label: const Text('Add planned transport'),
  );
}

class _TransportLegCard extends StatelessWidget {
  const _TransportLegCard({
    required this.controller,
    required this.data,
    required this.from,
    required this.to,
    required this.existing,
  });

  final CreateController controller;
  final ScenarioDraftData data;
  final ScenarioItemDraft from;
  final ScenarioItemDraft to;
  final ScenarioLegDraft? existing;

  @override
  Widget build(BuildContext context) {
    final bool canEdit =
        (from.endLocationId ?? from.startLocationId) != null &&
        (to.startLocationId ?? to.endLocationId) != null;
    final ScenarioLegDraft? leg = existing;
    return Card.outlined(
      key: ValueKey<String>('scenario-leg-${from.id}-${to.id}'),
      child: ListTile(
        leading: Icon(
          _travelModeIcon(leg?.mode ?? data.constraints.primaryTravelMode),
        ),
        title: Text('${_itemTitle(from, data)} → ${_itemTitle(to, data)}'),
        subtitle: Text(
          leg == null
              ? canEdit
                    ? '${_travelModeLabel(data.constraints.primaryTravelMode)} · time not entered'
                    : 'Location data required for a manual leg'
              : '${_travelModeLabel(leg.mode)} · '
                    '${leg.durationMinutes ?? 'unknown'} min · '
                    '${_legSourceLabel(leg.source)}',
        ),
        trailing: TextButton(
          onPressed: !canEdit
              ? null
              : () async {
                  final ScenarioManualLegInput? result =
                      await showScenarioManualLegEditor(
                        context,
                        initialMode: data.constraints.primaryTravelMode,
                        current: leg,
                      );
                  if (result != null) {
                    controller.upsertScenarioManualLeg(
                      fromItemId: from.id,
                      toItemId: to.id,
                      mode: result.mode,
                      durationMinutes: result.durationMinutes,
                      distanceKm: result.distanceKm,
                      otherCostMinorUnits: result.otherCostMinorUnits,
                    );
                  }
                },
          child: Text(leg == null ? 'Add' : 'Edit'),
        ),
      ),
    );
  }
}

class _EmptyComposer extends StatelessWidget {
  const _EmptyComposer();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Text(
      'Add at least two independent stops. Use catalog objects or custom time blocks.',
      textAlign: TextAlign.center,
    ),
  );
}

String _itemTitle(ScenarioItemDraft item, ScenarioDraftData data) =>
    switch (item.source) {
      ScenarioCatalogObjectSourceDraft source => source.snapshot.title,
      ScenarioTimeBlockSourceDraft source => source.title,
      ScenarioCustomLocationSourceDraft source => _customLocationTitle(
        source,
        data,
      ),
      ScenarioPlannedTransportSourceDraft source =>
        source.publicServiceLabel ?? source.carrierName ?? 'Planned transport',
    };

String _customLocationTitle(
  ScenarioCustomLocationSourceDraft source,
  ScenarioDraftData data,
) {
  for (final ScenarioLocationDraft location in data.locations) {
    if (location.id == source.locationId) {
      return location.title;
    }
  }
  return 'Custom location';
}

String _legSourceLabel(ScenarioLegSource source) => switch (source) {
  ScenarioLegSource.schedule => 'Planned schedule · not live',
  ScenarioLegSource.manual => 'Entered manually',
  ScenarioLegSource.estimate => 'Estimated time',
  ScenarioLegSource.provider => 'Provider value',
  ScenarioLegSource.unknown => 'Unknown',
};

String _travelModeLabel(ScenarioTravelMode mode) => switch (mode) {
  ScenarioTravelMode.walking => 'Walking',
  ScenarioTravelMode.bicycle => 'Bicycle',
  ScenarioTravelMode.car => 'Own car',
  ScenarioTravelMode.taxi => 'Taxi',
  ScenarioTravelMode.transit => 'Public transport',
  ScenarioTravelMode.other => 'Other',
};

IconData _travelModeIcon(ScenarioTravelMode mode) => switch (mode) {
  ScenarioTravelMode.walking => Icons.directions_walk,
  ScenarioTravelMode.bicycle => Icons.directions_bike,
  ScenarioTravelMode.car => Icons.directions_car,
  ScenarioTravelMode.taxi => Icons.local_taxi,
  ScenarioTravelMode.transit => Icons.directions_transit,
  ScenarioTravelMode.other => Icons.route,
};
