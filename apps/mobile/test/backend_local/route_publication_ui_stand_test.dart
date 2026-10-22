import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:recharge/app/adapters/route_gpx_file_selector_adapter.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/route_content_publication_composition.dart';
import 'package:recharge/app/di/service_locator.dart';
import 'package:recharge/app/presentation/route_content_publication_panel.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/auth/application/auth_providers.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_functions_transport.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/create/application/controllers/route_gpx_transfer_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/application/route_create_config.dart';
import 'package:recharge/features/create/application/route_create_coordinator.dart';
import 'package:recharge/features/create/application/route_draft_autosave_coordinator.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/datasources/route_gpx_memory_source_store.dart';
import 'package:recharge/features/create/data/gpx/route_gpx_exporter.dart';
import 'package:recharge/features/create/data/gpx/route_gpx_importer.dart';
import 'package:recharge/features/create/data/gpx/route_gpx_inspector.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/data/repositories/route_gpx_repository_impl.dart';
import 'package:recharge/features/create/data/repositories/route_sync_client.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/entities/route_draft_save_result.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/repositories/route_draft_persistence_repository.dart';
import 'package:recharge/features/create/domain/repositories/route_gpx_file_picker_port.dart';
import 'package:recharge/features/create/domain/repositories/route_gpx_repository.dart';
import 'package:recharge/features/create/domain/repositories/route_gpx_source_store.dart';
import 'package:recharge/features/create/domain/repositories/route_routing_repository.dart';
import 'package:recharge/features/create/domain/usecases/export_route_gpx_usecase.dart';
import 'package:recharge/features/create/domain/usecases/inspect_route_gpx_usecase.dart';
import 'package:uuid/uuid.dart';

import 'session_publication_ui_stand_test.dart' show sessionStandAuth;
import 'support/stand_backend.dart';

const String _installation = 'j2-ui-installation-creator';

/// A walk with private metadata and a waypoint at its start.
final Uint8List _gpx = Uint8List.fromList(
  utf8.encode('''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="J2 UI" xmlns="http://www.topografix.com/GPX/1/1">
  <metadata><author><name>J2 UI Private Author</name></author></metadata>
  <wpt lat="56.9500100" lon="24.1200100"><name>PRIVATE-ui-home</name><type>shelter</type></wpt>
  <trk><name>J2 UI private track</name>
    <trkseg>
${List<String>.generate(160, (i) => '      <trkpt lat="${(56.95 + (i % 6) * 0.00002).toStringAsFixed(7)}" lon="${(24.12 + i * 0.0001).toStringAsFixed(7)}"><ele>9.0</ele></trkpt>').join('\n')}
    </trkseg>
  </trk>
</gpx>
'''),
);

/// J2 through the UI: the signed-in Creator's Create Route (imported from GPX
/// and registered through the J1 owner sync) is saved, its ends are hidden, it
/// is pinned, bound with a cover, submitted, approved at once by the trust the
/// stand seed earned (RP-06), published and hidden from the default-off test
/// page, with the real controller, Route/Content/Media adapters and the local
/// demo-recharge stand. The define `RECHARGE_TEST_ROUTE_PUBLICATION=true` comes
/// from the gate.
///
/// Limits: PC host run (no physical device), Session from the B1-local Auth
/// Emulator path, Media with the existing fake scanner/processor.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final stand = StandBackend.fromEnvironment();
  late String serverUserId;
  late Directory temp;
  late File cover;
  late CreateDraftEntity draft;
  late BookingTransportRuntime runtime;
  late String routeId;

  Future<void> boot() async {
    await sl.reset();
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    await stand!.routeSeed();
    serverUserId = (await stand.routeManifest())['publisherUserId']! as String;
    final binding = BookingBackendBindingController(
      emulatorBase: StandBackend.functionsBase,
      releaseMode: false,
      initial: BackendBindingMode.testBackend,
    );
    final repository = CreateRepositoryImpl(
      localDataSource: CreateLocalDataSource(const FlutterSecureStorage()),
      idGenerator: UuidV4IdGenerator(),
    );
    // The existing GPX preview → apply flow builds the Create Route.
    const RouteGpxImportConfig config = RouteGpxImportConfig();
    final RouteGpxMemorySourceStore store = RouteGpxMemorySourceStore(
      idGenerator: UuidV4IdGenerator(),
      config: config,
    );
    const RouteGpxInspector inspector = RouteGpxInspector(config: config);
    final RouteGpxRepositoryImpl gpxRepository = RouteGpxRepositoryImpl(
      sourceStore: store,
      inspector: inspector,
      importer: const RouteGpxImporter(inspector: inspector),
      exporter: const RouteGpxExporter(),
    );
    final RouteGpxTransferController transfer = RouteGpxTransferController(
      filePicker: _BytesPicker(store),
      repository: gpxRepository,
      inspectGpx: InspectRouteGpxUseCase(gpxRepository),
      exportGpx: ExportRouteGpxUseCase(gpxRepository),
    );
    final RouteCreateCoordinator coordinator = RouteCreateCoordinator(
      idGenerator: UuidV4IdGenerator(),
      routingRepository: const _NoRouting(),
      autosaveCoordinator: RouteDraftAutosaveCoordinator(_MemoryDrafts()),
      config: demoRouteCreateConfig(),
      gpxRepository: gpxRepository,
      clock: () => DateTime.utc(2026, 10, 22, 12),
    );
    draft =
        CreateDraftEntity.defaults(
          organizerId: serverUserId,
          organizerEmail: '',
          organizerName: '',
        ).copyWith(
          objectType: CreateObjectType.route,
          title: 'Riga riverside (UI path)',
          mainCategory: 'art_culture_museums',
          subcategory: 'art_walk',
          shortDescription: 'A calm riverside walk through Riga parks',
          fullDescription:
              'A calm riverside walk through Riga parks and lanes.',
          routeData: createEmptyRouteDraft().copyWith(
            publisherRef: PublisherRef(
              type: PublisherType.user,
              id: serverUserId,
            ),
          ),
        );
    coordinator.initialize(userId: serverUserId, createDraft: draft);
    await transfer.chooseAndInspect();
    transfer.setImportWaypoints(true);
    final selection = transfer.buildImportSelection()!;
    transfer.beginImport();
    final outcome = await coordinator.importGpx(
      selection,
      confirmGeometryReplacement: true,
    );
    transfer.completeImport(accepted: outcome.accepted);
    expect(outcome.accepted, isTrue, reason: '${outcome.failureCode}');
    draft = draft.copyWith(
      media: draft.media.copyWith(coverImage: cover.path),
      routeData: coordinator.state.route.copyWith(
        publisherRef: PublisherRef(type: PublisherType.user, id: serverUserId),
      ),
    );
    await repository.saveDraft(serverUserId, draft);
    final sessions = FileSessionStore(File('${temp.path}/session.json'));
    runtime = await BookingTransportRuntimeFactory(
      endpoint: binding.endpoint,
      client: CountingClient(),
      tokens: AuthEmulatorTokenProvider('stand-user-creator'),
      sessions: sessions,
      installations: const FixedInstallationId(_installation),
      supportDirectory: () async =>
          Directory('${temp.path}/support').create(recursive: true),
    ).create();
    sl
      ..registerSingleton<BookingBackendBindingController>(binding)
      ..registerSingleton<RoutePublicationTestEntryGuard>(
        RoutePublicationTestEntryGuard.fromEnvironment(binding),
      )
      ..registerSingleton<BookingSupportDirectoryProvider>(
        () async => Directory('${temp.path}/support').create(recursive: true),
      )
      ..registerSingleton<BookingInstallationIdProvider>(
        const FixedInstallationId(_installation),
      )
      ..registerSingleton<FlutterSecureStorage>(const FlutterSecureStorage())
      ..registerSingleton<CreateRuntimeDefaults>(
        const CreateRuntimeDefaults(
          marketCityId: 'riga',
          timezone: 'Europe/Riga',
          country: 'LV',
          city: 'Riga',
          currency: 'EUR',
        ),
      )
      ..registerSingleton<CreateRepository>(repository)
      ..registerLazySingletonAsync<BookingTransportRuntime>(
        () async => runtime,
      );
    if (await sessions.read() == null) {
      try {
        await runtime.identitySessions!.establish(requestId: const Uuid().v4());
      } on BookingCallableFailure catch (error) {
        fail('establish failed with ${error.code}');
      }
    }
    // J1: an imported GPX enters the server through its import intent; the
    // page's own sync client finds the same journal (installation and owner).
    final sync = RouteSyncClient(
      invoke: routePublicationInvoke(
        guard: sl<RoutePublicationTestEntryGuard>(),
        port: runtime.port!,
      ),
      storage: const FlutterSecureStorage(),
      installationId: _installation,
      currentOwner: () => serverUserId,
    );
    await sync.restore();
    await sync.importRoute(
      localDraftId: draft.id,
      title: draft.title,
      route: draft.routeData!,
    );
    routeId = sync.routeIdFor(draft.id)!;
  }

  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (finder.evaluate().isNotEmpty) return;
    }
    String text(String key) {
      final Finder f = find.byKey(Key(key));
      return f.evaluate().isEmpty
          ? ''
          : (f.evaluate().first.widget as Text).data!;
    }

    fail(
      'timed out waiting for $finder; status="${text('route-publication-status')}" '
      'message="${text('route-publication-message')}"',
    );
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byWidgetPredicate(
      (widget) =>
          widget.key == Key(key) &&
          widget is ButtonStyleButton &&
          widget.onPressed != null,
    );
    await waitFor(tester, finder);
    await tester.tap(finder);
  }

  Finder keyed(String key, String fragment) => find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        widget.key == Key(key) &&
        (widget.data ?? '').contains(fragment),
  );

  setUpAll(() async {
    if (stand == null) return;
    temp = await Directory.systemTemp.createTemp('j2-ui-');
    cover = await File(
      'test/fixtures/media/stand_cover.png',
    ).copy('${temp.path}/cover.png');
  });

  tearDownAll(() async {
    if (stand != null && await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  testWidgets(
    'the Creator publishes their Create Route from the test page',
    (WidgetTester tester) async {
      await tester.runAsync(boot);
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final auth = await tester.runAsync(() => sessionStandAuth(serverUserId));
      final router = GoRouter(
        initialLocation: '/test/route-publication',
        routes: <RouteBase>[
          GoRoute(
            path: '/test/route-publication',
            redirect: (context, state) => routePublicationTestEntryRedirect(
              sl<RoutePublicationTestEntryGuard>(),
              fallback: '/blocked',
            ),
            builder: (context, state) => const RouteContentPublicationPage(),
          ),
          GoRoute(
            path: '/blocked',
            builder: (context, state) => const Text('blocked'),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            authControllerProvider.overrideWith((ref) => auth!),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await waitFor(tester, find.text('Riga riverside (UI path)'));
      await waitFor(tester, find.text('Server revision 1'));

      // The current Create Route is saved again through the J1 sync.
      await tapKey(tester, 'route-publication-sync');
      await waitFor(tester, find.text('Server revision 2'));
      await tapKey(tester, 'route-publication-hide-ends');
      await waitFor(
        tester,
        keyed('route-publication-trim', 'start 200 m, end 200 m'),
      );
      await tapKey(tester, 'route-publication-prepare');
      await waitFor(tester, keyed('route-publication-status', 'review: draft'));
      await tester.tap(find.byKey(const Key('route-publication-rights')));
      await tapKey(tester, 'route-publication-cover');
      await tapKey(tester, 'route-publication-submit');
      // RP-06: the stand seed's reviewed Route earned this Creator's trust.
      await waitFor(
        tester,
        keyed('route-publication-status', 'approved_for_publication'),
      );
      expect(find.byKey(const Key('route-publication-message')), findsNothing);
      await tapKey(tester, 'route-publication-publish');
      await waitFor(
        tester,
        keyed('route-publication-status', 'visibility: visible'),
      );

      // The published revision carries only the trimmed public snapshot.
      final String body =
          await tester.runAsync(
            () => _publishedRevision(runtime.port!, routeId),
          ) ??
          '';
      for (final String marker in <String>[
        'PRIVATE-ui-home',
        'J2 UI Private Author',
        'J2 UI private track',
        'anchorId',
      ]) {
        expect(body.contains(marker), isFalse, reason: 'leak: $marker');
      }
      expect(body.contains('Riga riverside (UI path)'), isTrue);

      await tapKey(tester, 'route-publication-hide');
      await waitFor(
        tester,
        keyed('route-publication-status', 'visibility: withdrawn'),
      );
    },
    skip: stand == null || !routePublicationTestEntryDefined,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

/// One published revision as the public Content query returns it.
Future<String> _publishedRevision(BookingCallablePort port, String id) async =>
    jsonEncode(
      await port.invoke('contentQueryV1', <String, Object?>{
        'schemaVersion': 1,
        'queryType': 'getPublishedRevision',
        'payload': <String, Object?>{'contentId': id},
      }),
    );

final class _BytesPicker implements RouteGpxFilePickerPort {
  _BytesPicker(this._store);

  final RouteGpxSourceStore _store;

  @override
  Future<RouteSafeFileRef?> pickForImport() async {
    final XFile file = XFile.fromData(
      _gpx,
      name: 'walk.gpx',
      length: _gpx.length,
    );
    final Uint8List bytes = await readBoundedGpx(
      file,
      const RouteGpxImportConfig().maximumFileBytes,
    );
    return _store.register(
      displayName: 'walk.gpx',
      mediaType: 'application/gpx+xml',
      bytes: bytes,
    );
  }

  @override
  Future<bool> saveExport(RouteSafeFileRef file) async => true;
}

final class _NoRouting implements RouteRoutingRepository {
  const _NoRouting();

  @override
  Future<RouteRoutingResult> route(RouteRoutingRequest request) =>
      throw StateError('J2 never calls a routing provider');

  @override
  Future<List<RouteGeneratedCandidate>> generate(
    RouteGenerationRequest request,
  ) => throw StateError('J2 never calls a routing provider');
}

final class _MemoryDrafts implements RouteDraftPersistenceRepository {
  @override
  Future<RouteDraftSaveResult> saveRouteDraft({
    required String userId,
    required CreateDraftEntity draft,
    required int? expectedRevision,
  }) async => RouteDraftSaveResult(
    status: RouteDraftSaveStatus.saved,
    requestedRevision: draft.routeData!.revision,
    persistedRevision: draft.routeData!.revision,
  );
}
