import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/event_publication_composition.dart';
import 'package:recharge/app/di/rental_publication_composition.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/create/application/rental_publication_controller.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/functions_event_publication_gateway.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:uuid/uuid.dart';

import '../fixtures/create/user_rental_draft.dart';
import 'support/content_fault_client.dart';
import 'support/stand_backend.dart';

/// D3.3: the user's own Create Rental draft goes through the real Content,
/// Media and C2 moderation services of the local demo-recharge stand: save
/// (empty draft, then the body attested by this account), cover and gallery
/// upload, submit, staff review (the C2 staff script), owner publish, owner
/// hide and a moderation restriction, plus "my rentals" bound to the account.
/// The draft is read back through the real Create repository.
///
/// Limits: PC host run against the local Emulator; Media uses the existing
/// fake scanner/processor; staff authority is the test-only stand registry;
/// the Rental policy is the Emulator TEST-ONLY policy; Rental authoring is
/// enabled on the stand by `stand-seed.mjs rental seed`.
DateTime todayUtc() {
  final DateTime now = DateTime.now().toUtc();
  return DateTime.utc(now.year, now.month, now.day);
}

void main() {
  final stand = StandBackend.fromEnvironment();
  late Directory temp;
  late File cover;
  late List<File> gallery;
  late Map<String, Object?> seededRental;
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
      installations: FixedInstallationId('d33-local-installation-$label'),
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

  RentalPublicationTestEntryGuard guard() => RentalPublicationTestEntryGuard(
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
  Future<RentalPublicationController> controllerFor(
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
    return rentalPublicationControllerFor(
      accountId: 'user-$label',
      port: runtime.port!,
      guard: guard(),
      drafts: CreateRepositoryRentalDraftSource(repository, 'user-$label'),
      journalFile: File('${temp.path}/$journal.json'),
    );
  }

  // Confirmed and attested today by the stand Creator account (§2 Q3, Q5).
  PublicationProbe probe(RentalPublicationController c) => PublicationProbe(
    load: c.load,
    save: c.save,
    uploadMedia: c.uploadMedia,
    submit: c.submit,
    publish: c.publish,
    refresh: c.refresh,
    dispose: c.dispose,
    message: () => c.state.message,
    offline: () => c.state.phase == RentalPublicationPhase.offline,
    journaledSubmissionId: () => c.state.record?.submissionId,
    status: () => c.state.status,
  );

  Future<void> approve(String submissionId) async {
    final approved = await stand!.moderate(<String>[
      'approve',
      submissionId,
      '--reason',
      'm1 stage 2: the Rental is fine',
    ]);
    expect(approved.exitCode, 0, reason: '${approved.json}');
  }

  CreateDraftEntity draftOf(String localId, {String? title}) => userRentalDraft(
    pageId: seededRental['pageId']! as String,
    coverPath: cover.path,
    galleryPaths: gallery.map((file) => file.path).toList(),
    localId: localId,
    accountId: 'user-creator',
    anchor: todayUtc(),
    title: title ?? 'Kipsala sea kayak rental',
  );

  setUpAll(() async {
    if (stand == null) return;
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    temp = await Directory.systemTemp.createTemp('d33-local-');
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
    // Idempotent: the D3.3 gate has seeded it already.
    await stand.rentalSeed();
    seededRental = await stand.rentalManifest();
  });

  tearDownAll(() async {
    if (stand != null && await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test(
    'the Creator publishes the Create Rental draft through Content, Media and review',
    () async {
      final draft = draftOf('loc_d33_${const Uuid().v4()}');
      final c = await controllerFor('creator', draft);
      await c.load();
      expect(c.state.draftTitle, draft.title);

      await c.save();
      expect(c.state.message, isNull, reason: c.state.message);
      expect(c.state.record?.authorApplied, isTrue);
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
        'd3.3 local: the Rental is fine',
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
        'd3.3 local: restricted by staff',
      ]);
      expect(restricted.exitCode, 0, reason: '${restricted.json}');
      await c.refresh();
      expect(c.state.status?.visibility, 'restricted');
      expect(c.state.status?.ownerHold, 'withdrawn');
      c.dispose();
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'a repeated save after a fresh start reuses the same server draft',
    () async {
      final draft = draftOf('loc_d33_repeat_${const Uuid().v4()}');
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
    'another account on the same install never sends the Creator\'s confirmation',
    () async {
      final draft = draftOf('loc_d33_switch_${const Uuid().v4()}');
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
    'the seeded Rental of the stand is a Content publication (manifest ids)',
    () async {
      final runtime = await runtimeFor('creator');
      final gateway = FunctionsEventPublicationGateway(
        port: BookingPortContentAdapter(runtime.port!),
        gate: guard(),
        typeId: 'rental',
      );
      final status = await gateway.status(seededRental['contentId']! as String);
      expect(status.visibility, 'visible');
      expect(
        status.currentPublishedRevisionId,
        seededRental['publishedRevisionId'],
      );
      expect(status.latestSubmissionState, 'published');
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'M1 S1-S3 submit: severed, lost answer, restart and retry give one submission',
    () async {
      final draft = draftOf('loc_m1_rental_submit_${const Uuid().v4()}');
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
      final draft = draftOf('loc_m1_rental_publish_${const Uuid().v4()}');
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
