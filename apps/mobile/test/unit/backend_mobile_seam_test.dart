import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/adapters/reversible_backend_repository_adapter.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/core/network/backend_clients.dart';
import 'package:recharge/core/network/backend_contract.dart';
import 'package:recharge/core/network/backend_payload.dart';
import 'package:recharge/core/network/backend_request_context.dart';
import 'package:recharge/core/network/backend_transport.dart';
import 'package:recharge/core/sync/backend_import.dart';
import 'package:recharge/core/sync/backend_sync_state.dart';

void main() {
  BackendRequestContext context({
    String key = 'idem-1',
    Map<String, Object?> payload = const <String, Object?>{},
    String? hash,
  }) => BackendRequestContext(
    attemptRequestId: 'attempt-1',
    idempotencyKey: key,
    semanticPayloadHash: hash ?? semanticPayloadHash(payload),
    clientBuild: 'test',
    contractVersion: 'v1',
    createdAtUtc: DateTime.utc(2026, 9, 22),
  );

  BackendResponse success(String id, {int revision = 1}) => BackendResponse(
    statusCode: 200,
    body: <String, Object?>{
      'status': 'success',
      'value': <String, Object?>{
        'id': id,
        'serverId': id,
        'serverRevision': revision,
      },
      'serverRevision': revision,
      'committedAtUtc': '2026-09-22T00:00:00.000Z',
    },
  );

  test(
    'double submit replays receipt and conflicting payload is rejected',
    () async {
      final _QueueTransport transport = _QueueTransport(<Object>[
        success('srv-1'),
      ]);
      final BackendCommandClient client = _client(transport);
      final BackendCancellationToken token = BackendCancellationToken();

      final BackendResult<String> first = await client.execute<String>(
        operation: 'createV1',
        payload: const <String, Object?>{'name': 'A'},
        context: context(payload: const <String, Object?>{'name': 'A'}),
        decode: (Map<String, Object?> value) => value['id']! as String,
        cancellationToken: token,
      );
      final BackendResult<String> replay = await client.execute<String>(
        operation: 'createV1',
        payload: const <String, Object?>{'name': 'A'},
        context: context(payload: const <String, Object?>{'name': 'A'}),
        decode: (Map<String, Object?> value) => value['id']! as String,
        cancellationToken: token,
      );
      final BackendResult<String> conflict = await client.execute<String>(
        operation: 'createV1',
        payload: const <String, Object?>{'name': 'B'},
        context: context(payload: const <String, Object?>{'name': 'B'}),
        decode: (Map<String, Object?> value) => value['id']! as String,
        cancellationToken: token,
      );

      expect((first as BackendSuccess<String>).value, 'srv-1');
      expect((replay as BackendSuccess<String>).value, 'srv-1');
      expect(transport.requests, hasLength(1));
      expect(
        (conflict as BackendRejected<String>).failure.code,
        BackendFailureCode.idempotencyConflict,
      );
    },
  );

  test(
    'definitely-unsent timeout retries with a fresh attempt request ID',
    () async {
      final _QueueTransport transport = _QueueTransport(<Object>[
        const BackendTransportException(possiblySent: false, retryable: true),
        success('srv-2'),
      ]);
      int attempt = 1;
      final BackendCommandClient client = BackendCommandClient(
        transport: transport,
        receiptStore: InMemoryBackendReceiptStore(),
        attemptIdFactory: () => 'attempt-${++attempt}',
        delay: (_) async {},
      );
      final BackendResult<String> result = await client.execute<String>(
        operation: 'createV1',
        payload: const <String, Object?>{},
        context: context(),
        decode: (Map<String, Object?> value) => value['id']! as String,
        cancellationToken: BackendCancellationToken(),
      );

      expect(result, isA<BackendSuccess<String>>());
      expect(
        transport.requests.map(
          (BackendRequest value) => value.context.attemptRequestId,
        ),
        <String>['attempt-1', 'attempt-2'],
      );
      expect(
        transport.requests
            .map((BackendRequest value) => value.context.idempotencyKey)
            .toSet(),
        <String>{'idem-1'},
      );
    },
  );

  test('semantic hash must match the exact frozen command payload', () async {
    final _QueueTransport transport = _QueueTransport(<Object>[
      success('must-not-send'),
    ]);
    final BackendResult<String> result = await _client(transport)
        .execute<String>(
          operation: 'createV1',
          payload: const <String, Object?>{'name': 'actual'},
          context: context(
            hash: semanticPayloadHash(const <String, Object?>{
              'name': 'different',
            }),
          ),
          decode: (Map<String, Object?> value) => value['id']! as String,
          cancellationToken: BackendCancellationToken(),
        );

    expect(
      (result as BackendRejected<String>).failure.code,
      BackendFailureCode.idempotencyConflict,
    );
    expect(transport.requests, isEmpty);
  });

  test(
    'retryable rejection also receives a fresh attempt request ID',
    () async {
      final _QueueTransport transport = _QueueTransport(<Object>[
        BackendResponse(
          statusCode: 503,
          body: <String, Object?>{
            'status': 'failure',
            'errorCode': 'unavailable',
          },
        ),
        success('srv-retry'),
      ]);
      int attempt = 1;
      final BackendCommandClient client = BackendCommandClient(
        transport: transport,
        receiptStore: InMemoryBackendReceiptStore(),
        attemptIdFactory: () => 'attempt-${++attempt}',
        delay: (_) async {},
      );

      final BackendResult<String> result = await client.execute<String>(
        operation: 'createV1',
        payload: const <String, Object?>{},
        context: context(),
        decode: (Map<String, Object?> value) => value['id']! as String,
        cancellationToken: BackendCancellationToken(),
      );

      expect(result, isA<BackendSuccess<String>>());
      expect(
        transport.requests.map(
          (BackendRequest value) => value.context.attemptRequestId,
        ),
        <String>['attempt-1', 'attempt-2'],
      );
    },
  );

  test(
    'idempotency receipt is operation-scoped and replay is decoded again',
    () async {
      final _QueueTransport transport = _QueueTransport(<Object>[
        success('srv-replay'),
      ]);
      final BackendCommandClient client = _client(transport);
      final BackendCancellationToken token = BackendCancellationToken();

      await client.execute<String>(
        operation: 'createV1',
        payload: const <String, Object?>{},
        context: context(),
        decode: (Map<String, Object?> value) => value['id']! as String,
        cancellationToken: token,
      );
      final BackendResult<int> replay = await client.execute<int>(
        operation: 'createV1',
        payload: const <String, Object?>{},
        context: context(),
        decode: (Map<String, Object?> value) => (value['id']! as String).length,
        cancellationToken: token,
      );
      final BackendResult<String> wrongOperation = await client.execute<String>(
        operation: 'updateV1',
        payload: const <String, Object?>{},
        context: context(),
        decode: (Map<String, Object?> value) => value['id']! as String,
        cancellationToken: token,
      );

      expect((replay as BackendSuccess<int>).value, 'srv-replay'.length);
      expect(
        (wrongOperation as BackendRejected<String>).failure.code,
        BackendFailureCode.idempotencyConflict,
      );
      expect(transport.requests, hasLength(1));
    },
  );

  test('possibly-sent timeout becomes typed unknown outcome', () async {
    final BackendCommandClient client = _client(
      _QueueTransport(<Object>[
        const BackendTransportException(possiblySent: true, retryable: true),
      ]),
    );
    final BackendResult<String> result = await client.execute<String>(
      operation: 'createV1',
      payload: const <String, Object?>{},
      context: context(),
      decode: (Map<String, Object?> value) => value['id']! as String,
      cancellationToken: BackendCancellationToken(),
    );
    expect(result, isA<BackendUnknownOutcome<String>>());
  });

  test(
    'cancellation before send is neutral and performs no transport call',
    () async {
      final _QueueTransport transport = _QueueTransport(<Object>[
        success('unused'),
      ]);
      final BackendCancellationToken token = BackendCancellationToken()
        ..cancel();
      final BackendResult<String> result = await _client(transport)
          .execute<String>(
            operation: 'createV1',
            payload: const <String, Object?>{},
            context: context(),
            decode: (Map<String, Object?> value) => value['id']! as String,
            cancellationToken: token,
          );
      expect(result, isA<BackendCancelled<String>>());
      expect(transport.requests, isEmpty);
    },
  );

  test(
    'reversible adapter returns stale cache without claiming server truth',
    () async {
      final CacheProvenance provenance = CacheProvenance(
        source: BackendDataSourceKind.cache,
        schemaVersion: 1,
        serverRevision: 3,
        fetchedAtUtc: DateTime.utc(2026, 9, 21),
        expiresAtUtc: DateTime.utc(2026, 9, 21, 1),
      );
      final ReversibleBackendRepositoryAdapter<String> adapter =
          ReversibleBackendRepositoryAdapter<String>(
            capabilityId: 'identity.read',
            manifest: BackendBindingManifest(
              revision: 2,
              bindings: <String, BackendBindingMode>{
                'identity.read': BackendBindingMode.testBackend,
              },
            ),
            local: _LocalPort('local'),
            cache: _CachePort(
              BackendSyncState<String>(
                status: BackendSyncStatus.cached,
                value: 'cached',
                provenance: provenance,
              ),
            ),
            server: const _ServerPort(
              BackendRejected<String>(
                BackendFailure(
                  code: BackendFailureCode.unavailable,
                  retryable: true,
                ),
              ),
            ),
          );

      final BackendSyncState<String> result = await adapter.read();
      expect(result.status, BackendSyncStatus.stale);
      expect(result.value, 'cached');
      expect(result.isAuthoritative, isFalse);
    },
  );

  test('import dry-run preserves owner/publisher and rejects mock grants', () {
    final BackendImportCoordinator coordinator = BackendImportCoordinator(
      commandClient: _client(_QueueTransport(<Object>[])),
      checkpoints: InMemoryImportCheckpointStore(),
    );
    const ImportPublisherRef publisher = ImportPublisherRef(
      type: ImportPublisherType.page,
      id: 'page-1',
    );
    final LocalImportCandidate candidate = LocalImportCandidate(
      localId: 'loc-1',
      ownerId: 'user-1',
      publisherRef: publisher,
      payload: <String, Object?>{'title': 'Draft'},
      mockAuthorityClaims: <String>{'manage_page'},
    );
    final ImportDryRun result = coordinator.dryRun(
      candidate,
      expectedOwnerId: 'user-1',
      eligiblePublishers: <ImportPublisherRef>{publisher},
    );
    expect(result.eligible, isFalse);
    expect(result.rejectionCode, 'mock_authority_rejected');
  });

  test('request, binding and import candidate snapshots are immutable', () {
    final Map<String, Object?> nested = <String, Object?>{'value': 'A'};
    final List<Object?> list = <Object?>['A'];
    final Map<String, Object?> payload = <String, Object?>{
      'title': 'A',
      'nested': nested,
      'list': list,
    };
    final BackendRequest request = BackendRequest(
      operation: 'readV1',
      kind: BackendOperationKind.query,
      context: context(),
      payload: payload,
    );
    final Map<String, BackendBindingMode> bindings =
        <String, BackendBindingMode>{
          'identity.read': BackendBindingMode.testBackend,
        };
    final BackendBindingManifest manifest = BackendBindingManifest(
      revision: 1,
      bindings: bindings,
    );
    final LocalImportCandidate candidate = LocalImportCandidate(
      localId: 'loc-immutable',
      ownerId: 'user-1',
      publisherRef: const ImportPublisherRef(
        type: ImportPublisherType.user,
        id: 'user-1',
      ),
      payload: payload,
    );

    payload['title'] = 'B';
    nested['value'] = 'B';
    list.add('B');
    bindings['identity.read'] = BackendBindingMode.disabled;

    expect(request.payload['title'], 'A');
    expect(candidate.payload['title'], 'A');
    expect(request.payload['nested'], <String, Object?>{'value': 'A'});
    expect(request.payload['list'], <Object?>['A']);
    expect(candidate.payload['nested'], <String, Object?>{'value': 'A'});
    expect(manifest.modeFor('identity.read'), BackendBindingMode.testBackend);
    expect(() => request.payload['x'] = 1, throwsUnsupportedError);
  });

  test(
    'interrupted import resumes from checkpoint without duplication',
    () async {
      final _QueueTransport transport = _QueueTransport(<Object>[
        success('srv-import', revision: 4),
      ]);
      final BackendImportCoordinator coordinator = BackendImportCoordinator(
        commandClient: _client(transport),
        checkpoints: InMemoryImportCheckpointStore(),
      );
      const ImportPublisherRef publisher = ImportPublisherRef(
        type: ImportPublisherType.user,
        id: 'user-1',
      );
      final LocalImportCandidate candidate = LocalImportCandidate(
        localId: 'loc-1',
        ownerId: 'user-1',
        publisherRef: publisher,
        payload: <String, Object?>{'title': 'Draft'},
      );
      final ImportDryRun dryRun = coordinator.dryRun(
        candidate,
        expectedOwnerId: 'user-1',
        eligiblePublishers: <ImportPublisherRef>{publisher},
      );
      final BackendRequestContext importContext = context(
        hash: dryRun.semanticHash,
      );

      final BackendResult<ImportReceipt> first = await coordinator.import(
        candidate: candidate,
        dryRun: dryRun,
        context: importContext,
        cancellationToken: BackendCancellationToken(),
      );
      final BackendResult<ImportReceipt> resumed = await coordinator.import(
        candidate: candidate,
        dryRun: dryRun,
        context: importContext,
        cancellationToken: BackendCancellationToken(),
      );

      expect(
        (first as BackendSuccess<ImportReceipt>).value.serverId,
        'srv-import',
      );
      expect(
        (resumed as BackendSuccess<ImportReceipt>).value.serverId,
        'srv-import',
      );
      expect(transport.requests, hasLength(1));
    },
  );
}

BackendCommandClient _client(BackendTransport transport) =>
    BackendCommandClient(
      transport: transport,
      receiptStore: InMemoryBackendReceiptStore(),
      attemptIdFactory: () => 'retry-attempt',
      delay: (_) async {},
    );

final class _QueueTransport implements BackendTransport {
  _QueueTransport(this._queue);

  final List<Object> _queue;
  final List<BackendRequest> requests = <BackendRequest>[];

  @override
  Future<BackendResponse> send(
    BackendRequest request, {
    required BackendCancellationToken cancellationToken,
  }) async {
    requests.add(request);
    final Object next = _queue.removeAt(0);
    if (next is BackendTransportException) throw next;
    return next as BackendResponse;
  }
}

final class _LocalPort implements LocalReadPort<String> {
  const _LocalPort(this.value);
  final String value;
  @override
  Future<String?> read() async => value;
}

final class _CachePort implements CacheReadPort<String> {
  const _CachePort(this.value);
  final BackendSyncState<String>? value;
  @override
  Future<BackendSyncState<String>?> readCache() async => value;
}

final class _ServerPort implements ServerReadPort<String> {
  const _ServerPort(this.value);
  final BackendResult<String> value;
  @override
  Future<BackendResult<String>> readServer() async => value;
}
