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
import 'package:recharge/app/di/route_sync_composition.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/create/application/controllers/route_gpx_transfer_controller.dart';
import 'package:recharge/features/create/application/route_create_config.dart';
import 'package:recharge/features/create/application/route_create_coordinator.dart';
import 'package:recharge/features/create/application/route_draft_autosave_coordinator.dart';
import 'package:recharge/features/create/data/datasources/route_gpx_memory_source_store.dart';
import 'package:recharge/features/create/data/gpx/route_gpx_exporter.dart';
import 'package:recharge/features/create/data/gpx/route_gpx_importer.dart';
import 'package:recharge/features/create/data/gpx/route_gpx_inspector.dart';
import 'package:recharge/features/create/data/models/route_canonical_codec.dart';
import 'package:recharge/features/create/data/models/scenario_draft_mapper.dart';
import 'package:recharge/features/create/data/repositories/route_gpx_repository_impl.dart';
import 'package:recharge/features/create/data/repositories/route_sync_client.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/route_draft_data.dart';
import 'package:recharge/features/create/domain/entities/route_draft_save_result.dart';
import 'package:recharge/features/create/domain/entities/route_sync_data.dart';
import 'package:recharge/features/create/domain/repositories/route_draft_persistence_repository.dart';
import 'package:recharge/features/create/domain/repositories/route_gpx_file_picker_port.dart';
import 'package:recharge/features/create/domain/repositories/route_gpx_repository.dart';
import 'package:recharge/features/create/domain/repositories/route_gpx_source_store.dart';
import 'package:recharge/features/create/domain/repositories/route_routing_repository.dart';
import 'package:recharge/features/create/domain/repositories/route_sync_repository.dart';
import 'package:recharge/features/create/domain/usecases/export_route_gpx_usecase.dart';
import 'package:recharge/features/create/domain/usecases/inspect_route_gpx_usecase.dart';
import 'package:uuid/uuid.dart';

import 'support/stand_backend.dart';

/// Two parts, one gap (confirmed direct), a duplicate point, private
/// metadata, timestamps, extensions and a waypoint next to the start.
final Uint8List _gpx = Uint8List.fromList(
  utf8.encode('''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="J1 Device" xmlns="http://www.topografix.com/GPX/1/1">
  <metadata><author><name>J1 Private Author</name></author></metadata>
  <wpt lat="56.9496100" lon="24.1052100"><name>Home &lt;door&gt; &amp; "gate"</name><type>shelter</type></wpt>
  <wpt lat="56.9496000" lon="24.1112000"><name>Viewpoint</name><type>viewpoint</type></wpt>
  <trk><name>J1 private track</name>
    <trkseg>
${List<String>.generate(10, (i) => '      <trkpt lat="56.9496000" lon="${(24.1052 + i * 0.0001).toStringAsFixed(7)}"><ele>12.0</ele><time>2026-10-20T08:0$i:00Z</time></trkpt>').join('\n')}
      <trkpt lat="56.9496000" lon="24.1061000"><ele>12.0</ele></trkpt>
    </trkseg>
    <trkseg>
${List<String>.generate(10, (i) => '      <trkpt lat="56.9496000" lon="${(24.1072 + i * 0.0001).toStringAsFixed(7)}"><ele>13.0</ele></trkpt>').join('\n')}
    </trkseg>
    <extensions><x:Secret xmlns:x="urn:j1">J1-EXTENSION-SENTINEL</x:Secret></extensions>
  </trk>
</gpx>
'''),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final enabled = Platform.environment['RECHARGE_J1_LOCAL'] == '1';
  if (enabled) HttpOverrides.global = null;
  test(
    'J1 real Flutter adapters: GPX preview/apply/sync/trimmed export, conflicts, recovery, isolation',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final temp = await Directory.systemTemp.createTemp('j1-client-');
      addTearDown(() => temp.delete(recursive: true));
      final network = <Uri>[];
      Future<(RouteInvoke, String)> transport(
        String uid,
        String installation,
      ) async {
        final binding = BookingBackendBindingController(
          emulatorBase: StandBackend.functionsBase,
          releaseMode: false,
          initial: BackendBindingMode.testBackend,
        );
        final client = _LoopbackOnlyClient(network);
        addTearDown(client.close);
        final runtime = await BookingTransportRuntimeFactory(
          endpoint: binding.endpoint,
          client: client,
          tokens: AuthEmulatorTokenProvider(uid),
          sessions: FileSessionStore(File('${temp.path}/$installation.json')),
          installations: FixedInstallationId(installation),
          supportDirectory: () => Directory(
            '${temp.path}/$installation-support',
          ).create(recursive: true),
        ).create();
        try {
          await runtime.identitySessions!.establish(
            requestId: const Uuid().v4(),
          );
        } on BookingCallableFailure catch (e) {
          fail('Session setup $installation: ${e.code}');
        }
        final invoke = routeSyncInvoke(
          binding: binding,
          runtime: () async => runtime,
        );
        final identity = await invoke('routeQueryV1', {
          'schemaVersion': 1,
          'requestId': const Uuid().v4(),
          'queryType': 'list',
          'cursor': null,
        });
        expect(identity['kind'], 'succeeded', reason: identity.toString());
        return (invoke, identity['ownerId']! as String);
      }

      final (invokeA, owner) = await transport(
        Platform.environment['RECHARGE_J1_UID']!,
        'j1-mobile-a',
      );
      final (invokeA2, owner2) = await transport(
        Platform.environment['RECHARGE_J1_UID']!,
        'j1-mobile-a2',
      );
      final (invokeOther, other) = await transport(
        Platform.environment['RECHARGE_J1_OTHER_UID']!,
        'j1-mobile-other',
      );
      expect(owner2, owner);
      expect(other, isNot(owner));
      String? active = owner;
      var route = invokeA;
      var offline = false, lost = false, expired = false;
      Future<Map<String, Object?>> controlled(
        String surface,
        Map<String, Object?> request,
      ) async {
        if (offline) throw const RouteSyncFailure('unavailable');
        if (expired) {
          return {'kind': 'rejected', 'code': 'unauthenticated'};
        }
        final answer = await route(surface, request);
        if (lost && surface == 'routeCommandV1') {
          lost = false;
          throw const RouteSyncFailure('deadline-exceeded');
        }
        return answer;
      }

      RouteSyncClient reboot() => RouteSyncClient(
        invoke: controlled,
        storage: const FlutterSecureStorage(),
        installationId: 'j1-device-a',
        currentOwner: () => active,
      );
      var a = reboot();
      final b = RouteSyncClient(
        invoke: invokeA2,
        storage: const FlutterSecureStorage(),
        installationId: 'j1-device-a2',
        currentOwner: () => owner,
      );
      final failure = throwsA(isA<RouteSyncFailure>());
      Matcher refused(String code) =>
          throwsA(isA<RouteSyncFailure>().having((e) => e.code, 'code', code));

      // Existing preview → apply flow with the real parser, picker read and store.
      const config = RouteGpxImportConfig();
      final store = RouteGpxMemorySourceStore(
        idGenerator: UuidV4IdGenerator(),
        config: config,
      );
      const inspector = RouteGpxInspector(config: config);
      final gpxRepository = RouteGpxRepositoryImpl(
        sourceStore: store,
        inspector: inspector,
        importer: const RouteGpxImporter(inspector: inspector),
        exporter: const RouteGpxExporter(),
      );
      final picker = _BytesPicker(store);
      final transfer = RouteGpxTransferController(
        filePicker: picker,
        repository: gpxRepository,
        inspectGpx: InspectRouteGpxUseCase(gpxRepository),
        exportGpx: ExportRouteGpxUseCase(gpxRepository),
      );
      final coordinator = RouteCreateCoordinator(
        idGenerator: UuidV4IdGenerator(),
        routingRepository: const _NoRouting(),
        autosaveCoordinator: RouteDraftAutosaveCoordinator(_MemoryDrafts()),
        config: demoRouteCreateConfig(),
        gpxRepository: gpxRepository,
        clock: () => DateTime.utc(2026, 10, 20, 12),
      );
      final draft =
          CreateDraftEntity.defaults(
            organizerId: owner,
            organizerEmail: '',
            organizerName: '',
          ).copyWith(
            objectType: CreateObjectType.route,
            routeData: createEmptyRouteDraft(),
          );
      coordinator.initialize(userId: owner, createDraft: draft);

      Future<RouteDraftData> importFlow(Uint8List bytes) async {
        picker.next = bytes;
        await transfer.chooseAndInspect();
        expect(transfer.status, RouteGpxTransferStatus.preview);
        final inspection = transfer.inspection!;
        expect(inspection.containsPrivateMetadata, isTrue);
        expect(inspection.candidates.single.gapCount, 1);
        transfer
          ..setConnectGapsConfirmed(true)
          ..setImportWaypoints(true);
        final selection = transfer.buildImportSelection()!;
        transfer.beginImport();
        final outcome = await coordinator.importGpx(
          selection,
          confirmGeometryReplacement: true,
        );
        transfer.completeImport(accepted: outcome.accepted);
        expect(outcome.accepted, isTrue, reason: '${outcome.failureCode}');
        // The temporary source copy is gone after apply.
        await expectLater(
          store.read(selection.file),
          throwsA(isA<RouteGpxException>()),
        );
        return coordinator.state.route;
      }

      final imported = await importFlow(_gpx);
      expect(imported.orderedSegments.map((s) => s.source), [
        RouteSegmentSource.importedGpx,
        RouteSegmentSource.intentionalDirect,
        RouteSegmentSource.importedGpx,
      ]);
      expect(
        imported.sourceIssues.map((i) => i.code),
        contains('gpx_duplicates_removed'),
      );

      // Hostile GPX through the same flow changes nothing and reaches nobody.
      final before = coordinator.state.route;
      picker.next = Uint8List.fromList(
        utf8.encode(
          '<!DOCTYPE gpx [<!ENTITY x SYSTEM "file:///etc/passwd">]>'
          '<gpx version="1.1"><trk><trkseg><trkpt lat="1" lon="1"/>'
          '<trkpt lat="2" lon="2"/></trkseg></trk></gpx>',
        ),
      );
      await transfer.chooseAndInspect();
      expect(transfer.status, RouteGpxTransferStatus.failed);
      expect(transfer.failureCode, 'gpx_dtd_or_entity_forbidden');
      expect(identical(coordinator.state.route, before), isTrue);

      // Lost answer on the import intent, restart, replay: exactly one Route.
      final localId = draft.id;
      lost = true;
      await expectLater(
        a.importRoute(localDraftId: localId, title: 'Forest', route: imported),
        failure,
      );
      a = reboot();
      await a.restore();
      final routeId = a.routeIdFor(localId)!;
      expect(a.hasPending(routeId), isTrue);
      await a.flush();
      final created = (await a.refresh(routeId))!;
      expect(created.revision, 1);
      expect(created.origin, 'gpxImport');
      // Repeating the same intent is a no-op; changed content is refused.
      await a.importRoute(
        localDraftId: localId,
        title: 'Forest',
        route: imported,
      );
      expect(a.cached(routeId)!.revision, 1);
      await expectLater(
        a.importRoute(localDraftId: localId, title: 'Changed', route: imported),
        refused('idempotency_conflict'),
      );
      await a.resolveConflict(a.conflicts.single.key, reapplyLocal: false);
      final listed = await b.list();
      expect(listed.where((e) => e.routeId == routeId), hasLength(1));

      // Second device: canonical round trip through the server.
      final remote = (await b.refresh(routeId))!;
      final onB = b.draftFrom(remote, template: createEmptyRouteDraft());
      // Firestore does not keep key order: compare canonical JSON.
      expect(
        ScenarioDraftMapper.canonicalJson(
          RouteCanonicalCodec.encode(
            onB,
            title: 'Forest',
            idFor: (id) => fail('no local IDs on B: $id'),
          ),
        ),
        ScenarioDraftMapper.canonicalJson(remote.route),
      );
      expect(remote.summary!.pointCount, 22);
      expect(remote.summary!.gapCount, 0);
      final json = jsonEncode(remote.route);
      for (final secret in <String>[
        'J1 Private',
        'J1 private track',
        'J1-EXTENSION',
        '2026-10-20T08',
        'J1 Device',
      ]) {
        expect(json, isNot(contains(secret)), reason: secret);
      }

      // Edit/edit in both delivery orders: first wins, loser kept for review.
      var revision = 1;
      for (final reversed in <bool>[false, true]) {
        final first = reversed ? b : a, second = reversed ? a : b;
        await first.save(
          localDraftId: reversed ? routeId : localId,
          title: 'winner $reversed',
          route: reversed ? onB : imported,
          expectedRevision: revision,
        );
        await expectLater(
          second.save(
            localDraftId: reversed ? localId : routeId,
            title: 'loser $reversed',
            route: reversed ? imported : onB,
            expectedRevision: revision,
          ),
          refused('revision_conflict'),
        );
        revision++;
        final conflict = second.conflicts.last;
        expect(conflict.serverRevision, revision);
        expect(
          (second.conflictPayload(conflict.key)!['route'] as Map)['title'],
          'loser $reversed',
        );
        expect((await second.refresh(routeId))!.title, 'winner $reversed');
        await second.resolveConflict(conflict.key, reapplyLocal: false);
      }

      // Trim/edit in both orders: CAS; a save never removes the trim.
      for (final trimFirst in <bool>[true, false]) {
        await a.refresh(routeId);
        await b.refresh(routeId);
        final trim = const RoutePrivacyTrim(startMeters: 20, endMeters: 13);
        if (trimFirst) {
          await a.setPrivacyTrim(
            routeId: routeId,
            trim: trim,
            expectedRevision: revision,
          );
          await expectLater(
            b.save(
              localDraftId: routeId,
              title: 'edit after trim',
              route: onB,
              expectedRevision: revision,
            ),
            refused('revision_conflict'),
          );
        } else {
          await b.save(
            localDraftId: routeId,
            title: 'edit before trim',
            route: onB,
            expectedRevision: revision,
          );
          await expectLater(
            a.setPrivacyTrim(
              routeId: routeId,
              trim: const RoutePrivacyTrim(startMeters: 0, endMeters: 0),
              expectedRevision: revision,
            ),
            refused('revision_conflict'),
          );
        }
        revision++;
        expect(
          (await b.refresh(routeId))!.privacyTrim!.startMeters,
          20,
          reason: 'trimFirst=$trimFirst',
        );
      }

      // Trimmed preview and export share one revision and one trim variant.
      final preview = await a.trimmedView(routeId, expectedRevision: revision);
      final again = await a.trimmedView(routeId, expectedRevision: revision);
      expect(again.variantHash, preview.variantHash);
      await expectLater(
        a.trimmedView(routeId, expectedRevision: revision - 1),
        refused('revision_conflict'),
      );
      final exported = await gpxRepository.exportTrimmed(
        preview,
        includeElevation: true,
        includeWaypoints: true,
      );
      final xml = utf8.decode(await store.read(exported));
      await gpxRepository.discard(exported);
      final full = b.draftFrom(
        (await b.refresh(routeId))!,
        template: createEmptyRouteDraft(),
      );
      final kept = preview.segments.expand((s) => s.points).toSet();
      final removed = full.orderedSegments
          .expand((s) => s.geometry.points)
          .where((p) => !kept.contains(p))
          .toList();
      expect(removed, hasLength(7));
      String number(double v) =>
          v.toStringAsFixed(7).replaceFirst(RegExp(r'\.?0+$'), '');
      for (final p in removed) {
        expect(xml, isNot(contains('lon="${number(p.longitude)}"')));
      }
      expect(xml, isNot(contains('Home')));
      expect(xml, contains('Viewpoint'));
      for (final secret in <String>[
        '<time>',
        '<bounds',
        'J1',
        'extensions',
        routeId,
      ]) {
        expect(xml, isNot(contains(secret)), reason: secret);
      }
      final reread = inspector.inspect(
        file: RouteSafeFileRef(
          token: 't',
          displayName: 'export.gpx',
          sizeBytes: utf8.encode(xml).length,
          mediaType: 'application/gpx+xml',
        ),
        bytes: Uint8List.fromList(utf8.encode(xml)),
      );
      // 15 view points; the two points shared with the direct segment are
      // written once inside the continuous <trkseg>.
      expect(preview.segments.fold<int>(0, (n, s) => n + s.points.length), 15);
      expect(reread.pointCount, 13);
      expect(reread.candidates.single.segmentCount, 1);
      // A trim that would remove everything is refused; no untrimmed fallback.
      await expectLater(
        a.setPrivacyTrim(
          routeId: routeId,
          trim: const RoutePrivacyTrim(startMeters: 2000, endMeters: 0),
          expectedRevision: revision,
        ),
        refused('privacy_trim_empty'),
      );
      await a.resolveConflict(a.conflicts.last.key, reapplyLocal: false);

      // Offline queue, restart and refresh: the same intent goes out once.
      offline = true;
      await expectLater(
        a.save(
          localDraftId: localId,
          title: 'offline edit',
          route: imported,
          expectedRevision: revision,
        ),
        failure,
      );
      a = reboot();
      await a.restore();
      expect(a.hasPending(routeId), isTrue);
      offline = false;
      expect((await a.refresh(routeId))!.title, 'offline edit');
      revision++;

      // Session loss keeps the queue; another account neither sees nor sends it.
      expired = true;
      await expectLater(
        a.save(
          localDraftId: localId,
          title: 'pending A',
          route: imported,
          expectedRevision: revision,
        ),
        refused('unauthenticated'),
      );
      active = null;
      a.clearVisible();
      expect(a.cached(routeId), isNull);
      active = other;
      route = invokeOther;
      expired = false;
      await a.restore();
      expect(a.hasPending(routeId), isFalse);
      expect(await a.refresh(routeId), isNull);
      expect(await a.list(), isEmpty);
      expect((await b.refresh(routeId))!.title, 'offline edit');
      active = owner;
      route = invokeA;
      a = reboot();
      expect((await a.refresh(routeId))!.title, 'pending A');
      revision++;

      // Edit/delete: an offline stale edit cannot resurrect the tombstone.
      offline = true;
      await expectLater(
        a.save(
          localDraftId: localId,
          title: 'stale offline',
          route: imported,
          expectedRevision: revision,
        ),
        failure,
      );
      await b.refresh(routeId);
      await b.delete(routeId: routeId, expectedRevision: revision);
      offline = false;
      await expectLater(a.flush(), refused('deleted'));
      expect(await a.refresh(routeId), isNull);
      expect(await b.refresh(routeId), isNull);
      await expectLater(
        a.importRoute(localDraftId: localId, title: 'Forest', route: imported),
        completion(isNull),
      );
      expect(await a.refresh(routeId), isNull);

      // Foreign reads and forged owner claims disclose nothing.
      final foreign = await invokeOther('routeQueryV1', {
        'schemaVersion': 1,
        'requestId': const Uuid().v4(),
        'queryType': 'get',
        'routeId': routeId,
      });
      expect(foreign['entry'], isNull);
      final forged = await invokeOther('routeCommandV1', {
        'schemaVersion': 1,
        'requestId': const Uuid().v4(),
        'ownerContext': owner,
        'idempotencyKey': 'delete-${const Uuid().v4()}',
        'commandType': 'delete',
        'routeId': routeId,
        'expectedRevision': 1,
      });
      expect(forged['code'], 'owner_changed');
      // Only the loopback Emulator was contacted: no routing or other host.
      expect(network, isNotEmpty);
      expect(
        network.every((u) => u.host == '127.0.0.1' && u.port == 5001),
        isTrue,
        reason: network.map((u) => u.toString()).toSet().toString(),
      );
    },
    skip: enabled ? false : 'Run the route-j1 Emulator group.',
    timeout: const Timeout(Duration(minutes: 3)),
  );
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
    final file = XFile.fromData(next, name: 'walk.gpx', length: next.length);
    final bytes = await readBoundedGpx(
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
      throw StateError('J1 never calls a routing provider');

  @override
  Future<List<RouteGeneratedCandidate>> generate(
    RouteGenerationRequest request,
  ) => throw StateError('J1 never calls a routing provider');
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
