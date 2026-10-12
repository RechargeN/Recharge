import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/event_publication_composition.dart';
import 'package:recharge/app/di/activity_publication_composition.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/create/application/activity_publication_controller.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/functions_event_publication_gateway.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:uuid/uuid.dart';

import '../fixtures/create/user_activity_draft.dart';
import 'support/stand_backend.dart';

/// D3.2: the user's own Create Recharge Activity draft goes through the real
/// Content, Media and C2 moderation services of the local demo-recharge stand:
/// save (empty draft, then the full body), cover and gallery upload, submit,
/// staff review (the C2 staff script), owner publish, owner hide and a
/// moderation restriction, plus "my activities" bound to the account. The
/// draft is read back through the real Create repository.
///
/// Limits: PC host run against the local Emulator; Media uses the existing
/// fake scanner/processor; staff authority is the test-only stand registry;
/// Activity authoring is enabled on the stand by `stand-seed.mjs activity
/// seed`.
void main() {
  final stand = StandBackend.fromEnvironment();
  late Directory temp;
  late File cover;
  late List<File> gallery;
  late Map<String, Object?> seededActivity;
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
      installations: FixedInstallationId('d32-local-installation-$label'),
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

  ActivityPublicationTestEntryGuard guard() =>
      ActivityPublicationTestEntryGuard(
        flag: true,
        releaseMode: false,
        binding: BookingBackendBindingController(
          emulatorBase: StandBackend.functionsBase,
          releaseMode: false,
          initial: BackendBindingMode.testBackend,
        ),
      );

  /// The draft is saved and read back through the real Create repository;
  /// [journal] is shared when a test switches accounts on one install.
  Future<ActivityPublicationController> controllerFor(
    String label,
    CreateDraftEntity draft, {
    String journal = 'journal',
  }) async {
    final repository = CreateRepositoryImpl(
      localDataSource: CreateLocalDataSource(const FlutterSecureStorage()),
      idGenerator: UuidV4IdGenerator(),
    );
    await repository.saveDraft('user-$label', draft);
    final runtime = await runtimeFor(label);
    return activityPublicationControllerFor(
      accountId: 'user-$label',
      port: runtime.port!,
      guard: guard(),
      drafts: CreateRepositoryActivityDraftSource(repository, 'user-$label'),
      journalFile: File('${temp.path}/$journal.json'),
    );
  }

  CreateDraftEntity draftOf(String localId, {String? title}) =>
      userActivityDraft(
        pageId: seededActivity['pageId']! as String,
        coverPath: cover.path,
        galleryPaths: gallery.map((file) => file.path).toList(),
        localId: localId,
        title: title ?? 'Ķemeri bog boardwalk loop',
      );

  // Read-only inspection of this stand's immutable history. The owner API
  // returns only the current revision, so inspect the old one on loopback.
  Future<Map<String, dynamic>> storedRevision(String id) async {
    final response = await http.get(
      Uri.parse(
        'http://127.0.0.1:8080/v1/projects/demo-recharge/databases/(default)/documents/contentPublishedRevisions/$id',
      ),
      // Synthetic Emulator admin fixture, never a user credential or runtime read.
      headers: {'Authorization': 'Bearer owner'},
    );
    expect(response.statusCode, 200);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  setUpAll(() async {
    if (stand == null) return;
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    temp = await Directory.systemTemp.createTemp('d32-local-');
    cover = await File(
      'test/fixtures/media/stand_cover.png',
    ).copy('${temp.path}/cover.png');
    gallery = <File>[
      await File(
        'test/fixtures/media/stand_gallery_1.png',
      ).copy('${temp.path}/gallery-1.png'),
      await File(
        'test/fixtures/media/stand_gallery_2.png',
      ).copy('${temp.path}/gallery-2.png'),
    ];
    // Idempotent: the D3.2 gate has seeded it already.
    await stand.activitySeed();
    seededActivity = await stand.activityManifest();
  });

  tearDownAll(() async {
    if (stand != null && await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test(
    'the Creator publishes the Create Activity draft through Content, Media and review',
    () async {
      final draft = draftOf('loc_d32_${const Uuid().v4()}');
      final c = await controllerFor('creator', draft);
      await c.load();
      expect(c.state.draftTitle, draft.title);

      await c.save();
      expect(c.state.message, isNull, reason: c.state.message);
      expect(c.state.record?.bodySaved, isTrue);
      expect(c.state.status?.latestSubmissionState, isNull);

      // Before the photos are uploaded the server refuses the local ids.
      await c.submit();
      expect(c.state.message, 'validation_failed');

      await c.uploadMedia();
      expect(c.state.message, isNull, reason: c.state.message);
      expect(c.state.record?.attachments, hasLength(3));

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
        'd3.2 local: the Activity is fine',
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

      final originalRevisionId = c.state.status!.currentPublishedRevisionId!;
      final originalRevision = await storedRevision(originalRevisionId);
      final originalContentId = c.state.record!.contentId;
      final originalDraftRevision = c.state.record!.draftRevision;
      await c.hide();
      expect(c.state.status!.visibility, 'withdrawn');
      await c.activate();
      expect(c.state.message, isNull, reason: c.state.message);
      expect(c.state.status!.visibility, 'visible');
      expect(c.state.status!.currentPublishedRevisionId, originalRevisionId);
      await c.beginEditing();
      expect(c.state.canSubmit, isFalse);
      c.dispose();
      // Resume editing after restart, preserving the Content binding and media.
      final edited = await controllerFor(
        'creator',
        draft.copyWith(title: 'Edited boardwalk Activity'),
      );
      await edited.load();
      expect(edited.state.record!.editingFromRevisionId, originalRevisionId);
      await edited.save();
      expect(edited.state.message, isNull, reason: edited.state.message);
      expect(edited.state.record!.contentId, originalContentId);
      expect(
        edited.state.record!.draftRevision,
        greaterThan(originalDraftRevision),
      );
      expect(
        edited.state.status!.currentPublishedRevisionId,
        originalRevisionId,
      );
      expect(await storedRevision(originalRevisionId), originalRevision);
      await edited.submit();
      expect(edited.state.status!.latestSubmissionState, 'under_review');
      await edited.publish();
      expect(edited.state.message, 'moderation_required');
      expect(
        edited.state.status!.currentPublishedRevisionId,
        originalRevisionId,
      );
      final editApproved = await stand.moderate(<String>[
        'approve',
        edited.state.status!.latestSubmissionId!,
        '--reason',
        'd3.7: revised draft approved',
      ]);
      expect(editApproved.exitCode, 0, reason: '${editApproved.json}');
      await edited.refresh();
      await edited.publish();
      expect(edited.state.message, isNull, reason: edited.state.message);
      expect(
        edited.state.status!.currentPublishedRevisionId,
        isNot(originalRevisionId),
      );
      expect(
        edited.state.status!.previousPublishedRevisionId,
        originalRevisionId,
      );
      expect(edited.state.record!.editingFromRevisionId, isNull);
      expect(await storedRevision(originalRevisionId), originalRevision);

      // The owner hides it; then staff restricts it: moderation wins the view.
      await edited.hide();
      expect(edited.state.status?.visibility, 'withdrawn');
      final restricted = await stand.moderate(<String>[
        'restrict',
        edited.state.record!.contentId,
        '--reason',
        'd3.2 local: restricted by staff',
      ]);
      expect(restricted.exitCode, 0, reason: '${restricted.json}');
      await edited.refresh();
      expect(edited.state.status?.visibility, 'restricted');
      expect(edited.state.status?.ownerHold, 'withdrawn');
      edited.dispose();
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'a repeated save after a fresh start reuses the same server draft',
    () async {
      final draft = draftOf('loc_d32_repeat_${const Uuid().v4()}');
      final first = await controllerFor('creator', draft, journal: 'repeat');
      await first.load();
      await first.save();
      final contentId = first.state.record!.contentId;
      first.dispose();
      // A new controller (app restart) with the same journal and draft.
      final again = await controllerFor('creator', draft, journal: 'repeat');
      await again.load();
      expect(again.state.record?.contentId, contentId);
      await again.save();
      expect(again.state.message, isNull, reason: again.state.message);
      expect(again.state.record?.contentId, contentId);
      expect(again.state.myObjects, hasLength(1));
      again.dispose();
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'another account on the same install never uses the record, and cannot author for the Page',
    () async {
      final draft = draftOf('loc_d32_switch_${const Uuid().v4()}');
      final creator = await controllerFor('creator', draft, journal: 'shared');
      await creator.load();
      await creator.save();
      expect(creator.state.record, isNotNull);
      creator.dispose();
      final viewer = await controllerFor('viewer', draft, journal: 'shared');
      await viewer.load();
      expect(viewer.state.record, isNull);
      expect(viewer.state.myObjects, isEmpty);
      await viewer.save();
      expect(viewer.state.message, isNotNull);
      expect(viewer.state.record, isNull);
      viewer.dispose();
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'the seeded Activity of the stand is a Content publication (manifest ids)',
    () async {
      final runtime = await runtimeFor('creator');
      final gateway = FunctionsEventPublicationGateway(
        port: BookingPortContentAdapter(runtime.port!),
        gate: guard(),
        typeId: 'activity',
      );
      final status = await gateway.status(
        seededActivity['contentId']! as String,
      );
      expect(status.visibility, 'visible');
      expect(
        status.currentPublishedRevisionId,
        seededActivity['publishedRevisionId'],
      );
      expect(status.latestSubmissionState, 'published');
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
