import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/controllers/scenario_transit_picker_controller.dart';
import 'package:recharge/features/create/application/scenario_transit_picker_config.dart';
import 'package:recharge/features/create/application/scenario_transit_schedule_coordinator.dart';
import 'package:recharge/features/create/domain/entities/scenario_transit_schedule.dart';
import 'package:recharge/features/create/domain/repositories/scenario_transit_schedule_repository.dart';
import 'package:recharge/features/create/presentation/widgets/scenario/scenario_transit_schedule_picker_sheet.dart';

void main() {
  late _FakeTransitRepository repository;
  late ScenarioTransitPickerController controller;

  setUp(() {
    repository = _FakeTransitRepository();
    controller = ScenarioTransitPickerController(
      coordinator: ScenarioTransitScheduleCoordinator(repository: repository),
      config: const ScenarioTransitPickerConfig(
        pickerEnabled: true,
        stopSearchDebounce: Duration.zero,
      ),
    );
  });

  tearDown(() => controller.dispose());

  testWidgets(
    'opens from cache without network and requires a date for templates',
    (WidgetTester tester) async {
      final semantics = tester.ensureSemantics();
      await _setPhoneViewport(tester);
      await _openPicker(tester, controller: controller, textScale: 1.5);

      expect(
        find.text(
          'Planned schedule · not live. Delays, tickets, fares, seats '
          'and transfers are not confirmed. Recheck before travel.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('scenario-transit-date-required')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(
                const ValueKey<String>('scenario-transit-search-services'),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(repository.refreshCalls, isEmpty);
      expect(tester.takeException(), isNull);

      semantics.dispose();
    },
  );

  testWidgets('selects a direct service and returns an explicit Apply intent', (
    WidgetTester tester,
  ) async {
    final origin = _stop('origin', 'Riga Central');
    final destination = _stop('destination', 'Sigulda');
    repository
      ..stopResults = <ScenarioTransitStop>[origin, destination]
      ..serviceResult = ScenarioTransitSearchResult(
        options: <ScenarioTransitServiceOption>[
          _service(origin: origin, destination: destination),
        ],
        loadedProviders: const <String>{'provider-a'},
        unavailableProviders: const <String>{},
      );
    var scenarioMutationCount = 0;
    ScenarioTransitPickerSheetResult? result;

    await _setPhoneViewport(tester);
    await _openPicker(
      tester,
      controller: controller,
      initialServiceDate: const ScenarioTransitLocalDate(2026, 8, 3),
      initialDepartAfter: const ScenarioTransitTime(9 * 3600),
      dateLocked: true,
      onResult: (value) => result = value,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('scenario-transit-origin-query')),
      'Riga',
    );
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(
        const ValueKey<String>('scenario-transit-origin-result-origin'),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('scenario-transit-destination-query')),
      'Sigulda',
    );
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(
        const ValueKey<String>(
          'scenario-transit-destination-result-destination',
        ),
      ),
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey<String>('scenario-transit-search-services')),
    );
    await _tapVisible(
      tester,
      find.byKey(
        const ValueKey<String>('scenario-transit-service-provider-a-trip-1'),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('scenario-transit-selected-preview')),
      findsOneWidget,
    );
    expect(find.text('Freshness: current'), findsOneWidget);
    expect(
      find.textContaining('This selection is not yet applied'),
      findsOneWidget,
    );

    await _tapVisible(
      tester,
      find.byKey(const ValueKey<String>('scenario-transit-apply')),
    );

    expect(result, ScenarioTransitPickerSheetResult.apply);
    expect(controller.state.selectedService?.tripId, 'trip-1');
    expect(scenarioMutationCount, 0);
    expect(repository.lastServiceQuery?.originStopId, 'origin');
    expect(repository.lastServiceQuery?.destinationStopId, 'destination');
    expect(repository.lastServiceQuery?.serviceDate.iso8601, '2026-08-03');
  });

  testWidgets('offline update keeps stale cache available', (
    WidgetTester tester,
  ) async {
    repository
      ..inspection = _inspection(ScenarioTransitCacheStatus.stale)
      ..refreshError = const ScenarioTransitScheduleException(
        code: ScenarioTransitScheduleFailureCode.offline,
        providerCode: 'provider-a',
      );

    await _setPhoneViewport(tester);
    await _openPicker(
      tester,
      controller: controller,
      initialServiceDate: const ScenarioTransitLocalDate(2026, 8, 3),
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey<String>('scenario-transit-update')),
    );

    expect(
      find.byKey(const ValueKey<String>('scenario-transit-failure')),
      findsOneWidget,
    );
    expect(find.textContaining('offline'), findsOneWidget);
    expect(find.text('Use cached'), findsOneWidget);
    expect(repository.refreshCalls, <String>['provider-a']);
    expect(controller.state.selectedCache?.isUsable, isTrue);
  });
}

Future<void> _setPhoneViewport(WidgetTester tester) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(360, 800);
  addTearDown(tester.view.reset);
}

Future<void> _openPicker(
  WidgetTester tester, {
  required ScenarioTransitPickerController controller,
  ScenarioTransitLocalDate? initialServiceDate,
  ScenarioTransitTime? initialDepartAfter,
  bool dateLocked = false,
  double textScale = 1,
  ValueChanged<ScenarioTransitPickerSheetResult?>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  final result = await showScenarioTransitSchedulePicker(
                    context,
                    controller: controller,
                    initialServiceDate: initialServiceDate,
                    initialDepartAfter: initialDepartAfter,
                    dateLocked: dateLocked,
                  );
                  onResult?.call(result);
                },
                child: const Text('Open picker'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open picker'));
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

ScenarioTransitStop _stop(String id, String name) => ScenarioTransitStop(
  providerCode: 'provider-a',
  id: id,
  name: name,
  latitude: id == 'origin' ? 56.9463 : 57.1537,
  longitude: id == 'origin' ? 24.1204 : 24.8538,
);

ScenarioTransitServiceOption _service({
  required ScenarioTransitStop origin,
  required ScenarioTransitStop destination,
}) => ScenarioTransitServiceOption(
  providerCode: 'provider-a',
  serviceDate: const ScenarioTransitLocalDate(2026, 8, 3),
  tripId: 'trip-1',
  routeId: 'route-1',
  serviceId: 'weekday',
  mode: ScenarioTransitMode.train,
  origin: origin,
  destination: destination,
  departure: const ScenarioTransitTime(10 * 3600),
  arrival: const ScenarioTransitTime(11 * 3600),
  manifest: _manifest(ScenarioTransitFreshness.current),
  agencyName: 'Vivi',
  routeLabel: 'Riga–Sigulda',
);

ScenarioTransitCacheInspection _inspection(ScenarioTransitCacheStatus status) =>
    ScenarioTransitCacheInspection(
      providerCode: 'provider-a',
      status: status,
      manifest: _manifest(
        status == ScenarioTransitCacheStatus.stale
            ? ScenarioTransitFreshness.stale
            : ScenarioTransitFreshness.current,
      ),
    );

ScenarioTransitFeedManifest _manifest(ScenarioTransitFreshness freshness) =>
    ScenarioTransitFeedManifest(
      providerCode: 'provider-a',
      providerDisplayName: 'Provider A',
      licenseName: 'CC0 1.0',
      sourceUrl: 'https://example.test/a.zip',
      retrievedAtUtc: DateTime.utc(2026, 8, 3, 8),
      sha256: 'a' * 64,
      freshness: freshness,
    );

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
      ];

  ScenarioTransitCacheInspection inspection = _inspection(
    ScenarioTransitCacheStatus.current,
  );
  ScenarioTransitScheduleException? refreshError;
  List<ScenarioTransitStop> stopResults = <ScenarioTransitStop>[];
  ScenarioTransitSearchResult serviceResult = const ScenarioTransitSearchResult(
    options: <ScenarioTransitServiceOption>[],
    loadedProviders: <String>{'provider-a'},
    unavailableProviders: <String>{},
  );
  final List<String> refreshCalls = <String>[];
  ScenarioTransitSearchQuery? lastServiceQuery;

  @override
  Future<ScenarioTransitCacheInspection> inspectCache(
    String providerCode,
  ) async => inspection;

  @override
  Future<ScenarioTransitFeedManifest?> loadLastKnownGood(
    String providerCode,
  ) async => inspection.manifest;

  @override
  Future<ScenarioTransitFeedManifest> refreshProvider(
    String providerCode,
  ) async {
    refreshCalls.add(providerCode);
    final error = refreshError;
    if (error != null) throw error;
    final manifest = _manifest(ScenarioTransitFreshness.current);
    inspection = ScenarioTransitCacheInspection(
      providerCode: providerCode,
      status: ScenarioTransitCacheStatus.current,
      manifest: manifest,
    );
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
  }) async => stopResults
      .where((stop) => stop.name.toLowerCase().contains(query.toLowerCase()))
      .take(limit)
      .toList(growable: false);
}
