import '../../domain/entities/scenario_transit_schedule.dart';
import '../../domain/entities/scenario_transit_mutation.dart';

enum ScenarioTransitPickerMode { manual, official }

enum ScenarioTransitPickerStatus { idle, loading, ready, empty, failure }

enum ScenarioTransitPickerFailureCode {
  pickerDisabled,
  noProviders,
  invalidProvider,
  noUsableCache,
  networkDisabled,
  offline,
  downloadFailed,
  invalidFeed,
  cacheReadFailed,
  cacheWriteFailed,
  invalidSelection,
  stopSearchFailed,
  serviceSearchFailed,
}

enum ScenarioTransitPickerRetryAction {
  none,
  initialize,
  refresh,
  originSearch,
  destinationSearch,
  serviceSearch,
}

class ScenarioTransitPickerState {
  const ScenarioTransitPickerState({
    required this.mode,
    required this.initializationStatus,
    required this.refreshStatus,
    required this.originSearchStatus,
    required this.destinationSearchStatus,
    required this.serviceSearchStatus,
    required this.providers,
    required this.cacheInspections,
    required this.originResults,
    required this.destinationResults,
    required this.serviceOptions,
    required this.originQuery,
    required this.destinationQuery,
    required this.departAfter,
    required this.retryAction,
    this.recheckStatus = ScenarioTransitPickerStatus.idle,
    this.recheckingItemId,
    this.recheckResult,
    this.selectedProviderCode,
    this.refreshingProviderCode,
    this.origin,
    this.destination,
    this.serviceDate,
    this.selectedService,
    this.failureCode,
  });

  const ScenarioTransitPickerState.initial()
    : mode = ScenarioTransitPickerMode.manual,
      initializationStatus = ScenarioTransitPickerStatus.idle,
      refreshStatus = ScenarioTransitPickerStatus.idle,
      originSearchStatus = ScenarioTransitPickerStatus.idle,
      destinationSearchStatus = ScenarioTransitPickerStatus.idle,
      serviceSearchStatus = ScenarioTransitPickerStatus.idle,
      providers = const <ScenarioTransitProviderDescriptor>[],
      cacheInspections = const <String, ScenarioTransitCacheInspection>{},
      selectedProviderCode = null,
      refreshingProviderCode = null,
      originQuery = '',
      destinationQuery = '',
      originResults = const <ScenarioTransitStop>[],
      destinationResults = const <ScenarioTransitStop>[],
      origin = null,
      destination = null,
      serviceDate = null,
      departAfter = const ScenarioTransitTime(0),
      serviceOptions = const <ScenarioTransitServiceOption>[],
      selectedService = null,
      failureCode = null,
      retryAction = ScenarioTransitPickerRetryAction.none,
      recheckStatus = ScenarioTransitPickerStatus.idle,
      recheckingItemId = null,
      recheckResult = null;

  final ScenarioTransitPickerMode mode;
  final ScenarioTransitPickerStatus initializationStatus;
  final ScenarioTransitPickerStatus refreshStatus;
  final ScenarioTransitPickerStatus originSearchStatus;
  final ScenarioTransitPickerStatus destinationSearchStatus;
  final ScenarioTransitPickerStatus serviceSearchStatus;
  final List<ScenarioTransitProviderDescriptor> providers;
  final Map<String, ScenarioTransitCacheInspection> cacheInspections;
  final String? selectedProviderCode;
  final String? refreshingProviderCode;
  final String originQuery;
  final String destinationQuery;
  final List<ScenarioTransitStop> originResults;
  final List<ScenarioTransitStop> destinationResults;
  final ScenarioTransitStop? origin;
  final ScenarioTransitStop? destination;
  final ScenarioTransitLocalDate? serviceDate;
  final ScenarioTransitTime departAfter;
  final List<ScenarioTransitServiceOption> serviceOptions;
  final ScenarioTransitServiceOption? selectedService;
  final ScenarioTransitPickerFailureCode? failureCode;
  final ScenarioTransitPickerRetryAction retryAction;
  final ScenarioTransitPickerStatus recheckStatus;
  final String? recheckingItemId;
  final ScenarioTransitRecheckResult? recheckResult;

  ScenarioTransitCacheInspection? get selectedCache =>
      cacheInspections[selectedProviderCode];

  bool get canSearchServices =>
      mode == ScenarioTransitPickerMode.official &&
      selectedCache?.isUsable == true &&
      origin != null &&
      destination != null &&
      origin!.providerCode == selectedProviderCode &&
      destination!.providerCode == selectedProviderCode &&
      origin!.id != destination!.id &&
      serviceDate?.isValid == true;

  ScenarioTransitPickerState copyWith({
    ScenarioTransitPickerMode? mode,
    ScenarioTransitPickerStatus? initializationStatus,
    ScenarioTransitPickerStatus? refreshStatus,
    ScenarioTransitPickerStatus? originSearchStatus,
    ScenarioTransitPickerStatus? destinationSearchStatus,
    ScenarioTransitPickerStatus? serviceSearchStatus,
    List<ScenarioTransitProviderDescriptor>? providers,
    Map<String, ScenarioTransitCacheInspection>? cacheInspections,
    String? selectedProviderCode,
    bool clearSelectedProviderCode = false,
    String? refreshingProviderCode,
    bool clearRefreshingProviderCode = false,
    String? originQuery,
    String? destinationQuery,
    List<ScenarioTransitStop>? originResults,
    List<ScenarioTransitStop>? destinationResults,
    ScenarioTransitStop? origin,
    bool clearOrigin = false,
    ScenarioTransitStop? destination,
    bool clearDestination = false,
    ScenarioTransitLocalDate? serviceDate,
    bool clearServiceDate = false,
    ScenarioTransitTime? departAfter,
    List<ScenarioTransitServiceOption>? serviceOptions,
    ScenarioTransitServiceOption? selectedService,
    bool clearSelectedService = false,
    ScenarioTransitPickerFailureCode? failureCode,
    bool clearFailureCode = false,
    ScenarioTransitPickerRetryAction? retryAction,
    ScenarioTransitPickerStatus? recheckStatus,
    String? recheckingItemId,
    bool clearRecheckingItemId = false,
    ScenarioTransitRecheckResult? recheckResult,
    bool clearRecheckResult = false,
  }) => ScenarioTransitPickerState(
    mode: mode ?? this.mode,
    initializationStatus: initializationStatus ?? this.initializationStatus,
    refreshStatus: refreshStatus ?? this.refreshStatus,
    originSearchStatus: originSearchStatus ?? this.originSearchStatus,
    destinationSearchStatus:
        destinationSearchStatus ?? this.destinationSearchStatus,
    serviceSearchStatus: serviceSearchStatus ?? this.serviceSearchStatus,
    providers: List<ScenarioTransitProviderDescriptor>.unmodifiable(
      providers ?? this.providers,
    ),
    cacheInspections: Map<String, ScenarioTransitCacheInspection>.unmodifiable(
      cacheInspections ?? this.cacheInspections,
    ),
    selectedProviderCode: clearSelectedProviderCode
        ? null
        : (selectedProviderCode ?? this.selectedProviderCode),
    refreshingProviderCode: clearRefreshingProviderCode
        ? null
        : (refreshingProviderCode ?? this.refreshingProviderCode),
    originQuery: originQuery ?? this.originQuery,
    destinationQuery: destinationQuery ?? this.destinationQuery,
    originResults: List<ScenarioTransitStop>.unmodifiable(
      originResults ?? this.originResults,
    ),
    destinationResults: List<ScenarioTransitStop>.unmodifiable(
      destinationResults ?? this.destinationResults,
    ),
    origin: clearOrigin ? null : (origin ?? this.origin),
    destination: clearDestination ? null : (destination ?? this.destination),
    serviceDate: clearServiceDate ? null : (serviceDate ?? this.serviceDate),
    departAfter: departAfter ?? this.departAfter,
    serviceOptions: List<ScenarioTransitServiceOption>.unmodifiable(
      serviceOptions ?? this.serviceOptions,
    ),
    selectedService: clearSelectedService
        ? null
        : (selectedService ?? this.selectedService),
    failureCode: clearFailureCode ? null : (failureCode ?? this.failureCode),
    retryAction: retryAction ?? this.retryAction,
    recheckStatus: recheckStatus ?? this.recheckStatus,
    recheckingItemId: clearRecheckingItemId
        ? null
        : (recheckingItemId ?? this.recheckingItemId),
    recheckResult: clearRecheckResult
        ? null
        : (recheckResult ?? this.recheckResult),
  );
}
