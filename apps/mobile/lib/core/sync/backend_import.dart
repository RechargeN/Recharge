import '../network/backend_clients.dart';
import '../network/backend_contract.dart';
import '../network/backend_payload.dart';
import '../network/backend_request_context.dart';
import '../network/backend_transport.dart';

enum ImportPublisherType { user, page }

final class ImportPublisherRef {
  const ImportPublisherRef({required this.type, required this.id});

  final ImportPublisherType type;
  final String id;

  Map<String, Object> toJson() => <String, Object>{'type': type.name, 'id': id};

  @override
  bool operator ==(Object other) =>
      other is ImportPublisherRef && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);
}

final class LocalImportCandidate {
  LocalImportCandidate({
    required this.localId,
    required this.ownerId,
    required this.publisherRef,
    required Map<String, Object?> payload,
    Set<String> mockAuthorityClaims = const <String>{},
  }) : payload = freezeBackendPayload(payload),
       mockAuthorityClaims = Set<String>.unmodifiable(mockAuthorityClaims);

  final String localId;
  final String ownerId;
  final ImportPublisherRef publisherRef;
  final Map<String, Object?> payload;
  final Set<String> mockAuthorityClaims;
}

final class ImportDryRun {
  const ImportDryRun._({
    required this.localId,
    required this.semanticHash,
    required this.eligible,
    required this.rejectionCode,
    required Object proof,
  }) : _proof = proof;

  final String localId;
  final String semanticHash;
  final bool eligible;
  final String? rejectionCode;
  final Object _proof;
}

final Object _dryRunProof = Object();

final class ImportReceipt {
  const ImportReceipt({
    required this.localId,
    required this.serverId,
    required this.semanticHash,
    required this.serverRevision,
  });

  final String localId;
  final String serverId;
  final String semanticHash;
  final int serverRevision;
}

abstract interface class ImportCheckpointStore {
  ImportReceipt? read(String localId);
  void write(ImportReceipt receipt);
}

final class InMemoryImportCheckpointStore implements ImportCheckpointStore {
  final Map<String, ImportReceipt> _receipts = <String, ImportReceipt>{};

  @override
  ImportReceipt? read(String localId) => _receipts[localId];

  @override
  void write(ImportReceipt receipt) {
    _receipts[receipt.localId] = receipt;
  }
}

final class BackendImportCoordinator {
  const BackendImportCoordinator({
    required this.commandClient,
    required this.checkpoints,
  });

  final BackendCommandClient commandClient;
  final ImportCheckpointStore checkpoints;

  ImportDryRun dryRun(
    LocalImportCandidate candidate, {
    required String expectedOwnerId,
    required Set<ImportPublisherRef> eligiblePublishers,
  }) {
    final String semanticHash = semanticPayloadHash(<String, Object?>{
      'localId': candidate.localId,
      'ownerId': candidate.ownerId,
      'publisherRef': candidate.publisherRef.toJson(),
      'payload': candidate.payload,
    });
    if (candidate.ownerId != expectedOwnerId) {
      return ImportDryRun._(
        localId: candidate.localId,
        semanticHash: semanticHash,
        eligible: false,
        rejectionCode: 'owner_mismatch',
        proof: _dryRunProof,
      );
    }
    if (!eligiblePublishers.contains(candidate.publisherRef)) {
      return ImportDryRun._(
        localId: candidate.localId,
        semanticHash: semanticHash,
        eligible: false,
        rejectionCode: 'publisher_not_eligible',
        proof: _dryRunProof,
      );
    }
    if (candidate.mockAuthorityClaims.isNotEmpty) {
      return ImportDryRun._(
        localId: candidate.localId,
        semanticHash: semanticHash,
        eligible: false,
        rejectionCode: 'mock_authority_rejected',
        proof: _dryRunProof,
      );
    }
    return ImportDryRun._(
      localId: candidate.localId,
      semanticHash: semanticHash,
      eligible: true,
      rejectionCode: null,
      proof: _dryRunProof,
    );
  }

  Future<BackendResult<ImportReceipt>> import({
    required LocalImportCandidate candidate,
    required ImportDryRun dryRun,
    required BackendRequestContext context,
    required BackendCancellationToken cancellationToken,
  }) async {
    final String currentHash = semanticPayloadHash(<String, Object?>{
      'localId': candidate.localId,
      'ownerId': candidate.ownerId,
      'publisherRef': candidate.publisherRef.toJson(),
      'payload': candidate.payload,
    });
    if (dryRun._proof != _dryRunProof ||
        !dryRun.eligible ||
        dryRun.localId != candidate.localId ||
        candidate.mockAuthorityClaims.isNotEmpty) {
      return const BackendRejected<ImportReceipt>(
        BackendFailure(
          code: BackendFailureCode.permissionDenied,
          retryable: false,
        ),
      );
    }
    if (dryRun.semanticHash != currentHash ||
        dryRun.semanticHash != context.semanticPayloadHash) {
      return const BackendRejected<ImportReceipt>(
        BackendFailure(
          code: BackendFailureCode.idempotencyConflict,
          retryable: false,
        ),
      );
    }
    final ImportReceipt? previous = checkpoints.read(candidate.localId);
    if (previous != null) {
      if (previous.semanticHash != dryRun.semanticHash) {
        return const BackendRejected<ImportReceipt>(
          BackendFailure(
            code: BackendFailureCode.idempotencyConflict,
            retryable: false,
          ),
        );
      }
      return BackendSuccess<ImportReceipt>(
        value: previous,
        serverRevision: previous.serverRevision,
        committedAtUtc: context.createdAtUtc,
      );
    }

    final BackendResult<ImportReceipt> result = await commandClient.execute(
      operation: 'importLocalEntityV1',
      payload: <String, Object?>{
        'localId': candidate.localId,
        'ownerId': candidate.ownerId,
        'publisherRef': candidate.publisherRef.toJson(),
        'payload': candidate.payload,
      },
      context: context,
      decode: (Map<String, Object?> value) => ImportReceipt(
        localId: candidate.localId,
        serverId: value['serverId']! as String,
        semanticHash: dryRun.semanticHash,
        serverRevision: value['serverRevision']! as int,
      ),
      cancellationToken: cancellationToken,
    );
    if (result is BackendSuccess<ImportReceipt>) {
      if (result.serverRevision != result.value.serverRevision) {
        return const BackendRejected<ImportReceipt>(
          BackendFailure(
            code: BackendFailureCode.malformedResponse,
            retryable: false,
          ),
        );
      }
      checkpoints.write(result.value);
    }
    return result;
  }
}
