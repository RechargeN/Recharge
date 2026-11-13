import 'dart:convert';
import 'dart:io';

import '../../../core/network/backend_clients.dart';
import '../../../core/network/backend_transport.dart';
import '../../../core/sync/backend_import.dart';
import 'booking_callable_adapter.dart';

/// File-backed local/test store. The caller injects an app-support directory;
/// no Firebase or platform authority is inferred from persisted data.
final class FileBookingPersistenceStore {
  FileBookingPersistenceStore(
    this.file, {
    BookingClock? clock,
    this.maximumFileBytes = 1024 * 1024,
    this.maximumReceipts = 256,
    this.maximumImports = 256,
    this.maximumOperations = 512,
  }) : _clock = clock ?? (() => DateTime.now().toUtc()) {
    file.parent.createSync(recursive: true);
  }

  final File file;
  final BookingClock _clock;
  final int maximumFileBytes;
  final int maximumReceipts;
  final int maximumImports;
  final int maximumOperations;

  static const Duration retryWindow = Duration(days: 7);

  T _withExclusiveLock<T>(T Function() action) {
    final lockFile = File('${file.path}.lock')..createSync(recursive: true);
    final handle = lockFile.openSync(mode: FileMode.append);
    handle.lockSync(FileLock.exclusive);
    try {
      return action();
    } finally {
      handle.unlockSync();
      handle.closeSync();
    }
  }

  Map<String, Object?> _readRootUnlocked() {
    final backup = File('${file.path}.bak');
    if (!file.existsSync() && backup.existsSync()) {
      backup.renameSync(file.path);
    }
    if (!file.existsSync()) return <String, Object?>{};
    if (file.lengthSync() > maximumFileBytes) {
      throw const BookingPersistenceException('booking_journal_too_large');
    }
    final decoded = jsonDecode(file.readAsStringSync());
    return decoded is Map<String, dynamic>
        ? Map<String, Object?>.from(decoded)
        : throw const BookingPersistenceException(
            'booking_journal_invalid_root',
          );
  }

  void _writeRootUnlocked(Map<String, Object?> root) {
    root['schemaVersion'] = 1;
    _compactRoot(root, _clock().toUtc());
    final encoded = jsonEncode(root);
    if (utf8.encode(encoded).length > maximumFileBytes) {
      throw const BookingPersistenceException('booking_journal_limit_reached');
    }
    final temporary = File(
      '${file.path}.${pid}_${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    final backup = File('${file.path}.bak');
    temporary.writeAsStringSync(encoded, flush: true);
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
    } finally {
      if (temporary.existsSync()) temporary.deleteSync();
    }
  }

  Map<String, Object?> _readRoot() => _withExclusiveLock(_readRootUnlocked);

  void _mutate(void Function(Map<String, Object?> root) mutation) {
    _withExclusiveLock(() {
      final root = _readRootUnlocked();
      mutation(root);
      _writeRootUnlocked(root);
    });
  }

  void compact() => _mutate((_) {});

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
    _mutate((root) {
      final receipts = Map<String, Object?>.from(
        (root['receipts'] as Map?) ?? {},
      );
      receipts[idempotencyKey] = <String, Object?>{
        'operation': receipt.operation,
        'semanticHash': receipt.semanticHash,
        'statusCode': receipt.response.statusCode,
        'body': receipt.response.body,
        'storedAtUtc': _clock().toUtc().toIso8601String(),
      };
      root['receipts'] = receipts;
    });
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
      operationId: map['operationId'] as String? ?? idempotencyKey,
      firstAttemptAtUtc: DateTime.parse(
        map['firstAttemptAtUtc']! as String,
      ).toUtc(),
      state: BookingOperationState.values.byName(map['state']! as String),
      reconciliationAttempts: map['reconciliationAttempts'] as int? ?? 0,
      lastReconciledAtUtc: map['lastReconciledAtUtc'] == null
          ? null
          : DateTime.parse(map['lastReconciledAtUtc']! as String).toUtc(),
      reconciliationCallableName: map['reconciliationCallableName'] as String?,
      reconciliationQuery: map['reconciliationQuery'] is Map
          ? Map<String, Object?>.unmodifiable(
              Map<String, Object?>.from(map['reconciliationQuery']! as Map),
            )
          : null,
    );
  }

  // Dart cannot overload the two `read(String)` interface methods. Expose
  // narrow adapters while keeping a single atomically persisted file.
  BackendReceiptStore get receiptStore => _ReceiptView(this);
  ImportCheckpointStore get importStore => _ImportView(this);
  BookingOperationStore get operationStore => _OperationView(this);

  void writeImportReceipt(ImportReceipt receipt) {
    _mutate((root) {
      final imports = Map<String, Object?>.from(
        (root['imports'] as Map?) ?? {},
      );
      imports[receipt.localId] = <String, Object?>{
        'serverId': receipt.serverId,
        'semanticHash': receipt.semanticHash,
        'serverRevision': receipt.serverRevision,
        'storedAtUtc': _clock().toUtc().toIso8601String(),
      };
      root['imports'] = imports;
    });
  }

  void writeBookingOperation(BookingOperationRecord record) {
    _mutate((root) {
      final operations = Map<String, Object?>.from(
        (root['operations'] as Map?) ?? {},
      );
      operations[record.idempotencyKey] = <String, Object?>{
        'firstAttemptAtUtc': record.firstAttemptAtUtc.toUtc().toIso8601String(),
        'operationId': record.operationId,
        'state': record.state.name,
        'reconciliationAttempts': record.reconciliationAttempts,
        if (record.lastReconciledAtUtc != null)
          'lastReconciledAtUtc': record.lastReconciledAtUtc!
              .toUtc()
              .toIso8601String(),
        if (record.reconciliationCallableName != null)
          'reconciliationCallableName': record.reconciliationCallableName,
        if (record.reconciliationQuery != null)
          'reconciliationQuery': record.reconciliationQuery,
        'storedAtUtc': _clock().toUtc().toIso8601String(),
      };
      root['operations'] = operations;
    });
  }

  void _compactRoot(Map<String, Object?> root, DateTime now) {
    final receipts = Map<String, Object?>.from(
      (root['receipts'] as Map?) ?? {},
    );
    receipts.removeWhere((_, value) => _isOlderThanWindow(value, now));
    root['receipts'] = _keepNewest(receipts, maximumReceipts);

    final imports = Map<String, Object?>.from((root['imports'] as Map?) ?? {});
    root['imports'] = _keepNewest(imports, maximumImports);

    final operations = Map<String, Object?>.from(
      (root['operations'] as Map?) ?? {},
    );
    operations.removeWhere((_, value) {
      if (value is! Map || !_isOlderThanWindow(value, now)) return false;
      final state = value['state'];
      return state == BookingOperationState.succeeded.name ||
          state == BookingOperationState.failedFinal.name ||
          state == BookingOperationState.cancelled.name;
    });
    root['operations'] = _keepNewest(
      operations,
      maximumOperations,
      preserveUnknown: true,
    );
  }

  bool _isOlderThanWindow(Object? value, DateTime now) {
    if (value is! Map) return false;
    final raw = value['storedAtUtc'] ?? value['firstAttemptAtUtc'];
    final instant = raw is String ? DateTime.tryParse(raw)?.toUtc() : null;
    return instant != null && now.difference(instant) > retryWindow;
  }

  Map<String, Object?> _keepNewest(
    Map<String, Object?> values,
    int maximum, {
    bool preserveUnknown = false,
  }) {
    if (values.length <= maximum) return values;
    final entries = values.entries.toList()
      ..sort(
        (left, right) =>
            _entryInstant(right.value).compareTo(_entryInstant(left.value)),
      );
    final retained = <String, Object?>{};
    if (preserveUnknown) {
      for (final entry in entries) {
        final value = entry.value;
        if (value is Map &&
            (value['state'] == BookingOperationState.pending.name ||
                value['state'] == BookingOperationState.unknownOutcome.name ||
                value['state'] ==
                    BookingOperationState.expiredUnknownAfter7d.name)) {
          retained[entry.key] = entry.value;
        }
      }
    }
    for (final entry in entries) {
      if (retained.length >= maximum) break;
      retained.putIfAbsent(entry.key, () => entry.value);
    }
    if (retained.length > maximum) {
      throw const BookingPersistenceException(
        'booking_operation_tombstone_limit_reached',
      );
    }
    return retained;
  }

  DateTime _entryInstant(Object? value) {
    if (value is Map) {
      final raw = value['storedAtUtc'] ?? value['firstAttemptAtUtc'];
      if (raw is String) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed.toUtc();
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}

final class BookingPersistenceException implements Exception {
  const BookingPersistenceException(this.code);
  final String code;

  @override
  String toString() => 'BookingPersistenceException($code)';
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
