import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/scenario_publication_controller.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_publication.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/entities/scenario_publication.dart';
import 'package:recharge/features/create/domain/repositories/event_publication_gateway.dart';
import 'package:recharge/features/create/domain/repositories/scenario_publication_gateway.dart';

import '../fixtures/create/user_scenario_draft.dart';

void main() {
  const String user = 'user-1';
  late _Planning planning;
  late _Content content;
  late _Journal journal;
  late _Uploader uploader;
  late _Gate gate;
  late CreateDraftEntity draft;

  ScenarioPublicationController controller() => ScenarioPublicationController(
    accountId: user,
    defaultContentLocale: 'en',
    drafts: _Drafts(draft),
    planning: planning,
    content: content,
    uploader: uploader,
    mediaSource: const _Bytes(),
    journal: journal,
    gate: gate,
  );

  setUp(() {
    planning = _Planning();
    content = _Content();
    journal = _Journal();
    uploader = _Uploader();
    gate = _Gate(true);
    draft = userScenarioDraft(userId: user, coverPath: 'cover.png');
  });

  test('the closed test entry sends nothing', () async {
    gate = _Gate(false);
    final ScenarioPublicationController c = controller();
    await c.load();
    expect(c.state.phase, ScenarioPublicationPhase.noDraft);
    expect(c.state.message, 'not_allowed');
    expect(planning.calls, isEmpty);
    expect(content.calls, isEmpty);
  });

  test(
    'prepare pins the server revision and binds the one Content draft',
    () async {
      final ScenarioPublicationController c = controller();
      await c.load();
      expect(c.state.serverRevision, 3);
      expect(c.state.canPrepare, isTrue);
      await c.prepare();
      expect(planning.calls, contains('distribute:${draft.id}:3'));
      final Map<String, Object?> body = content.bodies.single;
      final Map<String, Object?> scenario =
          body['scenario']! as Map<String, Object?>;
      expect(scenario['ref'], <String, Object?>{
        'scenarioId': draft.id,
        'scenarioRevisionId': 'rev-1',
        'contentHash': 'h' * 64,
      });
      expect(body['title'], 'Pinned title');
      expect(
        content.publisher,
        PublisherRef(type: PublisherType.user, id: user),
      );
      expect(c.state.record?.contentDraftId, 'draft-1');
      // A second prepare updates the same draft; never a second Content draft.
      await c.prepare();
      expect(content.calls.where((call) => call == 'create'), hasLength(1));
      expect(content.calls.last, 'update');
    },
  );

  test(
    'the cover needs the rights confirmation and is uploaded once',
    () async {
      final ScenarioPublicationController c = controller();
      await c.load();
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

  test('submit, publish and hide follow the server status', () async {
    final ScenarioPublicationController c = controller();
    await c.load();
    await c.prepare();
    await c.submit();
    expect(content.calls, contains('submit'));
    content.state = 'approved_for_publication';
    await c.refresh();
    expect(c.state.canPublish, isTrue);
    await c.publish();
    expect(content.calls, contains('publish:sub-1'));
    content.visibility = 'visible';
    await c.refresh();
    expect(c.state.canHide, isTrue);
    await c.hide();
    expect(content.calls, contains('withdraw'));
  });

  test(
    'a lost share answer never shows a token and asks for a new link',
    () async {
      final ScenarioPublicationController c = controller();
      await c.load();
      planning.tokenLost = true;
      await c.share();
      expect(c.state.message, 'share_token_unavailable');
      expect(c.state.share?.token, isNull);
      planning.tokenLost = false;
      await c.share(ttlDays: 7);
      expect(c.state.share?.token, 'token');
      await c.unshare();
      expect(c.state.share, isNull);
      expect(
        planning.calls.where((call) => call.startsWith('share')),
        hasLength(2),
      );
    },
  );

  test('a server refusal is shown, nothing is assumed', () async {
    planning.refuse = 'distribution_invalid';
    final ScenarioPublicationController c = controller();
    await c.load();
    await c.prepare();
    expect(c.state.message, 'distribution_invalid');
    expect(content.calls, isEmpty);
  });
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

final class _Drafts implements ScenarioDraftSource {
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

final class _Journal implements ScenarioPublicationJournal {
  ScenarioPublicationRecord? record;
  @override
  Future<ScenarioPublicationRecord?> forScenario({
    required String accountId,
    required String scenarioId,
  }) async => record;
  @override
  Future<void> save(ScenarioPublicationRecord value) async => record = value;
}

final class _Planning implements ScenarioPlanningGateway {
  final List<String> calls = <String>[];
  String? refuse;
  bool tokenLost = false;

  @override
  Future<int> serverRevision(String scenarioId) async => 3;

  @override
  Future<ScenarioDistributionRef> distribute({
    required String scenarioId,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    calls.add('distribute:$scenarioId:$expectedRevision');
    if (refuse != null) throw EventPublicationRejected(refuse!);
    return ScenarioDistributionRef(
      scenarioRevisionId: 'rev-1',
      contentHash: 'h' * 64,
      distribution: const <String, Object?>{'title': 'Pinned title'},
    );
  }

  @override
  Future<ScenarioShareLink> share({
    required String scenarioId,
    required int expectedRevision,
    required String idempotencyKey,
    int? ttlDays,
  }) async {
    calls.add('share:$ttlDays');
    return ScenarioShareLink(
      expiresAtUtc: DateTime.utc(2030),
      token: tokenLost ? null : 'token',
    );
  }

  @override
  Future<bool> unshare({
    required String scenarioId,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    calls.add('unshare');
    return true;
  }

  @override
  Future<Map<String, Object?>> resolveShare(String token) async =>
      <String, Object?>{};
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
      contentId: 'scenario',
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
      contentId: 'scenario',
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
