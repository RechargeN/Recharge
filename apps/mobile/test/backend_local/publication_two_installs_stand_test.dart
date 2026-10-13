import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/event_publication_composition.dart';
import 'package:recharge/app/di/place_publication_composition.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/create/application/place_publication_controller.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/functions_event_publication_gateway.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/place_publication.dart';
import 'package:recharge/features/create/presentation/widgets/place_publication_section.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:uuid/uuid.dart';

import '../fixtures/create/user_place_draft.dart';
import 'support/stand_backend.dart';

/// M1 stage 2, S7: one user, two installations, one Place draft. Install B
/// got the draft and the publication journal by restoring app data from
/// install A; it has its own installation id and its own server-issued
/// Session (no credential or installation identity is copied). A saves an
/// edit; B then saves its own edit on the older revision and the server
/// refuses it with `revision_conflict`. A's edit stays on the server, B's
/// local edit stays on B, and nothing overwrites automatically: a refresh only
/// fetches the actual revision, and B's version is written once, on top of
/// A's, only when the user taps "Save my version" in the Place section.
///
/// Each install's local Create store is the process-wide secure storage mock,
/// switched between A and B like two devices; the backend is the real stand.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final stand = StandBackend.fromEnvironment();
  late Directory temp;
  late File cover;
  late List<File> gallery;
  late String pageId;

  Future<BookingTransportRuntime> install(String name) async {
    final binding = BookingBackendBindingController(
      emulatorBase: StandBackend.functionsBase,
      releaseMode: false,
      initial: BackendBindingMode.testBackend,
    );
    final sessions = FileSessionStore(File('${temp.path}/session-$name.json'));
    final runtime = await BookingTransportRuntimeFactory(
      endpoint: binding.endpoint,
      client: CountingClient(),
      tokens: AuthEmulatorTokenProvider('stand-user-creator'),
      sessions: sessions,
      installations: FixedInstallationId('m1-two-installs-$name'),
      supportDirectory: () async =>
          Directory('${temp.path}/support-$name').create(recursive: true),
    ).create();
    try {
      await runtime.identitySessions!.establish(requestId: const Uuid().v4());
    } on BookingCallableFailure catch (error) {
      fail('establish failed for install $name with ${error.code}');
    }
    return runtime;
  }

  BookingBackendBindingController testBinding() =>
      BookingBackendBindingController(
        emulatorBase: StandBackend.functionsBase,
        releaseMode: false,
        initial: BackendBindingMode.testBackend,
      );

  CreateRepositoryImpl repository() => CreateRepositoryImpl(
    localDataSource: CreateLocalDataSource(const FlutterSecureStorage()),
    idGenerator: UuidV4IdGenerator(),
  );

  PlacePublicationController controllerOn(
    BookingTransportRuntime runtime,
    CreateRepositoryImpl repo,
    File journal,
  ) => placePublicationControllerFor(
    accountId: 'user-creator',
    port: runtime.port!,
    guard: PlacePublicationTestEntryGuard(
      flag: true,
      releaseMode: false,
      binding: testBinding(),
    ),
    drafts: CreateRepositoryPlaceDraftSource(repo, 'user-creator'),
    journalFile: journal,
  );

  CreateDraftEntity draft(String localId, String title) => userPlaceDraft(
    pageId: pageId,
    coverPath: cover.path,
    galleryPaths: gallery.map((file) => file.path).toList(),
    localId: localId,
    title: title,
  );

  setUpAll(() async {
    if (stand == null) return;
    temp = await Directory.systemTemp.createTemp('m1-two-installs-');
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
    // Idempotent: the D3.1 gate has seeded it already.
    await stand.placeSeed();
    pageId = (await stand.placeManifest())['pageId']! as String;
  });

  tearDownAll(() async {
    if (stand != null && await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  testWidgets(
    'S7: a save on the older revision from the second install is a revision_conflict; nothing is overwritten until the user saves their version',
    (WidgetTester tester) async {
      final localId = 'loc_m1_two_installs_${const Uuid().v4()}';
      final journalA = File('${temp.path}/journal-a.json');
      final journalB = File('${temp.path}/journal-b.json');
      late PlacePublicationRecord bound;
      late int afterA;
      late PlacePublicationController b;
      late FunctionsEventPublicationGateway gateway;
      late CreateRepositoryImpl repoB;
      final editB = draft(localId, 'Pond (edit B)');

      await tester.runAsync(() async {
        // Install A: the first save binds the draft to the server.
        final runtimeA = await install('a');
        FlutterSecureStorage.setMockInitialValues(<String, String>{});
        final repoA = repository();
        await repoA.saveDraft('user-creator', draft(localId, 'Kronvalda pond'));
        final a = controllerOn(runtimeA, repoA, journalA);
        await a.load();
        await a.save();
        expect(a.state.message, isNull, reason: a.state.message);
        bound = a.state.record!;

        // Install B restores A's app data: the draft and the journal only.
        await journalA.copy(journalB.path);

        // A edits and saves first.
        await repoA.saveDraft('user-creator', draft(localId, 'Pond (edit A)'));
        await a.load();
        await a.save();
        expect(a.state.message, isNull, reason: a.state.message);
        afterA = a.state.record!.draftRevision;
        expect(afterA, greaterThan(bound.draftRevision));
        a.dispose();

        // Install B: its own device store, installation id and Session.
        FlutterSecureStorage.setMockInitialValues(<String, String>{});
        repoB = repository();
        await repoB.saveDraft('user-creator', editB);
        final runtimeB = await install('b');
        b = controllerOn(runtimeB, repoB, journalB);
        gateway = FunctionsEventPublicationGateway(
          port: BookingPortContentAdapter(runtimeB.port!),
          gate: EventPublicationTestEntryGuard(
            flag: true,
            releaseMode: false,
            binding: testBinding(),
          ),
          typeId: 'place',
        );
        await b.load();
        expect(
          b.state.record?.draftId,
          bound.draftId,
          reason: 'restored binding',
        );
        expect(b.state.record?.draftRevision, bound.draftRevision);
        await b.save();
        expect(b.state.message, 'revision_conflict');
        expect(b.state.conflict?.serverRevision, afterA);

        // Nothing was overwritten: the server keeps A's revision, B its edit.
        expect((await gateway.draft(bound.draftId)).revision, afterA);
        expect(b.state.record?.draftRevision, bound.draftRevision);
        expect((await repoB.loadDraft('user-creator'))?.title, editB.title);

        // A refresh fetches the actual revision; a plain save still never
        // writes B's edit over A's.
        await b.refresh();
        expect(b.state.conflict?.serverRevision, afterA);
        await b.save();
        expect(b.state.message, 'revision_conflict');
        expect((await gateway.draft(bound.draftId)).revision, afterA);
      });

      // The explicit choice, through the UI of install B.
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlacePublicationSection(controller: b),
            ),
          ),
        ),
      );
      Future<void> waitFor(Finder finder) async {
        final deadline = DateTime.now().add(const Duration(seconds: 60));
        while (DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 200));
          if (finder.evaluate().isNotEmpty) return;
        }
        fail('timed out waiting for $finder');
      }

      await waitFor(find.byKey(const Key('place-publication-conflict')));
      final saveMine = find.byWidgetPredicate(
        (widget) =>
            widget.key == const Key('place-publication-save-over-server') &&
            widget is ButtonStyleButton &&
            widget.onPressed != null,
      );
      await waitFor(saveMine);
      await tester.tap(saveMine);
      final deadline = DateTime.now().add(const Duration(seconds: 60));
      while (b.state.conflict != null ||
          b.state.phase != PlacePublicationPhase.ready) {
        if (DateTime.now().isAfter(deadline)) {
          fail('the explicit save did not finish');
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump();
      }
      expect(b.state.message, isNull, reason: b.state.message);
      expect(find.byKey(const Key('place-publication-conflict')), findsNothing);
      final revision = await tester.runAsync(
        () async => (await gateway.draft(bound.draftId)).revision,
      );
      expect(revision, afterA + 1, reason: 'one explicit write on top of A');
      expect(b.state.record?.draftRevision, afterA + 1);
      b.dispose();
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
