import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/event_publication_composition.dart';
import 'package:recharge/app/di/place_publication_composition.dart';
import 'package:recharge/app/di/service_locator.dart';
import 'package:recharge/app/presentation/place_publication_panel.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/auth/application/auth_providers.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/create/application/event_publication_controller.dart';
import 'package:recharge/features/create/application/place_publication_controller.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/functions_event_publication_gateway.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:uuid/uuid.dart';

import '../fixtures/create/user_event_draft.dart';
import '../fixtures/create/user_place_draft.dart';
import 'support/event_details_harness.dart';
import 'support/stand_backend.dart';

/// M1 stage 2, S5/S6: Page access is withdrawn and restored on the server
/// through the Identity owner services only (`setCapabilities` on the owner's
/// own membership, `decidePage` suspend/reverify by the stand staff), while
/// the client keeps its old view of that access. Save, submit and publish are
/// each refused by the server from a prepared stage: a typed code, the local
/// draft and the journal (binding and retry keys) unchanged, no server
/// progress. After the access returns the same controller retries and the
/// stage completes once. Every withdrawal is restored in `finally`, and the
/// gate checks the stand invariants afterwards.
///
/// Limits: PC host run against the local Emulator; Media uses the existing
/// fake scanner/processor; staff authority is the test-only stand registry.
/// The terminal `revokeMembership` is out of client M1 (no owner path adds a
/// second member to revoke).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final stand = StandBackend.fromEnvironment();
  late Directory temp;
  late File cover;
  late List<File> gallery;
  late String eventPageId;
  late String placePageId;
  // One Session for the whole file: the controller and UI paths share it.
  BookingTransportRuntime? shared;

  Future<BookingTransportRuntime> runtime() async {
    if (shared != null) return shared!;
    final binding = BookingBackendBindingController(
      emulatorBase: StandBackend.functionsBase,
      releaseMode: false,
      initial: BackendBindingMode.testBackend,
    );
    final sessions = FileSessionStore(File('${temp.path}/session.json'));
    final created = await BookingTransportRuntimeFactory(
      endpoint: binding.endpoint,
      client: CountingClient(),
      tokens: AuthEmulatorTokenProvider('stand-user-creator'),
      sessions: sessions,
      installations: const FixedInstallationId('m1-page-installation-creator'),
      supportDirectory: () async =>
          Directory('${temp.path}/support').create(recursive: true),
    ).create();
    if (await sessions.read() == null) {
      try {
        await created.identitySessions!.establish(requestId: const Uuid().v4());
      } on BookingCallableFailure catch (error) {
        fail('establish failed with ${error.code}');
      }
    }
    return shared = created;
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

  Future<FunctionsEventPublicationGateway> gateway(String typeId) async =>
      FunctionsEventPublicationGateway(
        port: BookingPortContentAdapter((await runtime()).port!),
        gate: EventPublicationTestEntryGuard(
          flag: true,
          releaseMode: false,
          binding: testBinding(),
        ),
        typeId: typeId,
      );

  Future<EventPublicationController> eventController(
    CreateDraftEntity draft,
    String journal,
  ) async {
    final repo = repository();
    await repo.saveDraft('user-creator', draft);
    return eventPublicationControllerFor(
      port: (await runtime()).port!,
      guard: EventPublicationTestEntryGuard(
        flag: true,
        releaseMode: false,
        binding: testBinding(),
      ),
      drafts: CreateRepositoryEventDraftSource(repo, 'user-creator'),
      journalFile: File('${temp.path}/$journal.json'),
    );
  }

  Future<PlacePublicationController> placeController(
    CreateDraftEntity draft,
    String journal,
  ) async {
    final repo = repository();
    await repo.saveDraft('user-creator', draft);
    return placePublicationControllerFor(
      accountId: 'user-creator',
      port: (await runtime()).port!,
      guard: PlacePublicationTestEntryGuard(
        flag: true,
        releaseMode: false,
        binding: testBinding(),
      ),
      drafts: CreateRepositoryPlaceDraftSource(repo, 'user-creator'),
      journalFile: File('${temp.path}/$journal.json'),
    );
  }

  CreateDraftEntity eventDraft(String localId, {String? title}) =>
      userEventDraft(
        pageId: eventPageId,
        coverPath: cover.path,
        localId: localId,
        title: title ?? 'Pottery evening at the studio',
      );

  CreateDraftEntity placeDraft(String localId, {String? title}) =>
      userPlaceDraft(
        pageId: placePageId,
        coverPath: cover.path,
        galleryPaths: gallery.map((file) => file.path).toList(),
        localId: localId,
        title: title ?? 'Kronvalda park pond',
      );

  Future<void> approve(String submissionId) async {
    final approved = await stand!.moderate(<String>[
      'approve',
      submissionId,
      '--reason',
      'm1 stage 2: approved',
    ]);
    expect(approved.exitCode, 0, reason: '${approved.json}');
  }

  /// Withdraws the Content capabilities of the creator on [pageId], runs
  /// [whileWithdrawn], and always puts back exactly the saved set.
  Future<void> withCapabilitiesWithdrawn(
    String pageId,
    Future<void> Function() whileWithdrawn,
  ) async {
    final withdrawn = await stand!.pageAccess(<String>[
      'withdraw-publish',
      'creator',
      pageId,
    ]);
    final saved = (withdrawn['before']! as List<Object?>).cast<String>();
    expect(withdrawn['after'], isNot(contains('content.publish')));
    try {
      await whileWithdrawn();
    } finally {
      final restored = await stand.pageAccess(<String>[
        'restore-publish',
        'creator',
        pageId,
        saved.join(','),
      ]);
      expect(restored['after'], saved);
    }
  }

  /// Suspends [pageId] through staff, runs [whileSuspended], always reverifies.
  Future<void> withPageSuspended(
    String pageId,
    Future<void> Function() whileSuspended,
  ) async {
    final suspended = await stand!.pageAccess(<String>['suspend', pageId]);
    expect(suspended['verificationStatus'], 'suspended');
    try {
      await whileSuspended();
    } finally {
      final reverified = await stand.pageAccess(<String>['reverify', pageId]);
      expect(reverified['verificationStatus'], 'verified');
      expect(reverified['status'], 'active');
    }
  }

  setUpAll(() async {
    if (stand == null) return;
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    temp = await Directory.systemTemp.createTemp('m1-page-');
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
    final manifest = await stand.manifest();
    eventPageId =
        (manifest['contentEvent']! as Map<String, Object?>)['pageId']!
            as String;
    // Idempotent: the D3.1 gate has seeded it already.
    await stand.placeSeed();
    placePageId = (await stand.placeManifest())['pageId']! as String;
  });

  tearDownAll(() async {
    if (stand != null && await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  // ---- Event, capabilities withdrawn (S5) ----

  test(
    'S5 Event save: refused while withdrawn, draft and binding kept, then saved once',
    () async {
      final localId = 'loc_m1_page_event_save_${const Uuid().v4()}';
      final c = await eventController(eventDraft(localId), 'event-save');
      await c.load();
      await c.save();
      expect(c.state.message, isNull, reason: c.state.message);
      final record = c.state.record!;
      // The user edits the draft locally; the client still believes it may save.
      final edited = eventDraft(localId, title: 'Pottery evening (edited)');
      await repository().saveDraft('user-creator', edited);
      await c.load();
      await withCapabilitiesWithdrawn(eventPageId, () async {
        await c.save();
        expect(c.state.message, 'capability_denied');
      });
      expect(c.state.record?.draftRevision, record.draftRevision);
      expect(c.state.record?.draftId, record.draftId);
      expect(
        (await repository().loadDraft('user-creator'))?.title,
        edited.title,
        reason: 'the local edit is kept',
      );
      final server = await (await gateway('event')).draft(record.draftId);
      expect(server.revision, record.draftRevision, reason: 'no server write');

      await c.save();
      expect(c.state.message, isNull, reason: c.state.message);
      expect(c.state.record?.draftId, record.draftId);
      expect(c.state.record!.draftRevision, greaterThan(record.draftRevision));
      c.dispose();
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'S5 Event submit: refused while withdrawn, no submission, then one submission',
    () async {
      final localId = 'loc_m1_page_event_submit_${const Uuid().v4()}';
      final c = await eventController(eventDraft(localId), 'event-submit');
      await c.load();
      await c.save();
      await c.uploadCover();
      expect(c.state.message, isNull, reason: c.state.message);
      final record = c.state.record!;
      await withCapabilitiesWithdrawn(eventPageId, () async {
        await c.submit();
        expect(c.state.message, 'capability_denied');
        expect(c.state.record?.submissionId, isNull);
      });
      final status = await (await gateway('event')).status(record.contentId);
      expect(status.latestSubmissionId, isNull, reason: 'nothing submitted');

      await c.submit();
      expect(c.state.message, isNull, reason: c.state.message);
      expect(c.state.status?.latestSubmissionState, 'under_review');
      expect(c.state.record?.submissionId, c.state.status?.latestSubmissionId);
      c.dispose();
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'S5 Event publish: refused while withdrawn, nothing published, then one publication',
    () async {
      final localId = 'loc_m1_page_event_publish_${const Uuid().v4()}';
      final c = await eventController(eventDraft(localId), 'event-publish');
      await c.load();
      await c.save();
      await c.uploadCover();
      await c.submit();
      expect(c.state.message, isNull, reason: c.state.message);
      await approve(c.state.status!.latestSubmissionId!);
      await c.refresh();
      expect(c.state.status?.latestSubmissionState, 'approved_for_publication');
      final contentId = c.state.record!.contentId;
      await withCapabilitiesWithdrawn(eventPageId, () async {
        await c.publish();
        expect(c.state.message, 'capability_denied');
      });
      final status = await (await gateway('event')).status(contentId);
      expect(
        status.currentPublishedRevisionId,
        isNull,
        reason: 'not published',
      );
      expect(status.latestSubmissionState, 'approved_for_publication');

      await c.publish();
      expect(c.state.message, isNull, reason: c.state.message);
      expect(c.state.status?.visibility, 'visible');
      expect(c.state.status?.currentPublishedRevisionId, isNotNull);
      c.dispose();
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 4)),
  );

  // ---- Place, capabilities withdrawn (S5) ----

  test(
    'S5 Place save: refused while withdrawn, draft and binding kept, then saved once',
    () async {
      final localId = 'loc_m1_page_place_save_${const Uuid().v4()}';
      final c = await placeController(placeDraft(localId), 'place-save');
      await c.load();
      await c.save();
      expect(c.state.message, isNull, reason: c.state.message);
      final record = c.state.record!;
      final edited = placeDraft(localId, title: 'Kronvalda pond (edited)');
      await repository().saveDraft('user-creator', edited);
      await c.load();
      await withCapabilitiesWithdrawn(placePageId, () async {
        await c.save();
        expect(c.state.message, 'capability_denied');
      });
      expect(c.state.record?.draftRevision, record.draftRevision);
      expect(c.state.record?.draftId, record.draftId);
      expect(
        (await repository().loadDraft('user-creator'))?.title,
        edited.title,
        reason: 'the local edit is kept',
      );
      final server = await (await gateway('place')).draft(record.draftId);
      expect(server.revision, record.draftRevision, reason: 'no server write');

      await c.save();
      expect(c.state.message, isNull, reason: c.state.message);
      expect(c.state.record?.draftId, record.draftId);
      expect(c.state.record!.draftRevision, greaterThan(record.draftRevision));
      c.dispose();
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'S5 Place submit: refused while withdrawn, no submission, then one submission',
    () async {
      final localId = 'loc_m1_page_place_submit_${const Uuid().v4()}';
      final c = await placeController(placeDraft(localId), 'place-submit');
      await c.load();
      await c.save();
      await c.uploadMedia();
      expect(c.state.message, isNull, reason: c.state.message);
      final record = c.state.record!;
      await withCapabilitiesWithdrawn(placePageId, () async {
        await c.submit();
        expect(c.state.message, 'capability_denied');
        expect(c.state.record?.submissionId, isNull);
      });
      final status = await (await gateway('place')).status(record.contentId);
      expect(status.latestSubmissionId, isNull, reason: 'nothing submitted');

      await c.submit();
      expect(c.state.message, isNull, reason: c.state.message);
      expect(c.state.status?.latestSubmissionState, 'under_review');
      expect(c.state.record?.submissionId, c.state.status?.latestSubmissionId);
      c.dispose();
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'S5 Place publish: refused while withdrawn, nothing published, then one publication',
    () async {
      final localId = 'loc_m1_page_place_publish_${const Uuid().v4()}';
      final c = await placeController(placeDraft(localId), 'place-publish');
      await c.load();
      await c.save();
      await c.uploadMedia();
      await c.submit();
      expect(c.state.message, isNull, reason: c.state.message);
      await approve(c.state.status!.latestSubmissionId!);
      await c.refresh();
      final contentId = c.state.record!.contentId;
      await withCapabilitiesWithdrawn(placePageId, () async {
        await c.publish();
        expect(c.state.message, 'capability_denied');
      });
      final status = await (await gateway('place')).status(contentId);
      expect(
        status.currentPublishedRevisionId,
        isNull,
        reason: 'not published',
      );

      await c.publish();
      expect(c.state.message, isNull, reason: c.state.message);
      expect(c.state.status?.visibility, 'visible');
      c.dispose();
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 4)),
  );

  // ---- Place, Page suspended (S6) ----

  test(
    'S6 Place: save, submit and publish are refused while the Page is suspended, then complete once',
    () async {
      final localId = 'loc_m1_page_place_suspended_${const Uuid().v4()}';
      final c = await placeController(placeDraft(localId), 'place-suspended');
      await c.load();
      await c.save();
      expect(c.state.message, isNull, reason: c.state.message);
      final record = c.state.record!;

      // save
      final edited = placeDraft(localId, title: 'Kronvalda pond (suspended)');
      await repository().saveDraft('user-creator', edited);
      await c.load();
      await withPageSuspended(placePageId, () async {
        await c.save();
        expect(c.state.message, 'publisher_not_eligible');
      });
      expect(c.state.record?.draftRevision, record.draftRevision);
      expect(
        (await repository().loadDraft('user-creator'))?.title,
        edited.title,
      );
      await c.save();
      expect(c.state.message, isNull, reason: c.state.message);

      // submit
      await c.uploadMedia();
      expect(c.state.message, isNull, reason: c.state.message);
      await withPageSuspended(placePageId, () async {
        await c.submit();
        expect(c.state.message, 'publisher_not_eligible');
      });
      final notSubmitted = await (await gateway(
        'place',
      )).status(record.contentId);
      expect(notSubmitted.latestSubmissionId, isNull);
      await c.submit();
      expect(c.state.message, isNull, reason: c.state.message);

      // publish
      await approve(c.state.status!.latestSubmissionId!);
      await c.refresh();
      await withPageSuspended(placePageId, () async {
        await c.publish();
        expect(c.state.message, 'publisher_not_eligible');
      });
      final notPublished = await (await gateway(
        'place',
      )).status(record.contentId);
      expect(notPublished.currentPublishedRevisionId, isNull);
      await c.publish();
      expect(c.state.message, isNull, reason: c.state.message);
      expect(c.state.status?.visibility, 'visible');
      c.dispose();
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 6)),
  );

  // ---- Place, capabilities withdrawn, through the UI (S5) ----

  testWidgets(
    'S5 Place UI: publish shows the server refusal while withdrawn, then publishes',
    (WidgetTester tester) async {
      final pageRuntime = (await tester.runAsync(runtime))!;
      final localTitle = 'Kronvalda pond (M1 UI)';
      await tester.runAsync(() async {
        await sl.reset();
        final binding = testBinding();
        final repo = repository();
        await repo.saveDraft(
          'user-1',
          placeDraft('loc_m1_page_ui_${const Uuid().v4()}', title: localTitle),
        );
        sl
          ..registerSingleton<BookingBackendBindingController>(binding)
          ..registerSingleton<PlacePublicationTestEntryGuard>(
            PlacePublicationTestEntryGuard.fromEnvironment(binding),
          )
          ..registerSingleton<BookingSupportDirectoryProvider>(
            () async =>
                Directory('${temp.path}/support').create(recursive: true),
          )
          ..registerSingleton<CreateRepository>(repo)
          ..registerLazySingletonAsync<BookingTransportRuntime>(
            () async => pageRuntime,
          );
      });
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Future<void> waitFor(Finder finder) async {
        final deadline = DateTime.now().add(const Duration(seconds: 90));
        while (DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 200));
          if (finder.evaluate().isNotEmpty) return;
        }
        fail('timed out waiting for $finder');
      }

      Future<void> tapKey(String key) async {
        final finder = find.byWidgetPredicate(
          (widget) =>
              widget.key == Key(key) &&
              widget is ButtonStyleButton &&
              widget.onPressed != null,
        );
        await waitFor(finder);
        await tester.tap(finder);
      }

      Finder keyedText(String key, String fragment) => find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.key == Key(key) &&
            (widget.data ?? '').contains(fragment),
      );

      final auth = await tester.runAsync(signedInAuthController);
      final router = GoRouter(
        initialLocation: '/test/place-publication',
        routes: <RouteBase>[
          GoRoute(
            path: '/test/place-publication',
            redirect: (context, state) => placePublicationTestEntryRedirect(
              sl<PlacePublicationTestEntryGuard>(),
              fallback: '/blocked',
            ),
            builder: (context, state) => const PlacePublicationPage(),
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
      await waitFor(find.text(localTitle));
      await tapKey('place-publication-save');
      await waitFor(keyedText('place-publication-status', 'review: draft'));
      await tapKey('place-publication-media-upload');
      await waitFor(find.text('Media uploaded: 3'));
      await tapKey('place-publication-submit');
      await waitFor(
        keyedText('place-publication-status', 'review: under_review'),
      );
      final tile = find.byWidgetPredicate(
        (widget) =>
            widget is ListTile &&
            (widget.key as ValueKey<String>?)?.value.startsWith(
                  'place-publication-object-',
                ) ==
                true,
      );
      final contentId = (tester.widget<ListTile>(tile).key! as ValueKey<String>)
          .value
          .substring('place-publication-object-'.length);
      final queue = await tester.runAsync(
        () => stand!.moderate(<String>['queue']),
      );
      final pending = ((queue!.json['data']! as Map)['pending']! as List)
          .cast<Map<Object?, Object?>>()
          .singleWhere((item) => item['contentId'] == contentId);
      await tester.runAsync(() => approve(pending['submissionId']! as String));
      await tapKey('place-publication-refresh');
      await waitFor(
        keyedText('place-publication-status', 'approved_for_publication'),
      );

      final withdrawn = (await tester.runAsync(
        () => stand!.pageAccess(<String>[
          'withdraw-publish',
          'creator',
          placePageId,
        ]),
      ))!;
      final saved = (withdrawn['before']! as List<Object?>).cast<String>();
      try {
        await tapKey('place-publication-publish');
        await waitFor(
          keyedText('place-publication-message', 'capability_denied'),
        );
        expect(
          keyedText('place-publication-status', 'visibility: visible'),
          findsNothing,
        );
      } finally {
        await tester.runAsync(
          () => stand!.pageAccess(<String>[
            'restore-publish',
            'creator',
            placePageId,
            saved.join(','),
          ]),
        );
      }
      await tapKey('place-publication-publish');
      await waitFor(
        keyedText('place-publication-status', 'visibility: visible'),
      );
    },
    skip: stand == null || !placePublicationTestEntryDefined,
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
