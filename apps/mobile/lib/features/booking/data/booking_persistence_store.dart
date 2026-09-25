import 'dart:convert';
import 'dart:io';

import '../../../core/network/backend_clients.dart';
import '../../../core/network/backend_transport.dart';
import '../../../core/sync/backend_import.dart';
import 'booking_callable_adapter.dart';

/// File-backed local/test store. The caller injects an app-support directory;
/// no Firebase or platform authority is inferred from persisted data.
final class FileBookingPersistenceStore {
  FileBookingPersistenceStore(this.file) {
    file.parent.createSync(recursive: true);
  }

  final File file;

  Map<String, Object?> _readRoot() {
    final backup = File('${file.path}.bak');
    if (!file.existsSync() && backup.existsSync()) {
      backup.renameSync(file.path);
    }
    if (!file.existsSync()) return <String, Object?>{};
    final decoded = jsonDecode(file.readAsStringSync());
    return decoded is Map<String, dynamic>
        ? Map<String, Object?>.from(decoded)
        : <String, Object?>{};
  }

  void _writeRoot(Map<String, Object?> root) {
    final temporary = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');
    temporary.writeAsStringSync(jsonEncode(root), flush: true);
    if (backup.existsSync()) backup.deleteSync();
    if (file.existsSync()) file.renameSync(backup.path);
    try {
      temporary.renameSync(file.path);
      if (backup.existsSync()) backup.deleteSync();
    } catch (_) {
      if (!file.existsSync() && backup.existsSync()) {
        backup.renameSync(file.path);
      }
      rethrow;
    }
  }

  BackendReceipt? read(String idempotencyKey) {
    final value = (_readRoot()['receipts'] as Map?)?[idempotencyKey];
    if (value is! Map) return null;
    final map = Map<String, Object?>.from(value);
    return BackendReceipt(
      operation: map['operation']! as String,
      semanticHash: map['semanticHash']! as String,
      response: BackendResponse(
        statusCode: map['statusCode']! as int,
        body: Map<String, Object?>.from(map['body']! as Map),
      ),
    );
  }

  void write(String idempotencyKey, BackendReceipt receipt) {
    final root = _readRoot();
    final receipts = Map<String, Object?>.from(
      (root['receipts'] as Map?) ?? {},
    );
    receipts[idempotencyKey] = <String, Object?>{
      'operation': receipt.operation,
      'semanticHash': receipt.semanticHash,
      'statusCode': receipt.response.statusCode,
      'body': receipt.response.body,
    };
    root['receipts'] = receipts;
    _writeRoot(root);
  }

  ImportReceipt? readImportReceipt(String localId) {
    final value = (_readRoot()['imports'] as Map?)?[localId];
    if (value is! Map) return null;
    final map = Map<String, Object?>.from(value);
    return ImportReceipt(
      localId: localId,
      serverId: map['serverId']! as String,
      semanticHash: map['semanticHash']! as String,
      serverRevision: map['serverRevision']! as int,
    );
  }

  BookingOperationRecord? readBookingOperation(String idempotencyKey) {
    final value = (_readRoot()['operations'] as Map?)?[idempotencyKey];
    if (value is! Map) return null;
    final map = Map<String, Object?>.from(value);
    return BookingOperationRecord(
      idempotencyKey: idempotencyKey,
      firstAttemptAtUtc: DateTime.parse(
        map['firstAttemptAtUtc']! as String,
      ).toUtc(),
      state: BookingOperationState.values.byName(map['state']! as String),
    );
  }

  // Dart cannot overload the two `read(String)` interface methods. Expose
  // narrow adapters while keeping a single atomically persisted file.
  BackendReceiptStore get receiptStore => _ReceiptView(this);
  ImportCheckpointStore get importStore => _ImportView(this);
  BookingOperationStore get operationStore => _OperationView(this);

  void writeImportReceipt(ImportReceipt receipt) {
    final root = _readRoot();
    final imports = Map<String, Object?>.from((root['imports'] as Map?) ?? {});
    imports[receipt.localId] = <String, Object?>{
      'serverId': receipt.serverId,
      'semanticHash': receipt.semanticHash,
      'serverRevision': receipt.serverRevision,
    };
    root['imports'] = imports;
    _writeRoot(root);
  }

  void writeBookingOperation(BookingOperationRecord record) {
    final root = _readRoot();
    final operations = Map<String, Object?>.from(
      (root['operations'] as Map?) ?? {},
    );
    operations[record.idempotencyKey] = <String, Object?>{
      'firstAttemptAtUtc': record.firstAttemptAtUtc.toUtc().toIso8601String(),
      'state': record.state.name,
    };
    root['operations'] = operations;
    _writeRoot(root);
  }
}

final class _ReceiptView implements BackendReceiptStore {
  const _ReceiptView(this.owner);
  final FileBookingPersistenceStore owner;
  @override
  BackendReceipt? read(String idempotencyKey) => owner.read(idempotencyKey);
  @override
  void write(String idempotencyKey, BackendReceipt receipt) =>
      owner.write(idempotencyKey, receipt);
}

final class _ImportView implements ImportCheckpointStore {
  const _ImportView(this.owner);
  final FileBookingPersistenceStore owner;
  @override
  ImportReceipt? read(String localId) => owner.readImportReceipt(localId);
  @override
  void write(ImportReceipt receipt) => owner.writeImportReceipt(receipt);
}

final class _OperationView implements BookingOperationStore {
  const _OperationView(this.owner);
  final FileBookingPersistenceStore owner;
  @override
  BookingOperationRecord? read(String idempotencyKey) =>
      owner.readBookingOperation(idempotencyKey);
  @override
  void write(BookingOperationRecord record) =>
      owner.writeBookingOperation(record);
}
