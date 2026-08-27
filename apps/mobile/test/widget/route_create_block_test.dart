import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/geo/geo_bounds.dart';
import 'package:recharge/core/geo/geo_point.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/core/map/map_scene.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/controllers/route_gpx_transfer_controller.dart';
import 'package:recharge/features/create/application/controllers/route_recording_controller.dart';
import 'package:recharge/features/create/application/create_providers.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/application/route_create_config.dart';
import 'package:recharge/features/create/application/route_create_coordinator.dart';
import 'package:recharge/features/create/application/route_create_runtime.dart';
import 'package:recharge/features/create/application/route_draft_autosave_coordinator.dart';
import 'package:recharge/features/create/application/state/route_recording_state.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/route_draft_data.dart';
import 'package:recharge/features/create/domain/entities/route_draft_save_result.dart';
import 'package:recharge/features/create/domain/entities/route_recording_data.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/repositories/route_gpx_file_picker_port.dart';
import 'package:recharge/features/create/domain/repositories/route_gpx_repository.dart';
import 'package:recharge/features/create/domain/repositories/route_gpx_source_store.dart';
import 'package:recharge/features/create/domain/repositories/route_draft_persistence_repository.dart';
import 'package:recharge/features/create/domain/repositories/route_routing_repository.dart';
import 'package:recharge/features/create/domain/repositories/route_location_recording_port.dart';
import 'package:recharge/features/create/domain/repositories/route_recording_journal_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/export_route_gpx_usecase.dart';
import 'package:recharge/features/create/domain/usecases/inspect_route_gpx_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/create/presentation/widgets/route/route_create_block.dart';
import 'package:recharge/features/create/presentation/widgets/route/route_recording_panel.dart';
import 'package:recharge/features/create/data/datasources/route_gpx_memory_source_store.dart';
import 'package:recharge/features/create/data/gpx/route_gpx_exporter.dart';
import 'package:recharge/features/create/data/gpx/route_gpx_importer.dart';
import 'package:recharge/features/create/data/gpx/route_gpx_inspector.dart';
import 'package:recharge/features/create/data/repositories/route_gpx_repository_impl.dart';

import '../support/event_create_test_support.dart';

void main() {
  testWidgets('Route method step has a stable phone visual baseline', (
    WidgetTester tester,
  ) async {
    await _setPhoneViewport(tester);
    final fixture = await _RouteWidgetFixture.create(_MemoryRepository());
    addTearDown(fixture.dispose);

    await tester.pumpWidget(fixture.app());
    await tester.pumpAndSettle();

    final surface = find.byKey(
      const ValueKey<String>('route-create-golden-surface'),
    );
    expect(tester.getSize(surface), const Size(366, 1216));
    final goldenPath = Platform.isWindows
        ? 'goldens/route_create_block_method_windows.png'
        : 'goldens/route_create_block_method.png';
    await expectLater(surface, matchesGoldenFile(goldenPath));
    await tester.pumpWidget(const SizedBox.shrink());
    await fixture.dispose();
  });

  testWidgets(
    'points flow edits one continuous track and restores the saved revision',
    (WidgetTester tester) async {
      await _setPhoneViewport(tester);
      final repository = _MemoryRepository();
      final fixture = await _RouteWidgetFixture.create(repository);
      addTearDown(fixture.dispose);

      await tester.pumpWidget(fixture.app());
      await tester.pumpAndSettle();
      fixture.controller.goToRouteStep(2);
      await tester.pumpAndSettle();

      await _enterAnchor(tester, latitude: '56.9700', longitude: '24.1300');
      await _enterAnchor(tester, latitude: '56.9710', longitude: '24.1310');

      expect(fixture.route.anchors, hasLength(2));
      expect(fixture.route.segments, hasLength(1));
      expect(fixture.route.segments.single.geometry.points.length, 3);

      final anchorMenus = find.byTooltip('Anchor actions');
      await tester.ensureVisible(anchorMenus.first);
      await tester.tap(anchorMenus.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add viewpoint').last);
      await tester.pumpAndSettle();
      expect(fixture.route.waypoints, hasLength(1));

      await _tapVisible(tester, find.text('Undo'));
      expect(fixture.route.waypoints, isEmpty);
      await _tapVisible(tester, find.text('Redo'));
      expect(fixture.route.waypoints, hasLength(1));

      final savedHash = _geometryFingerprint(fixture.route);
      final savedRevision = fixture.route.revision;
      await fixture.controller.saveDraft();
      await tester.pumpAndSettle();
      expect(repository.stored?.routeData?.revision, savedRevision);

      await _enterAnchor(tester, latitude: '56.9720', longitude: '24.1320');
      expect(fixture.route.anchors, hasLength(3));
      await _tapVisible(tester, find.text('Last saved'));

      expect(fixture.route.anchors, hasLength(2));
      expect(_geometryFingerprint(fixture.route), savedHash);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await fixture.dispose();
    },
  );

  testWidgets(
    'freehand flow is accessible at large text and saves exact geometry',
    (WidgetTester tester) async {
      await _setPhoneViewport(tester);
      final semantics = tester.ensureSemantics();
      final repository = _MemoryRepository();
      final fixture = await _RouteWidgetFixture.create(repository);
      addTearDown(fixture.dispose);

      await tester.pumpWidget(fixture.app(textScale: 1.5));
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.text('Freehand'));
      fixture.controller.goToRouteStep(2);
      await tester.pumpAndSettle();

      final canvas = find.byKey(const ValueKey<String>('route-map-canvas'));
      await tester.ensureVisible(canvas);
      expect(
        tester.getSemantics(canvas).label,
        contains('Draw a continuous route with one finger'),
      );
      final origin = tester.getTopLeft(canvas);
      final gesture = await tester.startGesture(origin + const Offset(35, 55));
      await gesture.moveBy(const Offset(55, 25));
      await tester.pump();
      await gesture.moveBy(const Offset(60, 20));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(fixture.route.creationMethod, RouteCreationMethod.freehand);
      expect(fixture.route.anchors, hasLength(2));
      expect(fixture.route.segments, hasLength(1));
      expect(
        fixture.route.segments.single.geometry.points.length,
        greaterThanOrEqualTo(2),
      );

      fixture.controller.goToRouteStep(4);
      await tester.pumpAndSettle();
      expect(find.text('Submit Route for review'), findsOneWidget);
      await _tapVisible(
        tester,
        find.byKey(const ValueKey<String>('route-save-draft')),
      );
      expect(
        _geometryFingerprint(repository.stored!.routeData!),
        _geometryFingerprint(fixture.route),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await fixture.dispose();
      semantics.dispose();
    },
  );

  testWidgets('persisted Route draft is recovered by a new runtime', (
    WidgetTester tester,
  ) async {
    await _setPhoneViewport(tester);
    final repository = _MemoryRepository();
    final first = await _RouteWidgetFixture.create(repository);

    await tester.pumpWidget(first.app());
    await tester.pumpAndSettle();
    first.controller.goToRouteStep(2);
    await tester.pumpAndSettle();
    await _enterAnchor(tester, latitude: '56.9700', longitude: '24.1300');
    await _enterAnchor(tester, latitude: '56.9710', longitude: '24.1310');
    await first.controller.saveDraft();
    final persistedHash = _geometryFingerprint(first.route);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await first.dispose();

    final second = await _RouteWidgetFixture.create(repository);
    addTearDown(second.dispose);
    await tester.pumpWidget(second.app());
    await tester.pumpAndSettle();

    expect(second.route.anchors, hasLength(2));
    expect(second.route.segments, hasLength(1));
    expect(_geometryFingerprint(second.route), persistedHash);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await second.dispose();
  });

  testWidgets('GPX preview imports one inspected track', (
    WidgetTester tester,
  ) async {
    await _setPhoneViewport(tester);
    final fixture = await _RouteWidgetFixture.create(_MemoryRepository());
    addTearDown(fixture.dispose);

    await tester.pumpWidget(fixture.app());
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Import GPX'));

    expect(find.text('investor-demo.gpx'), findsOneWidget);
    expect(find.textContaining('2 points'), findsWidgets);
    await _tapVisible(
      tester,
      find.byKey(const ValueKey<String>('route-gpx-import-confirm')),
    );

    expect(fixture.route.creationMethod, RouteCreationMethod.importedGpx);
    expect(fixture.route.segments, hasLength(1));
    expect(fixture.route.segments.single.geometry.points, hasLength(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await fixture.dispose();
  });

  testWidgets('GPS recording previews and applies a continuous track', (
    WidgetTester tester,
  ) async {
    await _setPhoneViewport(tester);
    final fixture = await _RouteWidgetFixture.create(_MemoryRepository());
    addTearDown(fixture.dispose);

    await tester.pumpWidget(fixture.app());
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Record with GPS'));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey<String>('route-gps-start')),
    );

    fixture.recordingLocation.emit(_gpsSample(0, 56.9700, 24.1300));
    fixture.recordingLocation.emit(_gpsSample(5000, 56.9702, 24.1302));
    await tester.pumpAndSettle();
    expect(fixture.recordingController.state.sampleCount, 2);
    expect(
      fixture.recordingController.state.status,
      RouteRecordingStatus.recording,
    );
    final finishButton = find.byKey(const ValueKey<String>('route-gps-finish'));
    await tester.ensureVisible(finishButton);
    tester.widget<FilledButton>(finishButton).onPressed!();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();

    expect(
      fixture.recordingController.state.status,
      RouteRecordingStatus.completed,
    );
    expect(fixture.recordingController.state.preview, isNotNull);
    expect(find.text('Review recorded track'), findsOneWidget);
    expect(find.byType(RouteRecordingPreviewMap), findsOneWidget);
    final applyButton = find.byKey(const ValueKey<String>('route-gps-apply'));
    await tester.ensureVisible(applyButton);
    tester.widget<FilledButton>(applyButton).onPressed!();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();

    expect(fixture.route.creationMethod, RouteCreationMethod.recordedGps);
    expect(fixture.route.segments, hasLength(1));
    expect(fixture.route.segments.single.geometry.points, hasLength(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await fixture.dispose();
  });
}

Future<void> _setPhoneViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _enterAnchor(
  WidgetTester tester, {
  required String latitude,
  required String longitude,
}) async {
  await tester.enterText(
    find.byKey(const ValueKey<String>('route-anchor-latitude')),
    latitude,
  );
  await tester.enterText(
    find.byKey(const ValueKey<String>('route-anchor-longitude')),
    longitude,
  );
  await _tapVisible(
    tester,
    find.byKey(const ValueKey<String>('route-add-anchor-coordinates')),
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

String _geometryFingerprint(RouteDraftData route) => route.orderedSegments
    .map((segment) => segment.geometry.geometryHash)
    .join('|');

class _RouteWidgetFixture {
  _RouteWidgetFixture({
    required this.controller,
    required this.runtime,
    required this.gpxTransfer,
    required this.recordingController,
    required this.recordingLocation,
    required this.containerKey,
  });

  final CreateController controller;
  final RouteCreateRuntime runtime;
  final RouteGpxTransferController gpxTransfer;
  final RouteRecordingController recordingController;
  final _TestLocationPort recordingLocation;
  final GlobalKey containerKey;
  bool _disposed = false;

  RouteDraftData get route => controller.routeCreateState!.route;

  static Future<_RouteWidgetFixture> create(
    _MemoryRepository repository,
  ) async {
    const gpxConfig = RouteGpxImportConfig();
    const gpxInspector = RouteGpxInspector(config: gpxConfig);
    final gpxSourceStore = RouteGpxMemorySourceStore(
      idGenerator: _SequenceIdGenerator(),
      config: gpxConfig,
    );
    final gpxRepository = RouteGpxRepositoryImpl(
      sourceStore: gpxSourceStore,
      inspector: gpxInspector,
      importer: const RouteGpxImporter(inspector: gpxInspector),
      exporter: const RouteGpxExporter(),
      clock: () => DateTime.utc(2026, 7, 25, 12),
    );
    final gpxTransfer = RouteGpxTransferController(
      filePicker: _TestGpxFilePicker(gpxSourceStore),
      repository: gpxRepository,
      inspectGpx: InspectRouteGpxUseCase(gpxRepository),
      exportGpx: ExportRouteGpxUseCase(gpxRepository),
    );
    final recordingLocation = _TestLocationPort();
    final recordingController = RouteRecordingController(
      idGenerator: _SequenceIdGenerator(),
      location: recordingLocation,
      journalRepository: _TestRecordingJournalRepository(),
      clock: () => DateTime.utc(2026, 7, 25, 12),
    );
    final controller = CreateController(
      loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
      saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
      publishCreateDraftUseCase: PublishCreateDraftUseCase(repository),
      analyticsService: _NoopAnalyticsService(),
      eventCreateCoordinator: createTestEventCoordinator(),
      runtimeDefaults: const CreateRuntimeDefaults(
        marketCityId: 'riga',
        timezone: 'Europe/Riga',
        country: 'LV',
        city: 'Riga',
        currency: 'EUR',
      ),
    );
    await controller.ensureLoaded(
      userId: 'creator-1',
      organizerEmail: 'creator@example.test',
      organizerName: 'Creator',
      capabilities: const <String>['create.route', 'submit.route'],
    );
    if (controller.state.draft.objectType != CreateObjectType.route) {
      controller.setObjectType(CreateObjectType.route);
    }
    final runtime = RouteCreateRuntime(
      coordinator: RouteCreateCoordinator(
        idGenerator: _SequenceIdGenerator(),
        routingRepository: const _ImmediateRoutingRepository(),
        autosaveCoordinator: RouteDraftAutosaveCoordinator(repository),
        config: RouteCreateConfig(
          version: 1,
          validationPolicy: demoRouteCreateConfig().validationPolicy,
          autosaveDebounce: const Duration(hours: 1),
          minimumHistoryEntries: 1,
          maximumHistoryEntries: 20,
          maximumHistoryGeometryPoints: 10000,
        ),
        gpxRepository: gpxRepository,
        clock: () => DateTime.utc(2026, 7, 25, 12),
      ),
      coverageBounds: _bounds,
      graphEdges: <MapPolylineData>[
        MapPolylineData(
          id: 'edge-1',
          layerId: 'offline-trails',
          points: const <GeoPoint>[
            GeoPoint(latitude: 56.9700, longitude: 24.1300),
            GeoPoint(latitude: 56.9710, longitude: 24.1310),
            GeoPoint(latitude: 56.9720, longitude: 24.1320),
          ],
        ),
      ],
      supportedProfiles: const <RouteProfileRef>[
        RouteProfileRef(id: 'walking', version: 1),
      ],
      attribution: 'Offline test graph',
    );
    return _RouteWidgetFixture(
      controller: controller,
      runtime: runtime,
      gpxTransfer: gpxTransfer,
      recordingController: recordingController,
      recordingLocation: recordingLocation,
      containerKey: GlobalKey(),
    );
  }

  Widget app({double textScale = 1}) => ProviderScope(
    key: containerKey,
    overrides: <Override>[
      routeCreateRuntimeProvider.overrideWith((ref) async => runtime),
      routeGpxTransferControllerProvider.overrideWith((ref) => gpxTransfer),
      routeRecordingControllerProvider.overrideWith(
        (ref) => recordingController,
      ),
    ],
    child: MaterialApp(
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, Widget? child) =>
              SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: RepaintBoundary(
                  key: const ValueKey<String>('route-create-golden-surface'),
                  child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: RouteCreateBlock(
                      controller: controller,
                      state: controller.state,
                      onPublished: () {},
                    ),
                  ),
                ),
              ),
        ),
      ),
    ),
  );

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    controller.dispose();
    await recordingLocation.close();
    await runtime.coordinator.dispose();
  }
}

RouteRecordingSample _gpsSample(
  int elapsedMilliseconds,
  double latitude,
  double longitude,
) => RouteRecordingSample(
  position: GeoPoint(latitude: latitude, longitude: longitude),
  horizontalAccuracyMeters: 4,
  elapsedMilliseconds: elapsedMilliseconds,
  capturedAtUtc: DateTime.utc(
    2026,
    7,
    25,
    12,
  ).add(Duration(milliseconds: elapsedMilliseconds)),
  source: RouteRecordingSampleSource.fused,
);

class _TestRecordingJournalRepository
    implements RouteRecordingJournalRepository {
  RouteRecordingJournal? journal;

  @override
  Future<void> delete({
    required String draftId,
    required String sessionId,
  }) async {
    journal = null;
  }

  @override
  Future<RouteRecordingJournal?> loadForDraft(String draftId) async =>
      journal?.draftId == draftId ? journal : null;

  @override
  Future<void> save(RouteRecordingJournal journal) async {
    this.journal = journal;
  }
}

class _TestLocationPort implements RouteLocationRecordingPort {
  final StreamController<RouteRecordingSample> _samples =
      StreamController<RouteRecordingSample>.broadcast();
  final StreamController<bool> _service = StreamController<bool>.broadcast();

  void emit(RouteRecordingSample sample) => _samples.add(sample);

  Future<void> close() async {
    await _samples.close();
    await _service.close();
  }

  @override
  Future<RouteLocationPermission> checkPermission() async =>
      RouteLocationPermission.whileInUse;

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<RouteLocationPermission> requestBackgroundPermission() async =>
      RouteLocationPermission.always;

  @override
  Future<RouteLocationPermission> requestForegroundPermission() async =>
      RouteLocationPermission.whileInUse;

  @override
  Stream<RouteRecordingSample> samples(
    RouteLocationRecordingSettings settings,
  ) => _samples.stream;

  @override
  Stream<bool> serviceEnabledChanges() => _service.stream;
}

class _TestGpxFilePicker implements RouteGpxFilePickerPort {
  const _TestGpxFilePicker(this._sourceStore);

  final RouteGpxSourceStore _sourceStore;

  @override
  Future<RouteSafeFileRef?> pickForImport() => _sourceStore.register(
    displayName: 'investor-demo.gpx',
    mediaType: 'application/gpx+xml',
    bytes: Uint8List.fromList(
      utf8.encode(
        '<gpx version="1.1" creator="test">'
        '<trk><name>Forest walk</name><trkseg>'
        '<trkpt lat="56.9700" lon="24.1300"/>'
        '<trkpt lat="56.9710" lon="24.1310"/>'
        '</trkseg></trk></gpx>',
      ),
    ),
  );

  @override
  Future<bool> saveExport(RouteSafeFileRef file) async => true;
}

const GeoBounds _bounds = GeoBounds(
  southwest: GeoPoint(latitude: 56.965, longitude: 24.125),
  northeast: GeoPoint(latitude: 56.980, longitude: 24.145),
);

class _MemoryRepository
    implements CreateRepository, RouteDraftPersistenceRepository {
  CreateDraftEntity? stored;

  @override
  Future<CreateDraftEntity?> loadDraft(String userId) async => stored;

  @override
  Future<void> saveDraft(String userId, CreateDraftEntity draft) async {
    stored = draft;
  }

  @override
  Future<RouteDraftSaveResult> saveRouteDraft({
    required String userId,
    required CreateDraftEntity draft,
    required int? expectedRevision,
  }) async {
    stored = draft;
    final revision = draft.routeData!.revision;
    return RouteDraftSaveResult(
      status: RouteDraftSaveStatus.saved,
      requestedRevision: revision,
      persistedRevision: revision,
    );
  }

  @override
  Future<CreateDraftEntity> publishDraft(
    String userId,
    CreateDraftEntity draft,
  ) async {
    throw StateError('Route publication is not available in RTE-06.');
  }
}

class _ImmediateRoutingRepository implements RouteRoutingRepository {
  const _ImmediateRoutingRepository();

  @override
  Future<RouteRoutingResult> route(RouteRoutingRequest request) async {
    final midpoint = GeoPoint(
      latitude:
          (request.from.position.latitude + request.to.position.latitude) / 2,
      longitude:
          (request.from.position.longitude + request.to.position.longitude) / 2,
    );
    final geometry = RouteGeometryDraft.fromPoints(<GeoPoint>[
      request.from.position,
      midpoint,
      request.to.position,
    ]);
    return RouteRoutingResult(
      operationId: request.operationId,
      expectedGeometryRevision: request.expectedGeometryRevision,
      requestFingerprint: request.requestFingerprint,
      fromAnchorId: request.from.anchorId,
      toAnchorId: request.to.anchorId,
      geometry: geometry,
      provenance: RouteProvenanceDraft(
        sourceId: 'offline-test',
        sourceRevision: 1,
        createdAtUtc: DateTime.utc(2026, 7, 25, 12),
        algorithmVersion: 'offline-test-v1',
        provider: const RouteProviderReference(
          code: 'offline-test',
          attribution: 'Offline test graph',
          licenseId: 'test',
          dataVersion: 'v1',
          allowsPublication: false,
        ),
      ),
      providerDurationSeconds: (geometry.lengthMeters / 1.4).round(),
    );
  }

  @override
  Future<List<RouteGeneratedCandidate>> generate(
    RouteGenerationRequest request,
  ) async => const <RouteGeneratedCandidate>[];
}

class _SequenceIdGenerator implements IdGenerator {
  int _next = 0;

  @override
  String generate() => 'route-test-id-${_next++}';
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}
