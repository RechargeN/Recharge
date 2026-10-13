import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/local_import_cleanup_policy.dart';
import 'package:recharge/features/create/application/local_import_type_adapters.dart';
import 'package:recharge/features/create/data/file_local_import_journal.dart';
import 'package:recharge/features/create/domain/entities/local_import.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/usecases/local_import_hash.dart';

/// D4 §5.2, §5.5, §6: the canonical hash, the import scope and keys, the
/// durable journal and the cleanup policy for the local original.
void main() {
  const PublisherRef page = PublisherRef(
    type: PublisherType.page,
    id: 'page-1',
  );

  LocalImportReceipt receipt({
    String account = 'account-a',
    PublisherRef publisher = page,
    LocalImportItemState state = LocalImportItemState.verified,
    DateTime? verifiedAt,
    DateTime? confirmedAt,
    DateTime? deletedAt,
  }) => LocalImportReceipt(
    accountId: account,
    publisherRef: publisher,
    localDraftId: 'loc_1',
    typeId: 'place',
    importSourceKey: 'loc_1',
    sourceHash: 'source',
    contentId: 'content-1',
    draftId: 'draft-1',
    serverOwnerUserId: 'server-user',
    serverRevision: 3,
    state: state,
    updatedAtUtc: DateTime.utc(2026, 10, 13),
    title: 'Pond',
    attachments: const <LocalImportAttachmentRecord>[
      LocalImportAttachmentRecord(
        attachmentId: 'att-1',
        assetId: 'asset-1',
        sha256: 'abc',
      ),
    ],
    sentBodyHash: 'body',
    verifiedAtUtc: verifiedAt,
    confirmedAtUtc: confirmedAt,
    localDeletedAtUtc: deletedAt,
  );

  test('the hash is canonical: key order, integral doubles, nesting', () {
    expect(
      localImportHash(<String, Object?>{
        'b': 1,
        'a': <Object?>[
          <String, Object?>{'y': 2.0, 'x': 'v'},
        ],
      }),
      localImportHash(<String, Object?>{
        'a': <Object?>[
          <String, Object?>{'x': 'v', 'y': 2},
        ],
        'b': 1.0,
      }),
    );
    expect(
      localImportHash(<String, Object?>{'a': 1.5}),
      isNot(localImportHash(<String, Object?>{'a': 1})),
    );
    expect(
      localImportHash(<Object?>[1, 2]),
      isNot(localImportHash(<Object?>[2, 1])),
    );
    expect(() => localImportHash(double.nan), throwsArgumentError);
    expect(
      () => localImportHash(<Object?>[DateTime(2026)]),
      throwsArgumentError,
    );
  });

  test(
    'the import scope is account, publisher and draft bound; keys are stable',
    () {
      final LocalImportScope scope = LocalImportScope(
        accountId: 'account-a',
        publisherRef: page,
        localDraftId: 'loc_1',
      );
      expect(
        LocalImportScope.namespace,
        'f0d6a4c1-6b0e-4a3e-9a51-5d2c3e7b8d41',
      );
      expect(scope.keyBase, startsWith('li1-'));
      expect(scope.keyBase, hasLength(4 + 24));
      expect(scope.uploadIntentId('a', 'h'), scope.uploadIntentId('a', 'h'));
      expect(
        scope.uploadIntentId('a', 'h'),
        isNot(scope.uploadIntentId('a', 'g')),
      );
      // Attempt 0 is the first intent; every later attempt is a new one.
      expect(
        scope.uploadIntentId('a', 'h', attempt: 0),
        scope.uploadIntentId('a', 'h'),
      );
      expect(<String>{
        for (int attempt = 0; attempt < 4; attempt += 1)
          scope.uploadIntentId('a', 'h', attempt: attempt),
      }, hasLength(4));
      final LocalImportScope other = LocalImportScope(
        accountId: 'account-b',
        publisherRef: page,
        localDraftId: 'loc_1',
      );
      expect(other.keyBase, isNot(scope.keyBase));
      expect(importSourceKeyOf('loc_1760000000000'), 'loc_1760000000000');
      expect(
        importSourceKeyOf('01HZZZZZZZZZZZZZZZZZZZZZZZ'),
        'loc_01HZZZZZZZZZZZZZZZZZZZZZZZ',
      );
      expect(importSourceKeyOf('has space'), isNull);
      expect(importSourceKeyOf('x' * 121), isNull);
    },
  );

  test(
    'receipts and sessions round-trip; malformed entries are skipped; accounts are isolated',
    () async {
      final Directory temp = await Directory.systemTemp.createTemp(
        'd4-journal-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final FileLocalImportJournal journal = FileLocalImportJournal(
        receipts: File('${temp.path}/receipts.json'),
        sessions: File('${temp.path}/sessions.json'),
      );
      final LocalImportReceipt mine = receipt(
        verifiedAt: DateTime.utc(2026, 10, 13, 1),
        confirmedAt: DateTime.utc(2026, 10, 13, 2),
      ).copyWith(uploadAttempts: const <String, int>{'att-1': 2});
      await journal.saveReceipt(mine);
      await journal.saveReceipt(receipt(account: 'account-b'));
      final LocalImportReceipt? read = await journal.receiptFor(
        accountId: 'account-a',
        publisherRef: page,
        localDraftId: 'loc_1',
      );
      expect(read?.toJson(), mine.toJson());
      expect(await journal.receipts('account-a'), hasLength(1));
      expect(
        await journal.receiptFor(
          accountId: 'account-a',
          publisherRef: const PublisherRef(type: PublisherType.user, id: 'u'),
          localDraftId: 'loc_1',
        ),
        isNull,
      );
      final LocalImportSession session = LocalImportSession(
        sessionId: 's-1',
        accountId: 'account-a',
        inventoryHash: 'inv',
        plannedLocalDraftIds: const <String>['loc_1'],
        plannedSourceHashes: const <String>['source'],
        checkpoint: 0,
        status: LocalImportSessionStatus.approved,
        startedAtUtc: DateTime.utc(2026, 10, 13),
        updatedAtUtc: DateTime.utc(2026, 10, 13),
      );
      await journal.saveSession(session);
      expect(
        (await journal.currentSession('account-a'))?.toJson(),
        session.toJson(),
      );
      expect(await journal.currentSession('account-b'), isNull);
      // Malformed entries never parse.
      expect(
        LocalImportReceipt.fromJson(<String, Object?>{'accountId': 'a'}),
        isNull,
      );
      expect(read?.uploadAttempts, const <String, int>{'att-1': 2});
      expect(receipt().toJson().containsKey('uploadAttempts'), isFalse);
      for (final Object? attempts in <Object?>[
        <String, Object?>{'att-1': 0},
        <String, Object?>{'att-1': '1'},
        <Object?>['att-1'],
      ]) {
        expect(
          LocalImportReceipt.fromJson(<String, Object?>{
            ...mine.toJson(),
            'uploadAttempts': attempts,
          }),
          isNull,
          reason: '$attempts',
        );
      }
      expect(
        LocalImportSession.fromJson(<String, Object?>{
          ...session.toJson(),
          'checkpoint': 5,
        }),
        isNull,
      );
      expect(
        LocalImportSession.fromJson(<String, Object?>{
          ...session.toJson(),
          'plannedSourceHashes': <String>[],
        }),
        isNull,
      );
    },
  );

  test(
    'the local original may go only after verification, confirmation and 30 days',
    () {
      const LocalImportCleanupPolicy policy = LocalImportCleanupPolicy();
      expect(
        LocalImportCleanupPolicy.defaultRecoveryPeriod,
        const Duration(days: 30),
      );
      final DateTime confirmed = DateTime.utc(2026, 10, 13, 12);
      LocalImportCleanupStage stage(LocalImportReceipt? value, DateTime now) =>
          policy.statusOf(value, now).stage;
      expect(stage(null, confirmed), LocalImportCleanupStage.notImported);
      expect(
        stage(receipt(state: LocalImportItemState.bodySaved), confirmed),
        LocalImportCleanupStage.awaitingVerification,
      );
      expect(
        stage(receipt(verifiedAt: confirmed), confirmed),
        LocalImportCleanupStage.awaitingConfirmation,
      );
      final LocalImportReceipt waiting = receipt(
        verifiedAt: confirmed,
        confirmedAt: confirmed,
      );
      expect(
        stage(waiting, confirmed.add(const Duration(days: 29, hours: 23))),
        LocalImportCleanupStage.recoveryPeriod,
      );
      expect(
        policy.statusOf(waiting, confirmed).eligibleAtUtc,
        confirmed.add(const Duration(days: 30)),
      );
      expect(
        stage(waiting, confirmed.add(const Duration(days: 30))),
        LocalImportCleanupStage.eligible,
      );
      expect(
        stage(
          receipt(
            verifiedAt: confirmed,
            confirmedAt: confirmed,
            deletedAt: confirmed.add(const Duration(days: 31)),
          ),
          confirmed.add(const Duration(days: 40)),
        ),
        LocalImportCleanupStage.deleted,
      );
    },
  );
}
