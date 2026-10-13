import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/local_import_cleanup_policy.dart';
import 'package:recharge/features/create/application/local_import_controller.dart';
import 'package:recharge/features/create/data/file_local_import_journal.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_publication.dart';
import 'package:recharge/features/create/domain/entities/local_import.dart';
import 'package:recharge/features/create/domain/entities/place_draft_data.dart';
import 'package:recharge/features/create/domain/repositories/event_publication_gateway.dart';
import 'package:recharge/features/create/domain/repositories/local_import_gateway.dart';
import 'package:recharge/features/create/domain/repositories/publisher_access_check.dart';

import '../fixtures/create/user_collection_draft.dart';
import '../fixtures/create/user_place_draft.dart';

/// D4 §5–§6: the import controller against an in-memory Content server that
/// keeps idempotent keys, deduplicates a local import source per author, and
/// can lose answers. Dry run sends nothing; an interrupted, resumed or
/// repeated import never creates a second server draft; a changed local item
/// is a conflict; the local original goes only after verification, explicit
/// confirmation and the recovery period, with fresh server and local checks.
void main() {
  late Directory temp;
  late _Server server;
  late _Uploader uploader;
  late _Media media;
  late _Gate gate;
  late _Source source;
  late _Originals originals;
  late _Access access;
  late _Existing existing;
  late FileLocalImportJournal journal;
  late DateTime now;

  const String account = 'user-1';
  const String cover = 'C:/photos/cover.png';
  const String photo = 'C:/photos/a.png';

  CreateDraftEntity place({String localId = 'loc_place_1', String? title}) =>
      userPlaceDraft(
        pageId: 'page-1',
        coverPath: cover,
        galleryPaths: const <String>[photo],
        localId: localId,
        title: title ?? 'Kronvalda park pond',
      );

  LocalImportController controller({LocalImportJournal? withJournal}) =>
      LocalImportController(
        accountId: account,
        source: source,
        journal: withJournal ?? journal,
        existing: existing,
        gateway: server,
        uploader: uploader,
        mediaSource: media,
        publisherAccess: access,
        originals: originals,
        gate: gate,
        clock: () => now,
        newSessionId: () => 'session-${now.microsecondsSinceEpoch}',
      );

  LocalImportItemView itemOf(LocalImportController c, String id) =>
      c.state.items.singleWhere((item) => item.candidate.localDraftId == id);

  Future<LocalImportController> imported(CreateDraftEntity draft) async {
    source.set(<CreateDraftEntity>[draft]);
    final LocalImportController c = controller();
    await c.load();
    await c.approve();
    await c.run();
    return c;
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('local-import-');
    server = _Server();
    uploader = _Uploader();
    media = _Media(<String, Uint8List>{
      cover: Uint8List.fromList(<int>[1, 1, 1]),
      photo: Uint8List.fromList(<int>[2, 2, 2]),
    });
    gate = _Gate();
    source = _Source();
    originals = _Originals(source);
    access = _Access(<String>{'user:user-1', 'page:page-1'});
    existing = _Existing();
    journal = FileLocalImportJournal(
      receipts: File('${temp.path}/receipts.json'),
      sessions: File('${temp.path}/sessions.json'),
    );
    now = DateTime.utc(2026, 10, 13, 10);
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test('a closed entry sends nothing', () async {
    gate.open = false;
    source.set(<CreateDraftEntity>[place()]);
    final LocalImportController c = controller();
    await c.load();
    await c.approve();
    await c.run();
    expect(c.state.message, 'not_allowed');
    expect(server.calls, isEmpty);
    expect(uploader.intents, isEmpty);
  });

  test(
    'the dry run classifies every item and calls nothing on the server',
    () async {
      final CreateDraftEntity foreign = place(
        localId: 'loc_foreign',
      ).copyWith(organizerId: 'someone-else');
      source.set(<CreateDraftEntity>[
        place(),
        foreign,
        userPlaceDraft(
          pageId: 'page-not-mine',
          coverPath: cover,
          localId: 'loc_other_page',
        ),
      ]);
      source.listed.add(
        const LocalImportSourceItem(
          localDraftId: 'loc_scenario_1',
          localType: 'scenario',
          title: 'Weekend',
        ),
      );
      existing.ids['loc_published'] = 'content-test-path';
      source.add(place(localId: 'loc_published'));
      final LocalImportController c = controller();
      await c.load();
      final Map<String, (LocalImportClass, String?)> classes =
          <String, (LocalImportClass, String?)>{
            for (final LocalImportItemView item in c.state.items)
              item.candidate.localDraftId: (
                item.candidate.classification,
                item.candidate.reason,
              ),
          };
      expect(classes, <String, (LocalImportClass, String?)>{
        'loc_place_1': (LocalImportClass.create, null),
        'loc_foreign': (LocalImportClass.blocked, 'owner_mismatch'),
        'loc_other_page': (LocalImportClass.blocked, 'publisher_not_eligible'),
        'loc_published': (
          LocalImportClass.alreadyMapped,
          'published_by_test_path',
        ),
        'loc_scenario_1': (
          LocalImportClass.unsupported,
          'type_not_importable:scenario',
        ),
      });
      expect(server.calls, isEmpty);
      expect(uploader.intents, isEmpty);
      expect(itemOf(c, 'loc_place_1').candidate.sourceHash, hasLength(64));
    },
  );

  test(
    'approve and run import one server draft, verified against the server copy',
    () async {
      final LocalImportController c = await imported(place());
      expect(c.state.message, isNull);
      expect(server.calls.take(2), <String>['createDraft', 'updateDraft']);
      expect(server.creates.single.body, isEmpty);
      expect(server.creates.single.importSourceKey, 'loc_place_1');
      final _Draft stored = server.drafts.values.single;
      expect(stored.importSourceKey, 'loc_place_1');
      // Place names its author: the server's own record, never a local id.
      expect(
        (stored.body['provenance']!
            as Map<String, Object?>)['submittedByUserId'],
        'server-user-a',
      );
      expect(uploader.intents, hasLength(2), reason: 'cover and one photo');
      final LocalImportItemView item = itemOf(c, 'loc_place_1');
      expect(item.candidate.classification, LocalImportClass.alreadyMapped);
      expect(item.receipt?.state, LocalImportItemState.verified);
      expect(item.receipt?.verifiedAtUtc, now);
      expect(item.cleanup.stage, LocalImportCleanupStage.awaitingConfirmation);
      expect(c.state.session?.status, LocalImportSessionStatus.completed);
      expect(c.state.session?.checkpoint, 1);
      // Nothing left to import: a second approval is refused locally.
      await c.approve();
      expect(c.state.message, 'nothing_to_import');
      expect(server.drafts, hasLength(1));
    },
  );

  test(
    'a lost create answer pauses the session; resume finds the same draft',
    () async {
      source.set(<CreateDraftEntity>[place()]);
      final LocalImportController c = controller();
      await c.load();
      await c.approve();
      server.loseAnswerOf.add('createDraft');
      await c.run();
      expect(c.state.phase, LocalImportPhase.offline);
      expect(c.state.session?.status, LocalImportSessionStatus.paused);
      expect(c.state.session?.checkpoint, 0);
      // A paused session is resumed, never replaced by a new approval.
      await c.approve();
      expect(c.state.message, 'session_open');
      await c.run();
      expect(c.state.message, isNull);
      expect(c.state.session?.status, LocalImportSessionStatus.completed);
      expect(server.drafts, hasLength(1), reason: 'never a second draft');
    },
  );

  test(
    'a lost body answer and a restart resume from the durable step',
    () async {
      source.set(<CreateDraftEntity>[place()]);
      final LocalImportController first = controller();
      await first.load();
      await first.approve();
      server.loseAnswerOf.add('updateDraft');
      await first.run();
      expect(first.state.session?.status, LocalImportSessionStatus.paused);
      // An app restart: a new controller over the same journal resumes.
      final LocalImportController restarted = controller();
      await restarted.load();
      expect(
        itemOf(restarted, 'loc_place_1').candidate.reason,
        'resume',
        reason: 'imported before, not verified yet',
      );
      await restarted.run();
      expect(
        restarted.state.session?.status,
        LocalImportSessionStatus.completed,
      );
      expect(server.drafts, hasLength(1));
      expect(uploader.intents, hasLength(2), reason: 'no upload repeated');
      expect(
        itemOf(restarted, 'loc_place_1').receipt?.state,
        LocalImportItemState.verified,
      );
    },
  );

  test(
    'lost receipts: the server returns the draft this author imported from the same source',
    () async {
      await imported(place());
      final String contentId = server.drafts.values.single.contentId;
      // Another journal (receipts lost), same local draft.
      final FileLocalImportJournal fresh = FileLocalImportJournal(
        receipts: File('${temp.path}/other-receipts.json'),
        sessions: File('${temp.path}/other-sessions.json'),
      );
      final LocalImportController again = controller(withJournal: fresh);
      await again.load();
      expect(
        itemOf(again, 'loc_place_1').candidate.classification,
        LocalImportClass.create,
      );
      await again.approve();
      await again.run();
      expect(server.drafts, hasLength(1), reason: 'deduplicated by the server');
      expect(itemOf(again, 'loc_place_1').receipt?.contentId, contentId);
      expect(
        itemOf(again, 'loc_place_1').receipt?.state,
        LocalImportItemState.verified,
      );
    },
  );

  test(
    'an upload session that expired unfinished moves to a new intent, saved before it is used',
    () async {
      uploader.expireNext = 1;
      final LocalImportController c = await imported(place());
      final LocalImportReceipt receipt = itemOf(c, 'loc_place_1').receipt!;
      expect(receipt.state, LocalImportItemState.verified);
      expect(receipt.uploadAttempts.values, <int>[1]);
      expect(uploader.tried, hasLength(3), reason: 'one expired, two uploaded');
      expect(uploader.dead, hasLength(1));
      expect(uploader.intents, isNot(contains(uploader.dead.single)));
      expect(receipt.attachments.map((item) => item.assetId), <String>[
        'asset-1',
        'asset-2',
      ]);
      expect(server.drafts, hasLength(1));
    },
  );

  test(
    'sessions that keep expiring fail the item after the per-run bound; the next run and lost receipts go on without a dead intent',
    () async {
      const int bound = LocalImportController.uploadAttemptsPerRun;
      uploader.expireNext = bound;
      source.set(<CreateDraftEntity>[place()]);
      final LocalImportController first = controller();
      await first.load();
      await first.approve();
      await first.run();
      final LocalImportReceipt failed = itemOf(first, 'loc_place_1').receipt!;
      expect(failed.state, LocalImportItemState.failed);
      expect(failed.failureCode, 'session_expired');
      expect(uploader.tried, hasLength(bound));
      expect(failed.uploadAttempts.values, <int>[bound]);
      first.dispose();

      // A restart goes on from the saved attempt: no dead intent again.
      final int before = uploader.tried.length;
      final LocalImportController restarted = controller();
      await restarted.load();
      expect(itemOf(restarted, 'loc_place_1').candidate.reason, 'resume');
      await restarted.approve();
      await restarted.run();
      expect(
        itemOf(restarted, 'loc_place_1').receipt?.state,
        LocalImportItemState.verified,
      );
      expect(
        uploader.tried.skip(before).where(uploader.dead.contains),
        isEmpty,
      );
      expect(server.drafts, hasLength(1));
      restarted.dispose();

      // Receipts lost: the walk passes the dead intents (one run's bound) and
      // the next run reuses the asset of the attempt that worked.
      final FileLocalImportJournal fresh = FileLocalImportJournal(
        receipts: File('${temp.path}/other-receipts.json'),
        sessions: File('${temp.path}/other-sessions.json'),
      );
      final int assets = uploader.intents.length;
      LocalImportController again = controller(withJournal: fresh);
      await again.load();
      await again.approve();
      await again.run();
      expect(
        itemOf(again, 'loc_place_1').receipt?.failureCode,
        'session_expired',
      );
      again.dispose();
      again = controller(withJournal: fresh);
      await again.load();
      await again.approve();
      await again.run();
      expect(
        itemOf(again, 'loc_place_1').receipt?.state,
        LocalImportItemState.verified,
      );
      expect(uploader.intents, hasLength(assets), reason: 'no new asset');
      expect(server.drafts, hasLength(1));
      again.dispose();
    },
  );

  test(
    'a local change after import is a conflict; importing again updates the same draft',
    () async {
      final LocalImportController c = await imported(place());
      await c.confirm('loc_place_1');
      expect(itemOf(c, 'loc_place_1').receipt?.confirmedAtUtc, now);
      source.set(<CreateDraftEntity>[place(title: 'Kronvalda pond, revised')]);
      await c.load();
      final LocalImportItemView changed = itemOf(c, 'loc_place_1');
      expect(changed.candidate.classification, LocalImportClass.conflict);
      expect(changed.candidate.reason, 'local_changed_since_import');
      // Not imported until the user chooses it.
      expect(c.state.canApprove, isFalse);
      c.chooseUpdate('loc_place_1');
      expect(c.state.canApprove, isTrue);
      await c.approve();
      await c.run();
      expect(server.drafts, hasLength(1));
      expect(
        server.drafts.values.single.body['title'],
        'Kronvalda pond, revised',
      );
      final LocalImportItemView updated = itemOf(c, 'loc_place_1');
      expect(updated.candidate.classification, LocalImportClass.alreadyMapped);
      // A new import needs a new confirmation.
      expect(updated.receipt?.confirmedAtUtc, isNull);
    },
  );

  test(
    'an item changed after approval is not imported in that session',
    () async {
      source.set(<CreateDraftEntity>[place()]);
      final LocalImportController c = controller();
      await c.load();
      await c.approve();
      source.set(<CreateDraftEntity>[place(title: 'Changed after approval')]);
      await c.run();
      expect(server.calls, isEmpty);
      expect(c.state.session?.status, LocalImportSessionStatus.completed);
      expect(
        itemOf(c, 'loc_place_1').candidate.classification,
        LocalImportClass.create,
      );
    },
  );

  test(
    'a refused create is recorded for the item and the run goes on',
    () async {
      server.refuseCreate = 'type_disabled';
      source.set(<CreateDraftEntity>[place()]);
      final LocalImportController c = controller();
      await c.load();
      await c.approve();
      await c.run();
      expect(c.state.session?.status, LocalImportSessionStatus.completed);
      expect(itemOf(c, 'loc_place_1').failureCode, 'type_disabled');
      expect(itemOf(c, 'loc_place_1').receipt, isNull);
      expect(server.drafts, isEmpty);
    },
  );

  test(
    'the local original goes only after verification, confirmation and 30 days',
    () async {
      final LocalImportController c = await imported(place());
      await c.deleteLocal('loc_place_1');
      expect(c.state.message, 'cleanup_awaitingConfirmation');
      await c.confirm('loc_place_1');
      now = now.add(const Duration(days: 29));
      await c.load();
      await c.deleteLocal('loc_place_1');
      expect(c.state.message, 'cleanup_recoveryPeriod');
      expect(originals.deleted, isEmpty);
      now = now.add(const Duration(days: 2));
      await c.load();
      expect(
        itemOf(c, 'loc_place_1').cleanup.stage,
        LocalImportCleanupStage.eligible,
      );
      // A server copy that no longer matches refuses the deletion.
      server.drafts.values.single.owner = 'intruder';
      await c.deleteLocal('loc_place_1');
      expect(c.state.message, 'server_check_failed');
      server.drafts.values.single.owner = 'server-user-a';
      // A local change since the import refuses it too.
      source.set(<CreateDraftEntity>[place(title: 'Edited locally')]);
      await c.load();
      await c.deleteLocal('loc_place_1');
      expect(c.state.message, 'local_changed_since_import');
      expect(originals.deleted, isEmpty);
      source.set(<CreateDraftEntity>[place()]);
      await c.load();
      await c.deleteLocal('loc_place_1');
      expect(c.state.message, isNull);
      expect(originals.deleted, <String>['loc_place_1']);
      expect(c.state.items, isEmpty, reason: 'the local original is gone');
    },
  );

  test(
    'a Collection is imported with its review bound to the revision the save produces',
    () async {
      access.allowed.add('page:$collectionCompatPageId');
      final CreateDraftEntity collection = userCollectionDraft(
        pageId: collectionCompatPageId,
        members: collectionCompatMembers(),
        coverPath: cover,
        localId: 'loc_collection_1',
      ).copyWith(organizerId: account);
      await imported(collection);
      final _Draft stored = server.drafts.values.single;
      expect(stored.typeId, 'collection');
      expect(stored.revision, 2);
      expect(
        (stored.body['compositionReview']!
            as Map<String, Object?>)['draftRevision'],
        2,
      );
      expect(
        ((stored.body['media']! as Map<String, Object?>)['coverImage']!
            as Map<String, Object?>)['mediaId'],
        startsWith('asset-'),
      );
    },
  );

  test(
    'a draft the server cannot hold is unsupported and never sent',
    () async {
      // Seasonal hours are outside the Place body (D3.1 §5.3): refused locally.
      final CreateDraftEntity seasonal = place().copyWith(
        placeData: place().placeData!.copyWith(
          hours: place().placeData!.hours.copyWith(
            mode: PlaceHoursMode.seasonal,
          ),
        ),
      );
      source.set(<CreateDraftEntity>[seasonal]);
      final LocalImportController c = controller();
      await c.load();
      final LocalImportItemView item = itemOf(c, 'loc_place_1');
      expect(item.candidate.classification, LocalImportClass.unsupported);
      expect(item.candidate.reason, 'unsupported_capability:hours.seasonal');
      await c.approve();
      expect(c.state.message, 'nothing_to_import');
      expect(server.calls, isEmpty);
    },
  );

  // ------------------------------------------------------------------ D4.1

  Future<LocalImportController> eligible(CreateDraftEntity draft) async {
    final LocalImportController c = await imported(draft);
    await c.confirm(draft.id);
    now = now.add(const Duration(days: 31));
    await c.load();
    return c;
  }

  test(
    'D4.1: rollback tombstones the server draft; the local original stays byte for byte and is never cleaned up',
    () async {
      final CreateDraftEntity original = place();
      final LocalImportController c = await imported(original);
      final String draftId = server.drafts.keys.single;
      final Uint8List coverBytes = Uint8List.fromList(media.files[cover]!);
      expect(itemOf(c, 'loc_place_1').canRollBack, isTrue);
      await c.rollback('loc_place_1');
      expect(c.state.message, isNull);
      expect(server.drafts[draftId]!.status, 'rolledBack');
      expect(server.bindings['loc_place_1']!.state, 'rolledBack');
      final LocalImportItemView item = itemOf(c, 'loc_place_1');
      expect(item.receipt?.state, LocalImportItemState.rolledBack);
      expect(item.receipt?.rolledBackAtUtc, now);
      expect(item.cleanup.stage, LocalImportCleanupStage.rolledBack);
      expect(item.candidate.classification, LocalImportClass.conflict);
      expect(item.candidate.reason, 'rolled_back');
      expect(item.canRollBack, isFalse);
      // The local original is exactly what was imported.
      expect(source.drafts.single, original);
      expect(media.files[cover], coverBytes);
      // Cleanup is refused for good, also after the recovery period.
      now = now.add(const Duration(days: 60));
      await c.load();
      await c.deleteLocal('loc_place_1');
      expect(c.state.message, 'cleanup_rolledBack');
      expect(originals.deleted, isEmpty);
      expect(server.calls, isNot(contains('reserveImportCleanup')));
    },
  );

  test(
    'D4.1: a lost rollback answer and a restart keep rollbackPending; the same intent is sent again',
    () async {
      final LocalImportController first = await imported(place());
      server.loseAnswerOf.add('rollbackImportedDraft');
      await first.rollback('loc_place_1');
      expect(first.state.phase, LocalImportPhase.offline);
      final LocalImportReceipt pending = itemOf(first, 'loc_place_1').receipt!;
      expect(pending.state, LocalImportItemState.rollbackPending);
      expect(pending.rollbackKey, contains(':g1:rollback:2'));
      expect(pending.rollbackExpectedRevision, 2);
      first.dispose();

      final LocalImportController restarted = controller();
      await restarted.load();
      final LocalImportItemView item = itemOf(restarted, 'loc_place_1');
      expect(item.cleanup.stage, LocalImportCleanupStage.rollbackPending);
      expect(item.candidate.reason, 'rollback_pending');
      // Nothing else may touch the item while the outcome is unknown.
      await restarted.deleteLocal('loc_place_1');
      expect(restarted.state.message, 'cleanup_rollbackPending');
      expect(restarted.state.canApprove, isFalse);
      await restarted.rollback('loc_place_1');
      expect(restarted.state.message, isNull);
      expect(
        itemOf(restarted, 'loc_place_1').receipt?.state,
        LocalImportItemState.rolledBack,
      );
      final List<String> rollbackKeys = server.keyed
          .where((e) => e.$1 == 'rollbackImportedDraft')
          .map((e) => e.$2)
          .toList();
      expect(rollbackKeys, hasLength(2));
      expect(rollbackKeys.toSet(), hasLength(1), reason: 'the same key');
      expect(server.drafts.values.single.revision, 3, reason: 'applied once');
    },
  );

  test(
    'D4.1: a server copy changed since the receipt refuses the rollback without override',
    () async {
      final LocalImportController c = await imported(place());
      server.editElsewhere(server.drafts.keys.single);
      await c.rollback('loc_place_1');
      expect(c.state.message, 'revision_conflict');
      final LocalImportReceipt receipt = itemOf(c, 'loc_place_1').receipt!;
      expect(receipt.state, LocalImportItemState.verified);
      expect(receipt.failureCode, 'revision_conflict');
      expect(receipt.rollbackKey, isNull);
      expect(server.drafts.values.single.status, 'editing');
      expect(server.drafts.values.single.body['title'], 'Edited elsewhere');
    },
  );

  test(
    'D4.1: a rollback refused because another installation already rolled back records it',
    () async {
      final LocalImportController c = await imported(place());
      server.rollBackElsewhere('loc_place_1');
      await c.rollback('loc_place_1');
      expect(c.state.message, isNull);
      expect(
        itemOf(c, 'loc_place_1').receipt?.state,
        LocalImportItemState.rolledBack,
      );
      expect(server.calls, contains('getImportBinding'));
    },
  );

  test(
    'D4.1: cleanup runs intent, reservation, deletion and completion in that order',
    () async {
      final LocalImportController c = await eligible(place());
      server.calls.clear();
      await c.deleteLocal('loc_place_1');
      expect(c.state.message, isNull);
      expect(server.calls, <String>[
        'getDraft',
        'reserveImportCleanup',
        'completeImportCleanup',
      ]);
      expect(originals.deleted, <String>['loc_place_1']);
      expect(server.bindings['loc_place_1']!.cleanupState, 'done');
      final LocalImportReceipt receipt = (await journal.receipts(
        account,
      )).single;
      expect(receipt.localDeletedAtUtc, now);
      expect(receipt.cleanupCompletedAtUtc, now);
      expect(receipt.cleanupToken, startsWith('ct-'));
      expect(c.state.pendingCleanups, 0);
    },
  );

  test(
    'D4.1: a lost completion after the deletion is finished after a restart with the same token',
    () async {
      final LocalImportController first = await eligible(place());
      server.loseAnswerOf.add('completeImportCleanup');
      await first.deleteLocal('loc_place_1');
      expect(first.state.phase, LocalImportPhase.offline);
      expect(originals.deleted, <String>['loc_place_1']);
      first.dispose();

      final LocalImportController restarted = controller();
      await restarted.load();
      expect(restarted.state.items, isEmpty);
      expect(restarted.state.pendingCleanups, 1);
      await restarted.finishCleanups();
      expect(restarted.state.message, isNull);
      expect(restarted.state.pendingCleanups, 0);
      final List<String> completeKeys = server.keyed
          .where((e) => e.$1 == 'completeImportCleanup')
          .map((e) => e.$2)
          .toList();
      expect(completeKeys, hasLength(2));
      expect(completeKeys.toSet(), hasLength(1));
      expect(server.bindings['loc_place_1']!.cleanupState, 'done');
    },
  );

  test(
    'D4.1: a lost reservation answer keeps the intent; rollback is refused locally; the retry reuses the token',
    () async {
      final LocalImportController first = await eligible(place());
      server.loseAnswerOf.add('reserveImportCleanup');
      await first.deleteLocal('loc_place_1');
      expect(first.state.phase, LocalImportPhase.offline);
      expect(originals.deleted, isEmpty, reason: 'not before the reservation');
      first.dispose();

      final LocalImportController restarted = controller();
      await restarted.load();
      final LocalImportItemView item = itemOf(restarted, 'loc_place_1');
      expect(item.candidate.reason, 'cleanup_pending');
      expect(item.canRollBack, isFalse);
      await restarted.rollback('loc_place_1');
      expect(restarted.state.message, 'cleanup_reserved');
      expect(server.calls, isNot(contains('rollbackImportedDraft')));
      await restarted.deleteLocal('loc_place_1');
      expect(restarted.state.message, isNull);
      expect(originals.deleted, <String>['loc_place_1']);
      final List<String> reserveKeys = server.keyed
          .where((e) => e.$1 == 'reserveImportCleanup')
          .map((e) => e.$2)
          .toList();
      expect(reserveKeys.toSet(), hasLength(1));
    },
  );

  test(
    'D4.1: cleanup after another installation rolled back keeps the original',
    () async {
      final LocalImportController c = await eligible(place());
      server.rollBackElsewhere('loc_place_1');
      await c.deleteLocal('loc_place_1');
      expect(c.state.message, 'server_check_failed');
      expect(originals.deleted, isEmpty);
      expect(server.calls, isNot(contains('reserveImportCleanup')));
    },
  );

  test(
    'D4.1: a rollback that wins the race against the reservation drops the cleanup intent',
    () async {
      final LocalImportController c = await eligible(place());
      server.beforeReserve = () => server.rollBackElsewhere('loc_place_1');
      await c.deleteLocal('loc_place_1');
      expect(c.state.message, 'import_rolled_back');
      expect(originals.deleted, isEmpty);
      final LocalImportReceipt receipt = itemOf(c, 'loc_place_1').receipt!;
      expect(receipt.cleanupToken, isNull);
      expect(receipt.failureCode, 'import_rolled_back');
      expect(receipt.state, LocalImportItemState.verified);
    },
  );

  test(
    'D4.1: a rollback against a reservation of another installation is refused; nothing is lost',
    () async {
      final LocalImportController c = await imported(place());
      server.reserveElsewhere('loc_place_1');
      await c.rollback('loc_place_1');
      expect(c.state.message, 'cleanup_reserved');
      final LocalImportReceipt receipt = itemOf(c, 'loc_place_1').receipt!;
      expect(receipt.state, LocalImportItemState.verified);
      expect(receipt.failureCode, 'cleanup_reserved');
      expect(server.drafts.values.single.status, 'editing');
      expect(source.drafts, hasLength(1));
    },
  );

  test(
    'D4.1: a local change after the reservation releases it with the same token',
    () async {
      final LocalImportController c = await eligible(place());
      originals.refuseNext = true;
      await c.deleteLocal('loc_place_1');
      expect(c.state.message, 'local_changed_since_import');
      expect(server.bindings['loc_place_1']!.cleanupState, isNull);
      final LocalImportReceipt receipt = itemOf(c, 'loc_place_1').receipt!;
      expect(receipt.state, LocalImportItemState.verified);
      expect(receipt.cleanupToken, isNull);
      expect(originals.deleted, isEmpty);
      // Rollback is open again once nothing is reserved.
      expect(itemOf(c, 'loc_place_1').canRollBack, isTrue);
    },
  );

  test(
    'D4.1: importing again after a rollback is an explicit choice and opens generation 2',
    () async {
      final LocalImportController c = await imported(place());
      final String firstDraft = server.drafts.keys.single;
      await c.rollback('loc_place_1');
      expect(c.state.canApprove, isFalse, reason: 'not without a new choice');
      c.chooseUpdate('loc_place_1');
      await c.approve();
      await c.run();
      expect(c.state.message, isNull);
      expect(server.drafts, hasLength(2));
      final String secondDraft = server.drafts.keys.last;
      expect(secondDraft, isNot(firstDraft));
      expect(server.drafts[secondDraft]!.generation, 2);
      expect(server.drafts[firstDraft]!.status, 'rolledBack');
      final LocalImportReceipt receipt = itemOf(c, 'loc_place_1').receipt!;
      expect(receipt.generation, 2);
      expect(receipt.draftId, secondDraft);
      expect(receipt.state, LocalImportItemState.verified);
      // Generation 2 keys and media intents differ from generation 1.
      expect(server.creates.last.key, contains(':g2:create'));
      expect(uploader.intents, hasLength(4));
      // A restart reads the generation back from the journal.
      final LocalImportController restarted = controller();
      await restarted.load();
      expect(itemOf(restarted, 'loc_place_1').receipt?.generation, 2);
    },
  );

  test(
    'D4.1 §3.3: a server edit after the create is kept; the import fails with revision_conflict',
    () async {
      source.set(<CreateDraftEntity>[place()]);
      final LocalImportController c = controller();
      await c.load();
      await c.approve();
      server.loseAnswerOf.add('createDraft');
      await c.run();
      // The draft exists on the server; another installation edits it.
      server.editElsewhere(server.drafts.keys.single);
      await c.run();
      final LocalImportReceipt receipt = itemOf(c, 'loc_place_1').receipt!;
      expect(receipt.state, LocalImportItemState.failed);
      expect(receipt.failureCode, 'revision_conflict');
      expect(server.drafts.values.single.body['title'], 'Edited elsewhere');
      expect(
        server.calls.where((String call) => call == 'updateDraft'),
        hasLength(1),
        reason: 'no second write over the edit',
      );
    },
  );
}

final class _Source implements LocalImportSource {
  final List<CreateDraftEntity> drafts = <CreateDraftEntity>[];
  final List<LocalImportSourceItem> listed = <LocalImportSourceItem>[];

  void set(List<CreateDraftEntity> value) => drafts
    ..clear()
    ..addAll(value);

  void add(CreateDraftEntity value) => drafts.add(value);

  @override
  Future<List<LocalImportSourceItem>> inventory(String accountId) async =>
      <LocalImportSourceItem>[
        for (final CreateDraftEntity draft in drafts)
          LocalImportSourceItem(
            localDraftId: draft.id,
            localType: draft.objectType.name,
            title: draft.title,
            draft: draft,
          ),
        ...listed,
      ];
}

final class _Originals implements LocalImportOriginalStore {
  _Originals(this.source);

  final _Source source;
  final List<String> deleted = <String>[];

  /// The next deletion finds the stored draft changed.
  bool refuseNext = false;

  @override
  Future<bool> deleteIfUnchanged({
    required String accountId,
    required String localDraftId,
    required bool Function(CreateDraftEntity draft) unchanged,
  }) async {
    final int index = source.drafts.indexWhere(
      (CreateDraftEntity draft) => draft.id == localDraftId,
    );
    if (refuseNext) {
      refuseNext = false;
      return false;
    }
    if (index < 0 || !unchanged(source.drafts[index])) return false;
    source.drafts.removeAt(index);
    deleted.add(localDraftId);
    return true;
  }
}

final class _Access implements PublisherAccessCheck {
  _Access(this.allowed);

  final Set<String> allowed;

  @override
  Future<bool> canPublishAs({
    required String actorUserId,
    required PublisherRef publisher,
  }) async => allowed.contains('${publisher.type.wireName}:${publisher.id}');
}

final class _Existing implements LocalImportExistingPublications {
  final Map<String, String> ids = <String, String>{};

  @override
  Future<String?> contentIdFor({
    required String typeId,
    required String accountId,
    required PublisherRef publisherRef,
    required String localDraftId,
  }) async => ids[localDraftId];
}

final class _Gate implements LocalImportCommandGate {
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

  /// Every intent the controller tried, in order.
  final List<String> tried = <String>[];

  /// The next this many new intents get an upload session that expires before
  /// the bytes are accepted; such an intent stays dead for good.
  int expireNext = 0;
  final Set<String> dead = <String>{};

  @override
  Future<String> upload({
    required String intentId,
    required Uint8List bytes,
    required String declaredMediaType,
    required PublisherRef publisherRef,
    required String contentId,
  }) async {
    tried.add(intentId);
    if (dead.contains(intentId)) {
      throw const EventPublicationRejected('session_expired');
    }
    if (_assets.containsKey(intentId)) return _assets[intentId]!;
    if (expireNext > 0) {
      expireNext -= 1;
      dead.add(intentId);
      throw const EventPublicationRejected('session_expired');
    }
    intents.add(intentId);
    return _assets[intentId] = 'asset-${_assets.length + 1}';
  }
}

final class _Draft {
  _Draft({
    required this.contentId,
    required this.typeId,
    required this.revision,
    required this.owner,
    required this.importSourceKey,
    required this.body,
    this.generation = 1,
  });

  final String contentId;
  final String typeId;
  int revision;
  String owner;
  final String importSourceKey;
  Map<String, Object?> body;
  final int generation;
  String status = 'editing';
}

/// D4.1: the server's binding of one local source to its current generation.
final class _Binding {
  _Binding(this.draftId);

  int generation = 1;
  String state = 'active';
  String draftId;
  String? cleanupState;
  String? cleanupToken;
  String? cleanupInstallationId;
}

/// In-memory Content: drafts with revisions and authors, idempotent keys,
/// one draft per author and import source and generation (D4.1), the cleanup
/// reservation with its fencing token, and injected failures.
final class _Server implements LocalImportContentGateway {
  final Map<String, _Draft> drafts = <String, _Draft>{};
  final Map<String, _Binding> bindings = <String, _Binding>{};
  final List<String> calls = <String>[];

  /// Every keyed command as (command, idempotency key), in order.
  final List<(String, String)> keyed = <(String, String)>[];
  final List<({String key, Map<String, Object?> body, String importSourceKey})>
  creates =
      <({String key, Map<String, Object?> body, String importSourceKey})>[];
  final Set<String> loseAnswerOf = <String>{};
  final Map<String, (String, Object)> _replies = <String, (String, Object)>{};
  String? refuseCreate;
  int _counter = 0;

  /// Runs once inside the next reservation, before its checks (a race).
  void Function()? beforeReserve;

  LocalImportServerDraft _of(String draftId) {
    final _Draft draft = drafts[draftId]!;
    return LocalImportServerDraft(
      contentId: draft.contentId,
      draftId: draftId,
      revision: draft.revision,
      typeId: draft.typeId,
      createdByUserId: draft.owner,
      importSourceKey: draft.importSourceKey,
      body: jsonDecode(jsonEncode(draft.body)) as Map<String, Object?>,
      status: draft.status,
      importGeneration: draft.generation,
    );
  }

  LocalImportBindingView _view(String importSourceKey) {
    final _Binding binding = bindings[importSourceKey]!;
    return LocalImportBindingView(
      generation: binding.generation,
      rolledBack: binding.state == 'rolledBack',
      draftId: binding.draftId,
      cleanupState: binding.cleanupState,
      cleanupInstallationId: binding.cleanupInstallationId,
    );
  }

  Future<T> _idempotent<T extends Object>(
    String command,
    String key,
    Map<String, Object?> payload,
    T Function() apply,
  ) async {
    calls.add(command);
    keyed.add((command, key));
    final String fingerprint = jsonEncode(payload);
    final (String, Object)? stored = _replies[key];
    final T reply;
    if (stored != null) {
      if (stored.$1 != fingerprint) {
        throw const EventPublicationRejected('idempotency_conflict');
      }
      reply = stored.$2 as T;
    } else {
      reply = apply();
      _replies[key] = (fingerprint, reply);
    }
    if (loseAnswerOf.remove(command)) {
      throw const EventPublicationUnavailable('transport');
    }
    return reply;
  }

  /// Another installation of the same author edits the server draft.
  void editElsewhere(String draftId) {
    final _Draft draft = drafts[draftId]!;
    draft
      ..revision = draft.revision + 1
      ..body = <String, Object?>{...draft.body, 'title': 'Edited elsewhere'};
  }

  /// Another installation reserves the cleanup of this source.
  void reserveElsewhere(String importSourceKey) {
    bindings[importSourceKey]!
      ..cleanupState = 'reserved'
      ..cleanupToken = 'ct-other-installation-token'
      ..cleanupInstallationId = 'install-other';
  }

  /// Another installation rolls this source's generation back.
  void rollBackElsewhere(String importSourceKey) {
    final _Binding binding = bindings[importSourceKey]!;
    final _Draft draft = drafts[binding.draftId]!;
    draft
      ..status = 'rolledBack'
      ..revision = draft.revision + 1;
    binding.state = 'rolledBack';
  }

  @override
  Future<LocalImportServerDraft> createImportDraft({
    required String typeId,
    required PublisherRef publisherRef,
    required String marketId,
    required String importSourceKey,
    required String idempotencyKey,
  }) {
    creates.add((
      key: idempotencyKey,
      body: const <String, Object?>{},
      importSourceKey: importSourceKey,
    ));
    if (refuseCreate != null) {
      calls.add('createDraft');
      throw EventPublicationRejected(refuseCreate!);
    }
    return _idempotent(
      'createDraft',
      idempotencyKey,
      <String, Object?>{
        'typeId': typeId,
        'publisher': publisherRef.id,
        'importSourceKey': importSourceKey,
      },
      () {
        final _Binding? binding = bindings[importSourceKey];
        if (binding != null && binding.state == 'active') {
          return _of(binding.draftId);
        }
        final int generation = (binding?.generation ?? 0) + 1;
        _counter += 1;
        final String draftId = 'draft-$_counter';
        drafts[draftId] = _Draft(
          contentId: 'content-$_counter',
          typeId: typeId,
          revision: 1,
          owner: 'server-user-a',
          importSourceKey: importSourceKey,
          body: <String, Object?>{},
          generation: generation,
        );
        bindings[importSourceKey] = _Binding(draftId)..generation = generation;
        return _of(draftId);
      },
    );
  }

  @override
  Future<LocalImportServerDraft> updateDraft({
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
      if (current.status == 'rolledBack') {
        throw const EventPublicationRejected('import_rolled_back');
      }
      if (current.revision != expectedRevision) {
        throw const EventPublicationRejected('revision_conflict');
      }
      current
        ..revision = current.revision + 1
        ..body = jsonDecode(jsonEncode(body)) as Map<String, Object?>;
      return _of(draftId);
    },
  );

  @override
  Future<LocalImportServerDraft> draft(String draftId) async {
    calls.add('getDraft');
    if (!drafts.containsKey(draftId)) {
      throw const EventPublicationRejected('not_found');
    }
    return _of(draftId);
  }

  @override
  Future<LocalImportServerDraft> rollbackImportedDraft({
    required String draftId,
    required String importSourceKey,
    required int generation,
    required int expectedRevision,
    required String idempotencyKey,
  }) => _idempotent(
    'rollbackImportedDraft',
    idempotencyKey,
    <String, Object?>{
      'draftId': draftId,
      'importSourceKey': importSourceKey,
      'generation': generation,
      'expectedRevision': expectedRevision,
    },
    () {
      final _Binding? binding = bindings[importSourceKey];
      final _Draft? draft = drafts[draftId];
      if (binding == null || draft == null) {
        throw const EventPublicationRejected('not_found');
      }
      if (binding.generation != generation) {
        throw const EventPublicationRejected('import_generation_mismatch');
      }
      if (binding.state == 'rolledBack') {
        throw const EventPublicationRejected('import_rolled_back');
      }
      if (binding.cleanupState == 'done') {
        throw const EventPublicationRejected('original_removed');
      }
      if (binding.cleanupState == 'reserved') {
        throw const EventPublicationRejected('cleanup_reserved');
      }
      if (draft.revision != expectedRevision) {
        throw const EventPublicationRejected('revision_conflict');
      }
      draft
        ..status = 'rolledBack'
        ..revision = draft.revision + 1;
      binding.state = 'rolledBack';
      return _of(draftId);
    },
  );

  @override
  Future<LocalImportBindingView> reserveImportCleanup({
    required String importSourceKey,
    required int generation,
    required String draftId,
    required String installationId,
    required String fencingToken,
    required String idempotencyKey,
  }) => _idempotent(
    'reserveImportCleanup',
    idempotencyKey,
    <String, Object?>{
      'importSourceKey': importSourceKey,
      'generation': generation,
      'draftId': draftId,
      'installationId': installationId,
      'fencingToken': fencingToken,
    },
    () {
      final void Function()? race = beforeReserve;
      beforeReserve = null;
      race?.call();
      final _Binding? binding = bindings[importSourceKey];
      if (binding == null || binding.draftId != draftId) {
        throw const EventPublicationRejected('not_found');
      }
      if (binding.generation != generation) {
        throw const EventPublicationRejected('import_generation_mismatch');
      }
      if (binding.state == 'rolledBack') {
        throw const EventPublicationRejected('import_rolled_back');
      }
      if (binding.cleanupState == 'done') {
        throw const EventPublicationRejected('original_removed');
      }
      if (binding.cleanupState == 'reserved' &&
          binding.cleanupToken != fencingToken) {
        throw const EventPublicationRejected('cleanup_reserved');
      }
      binding
        ..cleanupState = 'reserved'
        ..cleanupToken = fencingToken
        ..cleanupInstallationId = installationId;
      return _view(importSourceKey);
    },
  );

  @override
  Future<LocalImportBindingView> completeImportCleanup({
    required String importSourceKey,
    required int generation,
    required String fencingToken,
    required String idempotencyKey,
  }) => _idempotent(
    'completeImportCleanup',
    idempotencyKey,
    <String, Object?>{
      'importSourceKey': importSourceKey,
      'generation': generation,
      'fencingToken': fencingToken,
    },
    () {
      final _Binding binding = bindings[importSourceKey]!;
      if (binding.cleanupState == null) {
        throw const EventPublicationRejected('cleanup_not_reserved');
      }
      if (binding.cleanupToken != fencingToken) {
        throw const EventPublicationRejected('cleanup_token_mismatch');
      }
      binding.cleanupState = 'done';
      return _view(importSourceKey);
    },
  );

  @override
  Future<LocalImportBindingView> releaseImportCleanup({
    required String importSourceKey,
    required int generation,
    required String fencingToken,
    required String idempotencyKey,
  }) => _idempotent(
    'releaseImportCleanup',
    idempotencyKey,
    <String, Object?>{
      'importSourceKey': importSourceKey,
      'generation': generation,
      'fencingToken': fencingToken,
    },
    () {
      final _Binding binding = bindings[importSourceKey]!;
      if (binding.cleanupState == null) {
        throw const EventPublicationRejected('cleanup_not_reserved');
      }
      if (binding.cleanupState == 'done') {
        throw const EventPublicationRejected('original_removed');
      }
      if (binding.cleanupToken != fencingToken) {
        throw const EventPublicationRejected('cleanup_token_mismatch');
      }
      binding
        ..cleanupState = null
        ..cleanupToken = null
        ..cleanupInstallationId = null;
      return _view(importSourceKey);
    },
  );

  @override
  Future<LocalImportBindingView> importBinding(String importSourceKey) async {
    calls.add('getImportBinding');
    if (!bindings.containsKey(importSourceKey)) {
      throw const EventPublicationRejected('not_found');
    }
    return _view(importSourceKey);
  }
}
