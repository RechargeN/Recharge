import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/event_publication_composition.dart';
import 'package:recharge/app/di/local_import_composition.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/create/application/local_import_cleanup_policy.dart';
import 'package:recharge/features/create/application/local_import_controller.dart';
import 'package:recharge/features/create/data/create_local_import_store.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/functions_local_import_gateway.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_publication.dart';
import 'package:recharge/features/create/domain/entities/local_import.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/repositories/local_import_gateway.dart';
import 'package:recharge/features/create/domain/repositories/publisher_access_check.dart';
import 'package:uuid/uuid.dart';

import '../fixtures/create/user_place_draft.dart';
import 'support/stand_backend.dart';

/// D4: the user's own local Create Place draft is imported into a server
/// draft on the local demo-recharge stand through the real Content (with the
/// one-draft-per-import-source rule) and Media services: an interrupted
/// create whose answer was lost resumes into the same draft after a restart;
/// lost receipts and a repeated import never create a second draft; the local
/// original is removed only after verification, explicit confirmation and the
/// recovery period. The draft is read through the real Create storage.
///
/// D4.1: a rollback tombstones the server draft and keeps the local original
/// byte for byte; a lost rollback answer survives a restart in
/// `rollbackPending`; a cleanup reservation on one installation stops a
/// rollback on another; lost answers before and after the deletion of the
/// original are recovered with the same fencing token; a re-import opens the
/// next generation.
///
/// Limits: PC host run against the local Emulator; Place authoring is enabled
/// by `stand-seed.mjs place seed`; Media uses the stand's fake processor.
void main() {
  final stand = StandBackend.fromEnvironment();
  late Directory temp;
  late File cover;
  late File photo;
  late String pageId;
  final runtimes = <String, Future<BookingTransportRuntime>>{};

  Future<BookingTransportRuntime> runtimeFor(
    String label,
  ) => runtimes.putIfAbsent(label, () async {
    final binding = BookingBackendBindingController(
      emulatorBase: StandBackend.functionsBase,
      releaseMode: false,
      initial: BackendBindingMode.testBackend,
    );
    final sessions = FileSessionStore(File('${temp.path}/session-$label.json'));
    final runtime = await BookingTransportRuntimeFactory(
      endpoint: binding.endpoint,
      client: CountingClient(),
      tokens: AuthEmulatorTokenProvider('stand-user-$label'),
      sessions: sessions,
      installations: FixedInstallationId('d4-local-installation-$label'),
      supportDirectory: () async =>
          Directory('${temp.path}/support-$label').create(recursive: true),
    ).create();
    if (await sessions.read() == null) {
      try {
        await runtime.identitySessions!.establish(requestId: const Uuid().v4());
      } on BookingCallableFailure catch (error) {
        fail('establish failed for $label with ${error.code}');
      }
    }
    return runtime;
  });

  LocalImportTestEntryGuard guard() => LocalImportTestEntryGuard(
    flag: true,
    releaseMode: false,
    binding: BookingBackendBindingController(
      emulatorBase: StandBackend.functionsBase,
      releaseMode: false,
      initial: BackendBindingMode.testBackend,
    ),
  );

  late CreateLocalDataSource datasource;
  late CreateRepositoryImpl repository;
  DateTime now = DateTime.now().toUtc();

  Future<LocalImportController> controllerFor({
    required String support,
    BookingCallablePort? port,
  }) async {
    final runtime = await runtimeFor('creator');
    return localImportControllerFor(
      accountId: 'user-1',
      port: port ?? runtime.port!,
      guard: guard(),
      source: CreateLocalImportSource(
        repository: repository,
        library: datasource,
      ),
      originals: CreateLocalImportOriginalStore(datasource),
      publisherAccess: _PageAccess(pageId),
      support: await Directory('${temp.path}/$support').create(recursive: true),
      clock: () => now,
    );
  }

  CreateDraftEntity draftOf(String localId) => userPlaceDraft(
    pageId: pageId,
    coverPath: cover.path,
    galleryPaths: <String>[photo.path],
    localId: localId,
    title: 'Kronvalda pond (import)',
  );

  LocalImportItemView itemOf(LocalImportController c, String id) =>
      c.state.items.singleWhere((item) => item.candidate.localDraftId == id);

  setUpAll(() async {
    if (stand == null) return;
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    temp = await Directory.systemTemp.createTemp('d4-local-');
    cover = await File(
      'test/fixtures/media/stand_cover.png',
    ).copy('${temp.path}/cover.png');
    photo = await File(
      'test/fixtures/media/stand_gallery_1.png',
    ).copy('${temp.path}/gallery-1.png');
    // Idempotent: the D4 gate has seeded it already.
    await stand.placeSeed();
    pageId = (await stand.placeManifest())['pageId']! as String;
    datasource = CreateLocalDataSource(const FlutterSecureStorage());
    repository = CreateRepositoryImpl(
      localDataSource: datasource,
      idGenerator: UuidV4IdGenerator(),
    );
  });

  tearDownAll(() async {
    if (stand != null && await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test(
    'an interrupted import resumes into the same server draft; lost receipts and repeats never duplicate it',
    () async {
      final String localId = 'loc_d4_${const Uuid().v4().replaceAll('-', '')}';
      await repository.saveDraft('user-1', draftOf(localId));
      final runtime = await runtimeFor('creator');
      final _LosingPort losing = _LosingPort(runtime.port!);

      final LocalImportController first = await controllerFor(
        support: 'install-a',
        port: losing,
      );
      await first.load();
      expect(
        itemOf(first, localId).candidate.classification,
        LocalImportClass.create,
      );
      await first.approve();
      losing.loseNextCreate = true;
      await first.run();
      expect(first.state.phase, LocalImportPhase.offline);
      expect(first.state.session?.status, LocalImportSessionStatus.paused);
      expect(losing.lostCreates, 1, reason: 'the server created it');
      first.dispose();

      // An app restart over the same journal resumes from the checkpoint.
      final LocalImportController restarted = await controllerFor(
        support: 'install-a',
      );
      await restarted.load();
      await restarted.run();
      expect(restarted.state.message, isNull, reason: restarted.state.message);
      expect(
        restarted.state.session?.status,
        LocalImportSessionStatus.completed,
      );
      final LocalImportReceipt receipt = itemOf(restarted, localId).receipt!;
      expect(
        receipt.state,
        LocalImportItemState.verified,
        reason: receipt.failureCode,
      );
      expect(receipt.attachments, hasLength(2));
      expect(
        itemOf(restarted, localId).candidate.classification,
        LocalImportClass.alreadyMapped,
      );

      // Receipts lost (another install directory): the server returns the
      // draft this author already imported from the same source.
      final LocalImportController fresh = await controllerFor(
        support: 'install-b',
      );
      await fresh.load();
      await fresh.approve();
      await fresh.run();
      expect(fresh.state.message, isNull, reason: fresh.state.message);
      final LocalImportReceipt again = itemOf(fresh, localId).receipt!;
      expect(again.contentId, receipt.contentId);
      expect(again.draftId, receipt.draftId);
      expect(
        again.state,
        LocalImportItemState.verified,
        reason: again.failureCode,
      );

      // A repeat on the first install has nothing to import.
      await restarted.load();
      await restarted.approve();
      expect(restarted.state.message, 'nothing_to_import');
      restarted.dispose();
      fresh.dispose();
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'the local original goes only after verification, confirmation and the recovery period',
    () async {
      final String localId = 'loc_d4_${const Uuid().v4().replaceAll('-', '')}';
      await repository.saveDraft('user-1', draftOf(localId));
      final LocalImportController c = await controllerFor(support: 'install-c');
      await c.load();
      await c.approve();
      await c.run();
      expect(c.state.message, isNull, reason: c.state.message);
      expect(
        itemOf(c, localId).cleanup.stage,
        LocalImportCleanupStage.awaitingConfirmation,
      );
      await c.deleteLocal(localId);
      expect(c.state.message, 'cleanup_awaitingConfirmation');
      await c.confirm(localId);
      await c.deleteLocal(localId);
      expect(c.state.message, 'cleanup_recoveryPeriod');
      expect(await repository.loadDraft('user-1'), isNotNull);
      now = now.add(const Duration(days: 31));
      await c.load();
      await c.deleteLocal(localId);
      expect(c.state.message, isNull, reason: c.state.message);
      expect(await repository.loadDraft('user-1'), isNull);
      // Nothing local is left to list; the server copy stays.
      expect(
        c.state.items.where((item) => item.candidate.localDraftId == localId),
        isEmpty,
      );
      c.dispose();
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'D4.1: rollback keeps the local original, survives a lost answer and a restart, and a re-import opens generation 2',
    () async {
      final String localId = 'loc_d41_${const Uuid().v4().replaceAll('-', '')}';
      await repository.saveDraft('user-1', draftOf(localId));
      final runtime = await runtimeFor('creator');
      final _LosingPort losing = _LosingPort(runtime.port!);
      final LocalImportController first = await controllerFor(
        support: 'install-d',
        port: losing,
      );
      await first.load();
      await first.approve();
      await first.run();
      final LocalImportReceipt imported = itemOf(first, localId).receipt!;
      expect(
        imported.state,
        LocalImportItemState.verified,
        reason: imported.failureCode,
      );
      final CreateDraftEntity before = (await repository.loadDraft('user-1'))!;
      final List<int> coverBefore = await cover.readAsBytes();

      losing.loseNext.add('rollbackImportedDraft');
      await first.rollback(localId);
      expect(first.state.phase, LocalImportPhase.offline);
      expect(losing.lost, 1, reason: 'the server rolled it back');
      first.dispose();

      final LocalImportController restarted = await controllerFor(
        support: 'install-d',
      );
      await restarted.load();
      expect(
        itemOf(restarted, localId).receipt?.state,
        LocalImportItemState.rollbackPending,
      );
      await restarted.deleteLocal(localId);
      expect(restarted.state.message, 'cleanup_rollbackPending');
      await restarted.rollback(localId);
      expect(restarted.state.message, isNull, reason: restarted.state.message);
      expect(
        itemOf(restarted, localId).receipt?.state,
        LocalImportItemState.rolledBack,
      );
      final FunctionsLocalImportGateway server = FunctionsLocalImportGateway(
        port: BookingPortContentAdapter(runtime.port!),
        gate: guard(),
      );
      expect((await server.draft(imported.draftId)).status, 'rolledBack');
      final LocalImportBindingView binding = await server.importBinding(
        localId,
      );
      expect(binding.rolledBack, isTrue);
      expect(binding.generation, 1);
      // The local original is exactly what was imported.
      final CreateDraftEntity after = (await repository.loadDraft('user-1'))!;
      expect(after.id, before.id);
      expect(after.updatedAtUtc, before.updatedAtUtc);
      expect(after.title, before.title);
      expect(await cover.readAsBytes(), coverBefore);
      now = now.add(const Duration(days: 31));
      await restarted.load();
      await restarted.deleteLocal(localId);
      expect(restarted.state.message, 'cleanup_rolledBack');
      expect(await repository.loadDraft('user-1'), isNotNull);

      // A new, explicit import opens generation 2 with a new server draft.
      restarted.chooseUpdate(localId);
      await restarted.approve();
      await restarted.run();
      expect(restarted.state.message, isNull, reason: restarted.state.message);
      final LocalImportReceipt second = itemOf(restarted, localId).receipt!;
      expect(
        second.state,
        LocalImportItemState.verified,
        reason: second.failureCode,
      );
      expect(second.generation, 2);
      expect(second.draftId, isNot(imported.draftId));
      expect((await server.draft(second.draftId)).importGeneration, 2);
      expect((await server.draft(imported.draftId)).status, 'rolledBack');
      restarted.dispose();
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'D4.1: a cleanup reservation on one installation stops a rollback on another; lost answers around the deletion are recovered',
    () async {
      final String localId = 'loc_d41_${const Uuid().v4().replaceAll('-', '')}';
      await repository.saveDraft('user-1', draftOf(localId));
      final runtime = await runtimeFor('creator');
      final _LosingPort losing = _LosingPort(runtime.port!);
      final LocalImportController a = await controllerFor(
        support: 'install-e',
        port: losing,
      );
      await a.load();
      await a.approve();
      await a.run();
      expect(a.state.message, isNull, reason: a.state.message);
      // Another installation of the same author: its own journal, the same
      // server draft (the import source is deduplicated by the server).
      final LocalImportController b = await controllerFor(support: 'install-f');
      await b.load();
      await b.approve();
      await b.run();
      final LocalImportReceipt onB = itemOf(b, localId).receipt!;
      expect(onB.draftId, itemOf(a, localId).receipt!.draftId);

      await a.confirm(localId);
      now = now.add(const Duration(days: 31));
      await a.load();
      // The reservation is committed, its answer lost: A keeps its intent.
      losing.loseNext.add('reserveImportCleanup');
      await a.deleteLocal(localId);
      expect(a.state.phase, LocalImportPhase.offline);
      expect(await repository.loadDraft('user-1'), isNotNull);
      // One installation: its own rollback is refused while it holds the intent.
      await a.rollback(localId);
      expect(a.state.message, 'cleanup_reserved');
      // The other installation: the server refuses, whatever the lease age.
      await b.load();
      await b.rollback(localId);
      expect(b.state.message, 'cleanup_reserved');
      expect(itemOf(b, localId).receipt?.state, LocalImportItemState.verified);
      final FunctionsLocalImportGateway server = FunctionsLocalImportGateway(
        port: BookingPortContentAdapter(runtime.port!),
        gate: guard(),
      );
      expect((await server.draft(onB.draftId)).status, 'editing');

      // A restart of A resumes with the same token; the completion answer is lost.
      a.dispose();
      final LocalImportController restarted = await controllerFor(
        support: 'install-e',
        port: losing,
      );
      await restarted.load();
      losing.loseNext.add('completeImportCleanup');
      await restarted.deleteLocal(localId);
      expect(restarted.state.phase, LocalImportPhase.offline);
      expect(await repository.loadDraft('user-1'), isNull);
      expect(restarted.state.pendingCleanups, 1);
      restarted.dispose();
      final LocalImportController again = await controllerFor(
        support: 'install-e',
      );
      await again.load();
      expect(again.state.pendingCleanups, 1);
      await again.finishCleanups();
      expect(again.state.message, isNull, reason: again.state.message);
      expect(again.state.pendingCleanups, 0);
      expect((await server.importBinding(localId)).cleanupState, 'done');

      // The original is gone: the server refuses a rollback for good, so the
      // server copy stays.
      await expectLater(
        server.rollbackImportedDraft(
          draftId: onB.draftId,
          importSourceKey: localId,
          generation: onB.generation,
          expectedRevision: onB.serverRevision,
          idempotencyKey: 'd41-stand-${const Uuid().v4()}',
        ),
        throwsA(
          isA<EventPublicationRejected>().having(
            (EventPublicationRejected refusal) => refusal.code,
            'code',
            'original_removed',
          ),
        ),
      );
      expect((await server.draft(onB.draftId)).status, 'editing');
      again.dispose();
      b.dispose();
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

/// Loses the answer of the next import create after the server committed it.
final class _LosingPort implements BookingCallablePort {
  _LosingPort(this._inner);

  final BookingCallablePort _inner;
  bool loseNextCreate = false;
  int lostCreates = 0;

  /// D4.1: command types whose next answer is lost after the server committed.
  final Set<String> loseNext = <String>{};
  int lost = 0;

  @override
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> data,
  ) async {
    final Map<String, Object?> result = await _inner.invoke(callableName, data);
    if (loseNextCreate && data['commandType'] == 'createDraft') {
      loseNextCreate = false;
      lostCreates += 1;
      throw const BookingCallableFailure(
        code: 'transport_lost',
        dispatched: true,
      );
    }
    final Object? command = data['commandType'];
    if (command is String && loseNext.remove(command)) {
      lost += 1;
      throw const BookingCallableFailure(
        code: 'transport_lost',
        dispatched: true,
      );
    }
    return result;
  }
}

final class _PageAccess implements PublisherAccessCheck {
  const _PageAccess(this.pageId);

  final String pageId;

  @override
  Future<bool> canPublishAs({
    required String actorUserId,
    required PublisherRef publisher,
  }) async => publisher.type == PublisherType.page && publisher.id == pageId;
}
