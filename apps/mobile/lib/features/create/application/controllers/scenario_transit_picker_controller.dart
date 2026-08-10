import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/scenario_transit_schedule.dart';
import '../../domain/entities/scenario_item_draft.dart';
import '../../domain/entities/scenario_transit_mutation.dart';
import '../scenario_transit_picker_config.dart';
import '../scenario_transit_telemetry.dart';
import '../scenario_transit_schedule_coordinator.dart';
import '../state/scenario_transit_picker_state.dart';

class ScenarioTransitPickerController extends ChangeNotifier {
  ScenarioTransitPickerController({
    required ScenarioTransitScheduleCoordinator coordinator,
    this.config = scenarioTransitPickerConfig,
    ScenarioTransitTelemetry telemetry =
        const ScenarioTransitTelemetry.disabled(),
  }) : _coordinator = coordinator,
       _telemetry = telemetry {
    if (!config.isValid) {
      throw ArgumentError('Invalid Scenario transit picker configuration.');
    }
  }

  final ScenarioTransitScheduleCoordinator _coordinator;
  final ScenarioTransitTelemetry _telemetry;
  final ScenarioTransitPickerConfig config;

  ScenarioTransitPickerState _state =
      const ScenarioTransitPickerState.initial();
  ScenarioTransitPickerState get state => _state;

  bool get canApplySelectedService {
    final option = _state.selectedService;
    if (option == null) return false;
    bool valid(ScenarioTransitStop stop) =>
        stop.latitude != null &&
        stop.longitude != null &&
        ScenarioGeoPointDraft(
          latitude: stop.latitude!,
          longitude: stop.longitude!,
        ).isValid;
    return valid(option.origin) && valid(option.destination);
  }

  Timer? _originDebounce;
  Timer? _destinationDebounce;
  var _initializeOperation = 0;
  var _refreshOperation = 0;
  var _originOperation = 0;
  var _destinationOperation = 0;
  var _serviceOperation = 0;
  var _recheckOperation = 0;
  bool _disposed = false;

  Future<void> initialize() async {
    final operation = ++_initializeOperation;
    if (!config.pickerEnabled) {
      _setState(
        _state.copyWith(
          initializationStatus: ScenarioTransitPickerStatus.failure,
          failureCode: ScenarioTransitPickerFailureCode.pickerDisabled,
          retryAction: ScenarioTransitPickerRetryAction.none,
        ),
      );
      return;
    }
    _setState(
      _state.copyWith(
        initializationStatus: ScenarioTransitPickerStatus.loading,
        clearFailureCode: true,
        retryAction: ScenarioTransitPickerRetryAction.none,
      ),
    );
    try {
      final providers = _coordinator.providers;
      if (!_isCurrentInitialize(operation)) return;
      if (providers.isEmpty) {
        _setState(
          _state.copyWith(
            initializationStatus: ScenarioTransitPickerStatus.empty,
            providers: const <ScenarioTransitProviderDescriptor>[],
            cacheInspections: const <String, ScenarioTransitCacheInspection>{},
            clearSelectedProviderCode: true,
            failureCode: ScenarioTransitPickerFailureCode.noProviders,
            retryAction: ScenarioTransitPickerRetryAction.initialize,
          ),
        );
        return;
      }
      final inspections = await _coordinator.inspectCached(
        providers.map((provider) => provider.code),
      );
      if (!_isCurrentInitialize(operation)) return;
      final existingSelection = _state.selectedProviderCode;
      final selectedProviderCode =
          providers.any((provider) => provider.code == existingSelection)
          ? existingSelection
          : _firstUsableProvider(providers, inspections) ??
                providers.first.code;
      _setState(
        _state.copyWith(
          initializationStatus: ScenarioTransitPickerStatus.ready,
          providers: providers,
          cacheInspections: inspections,
          selectedProviderCode: selectedProviderCode,
          clearFailureCode: true,
          retryAction: ScenarioTransitPickerRetryAction.none,
        ),
      );
    } on ScenarioTransitScheduleException catch (error) {
      if (!_isCurrentInitialize(operation)) return;
      _fail(
        _mapFailure(error.code),
        statusTarget: _StatusTarget.initialization,
        retryAction: ScenarioTransitPickerRetryAction.initialize,
      );
    } on Object {
      if (!_isCurrentInitialize(operation)) return;
      _fail(
        ScenarioTransitPickerFailureCode.cacheReadFailed,
        statusTarget: _StatusTarget.initialization,
        retryAction: ScenarioTransitPickerRetryAction.initialize,
      );
    }
  }

  void useOfficialSchedule() {
    if (!config.pickerEnabled) {
      _fail(
        ScenarioTransitPickerFailureCode.pickerDisabled,
        statusTarget: _StatusTarget.initialization,
      );
      return;
    }
    _setState(
      _state.copyWith(
        mode: ScenarioTransitPickerMode.official,
        clearFailureCode: true,
        retryAction: ScenarioTransitPickerRetryAction.none,
      ),
    );
  }

  void useManualEntry() {
    _invalidateSearches();
    _setState(
      _state.copyWith(
        mode: ScenarioTransitPickerMode.manual,
        originQuery: '',
        destinationQuery: '',
        originResults: const <ScenarioTransitStop>[],
        destinationResults: const <ScenarioTransitStop>[],
        serviceOptions: const <ScenarioTransitServiceOption>[],
        originSearchStatus: ScenarioTransitPickerStatus.idle,
        destinationSearchStatus: ScenarioTransitPickerStatus.idle,
        serviceSearchStatus: ScenarioTransitPickerStatus.idle,
        clearOrigin: true,
        clearDestination: true,
        clearSelectedService: true,
        clearFailureCode: true,
        retryAction: ScenarioTransitPickerRetryAction.none,
      ),
    );
  }

  void selectProvider(String providerCode) {
    final normalized = providerCode.trim();
    if (!_state.providers.any((provider) => provider.code == normalized)) {
      _fail(
        ScenarioTransitPickerFailureCode.invalidProvider,
        statusTarget: _StatusTarget.initialization,
      );
      return;
    }
    _invalidateSearches();
    _setState(
      _state.copyWith(
        selectedProviderCode: normalized,
        originQuery: '',
        destinationQuery: '',
        originResults: const <ScenarioTransitStop>[],
        destinationResults: const <ScenarioTransitStop>[],
        serviceOptions: const <ScenarioTransitServiceOption>[],
        originSearchStatus: ScenarioTransitPickerStatus.idle,
        destinationSearchStatus: ScenarioTransitPickerStatus.idle,
        serviceSearchStatus: ScenarioTransitPickerStatus.idle,
        clearOrigin: true,
        clearDestination: true,
        clearSelectedService: true,
        clearFailureCode: true,
        retryAction: ScenarioTransitPickerRetryAction.none,
      ),
    );
  }

  bool useCachedProvider(String providerCode) {
    final inspection = _state.cacheInspections[providerCode];
    if (inspection?.isUsable != true) {
      _fail(
        ScenarioTransitPickerFailureCode.noUsableCache,
        statusTarget: _StatusTarget.refresh,
        retryAction: ScenarioTransitPickerRetryAction.refresh,
      );
      return false;
    }
    selectProvider(providerCode);
    _setState(
      _state.copyWith(
        refreshStatus: ScenarioTransitPickerStatus.ready,
        clearRefreshingProviderCode: true,
        clearFailureCode: true,
        retryAction: ScenarioTransitPickerRetryAction.none,
      ),
    );
    return true;
  }

  Future<bool> refreshProvider([String? providerCode]) async {
    final code = providerCode ?? _state.selectedProviderCode;
    if (code == null ||
        !_state.providers.any((provider) => provider.code == code)) {
      _fail(
        ScenarioTransitPickerFailureCode.invalidProvider,
        statusTarget: _StatusTarget.refresh,
      );
      return false;
    }
    final descriptor = _state.providers.firstWhere(
      (provider) => provider.code == code,
    );
    if (!config.networkRefreshEnabled || !descriptor.refreshEnabled) {
      _fail(
        ScenarioTransitPickerFailureCode.networkDisabled,
        statusTarget: _StatusTarget.refresh,
        retryAction: ScenarioTransitPickerRetryAction.none,
      );
      return false;
    }
    final operation = ++_refreshOperation;
    _setState(
      _state.copyWith(
        refreshStatus: ScenarioTransitPickerStatus.loading,
        refreshingProviderCode: code,
        clearFailureCode: true,
        retryAction: ScenarioTransitPickerRetryAction.none,
      ),
    );
    try {
      final manifest = await _coordinator.refresh(code);
      if (!_isCurrentRefresh(operation, code)) return false;
      final inspection = _inspection(manifest);
      _setState(
        _state.copyWith(
          refreshStatus: ScenarioTransitPickerStatus.ready,
          cacheInspections: <String, ScenarioTransitCacheInspection>{
            ..._state.cacheInspections,
            code: inspection,
          },
          clearRefreshingProviderCode: true,
          clearFailureCode: true,
          retryAction: ScenarioTransitPickerRetryAction.none,
        ),
      );
      return true;
    } on ScenarioTransitScheduleException catch (error) {
      if (!_isCurrentRefresh(operation, code)) return false;
      _fail(
        _mapFailure(error.code),
        statusTarget: _StatusTarget.refresh,
        retryAction: ScenarioTransitPickerRetryAction.refresh,
        clearRefreshingProvider: true,
      );
      return false;
    } on Object {
      if (!_isCurrentRefresh(operation, code)) return false;
      _fail(
        ScenarioTransitPickerFailureCode.downloadFailed,
        statusTarget: _StatusTarget.refresh,
        retryAction: ScenarioTransitPickerRetryAction.refresh,
        clearRefreshingProvider: true,
      );
      return false;
    }
  }

  void updateOriginQuery(String value) =>
      _queueStopSearch(isOrigin: true, query: value);

  void updateDestinationQuery(String value) =>
      _queueStopSearch(isOrigin: false, query: value);

  Future<void> searchOriginNow(String value) =>
      _searchStopNow(isOrigin: true, query: value);

  Future<void> searchDestinationNow(String value) =>
      _searchStopNow(isOrigin: false, query: value);

  void selectOrigin(ScenarioTransitStop value) {
    if (!_validStopSelection(value) || value.id == _state.destination?.id) {
      _fail(
        ScenarioTransitPickerFailureCode.invalidSelection,
        statusTarget: _StatusTarget.origin,
      );
      return;
    }
    _invalidateServiceSearch();
    _setState(
      _state.copyWith(
        origin: value,
        originQuery: value.name,
        originSearchStatus: ScenarioTransitPickerStatus.ready,
        originResults: const <ScenarioTransitStop>[],
        serviceOptions: const <ScenarioTransitServiceOption>[],
        serviceSearchStatus: ScenarioTransitPickerStatus.idle,
        clearSelectedService: true,
        clearFailureCode: true,
        retryAction: ScenarioTransitPickerRetryAction.none,
      ),
    );
  }

  void selectDestination(ScenarioTransitStop value) {
    if (!_validStopSelection(value) || value.id == _state.origin?.id) {
      _fail(
        ScenarioTransitPickerFailureCode.invalidSelection,
        statusTarget: _StatusTarget.destination,
      );
      return;
    }
    _invalidateServiceSearch();
    _setState(
      _state.copyWith(
        destination: value,
        destinationQuery: value.name,
        destinationSearchStatus: ScenarioTransitPickerStatus.ready,
        destinationResults: const <ScenarioTransitStop>[],
        serviceOptions: const <ScenarioTransitServiceOption>[],
        serviceSearchStatus: ScenarioTransitPickerStatus.idle,
        clearSelectedService: true,
        clearFailureCode: true,
        retryAction: ScenarioTransitPickerRetryAction.none,
      ),
    );
  }

  bool setServiceDate(ScenarioTransitLocalDate value) {
    if (!value.isValid) {
      _fail(
        ScenarioTransitPickerFailureCode.invalidSelection,
        statusTarget: _StatusTarget.service,
      );
      return false;
    }
    _invalidateServiceSearch();
    _setState(
      _state.copyWith(
        serviceDate: value,
        serviceOptions: const <ScenarioTransitServiceOption>[],
        serviceSearchStatus: ScenarioTransitPickerStatus.idle,
        clearSelectedService: true,
        clearFailureCode: true,
        retryAction: ScenarioTransitPickerRetryAction.none,
      ),
    );
    return true;
  }

  bool setDepartAfter(ScenarioTransitTime value) {
    if (value.secondsFromServiceDay < 0 ||
        value.secondsFromServiceDay >= 48 * Duration.secondsPerHour) {
      _fail(
        ScenarioTransitPickerFailureCode.invalidSelection,
        statusTarget: _StatusTarget.service,
      );
      return false;
    }
    _invalidateServiceSearch();
    _setState(
      _state.copyWith(
        departAfter: value,
        serviceOptions: const <ScenarioTransitServiceOption>[],
        serviceSearchStatus: ScenarioTransitPickerStatus.idle,
        clearSelectedService: true,
        clearFailureCode: true,
        retryAction: ScenarioTransitPickerRetryAction.none,
      ),
    );
    return true;
  }

  Future<void> searchServices() async {
    if (!_state.canSearchServices) {
      _fail(
        ScenarioTransitPickerFailureCode.invalidSelection,
        statusTarget: _StatusTarget.service,
      );
      return;
    }
    final providerCode = _state.selectedProviderCode!;
    final origin = _state.origin!;
    final destination = _state.destination!;
    final serviceDate = _state.serviceDate!;
    final departAfter = _state.departAfter;
    final operation = ++_serviceOperation;
    final fingerprint = _serviceFingerprint(
      providerCode,
      origin.id,
      destination.id,
      serviceDate,
      departAfter,
    );
    _setState(
      _state.copyWith(
        serviceSearchStatus: ScenarioTransitPickerStatus.loading,
        serviceOptions: const <ScenarioTransitServiceOption>[],
        clearSelectedService: true,
        clearFailureCode: true,
        retryAction: ScenarioTransitPickerRetryAction.none,
      ),
    );
    try {
      final result = await _coordinator.search(
        ScenarioTransitSearchQuery(
          originStopId: origin.id,
          destinationStopId: destination.id,
          serviceDate: serviceDate,
          departAfter: departAfter,
          providerCodes: <String>{providerCode},
          limit: config.serviceResultLimit,
        ),
      );
      if (!_isCurrentService(operation, fingerprint)) return;
      if (result.unavailableProviders.contains(providerCode)) {
        _fail(
          ScenarioTransitPickerFailureCode.noUsableCache,
          statusTarget: _StatusTarget.service,
          retryAction: ScenarioTransitPickerRetryAction.serviceSearch,
        );
        return;
      }
      final options = result.options
          .where(
            (option) =>
                option.providerCode == providerCode &&
                option.serviceDate == serviceDate,
          )
          .take(config.serviceResultLimit)
          .toList(growable: false);
      _setState(
        _state.copyWith(
          serviceSearchStatus: options.isEmpty
              ? ScenarioTransitPickerStatus.empty
              : ScenarioTransitPickerStatus.ready,
          serviceOptions: options,
          clearSelectedService: true,
          clearFailureCode: true,
          retryAction: ScenarioTransitPickerRetryAction.none,
        ),
      );
    } on ScenarioTransitScheduleException catch (error) {
      if (!_isCurrentService(operation, fingerprint)) return;
      _fail(
        _mapFailure(error.code),
        statusTarget: _StatusTarget.service,
        retryAction: ScenarioTransitPickerRetryAction.serviceSearch,
      );
    } on Object {
      if (!_isCurrentService(operation, fingerprint)) return;
      _fail(
        ScenarioTransitPickerFailureCode.serviceSearchFailed,
        statusTarget: _StatusTarget.service,
        retryAction: ScenarioTransitPickerRetryAction.serviceSearch,
      );
    }
  }

  bool selectService(ScenarioTransitServiceOption value) {
    final exists = _state.serviceOptions.any(
      (option) =>
          option.providerCode == value.providerCode &&
          option.tripId == value.tripId &&
          option.routeId == value.routeId &&
          option.serviceDate == value.serviceDate &&
          option.departure.secondsFromServiceDay ==
              value.departure.secondsFromServiceDay,
    );
    if (!exists || value.providerCode != _state.selectedProviderCode) {
      _fail(
        ScenarioTransitPickerFailureCode.invalidSelection,
        statusTarget: _StatusTarget.service,
      );
      return false;
    }
    _setState(
      _state.copyWith(
        selectedService: value,
        clearFailureCode: true,
        retryAction: ScenarioTransitPickerRetryAction.none,
      ),
    );
    return true;
  }

  void clearSelectedServicePreview() {
    _setState(
      _state.copyWith(
        clearSelectedService: true,
        serviceSearchStatus: _state.serviceOptions.isEmpty
            ? ScenarioTransitPickerStatus.idle
            : ScenarioTransitPickerStatus.ready,
      ),
    );
  }

  Future<ScenarioTransitRecheckResult> recheckSnapshot({
    required String itemId,
    required ScenarioScheduleSnapshotDraft snapshot,
  }) async {
    final normalizedItemId = itemId.trim();
    if (normalizedItemId.isEmpty) {
      const result = ScenarioTransitRecheckResult(
        status: ScenarioTransitRecheckStatus.invalidSnapshot,
      );
      _telemetry.trackRecheck(result);
      return result;
    }
    final operation = ++_recheckOperation;
    _setState(
      _state.copyWith(
        recheckStatus: ScenarioTransitPickerStatus.loading,
        recheckingItemId: normalizedItemId,
        clearRecheckResult: true,
      ),
    );
    final result = await _coordinator.recheck(snapshot);
    if (_disposed ||
        operation != _recheckOperation ||
        _state.recheckingItemId != normalizedItemId) {
      return result;
    }
    _telemetry.trackRecheck(result);
    _setState(
      _state.copyWith(
        recheckStatus: switch (result.status) {
          ScenarioTransitRecheckStatus.unchanged ||
          ScenarioTransitRecheckStatus.changed =>
            ScenarioTransitPickerStatus.ready,
          ScenarioTransitRecheckStatus.notFound =>
            ScenarioTransitPickerStatus.empty,
          ScenarioTransitRecheckStatus.unavailable ||
          ScenarioTransitRecheckStatus.invalidSnapshot =>
            ScenarioTransitPickerStatus.failure,
        },
        recheckResult: result,
      ),
    );
    return result;
  }

  void clearRecheck() {
    _recheckOperation++;
    _setState(
      _state.copyWith(
        recheckStatus: ScenarioTransitPickerStatus.idle,
        clearRecheckingItemId: true,
        clearRecheckResult: true,
      ),
    );
  }

  Future<void> retry() async {
    switch (_state.retryAction) {
      case ScenarioTransitPickerRetryAction.none:
        return;
      case ScenarioTransitPickerRetryAction.initialize:
        await initialize();
        return;
      case ScenarioTransitPickerRetryAction.refresh:
        await refreshProvider();
        return;
      case ScenarioTransitPickerRetryAction.originSearch:
        await searchOriginNow(_state.originQuery);
        return;
      case ScenarioTransitPickerRetryAction.destinationSearch:
        await searchDestinationNow(_state.destinationQuery);
        return;
      case ScenarioTransitPickerRetryAction.serviceSearch:
        await searchServices();
        return;
    }
  }

  void _queueStopSearch({required bool isOrigin, required String query}) {
    final timer = isOrigin ? _originDebounce : _destinationDebounce;
    timer?.cancel();
    final operation = isOrigin ? ++_originOperation : ++_destinationOperation;
    _prepareStopQuery(isOrigin: isOrigin, query: query);
    if (query.trim().length < config.minimumStopQueryLength ||
        !_canSearchStops) {
      return;
    }
    void callback() => unawaited(
      _executeStopSearch(
        isOrigin: isOrigin,
        query: query,
        operation: operation,
      ),
    );
    final nextTimer = Timer(config.stopSearchDebounce, callback);
    if (isOrigin) {
      _originDebounce = nextTimer;
    } else {
      _destinationDebounce = nextTimer;
    }
  }

  Future<void> _searchStopNow({
    required bool isOrigin,
    required String query,
  }) async {
    if (isOrigin) {
      _originDebounce?.cancel();
    } else {
      _destinationDebounce?.cancel();
    }
    final operation = isOrigin ? ++_originOperation : ++_destinationOperation;
    _prepareStopQuery(isOrigin: isOrigin, query: query);
    if (query.trim().length < config.minimumStopQueryLength ||
        !_canSearchStops) {
      return;
    }
    await _executeStopSearch(
      isOrigin: isOrigin,
      query: query,
      operation: operation,
    );
  }

  void _prepareStopQuery({required bool isOrigin, required String query}) {
    _invalidateServiceSearch();
    if (isOrigin) {
      _setState(
        _state.copyWith(
          originQuery: query,
          originSearchStatus:
              query.trim().length < config.minimumStopQueryLength ||
                  !_canSearchStops
              ? ScenarioTransitPickerStatus.idle
              : ScenarioTransitPickerStatus.loading,
          originResults: const <ScenarioTransitStop>[],
          serviceOptions: const <ScenarioTransitServiceOption>[],
          serviceSearchStatus: ScenarioTransitPickerStatus.idle,
          clearOrigin: true,
          clearSelectedService: true,
          clearFailureCode: true,
          retryAction: ScenarioTransitPickerRetryAction.none,
        ),
      );
    } else {
      _setState(
        _state.copyWith(
          destinationQuery: query,
          destinationSearchStatus:
              query.trim().length < config.minimumStopQueryLength ||
                  !_canSearchStops
              ? ScenarioTransitPickerStatus.idle
              : ScenarioTransitPickerStatus.loading,
          destinationResults: const <ScenarioTransitStop>[],
          serviceOptions: const <ScenarioTransitServiceOption>[],
          serviceSearchStatus: ScenarioTransitPickerStatus.idle,
          clearDestination: true,
          clearSelectedService: true,
          clearFailureCode: true,
          retryAction: ScenarioTransitPickerRetryAction.none,
        ),
      );
    }
  }

  Future<void> _executeStopSearch({
    required bool isOrigin,
    required String query,
    required int operation,
  }) async {
    final providerCode = _state.selectedProviderCode;
    final normalizedQuery = query.trim();
    if (providerCode == null || !_canSearchStops) return;
    try {
      final raw = await _coordinator.searchStops(
        query: normalizedQuery,
        providerCodes: <String>{providerCode},
        limit: config.stopResultLimit,
      );
      if (!_isCurrentStopSearch(
        isOrigin: isOrigin,
        operation: operation,
        providerCode: providerCode,
        query: query,
      )) {
        return;
      }
      final results = raw
          .where((stop) => stop.providerCode == providerCode)
          .take(config.stopResultLimit)
          .toList(growable: false);
      if (isOrigin) {
        _setState(
          _state.copyWith(
            originSearchStatus: results.isEmpty
                ? ScenarioTransitPickerStatus.empty
                : ScenarioTransitPickerStatus.ready,
            originResults: results,
            clearFailureCode: true,
            retryAction: ScenarioTransitPickerRetryAction.none,
          ),
        );
      } else {
        _setState(
          _state.copyWith(
            destinationSearchStatus: results.isEmpty
                ? ScenarioTransitPickerStatus.empty
                : ScenarioTransitPickerStatus.ready,
            destinationResults: results,
            clearFailureCode: true,
            retryAction: ScenarioTransitPickerRetryAction.none,
          ),
        );
      }
    } on ScenarioTransitScheduleException catch (error) {
      if (!_isCurrentStopSearch(
        isOrigin: isOrigin,
        operation: operation,
        providerCode: providerCode,
        query: query,
      )) {
        return;
      }
      _fail(
        _mapFailure(error.code),
        statusTarget: isOrigin
            ? _StatusTarget.origin
            : _StatusTarget.destination,
        retryAction: isOrigin
            ? ScenarioTransitPickerRetryAction.originSearch
            : ScenarioTransitPickerRetryAction.destinationSearch,
      );
    } on Object {
      if (!_isCurrentStopSearch(
        isOrigin: isOrigin,
        operation: operation,
        providerCode: providerCode,
        query: query,
      )) {
        return;
      }
      _fail(
        ScenarioTransitPickerFailureCode.stopSearchFailed,
        statusTarget: isOrigin
            ? _StatusTarget.origin
            : _StatusTarget.destination,
        retryAction: isOrigin
            ? ScenarioTransitPickerRetryAction.originSearch
            : ScenarioTransitPickerRetryAction.destinationSearch,
      );
    }
  }

  bool get _canSearchStops =>
      _state.mode == ScenarioTransitPickerMode.official &&
      _state.selectedProviderCode != null &&
      _state.selectedCache?.isUsable == true;

  bool _validStopSelection(ScenarioTransitStop value) =>
      _state.mode == ScenarioTransitPickerMode.official &&
      value.providerCode == _state.selectedProviderCode &&
      value.id.trim().isNotEmpty &&
      value.name.trim().isNotEmpty;

  String? _firstUsableProvider(
    List<ScenarioTransitProviderDescriptor> providers,
    Map<String, ScenarioTransitCacheInspection> inspections,
  ) {
    for (final provider in providers) {
      if (inspections[provider.code]?.isUsable == true) return provider.code;
    }
    return null;
  }

  ScenarioTransitCacheInspection _inspection(
    ScenarioTransitFeedManifest manifest,
  ) => ScenarioTransitCacheInspection(
    providerCode: manifest.providerCode,
    status: switch (manifest.freshness) {
      ScenarioTransitFreshness.current => ScenarioTransitCacheStatus.current,
      ScenarioTransitFreshness.stale => ScenarioTransitCacheStatus.stale,
      ScenarioTransitFreshness.unknown => ScenarioTransitCacheStatus.unknown,
      ScenarioTransitFreshness.unavailable => ScenarioTransitCacheStatus.failed,
    },
    manifest: manifest.freshness == ScenarioTransitFreshness.unavailable
        ? null
        : manifest,
  );

  ScenarioTransitPickerFailureCode _mapFailure(
    ScenarioTransitScheduleFailureCode code,
  ) => switch (code) {
    ScenarioTransitScheduleFailureCode.unknownProvider =>
      ScenarioTransitPickerFailureCode.invalidProvider,
    ScenarioTransitScheduleFailureCode.networkDisabled =>
      ScenarioTransitPickerFailureCode.networkDisabled,
    ScenarioTransitScheduleFailureCode.offline =>
      ScenarioTransitPickerFailureCode.offline,
    ScenarioTransitScheduleFailureCode.downloadFailed =>
      ScenarioTransitPickerFailureCode.downloadFailed,
    ScenarioTransitScheduleFailureCode.invalidFeed =>
      ScenarioTransitPickerFailureCode.invalidFeed,
    ScenarioTransitScheduleFailureCode.cacheReadFailed =>
      ScenarioTransitPickerFailureCode.cacheReadFailed,
    ScenarioTransitScheduleFailureCode.cacheWriteFailed =>
      ScenarioTransitPickerFailureCode.cacheWriteFailed,
  };

  void _fail(
    ScenarioTransitPickerFailureCode code, {
    required _StatusTarget statusTarget,
    ScenarioTransitPickerRetryAction retryAction =
        ScenarioTransitPickerRetryAction.none,
    bool clearRefreshingProvider = false,
  }) {
    _setState(
      _state.copyWith(
        initializationStatus: statusTarget == _StatusTarget.initialization
            ? ScenarioTransitPickerStatus.failure
            : null,
        refreshStatus: statusTarget == _StatusTarget.refresh
            ? ScenarioTransitPickerStatus.failure
            : null,
        originSearchStatus: statusTarget == _StatusTarget.origin
            ? ScenarioTransitPickerStatus.failure
            : null,
        destinationSearchStatus: statusTarget == _StatusTarget.destination
            ? ScenarioTransitPickerStatus.failure
            : null,
        serviceSearchStatus: statusTarget == _StatusTarget.service
            ? ScenarioTransitPickerStatus.failure
            : null,
        clearRefreshingProviderCode: clearRefreshingProvider,
        failureCode: code,
        retryAction: retryAction,
      ),
    );
  }

  bool _isCurrentInitialize(int operation) =>
      !_disposed && operation == _initializeOperation;

  bool _isCurrentRefresh(int operation, String providerCode) =>
      !_disposed &&
      operation == _refreshOperation &&
      _state.refreshingProviderCode == providerCode;

  bool _isCurrentStopSearch({
    required bool isOrigin,
    required int operation,
    required String providerCode,
    required String query,
  }) =>
      !_disposed &&
      operation == (isOrigin ? _originOperation : _destinationOperation) &&
      _state.selectedProviderCode == providerCode &&
      (isOrigin ? _state.originQuery : _state.destinationQuery) == query;

  bool _isCurrentService(int operation, String fingerprint) =>
      !_disposed &&
      operation == _serviceOperation &&
      fingerprint ==
          _serviceFingerprint(
            _state.selectedProviderCode,
            _state.origin?.id,
            _state.destination?.id,
            _state.serviceDate,
            _state.departAfter,
          );

  String _serviceFingerprint(
    String? providerCode,
    String? originId,
    String? destinationId,
    ScenarioTransitLocalDate? serviceDate,
    ScenarioTransitTime departAfter,
  ) =>
      '$providerCode|$originId|$destinationId|${serviceDate?.compact}|'
      '${departAfter.secondsFromServiceDay}';

  void _invalidateSearches() {
    _originDebounce?.cancel();
    _destinationDebounce?.cancel();
    _originOperation++;
    _destinationOperation++;
    _serviceOperation++;
    _recheckOperation++;
  }

  void _invalidateServiceSearch() => _serviceOperation++;

  void _setState(ScenarioTransitPickerState value) {
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _originDebounce?.cancel();
    _destinationDebounce?.cancel();
    _initializeOperation++;
    _refreshOperation++;
    _originOperation++;
    _destinationOperation++;
    _serviceOperation++;
    _recheckOperation++;
    super.dispose();
  }
}

enum _StatusTarget { initialization, refresh, origin, destination, service }
