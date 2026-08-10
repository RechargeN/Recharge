import 'dart:async';

import 'package:flutter/material.dart';

import '../../../application/controllers/scenario_transit_picker_controller.dart';
import '../../../application/state/scenario_transit_picker_state.dart';
import '../../../domain/entities/scenario_transit_schedule.dart';

enum ScenarioTransitEntryChoice { manual, official }

enum ScenarioTransitPickerSheetResult { apply, manual }

Future<ScenarioTransitEntryChoice?> showScenarioTransitEntryChoice(
  BuildContext context,
) => showModalBottomSheet<ScenarioTransitEntryChoice>(
  context: context,
  builder: (BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Add planned transport',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ListTile(
            key: const ValueKey<String>('scenario-transit-choice-manual'),
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Enter manually'),
            subtitle: const Text('Works offline and stays editable.'),
            onTap: () =>
                Navigator.of(context).pop(ScenarioTransitEntryChoice.manual),
          ),
          ListTile(
            key: const ValueKey<String>('scenario-transit-choice-official'),
            leading: const Icon(Icons.travel_explore_outlined),
            title: const Text('Find in official schedule'),
            subtitle: const Text('Static timetable snapshot · not live.'),
            onTap: () =>
                Navigator.of(context).pop(ScenarioTransitEntryChoice.official),
          ),
        ],
      ),
    ),
  ),
);

Future<ScenarioTransitPickerSheetResult?> showScenarioTransitSchedulePicker(
  BuildContext context, {
  required ScenarioTransitPickerController controller,
  ScenarioTransitLocalDate? initialServiceDate,
  ScenarioTransitTime? initialDepartAfter,
  bool dateLocked = false,
}) {
  controller.useOfficialSchedule();
  if (initialServiceDate != null && initialServiceDate.isValid) {
    controller.setServiceDate(initialServiceDate);
  }
  if (initialDepartAfter != null) {
    controller.setDepartAfter(initialDepartAfter);
  }
  unawaited(controller.initialize());
  return showModalBottomSheet<ScenarioTransitPickerSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => FractionallySizedBox(
      heightFactor: 0.94,
      child: _ScenarioTransitSchedulePickerSheet(
        controller: controller,
        dateLocked: dateLocked,
      ),
    ),
  );
}

class _ScenarioTransitSchedulePickerSheet extends StatefulWidget {
  const _ScenarioTransitSchedulePickerSheet({
    required this.controller,
    required this.dateLocked,
  });

  final ScenarioTransitPickerController controller;
  final bool dateLocked;

  @override
  State<_ScenarioTransitSchedulePickerSheet> createState() =>
      _ScenarioTransitSchedulePickerSheetState();
}

class _ScenarioTransitSchedulePickerSheetState
    extends State<_ScenarioTransitSchedulePickerSheet> {
  late final TextEditingController _originController;
  late final TextEditingController _destinationController;

  @override
  void initState() {
    super.initState();
    _originController = TextEditingController(
      text: widget.controller.state.originQuery,
    );
    _destinationController = TextEditingController(
      text: widget.controller.state.destinationQuery,
    );
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (BuildContext context, Widget? child) {
      final state = widget.controller.state;
      return Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Official schedule',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close official schedule',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _NonLiveNotice(state: state),
                  const SizedBox(height: 12),
                  _ProviderAndCache(
                    controller: widget.controller,
                    state: state,
                  ),
                  const SizedBox(height: 12),
                  _DateAndTime(
                    controller: widget.controller,
                    state: state,
                    dateLocked: widget.dateLocked,
                  ),
                  const SizedBox(height: 12),
                  _StopSearch(
                    title: 'Origin',
                    fieldKey: const ValueKey<String>(
                      'scenario-transit-origin-query',
                    ),
                    resultKeyPrefix: 'scenario-transit-origin-result-',
                    textController: _originController,
                    status: state.originSearchStatus,
                    results: state.originResults,
                    selected: state.origin,
                    enabled: state.selectedCache?.isUsable == true,
                    onChanged: widget.controller.updateOriginQuery,
                    onSelected: (ScenarioTransitStop stop) {
                      widget.controller.selectOrigin(stop);
                      _originController.text = stop.name;
                    },
                  ),
                  const SizedBox(height: 12),
                  _StopSearch(
                    title: 'Destination',
                    fieldKey: const ValueKey<String>(
                      'scenario-transit-destination-query',
                    ),
                    resultKeyPrefix: 'scenario-transit-destination-result-',
                    textController: _destinationController,
                    status: state.destinationSearchStatus,
                    results: state.destinationResults,
                    selected: state.destination,
                    enabled: state.selectedCache?.isUsable == true,
                    onChanged: widget.controller.updateDestinationQuery,
                    onSelected: (ScenarioTransitStop stop) {
                      widget.controller.selectDestination(stop);
                      _destinationController.text = stop.name;
                    },
                  ),
                  const SizedBox(height: 12),
                  if (state.initializationStatus ==
                          ScenarioTransitPickerStatus.ready &&
                      state.selectedCache?.isUsable != true) ...<Widget>[
                    const Text(
                      'Download a schedule before searching for stops.',
                      key: ValueKey<String>('scenario-transit-cache-required'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton.icon(
                    key: const ValueKey<String>(
                      'scenario-transit-search-services',
                    ),
                    onPressed:
                        state.canSearchServices &&
                            state.serviceSearchStatus !=
                                ScenarioTransitPickerStatus.loading
                        ? widget.controller.searchServices
                        : null,
                    icon:
                        state.serviceSearchStatus ==
                            ScenarioTransitPickerStatus.loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: const Text('Find direct services'),
                  ),
                  if (state.serviceDate == null) ...<Widget>[
                    const SizedBox(height: 6),
                    const Text(
                      'Choose a date to check the official schedule.',
                      key: ValueKey<String>('scenario-transit-date-required'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _ServiceResults(controller: widget.controller, state: state),
                  if (state.selectedService != null) ...<Widget>[
                    const SizedBox(height: 12),
                    _SelectedServicePreview(option: state.selectedService!),
                    const SizedBox(height: 12),
                    FilledButton(
                      key: const ValueKey<String>('scenario-transit-apply'),
                      onPressed: widget.controller.canApplySelectedService
                          ? () => Navigator.of(
                              context,
                            ).pop(ScenarioTransitPickerSheetResult.apply)
                          : null,
                      child: const Text('Apply to Scenario'),
                    ),
                    if (!widget.controller.canApplySelectedService)
                      const Text(
                        'This service has no valid stop coordinates and cannot '
                        'be applied safely.',
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 4),
                    const Text(
                      'Apply creates one undoable Scenario change.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: const ValueKey<String>('scenario-transit-use-manual'),
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(ScenarioTransitPickerSheetResult.manual),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Enter schedule manually'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _NonLiveNotice extends StatelessWidget {
  const _NonLiveNotice({required this.state});

  final ScenarioTransitPickerState state;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: _statusAnnouncement(state),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.info_outline),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Planned schedule · not live. Delays, tickets, fares, seats '
                'and transfers are not confirmed. Recheck before travel.',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProviderAndCache extends StatelessWidget {
  const _ProviderAndCache({required this.controller, required this.state});

  final ScenarioTransitPickerController controller;
  final ScenarioTransitPickerState state;

  @override
  Widget build(BuildContext context) {
    if (state.initializationStatus == ScenarioTransitPickerStatus.loading ||
        state.initializationStatus == ScenarioTransitPickerStatus.idle) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.providers.isEmpty) {
      return _MessageCard(
        text: 'Official schedule providers are unavailable.',
        actionLabel:
            state.retryAction == ScenarioTransitPickerRetryAction.initialize
            ? 'Retry'
            : null,
        onAction:
            state.retryAction == ScenarioTransitPickerRetryAction.initialize
            ? controller.retry
            : null,
      );
    }
    final inspection = state.selectedCache;
    final refreshLoading =
        state.refreshStatus == ScenarioTransitPickerStatus.loading;
    final hasCache = inspection?.isUsable == true;
    final needsDownload =
        inspection == null ||
        inspection.status == ScenarioTransitCacheStatus.missing ||
        inspection.status == ScenarioTransitCacheStatus.corrupt ||
        inspection.status == ScenarioTransitCacheStatus.failed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DropdownButtonFormField<String>(
          key: const ValueKey<String>('scenario-transit-provider'),
          initialValue: state.selectedProviderCode,
          decoration: const InputDecoration(
            labelText: 'Schedule provider',
            border: OutlineInputBorder(),
          ),
          items: state.providers
              .map(
                (provider) => DropdownMenuItem<String>(
                  value: provider.code,
                  child: Text(provider.displayName),
                ),
              )
              .toList(growable: false),
          onChanged: refreshLoading
              ? null
              : (String? value) {
                  if (value != null) controller.selectProvider(value);
                },
        ),
        const SizedBox(height: 8),
        _MessageCard(
          text: _cacheDescription(inspection),
          icon: _cacheIcon(inspection?.status),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            if (needsDownload || hasCache)
              OutlinedButton.icon(
                key: ValueKey<String>(
                  needsDownload
                      ? 'scenario-transit-download'
                      : 'scenario-transit-update',
                ),
                onPressed: refreshLoading ? null : controller.refreshProvider,
                icon: refreshLoading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(needsDownload ? Icons.download : Icons.refresh),
                label: Text(
                  needsDownload ? 'Download schedule' : 'Update schedule',
                ),
              ),
            if (hasCache)
              TextButton(
                onPressed: () =>
                    controller.useCachedProvider(state.selectedProviderCode!),
                child: const Text('Use cached'),
              ),
            if (state.retryAction != ScenarioTransitPickerRetryAction.none)
              TextButton.icon(
                key: const ValueKey<String>('scenario-transit-retry'),
                onPressed: controller.retry,
                icon: const Icon(Icons.replay),
                label: const Text('Retry'),
              ),
          ],
        ),
        if (state.failureCode != null)
          Text(
            _failureLabel(state.failureCode!),
            key: const ValueKey<String>('scenario-transit-failure'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}

class _DateAndTime extends StatelessWidget {
  const _DateAndTime({
    required this.controller,
    required this.state,
    required this.dateLocked,
  });

  final ScenarioTransitPickerController controller;
  final ScenarioTransitPickerState state;
  final bool dateLocked;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Expanded(
        child: OutlinedButton.icon(
          key: const ValueKey<String>('scenario-transit-date'),
          onPressed: dateLocked ? null : () => _chooseDate(context),
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(
            state.serviceDate == null
                ? dateLocked
                      ? 'Scenario date is missing'
                      : 'Choose date'
                : '${state.serviceDate!.iso8601}${dateLocked ? ' · Scenario' : ''}',
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: OutlinedButton.icon(
          key: const ValueKey<String>('scenario-transit-depart-after'),
          onPressed: () => _chooseTime(context),
          icon: const Icon(Icons.schedule_outlined),
          label: Text('After ${_clockLabel(state.departAfter)}'),
        ),
      ),
    ],
  );

  Future<void> _chooseDate(BuildContext context) async {
    final current = state.serviceDate;
    final now = DateTime.now();
    final chosen = await showDatePicker(
      context: context,
      initialDate: current == null
          ? DateTime(now.year, now.month, now.day)
          : DateTime(current.year, current.month, current.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (chosen != null) {
      controller.setServiceDate(
        ScenarioTransitLocalDate(chosen.year, chosen.month, chosen.day),
      );
    }
  }

  Future<void> _chooseTime(BuildContext context) async {
    final seconds =
        state.departAfter.secondsFromServiceDay % Duration.secondsPerDay;
    final chosen = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: seconds ~/ Duration.secondsPerHour,
        minute:
            (seconds % Duration.secondsPerHour) ~/ Duration.secondsPerMinute,
      ),
    );
    if (chosen != null) {
      controller.setDepartAfter(
        ScenarioTransitTime(chosen.hour * 3600 + chosen.minute * 60),
      );
    }
  }
}

class _StopSearch extends StatelessWidget {
  const _StopSearch({
    required this.title,
    required this.fieldKey,
    required this.resultKeyPrefix,
    required this.textController,
    required this.status,
    required this.results,
    required this.selected,
    required this.enabled,
    required this.onChanged,
    required this.onSelected,
  });

  final String title;
  final Key fieldKey;
  final String resultKeyPrefix;
  final TextEditingController textController;
  final ScenarioTransitPickerStatus status;
  final List<ScenarioTransitStop> results;
  final ScenarioTransitStop? selected;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<ScenarioTransitStop> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      TextField(
        key: fieldKey,
        controller: textController,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: '$title stop',
          border: const OutlineInputBorder(),
          suffixIcon: status == ScenarioTransitPickerStatus.loading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search),
        ),
        onChanged: onChanged,
      ),
      if (selected != null) ...<Widget>[
        const SizedBox(height: 4),
        Text('Selected: ${selected!.name}'),
      ],
      if (status == ScenarioTransitPickerStatus.empty) ...<Widget>[
        const SizedBox(height: 4),
        Text('No $title stops found.'),
      ],
      ...results
          .take(6)
          .map(
            (stop) => ListTile(
              key: ValueKey<String>('$resultKeyPrefix${stop.id}'),
              dense: true,
              leading: const Icon(Icons.location_on_outlined),
              title: Text(stop.name),
              subtitle: Text(stop.providerCode),
              onTap: () => onSelected(stop),
            ),
          ),
    ],
  );
}

class _ServiceResults extends StatelessWidget {
  const _ServiceResults({required this.controller, required this.state});

  final ScenarioTransitPickerController controller;
  final ScenarioTransitPickerState state;

  @override
  Widget build(BuildContext context) {
    if (state.serviceSearchStatus == ScenarioTransitPickerStatus.empty) {
      return const _MessageCard(
        text: 'No direct services found after the selected time.',
        icon: Icons.search_off_outlined,
      );
    }
    if (state.serviceSearchStatus == ScenarioTransitPickerStatus.failure) {
      return _MessageCard(
        text: state.failureCode == null
            ? 'Schedule search failed.'
            : _failureLabel(state.failureCode!),
        icon: Icons.error_outline,
      );
    }
    return Column(
      children: state.serviceOptions
          .map(
            (option) => Semantics(
              label:
                  '${option.departure.hhmm} to ${option.arrival.hhmm}, '
                  '${option.durationMinutes} minutes, planned schedule not live',
              child: Card.outlined(
                child: ListTile(
                  key: ValueKey<String>(
                    'scenario-transit-service-${option.providerCode}-${option.tripId}',
                  ),
                  leading: Icon(_modeIcon(option.mode)),
                  title: Text(
                    '${option.departure.hhmm} → ${option.arrival.hhmm}',
                  ),
                  subtitle: Text(
                    '${option.agencyName ?? option.manifest.providerDisplayName} · '
                    '${option.routeLabel ?? option.headsign ?? option.routeId}\n'
                    '${option.durationMinutes} min · Planned schedule · not live',
                  ),
                  isThreeLine: true,
                  trailing: state.selectedService?.tripId == option.tripId
                      ? const Icon(Icons.check_circle)
                      : const Icon(Icons.chevron_right),
                  onTap: () => controller.selectService(option),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _SelectedServicePreview extends StatelessWidget {
  const _SelectedServicePreview({required this.option});

  final ScenarioTransitServiceOption option;

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey<String>('scenario-transit-selected-preview'),
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Selection preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text('${option.origin.name} → ${option.destination.name}'),
          Text(
            '${option.serviceDate.iso8601} · ${option.departure.hhmm} → '
            '${option.arrival.hhmm}',
          ),
          Text(
            '${option.manifest.providerDisplayName} · '
            '${option.manifest.licenseName}',
          ),
          Text('Feed retrieved ${option.manifest.retrievedAtUtc.toUtc()}'),
          Text('Freshness: ${_freshnessLabel(option.manifest.freshness)}'),
          const SizedBox(height: 6),
          const Text(
            'Planned schedule · not live. This selection is not yet applied '
            'to the Scenario.',
          ),
        ],
      ),
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.text,
    this.icon = Icons.info_outline,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Card.outlined(
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: <Widget>[
          Icon(icon),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    ),
  );
}

String _cacheDescription(ScenarioTransitCacheInspection? inspection) {
  if (inspection == null) return 'Checking cached schedule…';
  final retrieved = inspection.manifest?.retrievedAtUtc.toUtc();
  return switch (inspection.status) {
    ScenarioTransitCacheStatus.current =>
      'Cached schedule is current${retrieved == null ? '' : ' · $retrieved'}.',
    ScenarioTransitCacheStatus.stale =>
      'Cached schedule is stale${retrieved == null ? '' : ' · $retrieved'}. '
          'You may use it with a warning or update it.',
    ScenarioTransitCacheStatus.unknown =>
      'Cached schedule freshness is unknown. Recheck before travel.',
    ScenarioTransitCacheStatus.missing =>
      'No schedule is downloaded for this provider.',
    ScenarioTransitCacheStatus.corrupt =>
      'Cached schedule is damaged and cannot be used.',
    ScenarioTransitCacheStatus.failed => 'Cached schedule could not be read.',
  };
}

IconData _cacheIcon(ScenarioTransitCacheStatus? status) => switch (status) {
  ScenarioTransitCacheStatus.current => Icons.verified_outlined,
  ScenarioTransitCacheStatus.stale ||
  ScenarioTransitCacheStatus.unknown => Icons.warning_amber_outlined,
  ScenarioTransitCacheStatus.missing => Icons.download_outlined,
  ScenarioTransitCacheStatus.corrupt ||
  ScenarioTransitCacheStatus.failed => Icons.error_outline,
  null => Icons.hourglass_empty,
};

String _failureLabel(ScenarioTransitPickerFailureCode value) => switch (value) {
  ScenarioTransitPickerFailureCode.pickerDisabled =>
    'Official schedule is temporarily unavailable.',
  ScenarioTransitPickerFailureCode.noProviders =>
    'No official schedule providers are configured.',
  ScenarioTransitPickerFailureCode.invalidProvider =>
    'Choose a valid schedule provider.',
  ScenarioTransitPickerFailureCode.noUsableCache =>
    'Download or select a usable cached schedule first.',
  ScenarioTransitPickerFailureCode.networkDisabled =>
    'Schedule downloads are disabled. Cached data remains available.',
  ScenarioTransitPickerFailureCode.offline =>
    'You appear to be offline. Cached data remains available.',
  ScenarioTransitPickerFailureCode.downloadFailed =>
    'The schedule could not be downloaded.',
  ScenarioTransitPickerFailureCode.invalidFeed =>
    'The downloaded schedule is invalid and was not saved.',
  ScenarioTransitPickerFailureCode.cacheReadFailed =>
    'The cached schedule could not be read.',
  ScenarioTransitPickerFailureCode.cacheWriteFailed =>
    'The new schedule could not be saved. Existing cache was kept.',
  ScenarioTransitPickerFailureCode.invalidSelection =>
    'Complete the provider, stops, date and time selection.',
  ScenarioTransitPickerFailureCode.stopSearchFailed =>
    'Stop search failed. Try again.',
  ScenarioTransitPickerFailureCode.serviceSearchFailed =>
    'Schedule search failed. Try again.',
};

String _freshnessLabel(ScenarioTransitFreshness value) => switch (value) {
  ScenarioTransitFreshness.current => 'current',
  ScenarioTransitFreshness.stale => 'stale',
  ScenarioTransitFreshness.unknown => 'unknown',
  ScenarioTransitFreshness.unavailable => 'unavailable',
};

String _statusAnnouncement(ScenarioTransitPickerState state) {
  final failure = state.failureCode;
  if (failure != null) return _failureLabel(failure);
  if (state.serviceSearchStatus == ScenarioTransitPickerStatus.loading) {
    return 'Searching direct planned services.';
  }
  if (state.serviceSearchStatus == ScenarioTransitPickerStatus.empty) {
    return 'No direct planned services found.';
  }
  if (state.selectedService != null) {
    return 'Planned service selected for preview. Not applied to Scenario.';
  }
  return 'Planned schedule, not live.';
}

String _clockLabel(ScenarioTransitTime value) {
  final seconds = value.secondsFromServiceDay % Duration.secondsPerDay;
  final hour = seconds ~/ Duration.secondsPerHour;
  final minute =
      (seconds % Duration.secondsPerHour) ~/ Duration.secondsPerMinute;
  return '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}

IconData _modeIcon(ScenarioTransitMode value) => switch (value) {
  ScenarioTransitMode.bus => Icons.directions_bus_outlined,
  ScenarioTransitMode.train => Icons.train_outlined,
  ScenarioTransitMode.tram => Icons.tram_outlined,
  ScenarioTransitMode.trolleybus => Icons.directions_bus,
  ScenarioTransitMode.other => Icons.directions_transit_outlined,
};
