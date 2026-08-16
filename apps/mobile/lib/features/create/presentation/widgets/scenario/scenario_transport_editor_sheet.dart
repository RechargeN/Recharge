import 'package:flutter/material.dart';

import '../../../../../core/parsing/input_parsers.dart';
import '../../../domain/entities/scenario_item_draft.dart';
import '../../../domain/entities/scenario_logistics_draft.dart';

class ScenarioPlannedTransportInput {
  const ScenarioPlannedTransportInput({
    required this.kind,
    required this.carrierName,
    required this.serviceLabel,
    required this.durationMinutes,
    this.plannedDeparture,
    this.plannedArrival,
  });

  final ScenarioPlannedTransportKind kind;
  final String carrierName;
  final String serviceLabel;
  final int durationMinutes;
  final ScenarioLocalTimeDraft? plannedDeparture;
  final ScenarioLocalTimeDraft? plannedArrival;
}

class ScenarioManualLegInput {
  const ScenarioManualLegInput({
    required this.mode,
    required this.durationMinutes,
    required this.distanceKm,
    this.otherCostMinorUnits,
  });

  final ScenarioTravelMode mode;
  final int durationMinutes;
  final double distanceKm;
  final int? otherCostMinorUnits;
}

Future<ScenarioPlannedTransportInput?> showScenarioPlannedTransportEditor(
  BuildContext context,
) {
  String carrier = '';
  String service = '';
  String duration = '60';
  String departure = '';
  String arrival = '';
  ScenarioPlannedTransportKind kind = ScenarioPlannedTransportKind.bus;
  return showModalBottomSheet<ScenarioPlannedTransportInput>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Add planned transport',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              const Text(
                'Planned schedule · not live. Recheck the service before travel.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ScenarioPlannedTransportKind>(
                initialValue: kind,
                decoration: const InputDecoration(
                  labelText: 'Transport',
                  border: OutlineInputBorder(),
                ),
                items: ScenarioPlannedTransportKind.values
                    .map(
                      (ScenarioPlannedTransportKind value) =>
                          DropdownMenuItem<ScenarioPlannedTransportKind>(
                            value: value,
                            child: Text(_enumLabel(value.name)),
                          ),
                    )
                    .toList(growable: false),
                onChanged: (ScenarioPlannedTransportKind? value) {
                  if (value != null) {
                    setState(() => kind = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: carrier,
                decoration: const InputDecoration(
                  labelText: 'Carrier (optional)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (String value) => carrier = value,
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const ValueKey<String>('scenario-service-label'),
                initialValue: service,
                decoration: const InputDecoration(
                  labelText: 'Service or route *',
                  hintText: 'Train 802 / Bus 7480',
                  border: OutlineInputBorder(),
                ),
                onChanged: (String value) => service = value,
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: duration,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration, min *',
                  border: OutlineInputBorder(),
                ),
                onChanged: (String value) => duration = value,
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      initialValue: departure,
                      keyboardType: TextInputType.datetime,
                      decoration: const InputDecoration(
                        labelText: 'Departure (HH:mm)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (String value) => departure = value,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: arrival,
                      keyboardType: TextInputType.datetime,
                      decoration: const InputDecoration(
                        labelText: 'Arrival (HH:mm)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (String value) => arrival = value,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey<String>('save-planned-transport'),
                onPressed: () {
                  final int? minutes = int.tryParse(duration.trim());
                  if (service.trim().isEmpty ||
                      minutes == null ||
                      minutes <= 0) {
                    return;
                  }
                  Navigator.of(context).pop(
                    ScenarioPlannedTransportInput(
                      kind: kind,
                      carrierName: carrier.trim(),
                      serviceLabel: service.trim(),
                      durationMinutes: minutes,
                      plannedDeparture: _time(departure),
                      plannedArrival: _time(arrival),
                    ),
                  );
                },
                child: const Text('Add to Scenario'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<ScenarioManualLegInput?> showScenarioManualLegEditor(
  BuildContext context, {
  required ScenarioTravelMode initialMode,
  ScenarioLegDraft? current,
}) {
  ScenarioTravelMode mode = current?.mode ?? initialMode;
  String duration = current?.durationMinutes?.toString() ?? '15';
  String distance = current?.distanceM == null
      ? '1.0'
      : (current!.distanceM! / 1000).toStringAsFixed(1);
  String otherCost = '';
  return showModalBottomSheet<ScenarioManualLegInput>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Travel between stops',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              const Text('Manual values stay locked until you edit them.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<ScenarioTravelMode>(
                initialValue: mode,
                decoration: const InputDecoration(
                  labelText: 'Travel mode',
                  border: OutlineInputBorder(),
                ),
                items: ScenarioTravelMode.values
                    .map(
                      (ScenarioTravelMode value) =>
                          DropdownMenuItem<ScenarioTravelMode>(
                            value: value,
                            child: Text(_travelModeLabel(value)),
                          ),
                    )
                    .toList(growable: false),
                onChanged: (ScenarioTravelMode? value) {
                  if (value != null) {
                    setState(() => mode = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      initialValue: duration,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duration, min',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (String value) => duration = value,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: distance,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Distance, km',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (String value) => distance = value,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: otherCost,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Parking / ticket / other cost (optional)',
                  suffixText: 'EUR',
                  border: OutlineInputBorder(),
                ),
                onChanged: (String value) => otherCost = value,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final int? minutes = int.tryParse(duration.trim());
                  final double? km = _number(distance);
                  final double? cost = _number(otherCost);
                  if (minutes == null ||
                      minutes <= 0 ||
                      km == null ||
                      km < 0 ||
                      (cost != null && cost < 0)) {
                    return;
                  }
                  Navigator.of(context).pop(
                    ScenarioManualLegInput(
                      mode: mode,
                      durationMinutes: minutes,
                      distanceKm: km,
                      otherCostMinorUnits: cost == null
                          ? null
                          : (cost * 100).round(),
                    ),
                  );
                },
                child: const Text('Save travel'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

ScenarioLocalTimeDraft? _time(String value) {
  final List<String> parts = value.trim().split(':');
  if (parts.length != 2) {
    return null;
  }
  final int? hour = int.tryParse(parts[0]);
  final int? minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    return null;
  }
  final ScenarioLocalTimeDraft result = ScenarioLocalTimeDraft(
    hour: hour,
    minute: minute,
  );
  return result.isValid ? result : null;
}

double? _number(String value) {
  return parseLocaleDecimalInput(value);
}

String _travelModeLabel(ScenarioTravelMode mode) => switch (mode) {
  ScenarioTravelMode.walking => 'Walking',
  ScenarioTravelMode.bicycle => 'Bicycle',
  ScenarioTravelMode.car => 'Own car',
  ScenarioTravelMode.taxi => 'Taxi',
  ScenarioTravelMode.transit => 'Public transport',
  ScenarioTravelMode.other => 'Other',
};

String _enumLabel(String value) => value
    .replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (Match match) => '${match.group(1)} ${match.group(2)}',
    )
    .replaceAll('_', ' ');
