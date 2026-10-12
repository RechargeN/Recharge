import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/activity_publication_composition.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/app/di/discover_catalog_composition.dart';
import 'package:recharge/features/create/application/activity_place_link_controller.dart';
import 'package:recharge/features/create/data/repositories/catalog_activity_place_link_repository.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/create/application/activity_publication_controller.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
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
    await stand.placeSeed();
    await stand.activitySeed();
    seededActivity = await stand.activityManifest();
  });

  tearDownAll(() async {
    if (stand != null && await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test(
    'real Catalog picker to Activity save/media/submit/review/publish/activate; restriction hides relation only',
    () async {
      final place = await stand!.placeManifest();
      final placeId = place['contentId']! as String;
      final runtime = await runtimeFor('creator');
      final binding = BookingBackendBindingController(
        emulatorBase: StandBackend.functionsBase,
        releaseMode: false,
        initial: BackendBindingMode.testBackend,
      );
      final port = BookingPortCatalogAdapter(
        runtime: () async => runtime,
        guard: DiscoverCatalogTestEntryGuard(
          flag: true,
          releaseMode: false,
          binding: binding,
        ),
      );
      final picker = ActivityPlaceLinkController(
        CatalogActivityPlaceLinkRepository(
          query: port.query,
          marketId: 'LV',
          enabled: true,
        ),
      );
      addTearDown(picker.dispose);
      await picker.search('');
      // Bounded pages can include other content pointers: follow the owner cursor.
      while (!picker.items.any((item) => item.id == placeId) &&
          picker.nextCursor != null) {
        await picker.more();
      }
      expect(picker.items.any((item) => item.id == placeId), isTrue);
      expect(await picker.resolve(placeId), placeId);
      final original = draftOf('loc_d39_${const Uuid().v4()}');
      final draft = original.copyWith(
        activityData: original.activityData!.copyWith(
          location: original.activityData!.location.copyWith(
            linkedPlaceId: picker.selected!.id,
          ),
        ),
      );
      final controller = await controllerFor(
        'creator',
        draft,
        journal: 'linked-journal',
      );
      addTearDown(controller.dispose);
      await controller.load();
      await controller.save();
      await controller.uploadMedia();
      await controller.submit();
      expect(
        controller.state.message,
        isNull,
        reason: controller.state.message,
      );
      final approval = await stand.moderate([
        'approve',
        controller.state.status!.latestSubmissionId!,
        '--reason',
        'D3.9 linked Activity',
      ]);
      expect(approval.exitCode, 0, reason: '${approval.json}');
      await controller.refresh();
      await controller.publish();
      expect(
        controller.state.message,
        isNull,
        reason: controller.state.message,
      );
      final id = controller.state.record!.contentId;
      final revision = controller.state.status!.currentPublishedRevisionId;
      await controller.hide();
      await controller.activate();
      expect(
        controller.state.message,
        isNull,
        reason: controller.state.message,
      );
      expect(controller.state.status!.currentPublishedRevisionId, revision);
      await stand.catalog(['deliver']);
      Future<Map> details() async {
        final answer = await port.query({
          'schemaVersion': 1,
          'requestId': const Uuid().v4(),
          'queryType': 'details',
          'payload': {'contentId': id},
        });
        expect(answer['kind'], 'succeeded');
        return (answer['details']! as Map)['item']! as Map;
      }

      final visible = await details();
      expect((visible['linkedPlace']! as Map)['contentId'], placeId);
      expect(visible.containsKey('linkedPlaceId'), isFalse);
      final restricted = await stand.moderate([
        'restrict',
        placeId,
        '--reason',
        'D3.9 Place restriction',
      ]);
      expect(restricted.exitCode, 0, reason: '${restricted.json}');
      final hidden = await details();
      expect(hidden['contentId'], id);
      expect(hidden.containsKey('linkedPlace'), isFalse);
      expect(hidden['point'], visible['point']);
      await controller.activate();
      expect(controller.state.message, 'validation_failed');
      expect(controller.state.status!.currentPublishedRevisionId, revision);
      expect(await picker.resolve(placeId), isNull);
      expect(picker.status, 'forbidden');
      final decisionId =
          ((restricted.json['data']! as Map)['decision']! as Map)['decisionId']!
              as String;
      final restored = await stand.moderate([
        'restore',
        placeId,
        '--decision',
        decisionId,
        '--reason',
        'D3.9 restore Place',
      ]);
      expect(restored.exitCode, 0, reason: '${restored.json}');
      expect(((await details())['linkedPlace']! as Map)['contentId'], placeId);
      expect(await picker.resolve(placeId), placeId);
      expect(controller.state.status!.currentPublishedRevisionId, revision);
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
