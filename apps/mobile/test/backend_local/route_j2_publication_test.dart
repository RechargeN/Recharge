import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:recharge/app/adapters/route_gpx_file_selector_adapter.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/route_content_publication_composition.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/create/application/controllers/route_gpx_transfer_controller.dart';
import 'package:recharge/features/create/application/route_content_publication_controller.dart';
import 'package:recharge/features/create/application/route_create_config.dart';
import 'package:recharge/features/create/application/route_create_coordinator.dart';
import 'package:recharge/features/create/application/route_draft_autosave_coordinator.dart';
import 'package:recharge/features/create/data/datasources/route_gpx_memory_source_store.dart';
import 'package:recharge/features/create/data/gpx/route_gpx_exporter.dart';
import 'package:recharge/features/create/data/gpx/route_gpx_importer.dart';
import 'package:recharge/features/create/data/gpx/route_gpx_inspector.dart';
import 'package:recharge/features/create/data/repositories/route_gpx_repository_impl.dart';
import 'package:recharge/features/create/data/repositories/route_sync_client.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/entities/route_draft_data.dart';
import 'package:recharge/features/create/domain/entities/route_draft_save_result.dart';
import 'package:recharge/features/create/domain/repositories/route_content_publication_gateway.dart';
import 'package:recharge/features/create/domain/repositories/route_draft_persistence_repository.dart';
import 'package:recharge/features/create/domain/repositories/route_gpx_file_picker_port.dart';
import 'package:recharge/features/create/domain/repositories/route_gpx_repository.dart';
import 'package:recharge/features/create/domain/repositories/route_gpx_source_store.dart';
import 'package:recharge/features/create/domain/repositories/route_routing_repository.dart';
import 'package:recharge/features/create/domain/usecases/export_route_gpx_usecase.dart';
import 'package:recharge/features/create/domain/usecases/inspect_route_gpx_usecase.dart';
import 'package:uuid/uuid.dart';

import 'support/stand_backend.dart';

/// One continuous walk with private metadata, timestamps and a waypoint at
/// the start: nothing of it may reach the public snapshot.
final Uint8List _gpx = Uint8List.fromList(
  utf8.encode('''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="J2 Device" xmlns="http://www.topografix.com/GPX/1/1">
  <metadata><author><name>J2 Private Author</name></author></metadata>
  <wpt lat="56.9496100" lon="24.1052100"><name>J2-PRIVATE-home</name><type>shelter</type></wpt>
  <trk><name>J2 private track</name>
    <trkseg>
${List<String>.generate(120, (i) => '      <trkpt lat="${(56.9496 + (i % 5) * 0.00002).toStringAsFixed(7)}" lon="${(24.1052 + i * 0.0001).toStringAsFixed(7)}"><ele>12.0</ele><time>2026-10-21T08:00:00Z</time></trkpt>').join('\n')}
    </trkseg>
  </trk>
</gpx>
'''),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bool enabled = Platform.environment['RECHARGE_J2_LOCAL'] == '1';
  if (enabled) HttpOverrides.global = null;
  test(
    'J2 real Flutter adapters: GPX import, J1 sync, trim, distribute, Content and publish',
    () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      final Directory temp = await Directory.systemTemp.createTemp('j2-');
      addTearDown(() => temp.delete(recursive: true));
      final List<Uri> network = <Uri>[];
      final String uid = Platform.environment['RECHARGE_J2_UID']!;
      final BookingBackendBindingController binding =
          BookingBackendBindingController(
            emulatorBase: StandBackend.functionsBase,
            releaseMode: false,
            initial: BackendBindingMode.testBackend,
          );
      final _LoopbackOnlyClient client = _LoopbackOnlyClient(network);
      addTearDown(client.close);
      final BookingTransportRuntime runtime =
          await BookingTransportRuntimeFactory(
            endpoint: binding.endpoint,
            client: client,
            tokens: AuthEmulatorTokenProvider(uid),
            sessions: FileSessionStore(File('${temp.path}/session.json')),
            installations: FixedInstallationId('j2-mobile'),
            supportDirectory: () =>
                Directory('${temp.path}/support').create(recursive: true),
          ).create();
      try {
        await runtime.identitySessions!.establish(requestId: const Uuid().v4());
      } on BookingCallableFailure catch (e) {
        fail('Session setup: ${e.code}');
      }
      final BookingCallablePort port = runtime.port!;
      final RoutePublicationTestEntryGuard guard =
          RoutePublicationTestEntryGuard.fromEnvironment(binding);
      expect(guard.allowed, isTrue, reason: 'run with the J2 define');
      final RouteInvoke invoke = routePublicationInvoke(
        guard: guard,
        port: port,
      );
      final Map<String, Object?> list =
          await invoke('routeQueryV1', <String, Object?>{
            'schemaVersion': 1,
            'requestId': const Uuid().v4(),
            'queryType': 'list',
            'cursor': null,
          });
      expect(list['kind'], 'succeeded', reason: list.toString());
      final String owner = list['ownerId']! as String;

      // The existing preview → apply flow builds the Create Route draft.
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
      final _BytesPicker picker = _BytesPicker(store)..next = _gpx;
      final RouteGpxTransferController transfer = RouteGpxTransferController(
        filePicker: picker,
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
        clock: () => DateTime.utc(2026, 10, 21, 12),
      );
      CreateDraftEntity draft =
          CreateDraftEntity.defaults(
            organizerId: owner,
            organizerEmail: '',
            organizerName: '',
          ).copyWith(
            objectType: CreateObjectType.route,
            title: 'J2 riverside walk',
            mainCategory: 'art_culture_museums',
            subcategory: 'art_walk',
            shortDescription: 'A calm riverside walk through Riga parks',
            fullDescription:
                'A calm riverside walk through Riga parks with a tap.',
            routeData: createEmptyRouteDraft(),
          );
      coordinator.initialize(userId: owner, createDraft: draft);
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
      final RouteDraftData imported = coordinator.state.route;
      draft = draft.copyWith(routeData: imported);

      // J1: the import intent registers the source; J2 builds on it.
      final RouteSyncClient sync = RouteSyncClient(
        invoke: invoke,
        storage: const FlutterSecureStorage(),
        installationId: 'j2-mobile',
        currentOwner: () => owner,
      );
      await sync.restore();
      await sync.importRoute(
        localDraftId: draft.id,
        title: draft.title,
        route: imported,
      );
      final String routeId = sync.routeIdFor(draft.id)!;

      final RouteContentPublicationController controller =
          routeContentPublicationControllerFor(
            accountId: owner,
            defaultContentLocale: 'en',
            publisherRef: PublisherRef(type: PublisherType.user, id: owner),
            port: port,
            guard: guard,
            drafts: _Drafts(draft),
            sync: sync,
            journalFile: File('${temp.path}/route-publications.json'),
          );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.state.routeId, routeId);
      expect(controller.state.serverRevision, 1);
      await controller.hidePrivateEnds();
      expect(controller.state.message, isNull);
      expect(controller.state.trim?.startMeters, 200);
      await controller.prepare();
      expect(controller.state.message, isNull);
      final Map<String, Object?> distribution =
          controller.state.record!.distribution;
      final String json = jsonEncode(distribution);
      for (final String marker in <String>[
        'J2-PRIVATE-home',
        'J2 Private Author',
        'J2 private track',
        '2026-10-21T08',
        'gpx-',
        'anchorId',
      ]) {
        expect(json.contains(marker), isFalse, reason: 'leak: $marker');
      }
      expect(controller.state.record!.routeId, routeId);
      await controller.submit();
      expect(controller.state.message, isNull);
      // The world trusts this publisher already (RP-06): approved at once.
      expect(
        controller.state.status?.latestSubmissionState,
        'approved_for_publication',
      );
      await controller.publish();
      expect(controller.state.message, isNull);
      expect(controller.state.published, isTrue);
      File(
        Platform.environment['RECHARGE_J2_OUT']!,
      ).writeAsStringSync(jsonEncode(<String, Object?>{'routeId': routeId}));
      // Only the loopback Emulator was contacted.
      expect(network, isNotEmpty);
      expect(
        network.every((Uri u) => u.host == '127.0.0.1'),
        isTrue,
        reason: network.map((Uri u) => u.toString()).toSet().toString(),
      );
    },
    skip: enabled ? false : 'Run the route-j2 Emulator group.',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

final class _Drafts implements RouteDraftSource {
  const _Drafts(this.draft);
  final CreateDraftEntity draft;
  @override
  Future<CreateDraftEntity?> current() async => draft;
}

final class _LoopbackOnlyClient extends http.BaseClient {
  _LoopbackOnlyClient(this._seen);

  final List<Uri> _seen;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    _seen.add(request.url);
    if (request.url.host != '127.0.0.1') {
      throw StateError('non-loopback request ${request.url.host}');
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

final class _BytesPicker implements RouteGpxFilePickerPort {
  _BytesPicker(this._store);

  final RouteGpxSourceStore _store;
  Uint8List next = Uint8List(0);

  @override
  Future<RouteSafeFileRef?> pickForImport() async {
    final XFile file = XFile.fromData(
      next,
      name: 'walk.gpx',
      length: next.length,
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
