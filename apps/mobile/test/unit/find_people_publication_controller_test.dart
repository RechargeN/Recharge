import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/find_people_publication_controller.dart';
import 'package:recharge/features/create/data/file_find_people_publication_journal.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_publication.dart';
import 'package:recharge/features/create/domain/entities/find_people_draft_data.dart';
import 'package:recharge/features/create/domain/entities/find_people_publication.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/repositories/event_publication_gateway.dart';
import 'package:recharge/features/create/domain/repositories/find_people_publication_gateway.dart';

import '../fixtures/create/user_find_people_draft.dart';

void main() {
  late Directory temp;
  late _Server server;
  late _Consents consents;
  late _Gate gate;
  late FileFindPeoplePublicationJournal journal;
  CreateDraftEntity draft = userFindPeopleDraft(userId: 'account-a');
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('t3-find-people-controller-');
    server = _Server();
    consents = _Consents();
    gate = _Gate();
    journal = FileFindPeoplePublicationJournal(File('${temp.path}/fp.json'));
    draft = userFindPeopleDraft(userId: 'account-a');
  });
  tearDown(() => temp.delete(recursive: true));

  FindPeoplePublicationController controller() =>
      FindPeoplePublicationController(
        accountId: 'account-a',
        defaultContentLocale: 'en',
        drafts: _Drafts(() => draft),
        gateway: server,
        reader: server,
        consents: consents,
        journal: journal,
        gate: gate,
      );

  test('a closed gate sends nothing, not even a read', () async {
    gate.open = false;
    final FindPeoplePublicationController c = controller();
    await c.load();
    await c.save();
    await c.grantConsent();
    expect(server.calls, isEmpty);
    expect(consents.calls, isEmpty);
    c.dispose();
  });

  test(
    'an unsupported draft is refused before the empty draft is created',
    () async {
      draft = draft.copyWith(
        findPeopleData: draft.findPeopleData!.copyWith(
          scheduleMode: FindPeopleScheduleMode.recurring,
        ),
      );
      final FindPeoplePublicationController c = controller();
      await c.load();
      await c.save();
      expect(c.state.message, startsWith('unsupported_capability:'));
      expect(server.calls, isEmpty);
      c.dispose();
    },
  );

  test(
    'consent is an explicit server command; submit and publish wait for it',
    () async {
      final FindPeoplePublicationController c = controller();
      await c.load();
      await c.save();
      expect(c.state.record?.authorApplied, isTrue);
      // Saving is not consent: nothing was granted and submit stays closed.
      expect(consents.grants, isEmpty);
      expect(c.state.consent, isNull);
      expect(c.state.canSubmit, isFalse);
      expect(c.state.canGrantConsent, isTrue);
      // The saved body is the private source: no client public point is sent.
      expect(jsonEncode(server.lastBody).contains('publicGeo'), isFalse);
      await c.grantConsent();
      expect(c.state.consent?.active, isTrue);
      expect(consents.grants.single, endsWith(':consent:grant:0'));
      expect(c.state.canSubmit, isTrue);
      await c.submit();
      server.approve();
      await c.refresh();
      expect(c.state.canPublish, isTrue);
      // A lost publish answer replays the journaled intent, never a second publish.
      server.loseAnswerOf.add('publishApprovedRevision');
      await c.publish();
      expect(c.state.phase, FindPeoplePublicationPhase.offline);
      await c.refresh();
      await c.publish();
      expect(server.publications, 1);
      expect(c.state.status?.visibility, 'visible');
      // Withdrawing consent is always available and recorded on the server.
      expect(c.state.canRevokeConsent, isTrue);
      await c.revokeConsent();
      expect(c.state.consent?.state, 'revoked');
      expect(consents.revokes.single, endsWith(':consent:revoke:1'));
      expect(c.state.canPublish, isFalse);
      // No edit after publication: nothing is written.
      final int writes = server.calls
          .where((String v) => v == 'updateDraft')
          .length;
      await c.save();
      expect(c.state.message, 'editing_after_publication_not_supported');
      expect(
        server.calls.where((String v) => v == 'updateDraft').length,
        writes,
      );
      await c.hide();
      expect(c.state.status?.visibility, 'withdrawn');
      c.dispose();
    },
  );

  for (final String lost in <String>['createDraft', 'updateDraft']) {
    test(
      'a lost $lost answer resumes with one draft after a restart',
      () async {
        server.loseAnswerOf.add(lost);
        FindPeoplePublicationController c = controller();
        await c.load();
        await c.save();
        c.dispose();
        c = controller();
        await c.load();
        await c.save();
        expect(server.drafts, 1);
        expect(c.state.record?.authorApplied, isTrue);
        c.dispose();
      },
    );
  }

  test('the journal keeps ids only, never the meeting point', () async {
    final FindPeoplePublicationController c = controller();
    await c.load();
    await c.save();
    final String stored = await File('${temp.path}/fp.json').readAsString();
    // A pending write is cleared once applied, so no body remains in the file.
    for (final String secret in <String>[
      '56.95182',
      'Ķīpsalas iela',
      'blue bench',
    ]) {
      expect(stored.contains(secret), isFalse, reason: secret);
    }
    c.dispose();
  });

  test(
    'a page publisher is used as captured; another account is refused locally',
    () async {
      draft = draft.copyWith(
        findPeopleData: draft.findPeopleData!.copyWith(
          publisherType: FindPeoplePublisherType.page,
          publisherId: 'page-1',
        ),
      );
      final FindPeoplePublicationController c = controller();
      await c.load();
      await c.save();
      expect(
        server.publishers.single,
        const PublisherRef(type: PublisherType.page, id: 'page-1'),
      );
      c.dispose();
      draft = userFindPeopleDraft(userId: 'account-b');
      final FindPeoplePublicationController other = controller();
      await other.load();
      await other.save();
      expect(other.state.message, 'publisher_required');
      other.dispose();
    },
  );
}

final class _Drafts implements FindPeopleDraftSource {
  _Drafts(this.read);

  final CreateDraftEntity Function() read;

  @override
  Future<CreateDraftEntity?> current() async => read();
}

final class _Gate implements FindPeoplePublicationCommandGate {
  bool open = true;

  @override
  bool get allowed => open;

  @override
  void assertAllowed() {
    if (!open) throw StateError('closed');
  }
}

/// BCK-06 consent: revisioned, idempotent by key.
final class _Consents implements FindPeopleConsentGateway {
  final List<String> calls = <String>[];
  final List<String> grants = <String>[];
  final List<String> revokes = <String>[];
  FindPeopleConsentView? _current;

  @override
  Future<FindPeopleConsentView?> consent(String contentId) async {
    calls.add('get');
    return _current;
  }

  @override
  Future<FindPeopleConsentView> grant({
    required String contentId,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    calls.add('grant');
    grants.add(idempotencyKey);
    return _current = FindPeopleConsentView(
      state: 'active',
      revision: expectedRevision + 1,
      expiresAtUtc: DateTime.utc(2027, 6),
    );
  }

  @override
  Future<FindPeopleConsentView> revoke({
    required String contentId,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    calls.add('revoke');
    revokes.add(idempotencyKey);
    return _current = FindPeopleConsentView(
      state: 'revoked',
      revision: expectedRevision + 1,
      expiresAtUtc: DateTime.utc(2027, 6),
    );
  }
}

/// In-memory Content with idempotent keys and injected lost answers.
final class _Server implements EventPublicationGateway, ContentDraftReader {
  final List<String> calls = <String>[];
  final Set<String> loseAnswerOf = <String>{};
  final List<PublisherRef> publishers = <PublisherRef>[];
  final Map<String, EventServerDraftRef> _replies =
      <String, EventServerDraftRef>{};
  final Set<String> _published = <String>{};
  Map<String, Object?>? lastBody;
  int drafts = 0;
  int publications = 0;
  int _revision = 0;
  String? _submissionState;
  int? _pointer;
  String? _visibility;

  void approve() => _submissionState = 'approved_for_publication';

  EventServerDraftRef _ref() => EventServerDraftRef(
    contentId: 'content-1',
    draftId: 'draft-1',
    revision: _revision,
    createdByUserId: 'server-user-a',
  );

  Future<EventServerDraftRef> _once(
    String command,
    String key,
    EventServerDraftRef Function() apply,
  ) async {
    calls.add(command);
    final EventServerDraftRef reply = _replies[key] ??= apply();
    if (loseAnswerOf.remove(command)) {
      throw const EventPublicationUnavailable('transport');
    }
    return reply;
  }

  @override
  Future<EventServerDraftRef> createDraft({
    required PublisherRef publisherRef,
    required String marketId,
    required Map<String, Object?> body,
    required String idempotencyKey,
  }) => _once('createDraft', idempotencyKey, () {
    publishers.add(publisherRef);
    drafts += 1;
    _revision = 1;
    return _ref();
  });

  @override
  Future<EventServerDraftRef> updateDraft({
    required String draftId,
    required int expectedRevision,
    required Map<String, Object?> body,
    required String idempotencyKey,
  }) => _once('updateDraft', idempotencyKey, () {
    if (expectedRevision != _revision) {
      throw const EventPublicationRejected('revision_conflict');
    }
    lastBody = body;
    _revision += 1;
    return _ref();
  });

  @override
  Future<EventServerDraftRef> draft(String draftId) async {
    calls.add('getDraft');
    return _ref();
  }

  @override
  Future<String> submit({
    required String draftId,
    required int expectedDraftRevision,
    required String idempotencyKey,
  }) async {
    calls.add('submitForPublication');
    _submissionState = 'under_review';
    return 'submission-1';
  }

  @override
  Future<void> publishApproved({
    required String submissionId,
    required int expectedPointerRevision,
    required String idempotencyKey,
  }) async {
    calls.add('publishApprovedRevision');
    if (_published.add(idempotencyKey)) {
      publications += 1;
      _submissionState = 'published';
      _pointer = (_pointer ?? 0) + 1;
      _visibility = 'visible';
    }
    if (loseAnswerOf.remove('publishApprovedRevision')) {
      throw const EventPublicationUnavailable('transport');
    }
  }

  @override
  Future<void> withdraw({
    required String contentId,
    required int expectedPointerRevision,
    required String idempotencyKey,
  }) async {
    calls.add('withdrawPublication');
    _pointer = (_pointer ?? 0) + 1;
    _visibility = 'withdrawn';
  }

  @override
  Future<EventPublicationStatus> status(String contentId) async =>
      EventPublicationStatus(
        contentId: contentId,
        latestSubmissionId: _submissionState == null ? null : 'submission-1',
        latestSubmissionState: _submissionState,
        pointerRevision: _pointer,
        visibility: _visibility,
        currentPublishedRevisionId: _visibility == null ? null : 'revision-1',
      );
}
