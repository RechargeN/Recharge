import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/local_import_controller.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_publication.dart';
import 'package:recharge/features/create/domain/entities/local_import.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/repositories/event_publication_gateway.dart';
import 'package:recharge/features/create/domain/repositories/local_import_gateway.dart';
import 'package:recharge/features/create/domain/repositories/publisher_access_check.dart';
import 'package:recharge/features/create/presentation/widgets/local_import_section.dart';

import '../fixtures/create/user_place_draft.dart';

/// D4.1 §3.4: the import section offers "Roll back import" only for a
/// verified import, asks for confirmation, and shows the pending state, the
/// success and typed refusals; a cleanup under way can be kept back.
void main() {
  const String id = 'loc_place_1';
  const String cover = 'C:/photos/cover.png';

  late _Gateway gateway;
  late _Journal journal;
  late _Source source;
  late LocalImportController controller;

  setUp(() async {
    gateway = _Gateway();
    journal = _Journal();
    source = _Source(<CreateDraftEntity>[
      userPlaceDraft(pageId: 'page-1', coverPath: cover, localId: id),
    ]);
    controller = LocalImportController(
      accountId: 'user-1',
      source: source,
      journal: journal,
      existing: _Existing(),
      gateway: gateway,
      uploader: _Uploader(),
      mediaSource: _Media(<String, Uint8List>{
        cover: Uint8List.fromList(<int>[1, 2, 3]),
      }),
      publisherAccess: _Access(),
      originals: _Originals(source),
      gate: _Gate(),
      clock: () => DateTime.utc(2026, 10, 13, 10),
    );
    await controller.load();
    await controller.approve();
    await controller.run();
  });

  tearDown(() => controller.dispose());

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LocalImportSection(controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder rollbackButton() => find.byKey(const Key('local-import-rollback-$id'));

  Future<void> tapRollback(WidgetTester tester, {required bool confirm}) async {
    await tester.ensureVisible(rollbackButton());
    await tester.tap(rollbackButton());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('local-import-rollback-dialog')), findsOne);
    await tester.tap(
      find.byKey(
        Key(
          confirm
              ? 'local-import-rollback-confirm'
              : 'local-import-rollback-cancel',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('rollback asks first; a cancel sends nothing', (
    WidgetTester tester,
  ) async {
    await show(tester);
    expect(find.text('Roll back import'), findsOne);
    await tapRollback(tester, confirm: false);
    expect(gateway.calls, isNot(contains('rollbackImportedDraft')));
    expect(find.textContaining('verified'), findsOne);
  });

  testWidgets(
    'a confirmed rollback shows the rolled-back import and offers it again',
    (WidgetTester tester) async {
      await show(tester);
      await tapRollback(tester, confirm: true);
      expect(gateway.calls, contains('rollbackImportedDraft'));
      expect(find.textContaining(': rolledBack'), findsOne);
      expect(find.text('local copy: kept (import rolled back)'), findsOne);
      expect(rollbackButton(), findsNothing);
      expect(find.byKey(const Key('local-import-delete-$id')), findsNothing);
      expect(find.byKey(const Key('local-import-choose-$id')), findsOne);
    },
  );

  testWidgets('an unknown outcome shows the pending rollback and a retry', (
    WidgetTester tester,
  ) async {
    gateway.loseNext = true;
    await show(tester);
    await tapRollback(tester, confirm: true);
    expect(find.byKey(const Key('local-import-message')), findsOne);
    expect(find.textContaining(': rollbackPending'), findsOne);
    expect(
      find.text('local copy: kept (rollback waiting for the server)'),
      findsOne,
    );
    expect(find.text('Retry rollback'), findsOne);
    await tapRollback(tester, confirm: true);
    expect(find.textContaining(': rolledBack'), findsOne);
  });

  testWidgets('a typed refusal is shown and the import stays as it was', (
    WidgetTester tester,
  ) async {
    gateway.refuseNext = 'cleanup_reserved';
    await show(tester);
    await tapRollback(tester, confirm: true);
    expect(
      tester.widget<Text>(find.byKey(const Key('local-import-message'))).data,
      'cleanup_reserved',
    );
    expect(find.textContaining(': verified (cleanup_reserved)'), findsOne);
    expect(find.text('Roll back import'), findsOne);
  });

  testWidgets(
    'a reserved cleanup can be finished or kept back; no rollback meanwhile',
    (WidgetTester tester) async {
      final LocalImportReceipt receipt = (await journal.receipts(
        'user-1',
      )).single;
      await journal.saveReceipt(
        receipt.copyWith(
          state: LocalImportItemState.cleanupReserved,
          cleanupToken: 'ct-0123456789abcdefghijkl',
          cleanupInstallationId: 'install-a',
        ),
      );
      gateway.cleanupState = 'reserved';
      await controller.load();
      await show(tester);
      expect(find.text('Finish deleting local copy'), findsOne);
      expect(rollbackButton(), findsNothing);
      final Finder keep = find.byKey(
        const Key('local-import-cancel-cleanup-$id'),
      );
      await tester.ensureVisible(keep);
      await tester.tap(keep);
      await tester.pumpAndSettle();
      expect(gateway.calls.last, 'releaseImportCleanup');
      expect(find.text('Roll back import'), findsOne);
      expect(
        find.byKey(const Key('local-import-cancel-cleanup-$id')),
        findsNothing,
      );
    },
  );
}

/// One imported draft on a minimal server, with programmable outcomes.
final class _Gateway implements LocalImportContentGateway {
  final List<String> calls = <String>[];
  int revision = 1;
  String status = 'editing';
  bool rolledBack = false;
  String? cleanupState;
  Map<String, Object?> body = <String, Object?>{};

  /// The next lifecycle command is applied but its answer is lost.
  bool loseNext = false;

  /// The next lifecycle command is refused with this code.
  String? refuseNext;

  LocalImportServerDraft get _draft => LocalImportServerDraft(
    contentId: 'content-1',
    draftId: 'draft-1',
    revision: revision,
    typeId: 'place',
    createdByUserId: 'server-user',
    importSourceKey: 'loc_place_1',
    body: jsonDecode(jsonEncode(body)) as Map<String, Object?>,
    status: status,
    importGeneration: 1,
  );

  LocalImportBindingView get _binding => LocalImportBindingView(
    generation: 1,
    rolledBack: rolledBack,
    draftId: 'draft-1',
    cleanupState: cleanupState,
  );

  T _lifecycle<T>(String command, T Function() apply) {
    calls.add(command);
    final String? refusal = refuseNext;
    refuseNext = null;
    if (refusal != null) throw EventPublicationRejected(refusal);
    final T result = apply();
    if (loseNext) {
      loseNext = false;
      throw const EventPublicationUnavailable('transport');
    }
    return result;
  }

  @override
  Future<LocalImportServerDraft> createImportDraft({
    required String typeId,
    required PublisherRef publisherRef,
    required String marketId,
    required String importSourceKey,
    required String idempotencyKey,
  }) async {
    calls.add('createDraft');
    return _draft;
  }

  @override
  Future<LocalImportServerDraft> updateDraft({
    required String draftId,
    required int expectedRevision,
    required Map<String, Object?> body,
    required String idempotencyKey,
  }) async {
    calls.add('updateDraft');
    if (expectedRevision != revision) {
      throw const EventPublicationRejected('revision_conflict');
    }
    revision += 1;
    this.body = jsonDecode(jsonEncode(body)) as Map<String, Object?>;
    return _draft;
  }

  @override
  Future<LocalImportServerDraft> draft(String draftId) async {
    calls.add('getDraft');
    return _draft;
  }

  @override
  Future<LocalImportServerDraft> rollbackImportedDraft({
    required String draftId,
    required String importSourceKey,
    required int generation,
    required int expectedRevision,
    required String idempotencyKey,
  }) async => _lifecycle('rollbackImportedDraft', () {
    if (!rolledBack) {
      rolledBack = true;
      status = 'rolledBack';
      revision += 1;
    }
    return _draft;
  });

  @override
  Future<LocalImportBindingView> reserveImportCleanup({
    required String importSourceKey,
    required int generation,
    required String draftId,
    required String installationId,
    required String fencingToken,
    required String idempotencyKey,
  }) async => _lifecycle('reserveImportCleanup', () {
    cleanupState = 'reserved';
    return _binding;
  });

  @override
  Future<LocalImportBindingView> completeImportCleanup({
    required String importSourceKey,
    required int generation,
    required String fencingToken,
    required String idempotencyKey,
  }) async => _lifecycle('completeImportCleanup', () {
    cleanupState = 'done';
    return _binding;
  });

  @override
  Future<LocalImportBindingView> releaseImportCleanup({
    required String importSourceKey,
    required int generation,
    required String fencingToken,
    required String idempotencyKey,
  }) async => _lifecycle('releaseImportCleanup', () {
    cleanupState = null;
    return _binding;
  });

  @override
  Future<LocalImportBindingView> importBinding(String importSourceKey) async {
    calls.add('getImportBinding');
    return _binding;
  }
}

/// Durable in the sense the controller needs: every receipt goes through its
/// JSON form, as the file journal does.
final class _Journal implements LocalImportJournal {
  final Map<String, Map<String, Object?>> _receipts =
      <String, Map<String, Object?>>{};
  Map<String, Object?>? _session;

  static String _key(String account, PublisherRef publisher, String local) =>
      '$account|${publisher.type.wireName}:${publisher.id}|$local';

  @override
  Future<List<LocalImportReceipt>> receipts(
    String accountId,
  ) async => <LocalImportReceipt>[
    for (final Map<String, Object?> json in _receipts.values)
      if (json['accountId'] == accountId) LocalImportReceipt.fromJson(json)!,
  ];

  @override
  Future<LocalImportReceipt?> receiptFor({
    required String accountId,
    required PublisherRef publisherRef,
    required String localDraftId,
  }) async {
    final Map<String, Object?>? json =
        _receipts[_key(accountId, publisherRef, localDraftId)];
    return json == null ? null : LocalImportReceipt.fromJson(json);
  }

  @override
  Future<void> saveReceipt(LocalImportReceipt receipt) async {
    _receipts[_key(
          receipt.accountId,
          receipt.publisherRef,
          receipt.localDraftId,
        )] =
        jsonDecode(jsonEncode(receipt.toJson())) as Map<String, Object?>;
  }

  @override
  Future<LocalImportSession?> currentSession(String accountId) async {
    final Map<String, Object?>? json = _session;
    final LocalImportSession? session = json == null
        ? null
        : LocalImportSession.fromJson(json);
    return session?.accountId == accountId ? session : null;
  }

  @override
  Future<void> saveSession(LocalImportSession session) async {
    _session = jsonDecode(jsonEncode(session.toJson())) as Map<String, Object?>;
  }
}

final class _Source implements LocalImportSource {
  _Source(this.drafts);

  final List<CreateDraftEntity> drafts;

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
      ];
}

final class _Originals implements LocalImportOriginalStore {
  _Originals(this.source);

  final _Source source;

  @override
  Future<bool> deleteIfUnchanged({
    required String accountId,
    required String localDraftId,
    required bool Function(CreateDraftEntity draft) unchanged,
  }) async {
    final int index = source.drafts.indexWhere(
      (CreateDraftEntity draft) => draft.id == localDraftId,
    );
    if (index < 0 || !unchanged(source.drafts[index])) return false;
    source.drafts.removeAt(index);
    return true;
  }
}

final class _Existing implements LocalImportExistingPublications {
  @override
  Future<String?> contentIdFor({
    required String typeId,
    required String accountId,
    required PublisherRef publisherRef,
    required String localDraftId,
  }) async => null;
}

final class _Access implements PublisherAccessCheck {
  @override
  Future<bool> canPublishAs({
    required String actorUserId,
    required PublisherRef publisher,
  }) async => true;
}

final class _Gate implements LocalImportCommandGate {
  @override
  bool get allowed => true;

  @override
  void assertAllowed() {}
}

final class _Media implements EventCoverSource {
  _Media(this.files);

  final Map<String, Uint8List> files;

  @override
  Future<Uint8List?> read(String reference) async => files[reference];
}

final class _Uploader implements EventCoverUploader {
  int _next = 0;

  @override
  Future<String> upload({
    required String intentId,
    required Uint8List bytes,
    required String declaredMediaType,
    required PublisherRef publisherRef,
    required String contentId,
  }) async => 'asset-${_next += 1}';
}
