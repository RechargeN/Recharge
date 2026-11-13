import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/event_publication_composition.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/create/application/event_publication_controller.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/functions_event_publication_gateway.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:uuid/uuid.dart';

import '../fixtures/create/user_event_draft.dart';
import 'support/content_fault_client.dart';
import 'support/stand_backend.dart';

/// C3: the user's own Create Event draft goes through the real Content,
/// Media and C2 moderation services of the local demo-recharge stand: save,
/// cover upload, submit, staff review (the C2 staff script), owner publish,
/// owner hide and a moderation restriction, plus the "my objects" list. The
/// draft is read back through the real Create repository.
///
/// Limits: PC host run against the local Emulator; Media uses the existing
/// fake scanner/processor; staff authority is the test-only stand registry.
void main() {
  final stand = StandBackend.fromEnvironment();
  late Directory temp;
  late File cover;
  late Map<String, Object?> seededEvent;
  final runtimes = <String, Future<BookingTransportRuntime>>{};
  // M1 stage 2: real HTTP that a test can sever or make lose one answer.
  final faults = ContentFaultClient();

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
      client: faults,
      tokens: AuthEmulatorTokenProvider('stand-user-$label'),
      sessions: sessions,
      installations: FixedInstallationId('c3-local-installation-$label'),
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

  EventPublicationTestEntryGuard guard() => EventPublicationTestEntryGuard(
    flag: true,
    releaseMode: false,
    binding: BookingBackendBindingController(
      emulatorBase: StandBackend.functionsBase,
      releaseMode: false,
      initial: BackendBindingMode.testBackend,
    ),
  );

  /// The draft is saved and read back through the real Create repository;
  /// [journal] names a separate journal file (a restart reuses it).
  Future<EventPublicationController> controllerFor(
    String label,
    CreateDraftEntity draft, {
    String? journal,
  }) async {
    final repository = CreateRepositoryImpl(
      localDataSource: CreateLocalDataSource(const FlutterSecureStorage()),
      idGenerator: UuidV4IdGenerator(),
    );
    await repository.saveDraft('user-$label', draft);
    final runtime = await runtimeFor(label);
    return eventPublicationControllerFor(
      port: runtime.port!,
      guard: guard(),
      drafts: CreateRepositoryEventDraftSource(repository, 'user-$label'),
      journalFile: File('${temp.path}/${journal ?? 'journal-$label'}.json'),
    );
  }

  PublicationProbe probe(EventPublicationController c) => PublicationProbe(
    load: c.load,
    save: c.save,
    uploadMedia: c.uploadCover,
    submit: c.submit,
    publish: c.publish,
    refresh: c.refresh,
    dispose: c.dispose,
    message: () => c.state.message,
    offline: () => c.state.phase == EventPublicationPhase.offline,
    journaledSubmissionId: () => c.state.record?.submissionId,
    status: () => c.state.status,
  );

  Future<void> approve(String submissionId) async {
    final approved = await stand!.moderate(<String>[
      'approve',
      submissionId,
      '--reason',
      'm1 stage 2: the Event is fine',
    ]);
    expect(approved.exitCode, 0, reason: '${approved.json}');
  }

  setUpAll(() async {
    if (stand == null) return;
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    temp = await Directory.systemTemp.createTemp('c3-local-');
    cover = await File(
      'test/fixtures/media/stand_cover.png',
    ).copy('${temp.path}/cover.png');
    final manifest = await stand.manifest();
    seededEvent = Map<String, Object?>.from(manifest['contentEvent']! as Map);
  });

  tearDownAll(() async {
    if (stand != null && await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test(
    'the Creator publishes the Create draft through Content, Media and review',
    () async {
      final draft = userEventDraft(
        pageId: seededEvent['pageId']! as String,
        coverPath: cover.path,
        localId: 'loc_c3_${const Uuid().v4()}',
      );
      final c = await controllerFor('creator', draft);
      await c.load();
      expect(c.state.draftTitle, draft.title);

      await c.save();
      expect(c.state.message, isNull);
      expect(c.state.record, isNotNull);
      expect(c.state.status?.latestSubmissionState, isNull);

      await c.uploadCover();
      expect(c.state.message, isNull, reason: c.state.message);
      expect(c.state.record?.coverAssetId, isNotNull);

      await c.submit();
      expect(c.state.message, isNull, reason: c.state.message);
      expect(c.state.status?.latestSubmissionState, 'under_review');
      expect(c.state.canPublish, isFalse);
      // The server enforces the review, not the button.
      await c.publish();
      expect(c.state.message, 'moderation_required');

      final approved = await stand!.moderate(<String>[
        'approve',
        c.state.status!.latestSubmissionId!,
        '--reason',
        'c3 local: the Event is fine',
      ]);
      expect(approved.exitCode, 0, reason: '${approved.json}');

      await c.refresh();
      expect(c.state.status?.latestSubmissionState, 'approved_for_publication');
      await c.publish();
      expect(c.state.message, isNull, reason: c.state.message);
      expect(c.state.status?.visibility, 'visible');
      expect(c.state.status?.currentPublishedRevisionId, isNotNull);
      final mine = c.state.myObjects.single;
      expect(mine.record.contentId, c.state.record!.contentId);
      expect(mine.status?.visibility, 'visible');

      // The owner hides it; then staff restricts it: moderation wins the view.
      await c.hide();
      expect(c.state.status?.visibility, 'withdrawn');
      final restricted = await stand.moderate(<String>[
        'restrict',
        c.state.record!.contentId,
        '--reason',
        'c3 local: restricted by staff',
      ]);
      expect(restricted.exitCode, 0, reason: '${restricted.json}');
      await c.refresh();
      expect(c.state.status?.visibility, 'restricted');
      expect(c.state.status?.ownerHold, 'withdrawn');
      expect(c.state.myObjects.single.status?.visibility, 'restricted');
      c.dispose();
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'a user without Creator authority for the Page cannot create it',
    () async {
      final draft = userEventDraft(
        pageId: seededEvent['pageId']! as String,
        coverPath: cover.path,
        localId: 'loc_c3_viewer_${const Uuid().v4()}',
      );
      final c = await controllerFor('viewer', draft);
      await c.load();
      await c.save();
      expect(c.state.message, isNotNull);
      expect(c.state.record, isNull);
      expect(c.state.myObjects, isEmpty);
      c.dispose();
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'the seeded Event of the stand is a Content publication (manifest ids)',
    () async {
      final runtime = await runtimeFor('creator');
      final gateway = FunctionsEventPublicationGateway(
        port: BookingPortContentAdapter(runtime.port!),
        gate: guard(),
      );
      final status = await gateway.status(seededEvent['contentId']! as String);
      expect(status.visibility, 'visible');
      expect(
        status.currentPublishedRevisionId,
        seededEvent['publishedRevisionId'],
      );
      expect(status.latestSubmissionState, 'published');
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'M1 S4: a repeated save after a fresh start reuses the same server draft',
    () async {
      final draft = userEventDraft(
        pageId: seededEvent['pageId']! as String,
        coverPath: cover.path,
        localId: 'loc_m1_event_repeat_${const Uuid().v4()}',
      );
      final first = await controllerFor('creator', draft, journal: 'repeat');
      await first.load();
      await first.save();
      expect(first.state.message, isNull, reason: first.state.message);
      final contentId = first.state.record!.contentId;
      final draftId = first.state.record!.draftId;
      first.dispose();
      // A new controller (app restart) with the same journal and draft.
      final again = await controllerFor('creator', draft, journal: 'repeat');
      await again.load();
      expect(again.state.record?.contentId, contentId);
      await again.save();
      expect(again.state.message, isNull, reason: again.state.message);
      expect(again.state.record?.contentId, contentId);
      expect(again.state.record?.draftId, draftId);
      expect(again.state.myObjects, hasLength(1));
      again.dispose();
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'M1 S1-S3 submit: severed, lost answer, restart and retry give one submission',
    () async {
      final draft = userEventDraft(
        pageId: seededEvent['pageId']! as String,
        coverPath: cover.path,
        localId: 'loc_m1_event_submit_${const Uuid().v4()}',
      );
      await expectSubmitSurvivesFaults(
        faults,
        () async => probe(
          await controllerFor('creator', draft, journal: 'submit-faults'),
        ),
      );
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'M1 S1-S3 publish: severed, lost answer, restart and retry give one publication',
    () async {
      final draft = userEventDraft(
        pageId: seededEvent['pageId']! as String,
        coverPath: cover.path,
        localId: 'loc_m1_event_publish_${const Uuid().v4()}',
      );
      await expectPublishSurvivesFaults(
        faults,
        () async => probe(
          await controllerFor('creator', draft, journal: 'publish-faults'),
        ),
        approve,
      );
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
