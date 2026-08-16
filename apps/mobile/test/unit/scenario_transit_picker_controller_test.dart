import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/controllers/scenario_transit_picker_controller.dart';
import 'package:recharge/features/create/application/scenario_transit_picker_config.dart';
import 'package:recharge/features/create/application/scenario_transit_schedule_coordinator.dart';
import 'package:recharge/features/create/application/state/scenario_transit_picker_state.dart';
import 'package:recharge/features/create/domain/entities/scenario_transit_schedule.dart';
import 'package:recharge/features/create/domain/repositories/scenario_transit_schedule_repository.dart';

void main() {
  late _FakeTransitRepository repository;
  late ScenarioTransitPickerController controller;

  setUp(() {
    repository = _FakeTransitRepository();
    controller = ScenarioTransitPickerController(
      coordinator: ScenarioTransitScheduleCoordinator(repository: repository),
      config: const ScenarioTransitPickerConfig(
        stopSearchDebounce: Duration.zero,
      ),
    );
  });

  tearDown(() {
    controller.dispose();
  });

  test('initialize reads cache states without starting a download', () async {
    repository.inspections = <String, ScenarioTransitCacheInspection>{
      'provider-a': _inspection('provider-a', ScenarioTransitCacheStatus.stale),
      'provider-b': const ScenarioTransitCacheInspection(
        providerCode: 'provider-b',
        status: ScenarioTransitCacheStatus.corrupt,
      ),
    };

    await controller.initialize();

    expect(repository.refreshCalls, isEmpty);
    expect(
      controller.state.initializationStatus,
      ScenarioTransitPickerStatus.ready,
    );
    expect(controller.state.mode, ScenarioTransitPickerMode.manual);
    expect(controller.state.selectedProviderCode, 'provider-a');
    expect(
      controller.state.cacheInspections['provider-a']?.status,
      ScenarioTransitCacheStatus.stale,
    );
    expect(
      controller.state.cacheInspections['provider-b']?.status,
      ScenarioTransitCacheStatus.corrupt,
    );
  });

  test('picker kill switch blocks refresh and preserves cached data', () async {
    controller.dispose();
    controller = ScenarioTransitPickerController(
      coordinator: ScenarioTransitScheduleCoordinator(repository: repository),
      config: const ScenarioTransitPickerConfig(
        networkRefreshEnabled: false,
        stopSearchDebounce: Duration.zero,
      ),
    );
    await controller.initialize();

    expect(await controller.refreshProvider('provider-a'), isFalse);

    expect(repository.refreshCalls, isEmpty);
    expect(
      controller.state.failureCode,
      ScenarioTransitPickerFailureCode.networkDisabled,
    );
    expect(controller.state.cacheInspections['provider-a']?.isUsable, isTrue);
  });

  test(
    'global picker rollback switch fails closed without repository calls',
    () async {
      controller.dispose();
      controller = ScenarioTransitPickerController(
        coordinator: ScenarioTransitScheduleCoordinator(repository: repository),
        config: const ScenarioTransitPickerConfig(
          pickerEnabled: false,
          stopSearchDebounce: Duration.zero,
        ),
      );

      await controller.initialize();

      expect(repository.inspectionCalls, isEmpty);
      expect(repository.refreshCalls, isEmpty);
      expect(
        controller.state.failureCode,
        ScenarioTransitPickerFailureCode.pickerDisabled,
      );
    },
  );

  test('late stop result cannot overwrite a newer query', () async {
    final oldResult = Completer<List<ScenarioTransitStop>>();
    final newResult = Completer<List<ScenarioTransitStop>>();
    repository.stopSearch =
        ({required query, required providerCodes, required limit}) {
          return query == 'Old' ? oldResult.future : newResult.future;
        };
    await controller.initialize();
    controller.useOfficialSchedule();

    final oldSearch = controller.searchOriginNow('Old');
    final newSearch = controller.searchOriginNow('New');
    newResult.complete(<ScenarioTransitStop>[_stop('new-stop', 'New station')]);
    await newSearch;
    oldResult.complete(<ScenarioTransitStop>[_stop('old-stop', 'Old station')]);
    await oldSearch;

    expect(controller.state.originQuery, 'New');
    expect(controller.state.originResults.single.id, 'new-stop');
  });

  test('destination results are restricted to the selected provider', () async {
    repository.stopSearch =
        ({required query, required providerCodes, required limit}) async =>
            <ScenarioTransitStop>[
              _stop('right', 'Right provider'),
              const ScenarioTransitStop(
                providerCode: 'provider-b',
                id: 'wrong',
                name: 'Wrong provider',
              ),
            ];
    await controller.initialize();
    controller.useOfficialSchedule();

    await controller.searchDestinationNow('Station');

    expect(controller.state.destinationResults, hasLength(1));
    expect(controller.state.destinationResults.single.id, 'right');
  });

  test(
    'service search carries exact provider, date and depart-after',
    () async {
      final origin = _stop('origin', 'Origin');
      final destination = _stop('destination', 'Destination');
      repository.serviceResult = ScenarioTransitSearchResult(
        options: <ScenarioTransitServiceOption>[
          _service(origin: origin, destination: destination),
        ],
        loadedProviders: const <String>{'provider-a'},
        unavailableProviders: const <String>{},
      );
      await controller.initialize();
      controller.useOfficialSchedule();
      controller.selectOrigin(origin);
      controller.selectDestination(destination);
      controller.setServiceDate(const ScenarioTransitLocalDate(2026, 8, 3));
      controller.setDepartAfter(const ScenarioTransitTime(9 * 3600));

      await controller.searchServices();

      expect(repository.lastServiceQuery?.providerCodes, <String>{
        'provider-a',
      });
      expect(repository.lastServiceQuery?.originStopId, 'origin');
      expect(repository.lastServiceQuery?.destinationStopId, 'destination');
      expect(repository.lastServiceQuery?.serviceDate.iso8601, '2026-08-03');
      expect(
        repository.lastServiceQuery?.departAfter.secondsFromServiceDay,
        9 * 3600,
      );
      expect(
        controller.state.serviceSearchStatus,
        ScenarioTransitPickerStatus.ready,
      );
      expect(
        controller.selectService(controller.state.serviceOptions.single),
        isTrue,
      );
    },
  );

  test(
    'offline refresh is retryable and never removes cached fallback',
    () async {
      await controller.initialize();
      repository.refreshError = const ScenarioTransitScheduleException(
        code: ScenarioTransitScheduleFailureCode.offline,
        providerCode: 'provider-a',
      );

      expect(await controller.refreshProvider('provider-a'), isFalse);
      expect(
        controller.state.failureCode,
        ScenarioTransitPickerFailureCode.offline,
      );
      expect(
        controller.state.retryAction,
        ScenarioTransitPickerRetryAction.refresh,
      );
      expect(controller.state.cacheInspections['provider-a']?.isUsable, isTrue);

      repository.refreshError = null;
      await controller.retry();

      expect(controller.state.refreshStatus, ScenarioTransitPickerStatus.ready);
      expect(controller.state.failureCode, isNull);
      expect(repository.refreshCalls, <String>['provider-a', 'provider-a']);
    },
  );

  test(
    'manual fallback clears transient search without touching cache',
    () async {
      await controller.initialize();
      controller.useOfficialSchedule();
      controller.selectOrigin(_stop('origin', 'Origin'));
      controller.setServiceDate(const ScenarioTransitLocalDate(2026, 8, 3));

      controller.useManualEntry();

      expect(controller.state.mode, ScenarioTransitPickerMode.manual);
      expect(controller.state.origin, isNull);
      expect(controller.state.serviceDate?.iso8601, '2026-08-03');
      expect(controller.state.serviceOptions, isEmpty);
      expect(controller.state.cacheInspections['provider-a']?.isUsable, isTrue);
    },
  );

  test('dispose ignores an in-flight stop search completion', () async {
    final pending = Completer<List<ScenarioTransitStop>>();
    repository.stopSearch =
        ({required query, required providerCodes, required limit}) =>
            pending.future;
    await controller.initialize();
    controller.useOfficialSchedule();

    final search = controller.searchOriginNow('Pending');
    controller.dispose();
    pending.complete(<ScenarioTransitStop>[_stop('late', 'Late')]);

    await expectLater(search, completes);
    controller = ScenarioTransitPickerController(
      coordinator: ScenarioTransitScheduleCoordinator(repository: repository),
    );
  });
}

ScenarioTransitStop _stop(String id, String name) =>
    ScenarioTransitStop(providerCode: 'provider-a', id: id, name: name);

ScenarioTransitServiceOption _service({
  required ScenarioTransitStop origin,
  required ScenarioTransitStop destination,
}) => ScenarioTransitServiceOption(
  providerCode: 'provider-a',
  serviceDate: const ScenarioTransitLocalDate(2026, 8, 3),
  tripId: 'trip-1',
  routeId: 'route-1',
  serviceId: 'weekday',
  mode: ScenarioTransitMode.bus,
  origin: origin,
  destination: destination,
  departure: const ScenarioTransitTime(10 * 3600),
  arrival: const ScenarioTransitTime(11 * 3600),
  manifest: _manifest('provider-a'),
);

ScenarioTransitCacheInspection _inspection(
  String providerCode,
  ScenarioTransitCacheStatus status,
) => ScenarioTransitCacheInspection(
  providerCode: providerCode,
  status: status,
  manifest: _manifest(
    providerCode,
    freshness: status == ScenarioTransitCacheStatus.stale
        ? ScenarioTransitFreshness.stale
        : ScenarioTransitFreshness.current,
  ),
);

ScenarioTransitFeedManifest _manifest(
  String providerCode, {
  ScenarioTransitFreshness freshness = ScenarioTransitFreshness.current,
}) => ScenarioTransitFeedManifest(
  providerCode: providerCode,
  providerDisplayName: providerCode == 'provider-a'
      ? 'Provider A'
      : 'Provider B',
  licenseName: 'CC0 1.0',
  sourceUrl: 'https://example.test/$providerCode.zip',
  retrievedAtUtc: DateTime.utc(2026, 8, 3, 8),
  sha256: 'a' * 64,
  freshness: freshness,
);

typedef _StopSearch =
    Future<List<ScenarioTransitStop>> Function({
      required String query,
      required Set<String> providerCodes,
      required int limit,
    });

class _FakeTransitRepository implements ScenarioTransitScheduleRepository {
  @override
  final List<ScenarioTransitProviderDescriptor> providers =
      const <ScenarioTransitProviderDescriptor>[
        ScenarioTransitProviderDescriptor(
          code: 'provider-a',
          displayName: 'Provider A',
          licenseName: 'CC0 1.0',
          sourceUrl: 'https://example.test/a.zip',
          refreshEnabled: true,
        ),
        ScenarioTransitProviderDescriptor(
          code: 'provider-b',
          displayName: 'Provider B',
          licenseName: 'CC0 1.0',
          sourceUrl: 'https://example.test/b.zip',
          refreshEnabled: true,
        ),
      ];

  Map<String, ScenarioTransitCacheInspection> inspections =
      <String, ScenarioTransitCacheInspection>{
        'provider-a': _inspection(
          'provider-a',
          ScenarioTransitCacheStatus.current,
        ),
        'provider-b': const ScenarioTransitCacheInspection(
          providerCode: 'provider-b',
          status: ScenarioTransitCacheStatus.missing,
        ),
      };
  final List<String> refreshCalls = <String>[];
  final List<String> inspectionCalls = <String>[];
  ScenarioTransitScheduleException? refreshError;
  _StopSearch? stopSearch;
  ScenarioTransitSearchQuery? lastServiceQuery;
  ScenarioTransitSearchResult serviceResult = const ScenarioTransitSearchResult(
    options: <ScenarioTransitServiceOption>[],
    loadedProviders: <String>{'provider-a'},
    unavailableProviders: <String>{},
  );

  @override
  Future<ScenarioTransitCacheInspection> inspectCache(
    String providerCode,
  ) async {
    inspectionCalls.add(providerCode);
    return inspections[providerCode] ??
        ScenarioTransitCacheInspection(
          providerCode: providerCode,
          status: ScenarioTransitCacheStatus.missing,
        );
  }

  @override
  Future<ScenarioTransitFeedManifest?> loadLastKnownGood(
    String providerCode,
  ) async => inspections[providerCode]?.manifest;

  @override
  Future<ScenarioTransitFeedManifest> refreshProvider(
    String providerCode,
  ) async {
    refreshCalls.add(providerCode);
    final error = refreshError;
    if (error != null) throw error;
    final manifest = _manifest(providerCode);
    inspections = <String, ScenarioTransitCacheInspection>{
      ...inspections,
      providerCode: ScenarioTransitCacheInspection(
        providerCode: providerCode,
        status: ScenarioTransitCacheStatus.current,
        manifest: manifest,
      ),
    };
    return manifest;
  }

  @override
  Future<ScenarioTransitSearchResult> searchServices(
    ScenarioTransitSearchQuery query,
  ) async {
    lastServiceQuery = query;
    return serviceResult;
  }

  @override
  Future<List<ScenarioTransitStop>> searchStops({
    required String query,
    Set<String> providerCodes = const <String>{},
    int limit = 20,
  }) async {
    final handler = stopSearch;
    if (handler != null) {
      return handler(query: query, providerCodes: providerCodes, limit: limit);
    }
    return <ScenarioTransitStop>[];
  }
}
