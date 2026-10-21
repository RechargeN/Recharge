import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/class_workshop_publication_controller.dart';
import 'package:recharge/features/create/data/file_class_workshop_publication_journal.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_publication.dart';
import 'package:recharge/features/create/domain/repositories/event_publication_gateway.dart';
import 'package:recharge/features/create/domain/repositories/class_workshop_publication_gateway.dart';

import 'package:recharge/features/create/data/repositories/event_timezone_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_availability.dart';
import 'package:recharge/features/create/domain/usecases/build_class_workshop_content_body.dart';

import '../fixtures/create/user_class_workshop_draft.dart';

void main() {
  late Directory temp;
  late _Server server;
  late _Uploader uploader;
  late _Media media;
  late _Gate gate;
  late FileClassWorkshopPublicationJournal journal;
  const cover = 'cover.png';
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('t2-class-controller-');
    server = _Server();
    uploader = _Uploader();
    media = _Media(<String, Uint8List>{
      cover: Uint8List.fromList(<int>[1, 2, 3]),
    });
    gate = _Gate();
    journal = FileClassWorkshopPublicationJournal(
      File('${temp.path}/class-workshop.json'),
    );
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });
  ClassWorkshopPublicationController controller([CreateDraftEntity? draft]) =>
      ClassWorkshopPublicationController(
        accountId: 'account-a',
        defaultContentLocale: 'en',
        drafts: _Drafts(
          draft ??
              userClassWorkshopDraft(userId: 'account-a', coverPath: cover),
        ),
        mapper: ClassWorkshopContentBodyMapper(EventTimezoneRepositoryImpl()),
        gateway: server,
        reader: server,
        uploader: uploader,
        mediaSource: media,
        journal: journal,
        gate: gate,
      );
  test('default closed gate sends nothing', () async {
    gate.open = false;
    final c = controller();
    await c.load();
    await c.save();
    expect(server.calls, isEmpty);
    c.dispose();
  });
  for (final lost in <String>['createDraft', 'updateDraft']) {
    test('lost $lost response resumes with one draft', () async {
      server.loseAnswerOf.add(lost);
      var c = controller();
      await c.load();
      await c.save();
      c.dispose();
      c = controller();
      await c.load();
      await c.save();
      expect(server.drafts.length, 1);
      expect(c.state.record?.authorApplied, isTrue);
      c.dispose();
    });
  }
  test(
    'real controller saves/uploads/submits and recovers a lost publish response',
    () async {
      final c = controller();
      await c.load();
      await c.save();
      await c.uploadMedia();
      await c.submit();
      expect(c.state.record?.submissionId, isNotNull);
      server.approve(c.state.record!.submissionId!);
      await c.refresh();
      server.loseAnswerOf.add('publishApprovedRevision');
      await c.publish();
      await c.publish();
      expect(server.publications, 1);
      expect(c.state.status?.visibility, 'visible');
      expect(c.state.canSave, isFalse);
      expect(c.state.canUploadMedia, isFalse);
      final writes = server.calls.where((v) => v == 'updateDraft').length;
      await c.save();
      expect(c.state.message, 'editing_after_publication_not_supported');
      expect(server.calls.where((v) => v == 'updateDraft').length, writes);

      c.dispose();
    },
  );
  test('a legacy generic schedule refuses locally and sends nothing', () async {
    final legacy = userClassWorkshopDraft(userId: 'account-a', coverPath: cover)
        .copyWith(
          scheduleSlots: <CreateTimeSlotDraft>[
            CreateTimeSlotDraft(
              localId: 'loc_slot',
              startAtUtc: DateTime.utc(2027, 5, 15, 7),
              endAtUtc: DateTime.utc(2027, 5, 15, 10),
            ),
          ],
        );
    final c = controller(legacy);
    await c.load();
    await c.save();
    expect(c.state.message, 'unsupported_capability:eventSlots');
    expect(server.calls, isEmpty);
    c.dispose();
  });
  test('a non-Class draft is never published through the Class path', () async {
    final other = userClassWorkshopDraft(
      userId: 'account-a',
      coverPath: cover,
    ).copyWith(objectType: CreateObjectType.session);
    final c = controller(other);
    await c.load();
    expect(c.state.phase, ClassWorkshopPublicationPhase.noDraft);
    await c.save();
    expect(server.calls, isEmpty);
    c.dispose();
  });
}

final class _Drafts implements ClassWorkshopDraftSource {
  _Drafts(this.draft);

  final CreateDraftEntity draft;

  @override
  Future<CreateDraftEntity?> current() async => draft;
}

final class _Gate implements ClassWorkshopPublicationCommandGate {
  bool open = true;

  @override
  bool get allowed => open;

  @override
  void assertAllowed() {
    if (!open) throw StateError('closed');
  }
}

final class _Media implements EventCoverSource {
  _Media(this.files);

  final Map<String, Uint8List> files;

  @override
  Future<Uint8List?> read(String reference) async => files[reference];
}

final class _Uploader implements EventCoverUploader {
  final List<String> intents = <String>[];
  final Map<String, String> _assets = <String, String>{};

  String? assetFor(String intent) => _assets[intent];

  @override
  Future<String> upload({
    required String intentId,
    required Uint8List bytes,
    required String declaredMediaType,
    required PublisherRef publisherRef,
    required String contentId,
  }) async {
    intents.add(intentId);
    return _assets.putIfAbsent(intentId, () => 'asset-${_assets.length + 1}');
  }
}

final class _Draft {
  const _Draft({
    required this.contentId,
    required this.revision,
    required this.owner,
    required this.body,
  });

  final String contentId;
  final int revision;
  final String owner;
  final Map<String, Object?> body;

  _Draft withOwner(String value) => _Draft(
    contentId: contentId,
    revision: revision,
    owner: value,
    body: body,
  );
}

/// In-memory Content: drafts with revisions and authors, idempotent keys
/// (same key and payload replay the stored answer), and injected failures.
final class _Server implements EventPublicationGateway, ContentDraftReader {
  final Map<String, _Draft> drafts = <String, _Draft>{};
  final List<String> calls = <String>[];
  final List<({String key, Map<String, Object?> body})> creates =
      <({String key, Map<String, Object?> body})>[];
  final Set<String> loseAnswerOf = <String>{};
  final Map<String, String> _publishReplies = <String, String>{};
  int publications = 0;
  final Set<String> failBefore = <String>{};
  final Map<String, (String, EventServerDraftRef)> _replies =
      <String, (String, EventServerDraftRef)>{};
  final Map<String, String> _submissionStates = <String, String>{};
  String? _latestSubmission;
  int? _pointerRevision;
  String? _visibility;
  int _counter = 0;

  /// The account behind the current call: the first create makes it A.
  String owner = 'server-user-a';

  void approve(String submissionId) =>
      _submissionStates[submissionId] = 'approved_for_publication';

  /// M1 D2: another install of the same author saves the draft.
  void writeElsewhere(String draftId, Map<String, Object?> body) {
    final _Draft current = drafts[draftId]!;
    drafts[draftId] = _Draft(
      contentId: current.contentId,
      revision: current.revision + 1,
      owner: current.owner,
      body: body,
    );
  }

  EventServerDraftRef _ref(String draftId) {
    final _Draft draft = drafts[draftId]!;
    return EventServerDraftRef(
      contentId: draft.contentId,
      draftId: draftId,
      revision: draft.revision,
      createdByUserId: draft.owner,
    );
  }

  Future<EventServerDraftRef> _idempotent(
    String command,
    String key,
    Map<String, Object?> payload,
    EventServerDraftRef Function() apply,
  ) async {
    calls.add(command);
    if (failBefore.remove(command)) {
      throw const EventPublicationUnavailable('transport');
    }
    final String fingerprint = jsonEncode(payload);
    final (String, EventServerDraftRef)? stored = _replies[key];
    final EventServerDraftRef reply;
    if (stored != null) {
      if (stored.$1 != fingerprint) {
        throw const EventPublicationRejected('idempotency_conflict');
      }
      reply = stored.$2;
    } else {
      reply = apply();
      _replies[key] = (fingerprint, reply);
    }
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
  }) {
    creates.add((key: idempotencyKey, body: body));
    return _idempotent(
      'createDraft',
      idempotencyKey,
      <String, Object?>{'publisher': publisherRef.id, 'body': body},
      () {
        _counter += 1;
        final String draftId = 'draft-$_counter';
        // A second account (another key scope) is another server user.
        final String author = drafts.isEmpty ? owner : 'server-user-$_counter';
        drafts[draftId] = _Draft(
          contentId: 'content-$_counter',
          revision: 1,
          owner: author,
          body: body,
        );
        return _ref(draftId);
      },
    );
  }

  @override
  Future<EventServerDraftRef> updateDraft({
    required String draftId,
    required int expectedRevision,
    required Map<String, Object?> body,
    required String idempotencyKey,
  }) => _idempotent(
    'updateDraft',
    idempotencyKey,
    <String, Object?>{
      'draftId': draftId,
      'expectedRevision': expectedRevision,
      'body': body,
    },
    () {
      final _Draft current = drafts[draftId]!;
      if (current.revision != expectedRevision) {
        throw const EventPublicationRejected('revision_conflict');
      }
      drafts[draftId] = _Draft(
        contentId: current.contentId,
        revision: current.revision + 1,
        owner: current.owner,
        body: body,
      );
      return _ref(draftId);
    },
  );

  @override
  Future<EventServerDraftRef> draft(String draftId) async {
    calls.add('getDraft');
    if (!drafts.containsKey(draftId)) {
      throw const EventPublicationRejected('not_found');
    }
    return _ref(draftId);
  }

  /// M1 stage 3: the next submit is refused with these details.
  EventPublicationRejected? refuseSubmit;

  @override
  Future<String> submit({
    required String draftId,
    required int expectedDraftRevision,
    required String idempotencyKey,
  }) async {
    calls.add('submitForPublication');
    final EventPublicationRejected? refusal = refuseSubmit;
    if (refusal != null) {
      refuseSubmit = null;
      throw refusal;
    }
    _latestSubmission = 'submission-1';
    _submissionStates['submission-1'] = 'under_review';
    return 'submission-1';
  }

  @override
  Future<void> publishApproved({
    required String submissionId,
    required int expectedPointerRevision,
    required String idempotencyKey,
  }) async {
    calls.add('publishApprovedRevision');
    // Like Content: a key replays its stored answer only for the same payload.
    final String fingerprint = '$submissionId:$expectedPointerRevision';
    final String? stored = _publishReplies[idempotencyKey];
    if (stored != null) {
      if (stored != fingerprint) {
        throw const EventPublicationRejected('idempotency_conflict');
      }
    } else {
      _publishReplies[idempotencyKey] = fingerprint;
      publications += 1;
      _submissionStates[submissionId] = 'published';
      _pointerRevision = (_pointerRevision ?? 0) + 1;
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
    _pointerRevision = (_pointerRevision ?? 0) + 1;
    _visibility = 'withdrawn';
  }

  @override
  Future<EventPublicationStatus> status(String contentId) async =>
      EventPublicationStatus(
        contentId: contentId,
        latestSubmissionId: _latestSubmission,
        latestSubmissionState: _latestSubmission == null
            ? null
            : _submissionStates[_latestSubmission],
        pointerRevision: _pointerRevision,
        visibility: _visibility,
        currentPublishedRevisionId: _visibility == null ? null : 'revision-1',
      );
}
