import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/route_content_publication_composition.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/create/application/route_content_publication_controller.dart';
import 'package:recharge/features/create/application/route_create_config.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_publication.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/entities/route_content_publication.dart';
import 'package:recharge/features/create/domain/entities/route_draft_data.dart';
import 'package:recharge/features/create/domain/entities/route_sync_data.dart';
import 'package:recharge/features/create/domain/repositories/event_publication_gateway.dart';
import 'package:recharge/features/create/domain/repositories/route_content_publication_gateway.dart';
import 'package:recharge/features/create/domain/repositories/route_sync_repository.dart';

/// J2 / RTE-PUB-01: the Route publication test path coordinates J1 sync,
/// `distribute`, Content and Media; the server decides everything.
void main() {
  const String user = 'user-1';
  const PublisherRef page = PublisherRef(
    type: PublisherType.page,
    id: 'page-1',
  );
  late _Sync sync;
  late _Distribution distribution;
  late _Content content;
  late _Journal journal;
  late _Uploader uploader;
  late _Gate gate;
  late CreateDraftEntity draft;

  RouteContentPublicationController controller({
    PublisherRef publisher = const PublisherRef(
      type: PublisherType.user,
      id: user,
    ),
  }) => RouteContentPublicationController(
    accountId: user,
    defaultContentLocale: 'en',
    publisherRef: publisher,
    drafts: _Drafts(draft),
    sync: sync,
    distribution: distribution,
    content: content,
    uploader: uploader,
    mediaSource: const _Bytes(),
    journal: journal,
    gate: gate,
  );

  setUp(() {
    sync = _Sync();
    distribution = _Distribution();
    content = _Content();
    journal = _Journal();
    uploader = _Uploader();
    gate = _Gate(true);
    draft =
        CreateDraftEntity.defaults(
          organizerId: user,
          organizerEmail: 'user@example.test',
          organizerName: 'User',
          marketCityId: 'riga',
          timezone: 'Europe/Riga',
          country: 'LV',
          city: 'Riga',
          currency: 'EUR',
        ).copyWith(
          objectType: CreateObjectType.route,
          title: 'Riverside walk',
          mainCategory: 'art_culture_museums',
          subcategory: 'art_walk',
          shortDescription: 'A calm riverside walk through Riga parks',
          fullDescription: 'A calm riverside walk through Riga parks.',
          routeData: createEmptyRouteDraft(),
        );
  });

  test('the closed test entry sends nothing', () async {
    gate = _Gate(false);
    final RouteContentPublicationController c = controller();
    await c.load();
    expect(c.state.phase, RouteContentPublicationPhase.noDraft);
    expect(c.state.message, 'not_allowed');
    expect(sync.calls, isEmpty);
    expect(distribution.calls, isEmpty);
    expect(content.calls, isEmpty);
  });

  test('a draft of another type is never published as a Route', () async {
    draft = draft.copyWith(objectType: CreateObjectType.place);
    final RouteContentPublicationController c = controller();
    await c.load();
    expect(c.state.phase, RouteContentPublicationPhase.noDraft);
    expect(sync.calls, isEmpty);
  });

  test(
    'sync, then prepare pins the server revision to one Content draft',
    () async {
      final RouteContentPublicationController c = controller();
      await c.load();
      expect(c.state.canPrepare, isFalse, reason: 'not on the server yet');
      await c.syncRoute();
      expect(sync.calls, contains('save:${draft.id}:0'));
      expect(c.state.routeId, 'route-1');
      expect(c.state.serverRevision, 1);
      await c.prepare();
      expect(distribution.calls, contains('distribute:route-1:1'));
      final Map<String, Object?> body = content.bodies.single;
      expect(body['title'], 'Pinned title');
      expect(body['categoryId'], 'art_culture_museums');
      expect(body['subcategoryId'], 'art_walk');
      expect(body['route'], <String, Object?>{
        'ref': <String, Object?>{
          'routeId': 'route-1',
          'routeRevisionId': 'rev-1',
          'contentHash': 'h' * 64,
        },
        'distribution': const <String, Object?>{'title': 'Pinned title'},
      });
      expect(body.containsKey('visibility'), isFalse, reason: 'public only');
      expect(c.state.record?.contentDraftId, 'draft-1');
      // A second prepare updates the same draft; never a second Content draft.
      await c.prepare();
      expect(content.calls.where((call) => call == 'create'), hasLength(1));
      expect(content.calls.last, 'update');
    },
  );

  test('RP-04: the active Page is captured once as the publisher', () async {
    final RouteContentPublicationController c = controller(publisher: page);
    await c.load();
    await c.syncRoute();
    await c.prepare();
    expect(content.publisher, page);
    expect(journal.record?.publisherRef, page);
    // A later workspace switch does not move an existing publication.
    final RouteContentPublicationController personal = controller();
    await personal.load();
    await personal.prepare();
    expect(journal.record?.publisherRef, page);
    expect(content.calls.where((call) => call == 'create'), hasLength(1));
  });

  test(
    'RP-02: a recorded-GPS refusal is explained and the ends can be hidden',
    () async {
      distribution.refuse = 'privacy_trim_required';
      final RouteContentPublicationController c = controller();
      await c.load();
      await c.syncRoute();
      await c.prepare();
      expect(c.state.message, 'privacy_trim_required');
      expect(content.calls, isEmpty);
      expect(c.state.canHideEnds, isTrue);
      await c.hidePrivateEnds();
      expect(sync.calls, contains('trim:route-1:200:200:1'));
      expect(c.state.trim?.startMeters, 200);
      expect(c.state.serverRevision, 2);
      distribution.refuse = null;
      await c.prepare();
      expect(distribution.calls.last, 'distribute:route-1:2');
      expect(c.state.message, isNull);
    },
  );

  test(
    'the cover needs the rights confirmation and is uploaded once',
    () async {
      final RouteContentPublicationController c = controller();
      draft = draft.copyWith(
        media: draft.media.copyWith(coverImage: 'cover.png'),
      );
      await c.load();
      await c.syncRoute();
      await c.prepare();
      await c.uploadCover(rightsConfirmed: false);
      expect(c.state.message, 'media_rights_required');
      expect(uploader.count, 0);
      await c.uploadCover(rightsConfirmed: true);
      await c.uploadCover(rightsConfirmed: true);
      expect(uploader.count, 1);
      final Map<String, Object?> media =
          content.bodies.last['media']! as Map<String, Object?>;
      expect(media['rightsConfirmed'], isTrue);
      expect((media['coverImage']! as Map)['mediaId'], 'asset-1');
    },
  );

  test(
    'submit, auto-approval, publish and hide follow the server status',
    () async {
      final RouteContentPublicationController c = controller();
      await c.load();
      await c.syncRoute();
      await c.prepare();
      // RP-06: a trusted publisher's submission comes back approved at once.
      content.state = 'approved_for_publication';
      await c.submit();
      expect(content.calls, contains('submit'));
      expect(c.state.canPublish, isTrue);
      expect(c.state.canPrepare, isFalse, reason: 'approved body is locked');
      await c.publish();
      expect(content.calls, contains('publish:sub-1'));
      content.visibility = 'visible';
      await c.refresh();
      expect(c.state.published, isTrue);
      expect(c.state.canHide, isTrue);
      await c.hide();
      expect(content.calls, contains('withdraw'));
    },
  );

  test('a sync failure is shown and nothing is distributed', () async {
    sync.failure = 'revision_conflict';
    final RouteContentPublicationController c = controller();
    await c.load();
    await c.syncRoute();
    expect(c.state.message, 'revision_conflict');
    expect(distribution.calls, isEmpty);
  });

  test('the journal record round-trips with its publisher', () {
    const RouteContentPublicationRecord record = RouteContentPublicationRecord(
      accountId: user,
      localDraftId: 'loc_1',
      routeId: 'route-1',
      routeRevisionId: 'rev-1',
      contentHash: 'hash',
      distribution: <String, Object?>{'title': 'T'},
      publisherRef: page,
      contentDraftId: 'draft-1',
      contentRevision: 2,
    );
    final RouteContentPublicationRecord? back =
        RouteContentPublicationRecord.fromJson(record.toJson());
    expect(back?.publisherRef, page);
    expect(back?.contentRevision, 2);
    expect(
      RouteContentPublicationRecord.fromJson(<String, Object?>{
        ...record.toJson(),
        'publisherRef': <String, Object?>{'type': 'workspace', 'id': 'x'},
      }),
      isNull,
    );
  });

  group('test entry guard', () {
    final Uri base = Uri.parse(
      'http://127.0.0.1:5001/demo-recharge/europe-west1',
    );
    RoutePublicationTestEntryGuard guard({
      bool flag = true,
      bool release = false,
      BackendBindingMode mode = BackendBindingMode.testBackend,
      Uri? emulatorBase,
    }) => RoutePublicationTestEntryGuard(
      flag: flag,
      releaseMode: release,
      binding: BookingBackendBindingController(
        emulatorBase: emulatorBase ?? base,
        releaseMode: release,
        initial: mode,
      ),
    );

    test('the define is off by default in this build', () {
      expect(routePublicationTestEntryDefined, isFalse);
    });

    test('all four conditions are required at once', () {
      expect(guard().allowed, isTrue);
      expect(guard(flag: false).allowed, isFalse);
      expect(guard(release: true).allowed, isFalse);
      expect(guard(mode: BackendBindingMode.localOnly).allowed, isFalse);
      expect(
        guard(emulatorBase: Uri.parse('https://example.org/x')).allowed,
        isFalse,
      );
    });

    test(
      'a closed entry refuses every command and redirects the route',
      () async {
        expect(() => guard(flag: false).assertAllowed(), throwsStateError);
        expect(
          routePublicationTestEntryRedirect(guard(flag: false), fallback: '/x'),
          '/x',
        );
        expect(routePublicationTestEntryRedirect(null, fallback: '/x'), '/x');
        expect(
          routePublicationTestEntryRedirect(guard(), fallback: '/x'),
          isNull,
        );
        final invoke = routePublicationInvoke(
          guard: guard(flag: false),
          port: _NoPort(),
        );
        await expectLater(
          invoke('routeCommandV1', const <String, Object?>{}),
          throwsA(
            isA<RouteSyncFailure>().having(
              (RouteSyncFailure e) => e.code,
              'code',
              'test_entry_disabled',
            ),
          ),
        );
        final open = routePublicationInvoke(guard: guard(), port: _NoPort());
        await expectLater(
          open('contentCommandV1', const <String, Object?>{}),
          throwsA(isA<RouteSyncFailure>()),
          reason: 'only the Route surfaces pass this invoke',
        );
      },
    );
  });
}

final class _NoPort implements BookingCallablePort {
  @override
  Future<Map<String, Object?>> invoke(
    String name,
    Map<String, Object?> data,
  ) async => throw StateError('no call expected');
}

final class _Gate implements EventPublicationCommandGate {
  _Gate(this.allowed);
  @override
  final bool allowed;
  @override
  void assertAllowed() {
    if (!allowed) throw StateError('closed');
  }
}

final class _Drafts implements RouteDraftSource {
  const _Drafts(this.draft);
  final CreateDraftEntity draft;
  @override
  Future<CreateDraftEntity?> current() async => draft;
}

final class _Bytes implements EventCoverSource {
  const _Bytes();
  @override
  Future<Uint8List?> read(String reference) async =>
      Uint8List.fromList(<int>[0x89, 0x50, 0x4e, 0x47, 1, 2, 3]);
}

final class _Uploader implements EventCoverUploader {
  int count = 0;
  @override
  Future<String> upload({
    required String intentId,
    required Uint8List bytes,
    required String declaredMediaType,
    required PublisherRef publisherRef,
    required String contentId,
  }) async {
    count++;
    return 'asset-$count';
  }
}

final class _Journal implements RouteContentPublicationJournal {
  RouteContentPublicationRecord? record;
  @override
  Future<RouteContentPublicationRecord?> forDraft({
    required String accountId,
    required String localDraftId,
  }) async => record;
  @override
  Future<void> save(RouteContentPublicationRecord value) async =>
      record = value;
}

final class _Distribution implements RouteDistributionGateway {
  final List<String> calls = <String>[];
  String? refuse;

  @override
  Future<RouteDistributionRef> distribute({
    required String routeId,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    calls.add('distribute:$routeId:$expectedRevision');
    if (refuse != null) throw EventPublicationRejected(refuse!);
    return const RouteDistributionRef(
      routeRevisionId: 'rev-1',
      contentHash:
          'hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh',
      distribution: <String, Object?>{'title': 'Pinned title'},
    );
  }
}

/// J1 sync as the controller sees it: one Route, its revision and its trim.
final class _Sync implements RouteSyncRepository {
  final List<String> calls = <String>[];
  String? failure;
  int revision = 0;
  RoutePrivacyTrim trim = const RoutePrivacyTrim(startMeters: 0, endMeters: 0);

  RouteSyncEntry? get _entry => revision == 0
      ? null
      : RouteSyncEntry(
          routeId: 'route-1',
          revision: revision,
          deleted: false,
          title: 'Riverside walk',
          updatedAtUtc: DateTime.utc(2026, 10, 21),
          privacyTrim: trim,
        );

  @override
  Future<void> restore() async => calls.add('restore');

  @override
  Future<RouteSyncEntry?> save({
    required String localDraftId,
    required String title,
    required RouteDraftData route,
    required int expectedRevision,
  }) async {
    calls.add('save:$localDraftId:$expectedRevision');
    if (failure != null) throw RouteSyncFailure(failure!);
    revision++;
    return _entry;
  }

  @override
  Future<RouteSyncEntry?> setPrivacyTrim({
    required String routeId,
    required RoutePrivacyTrim trim,
    required int expectedRevision,
  }) async {
    calls.add(
      'trim:$routeId:${trim.startMeters}:${trim.endMeters}:$expectedRevision',
    );
    this.trim = trim;
    revision++;
    return _entry;
  }

  @override
  Future<RouteSyncEntry?> refresh(String routeId) async => _entry;

  @override
  RouteSyncEntry? cached(String routeId) => _entry;

  @override
  String? routeIdFor(String localDraftId) => revision == 0 ? null : 'route-1';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

final class _Content implements EventPublicationGateway {
  final List<String> calls = <String>[];
  final List<Map<String, Object?>> bodies = <Map<String, Object?>>[];
  PublisherRef? publisher;
  int revision = 0;
  String state = 'under_review';
  String? visibility;

  @override
  Future<EventServerDraftRef> createDraft({
    required PublisherRef publisherRef,
    required String marketId,
    required Map<String, Object?> body,
    required String idempotencyKey,
  }) async {
    calls.add('create');
    publisher = publisherRef;
    bodies.add(body);
    return EventServerDraftRef(
      contentId: 'route-1',
      draftId: 'draft-1',
      revision: ++revision,
    );
  }

  @override
  Future<EventServerDraftRef> updateDraft({
    required String draftId,
    required int expectedRevision,
    required Map<String, Object?> body,
    required String idempotencyKey,
  }) async {
    calls.add('update');
    bodies.add(body);
    return EventServerDraftRef(
      contentId: 'route-1',
      draftId: draftId,
      revision: ++revision,
    );
  }

  @override
  Future<String> submit({
    required String draftId,
    required int expectedDraftRevision,
    required String idempotencyKey,
  }) async {
    calls.add('submit');
    return 'sub-1';
  }

  @override
  Future<void> publishApproved({
    required String submissionId,
    required int expectedPointerRevision,
    required String idempotencyKey,
  }) async => calls.add('publish:$submissionId');

  @override
  Future<void> withdraw({
    required String contentId,
    required int expectedPointerRevision,
    required String idempotencyKey,
  }) async => calls.add('withdraw');

  @override
  Future<EventPublicationStatus> status(String contentId) async =>
      EventPublicationStatus(
        contentId: contentId,
        latestSubmissionId: calls.contains('submit') ? 'sub-1' : null,
        latestSubmissionState: calls.contains('submit') ? state : null,
        pointerRevision: visibility == null ? null : 1,
        visibility: visibility,
        currentPublishedRevisionId: visibility == null ? null : 'pub-1',
      );
}
