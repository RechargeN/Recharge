import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/discover_catalog_composition.dart';
import 'package:recharge/app/di/event_publication_composition.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/create/application/event_publication_controller.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/discover/data/repositories/catalog_discover_repository.dart';
import 'package:recharge/features/discover/data/repositories/catalog_published_event_discovery.dart';
import 'package:recharge/features/discover/data/repositories/catalog_snapshot_session.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/published_event_discovery_entity.dart';
import 'package:uuid/uuid.dart';

import '../fixtures/create/user_event_draft.dart';
import 'support/stand_backend.dart';
import 'package:recharge/features/discover/application/controllers/discover_feed_controller.dart';
import 'package:recharge/features/discover/data/repositories/discover_preferences_repository_impl.dart';
import 'package:recharge/features/discover/data/datasources/discover_preferences_local_datasource.dart';
import 'package:recharge/features/discover/domain/usecases/get_discover_feed_usecase.dart';
import 'support/event_details_harness.dart';

/// E2a: an Event the Creator publishes through the real C3 path reaches the
/// server Catalog through the Emulator-only Content effect trigger (no manual
/// delivery) and is read by another user, with another Session, through the
/// real Discover adapters: Feed, Search and Details show one revision, and
/// after the owner hides it, it leaves all of them. The Discover Map page
/// renders the same listing state as the Feed, so it shows the same revision.
///
/// Limits: PC host run against the local Emulator; the trigger is
/// asynchronous, so reads poll with a deadline instead of fixed delays.
void main() {
  final stand = StandBackend.fromEnvironment();
  late Directory temp;
  late File cover;
  late String pageId;
  final runtimes = <String, Future<BookingTransportRuntime>>{};

  BookingBackendBindingController binding() => BookingBackendBindingController(
    emulatorBase: StandBackend.functionsBase,
    releaseMode: false,
    initial: BackendBindingMode.testBackend,
  );

  Future<BookingTransportRuntime> runtimeFor(
    String label,
  ) => runtimes.putIfAbsent(label, () async {
    final sessions = FileSessionStore(File('${temp.path}/session-$label.json'));
    final runtime = await BookingTransportRuntimeFactory(
      endpoint: binding().endpoint,
      client: CountingClient(),
      tokens: AuthEmulatorTokenProvider('stand-user-$label'),
      sessions: sessions,
      installations: FixedInstallationId('e2a-local-installation-$label'),
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

  Future<EventPublicationController> creator(CreateDraftEntity draft) async {
    final repository = CreateRepositoryImpl(
      localDataSource: CreateLocalDataSource(const FlutterSecureStorage()),
      idGenerator: UuidV4IdGenerator(),
    );
    await repository.saveDraft('user-creator', draft);
    final runtime = await runtimeFor('creator');
    return eventPublicationControllerFor(
      port: runtime.port!,
      guard: EventPublicationTestEntryGuard(
        flag: true,
        releaseMode: false,
        binding: binding(),
      ),
      drafts: CreateRepositoryEventDraftSource(repository, 'user-creator'),
      journalFile: File('${temp.path}/journal-creator.json'),
    );
  }

  /// Polls a real read until [done] holds; the deadline is the only wait.
  Future<T> eventually<T>(
    Future<T> Function() read,
    bool Function(T value) done, {
    required String what,
  }) async {
    final DateTime deadline = DateTime.now().add(const Duration(seconds: 90));
    while (true) {
      final T value = await read();
      if (done(value)) return value;
      if (DateTime.now().isAfter(deadline)) fail('timed out waiting for $what');
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  setUpAll(() async {
    if (stand == null) return;
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    temp = await Directory.systemTemp.createTemp('e2a-local-');
    cover = await File(
      'test/fixtures/media/stand_cover.png',
    ).copy('${temp.path}/cover.png');
    final manifest = await stand.manifest();
    pageId = (manifest['contentEvent']! as Map)['pageId']! as String;
  });

  tearDownAll(() async {
    if (stand != null && await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test(
    'one revision in Feed, Search and Details for another user; hidden, '
    'it leaves all of them',
    () async {
      final String marker = const Uuid()
          .v4()
          .replaceAll('-', '')
          .substring(0, 10);
      final draft = userEventDraft(
        pageId: pageId,
        coverPath: cover.path,
        localId: 'loc_e2a_${const Uuid().v4()}',
        title: 'Pottery evening $marker',
      );
      final c = await creator(draft);
      await c.load();
      await c.save();
      await c.uploadCover();
      await c.submit();
      expect(c.state.message, isNull, reason: c.state.message);
      final approved = await stand!.moderate(<String>[
        'approve',
        c.state.status!.latestSubmissionId!,
        '--reason',
        'e2a local: the Event is fine',
      ]);
      expect(approved.exitCode, 0, reason: '${approved.json}');
      await c.refresh();
      await c.publish();
      expect(c.state.message, isNull, reason: c.state.message);
      final String contentId = c.state.record!.contentId;
      final String revision = c.state.status!.currentPublishedRevisionId!;

      // A different user and Session read through the real Discover adapters.
      final viewer = await runtimeFor('viewer');
      final guard = DiscoverCatalogTestEntryGuard(
        flag: true,
        releaseMode: false,
        binding: binding(),
      );
      expect(
        discoverBindingManifest(guard).modeFor(discoverCatalogCapabilityId),
        BackendBindingMode.testBackend,
      );
      final port = BookingPortCatalogAdapter(
        runtime: () async => viewer,
        guard: guard,
      );
      final session = CatalogSnapshotSession();
      final listing = CatalogDiscoverRepository(
        port: port,
        session: session,
        marketId: 'LV',
        currencyCode: 'EUR',
      );
      final details = CatalogPublishedEventDiscovery(
        port: port,
        session: session,
        currencyCode: 'EUR',
      );
      final DiscoverQuery query = DiscoverQuery.defaults(
        centerLat: 56.9496,
        centerLng: 24.1052,
      );
      bool lists(List<DiscoverItemEntity> items) =>
          items.any((DiscoverItemEntity item) => item.id == contentId);

      final List<DiscoverItemEntity> feed = await eventually(
        () => listing.getFeed(query),
        lists,
        what: 'the trigger to project the Event into the Feed',
      );
      final DiscoverItemEntity card = feed.firstWhere(
        (DiscoverItemEntity item) => item.id == contentId,
      );
      expect(card.revisionRef, revision);
      expect(card.title, draft.title);
      expect(card.objectKind, DiscoverObjectKind.event);
      // The Map page draws this same listing; the card carries its pin.
      expect(card.latitude, closeTo(56.951, 1e-9));
      expect(card.longitude, closeTo(24.113, 1e-9));

      final List<DiscoverItemEntity> search = await listing.getFeed(
        query.copyWith(queryText: marker),
      );
      expect(search.map((DiscoverItemEntity item) => item.id), <String>[
        contentId,
      ]);
      expect(search.single.revisionRef, revision);

      final PublishedEventDiscoveryEntity? event = await details.getActiveEvent(
        contentId,
      );
      expect(event, isNotNull);
      expect(event!.revisionRef, revision, reason: 'same revision as listed');
      expect(event.changedSinceListing, isFalse);
      expect(event.title, draft.title);
      expect(event.fullDescription, draft.fullDescription);

      // Map's actual controller and adapter path, independently loaded.
      final map = DiscoverFeedController(
        getDiscoverFeedUseCase: GetDiscoverFeedUseCase(listing),
        discoverPreferencesRepository: DiscoverPreferencesRepositoryImpl(
          localDataSource: DiscoverPreferencesLocalDataSource(
            const FlutterSecureStorage(),
            defaultMarketCityId: 'riga',
            defaultCenterLat: 56.9496,
            defaultCenterLng: 24.1052,
            defaultCurrencyCode: 'EUR',
          ),
        ),
        analyticsService: SpyAnalytics(),
        initialQuery: query,
      );
      await map.applySearchArea();
      final mapCard = map.state.items.singleWhere(
        (item) => item.id == contentId,
      );
      expect(mapCard.revisionRef, card.revisionRef);
      expect(mapCard.revisionRef, event.revisionRef);
      expect(mapCard.latitude, card.latitude);
      expect(mapCard.longitude, card.longitude);
      // The owner hides it: it leaves Feed, Search, Map controller and Details.
      await c.hide();
      expect(c.state.status?.visibility, 'withdrawn');
      await eventually(
        () => listing.getFeed(query),
        (List<DiscoverItemEntity> items) => !lists(items),
        what: 'the trigger to remove the hidden Event from the Feed',
      );
      expect(await listing.getFeed(query.copyWith(queryText: marker)), isEmpty);
      expect(await details.getActiveEvent(contentId), isNull);
      await map.applySearchArea();
      expect(map.state.items.any((item) => item.id == contentId), isFalse);
      map.dispose();
      c.dispose();
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
