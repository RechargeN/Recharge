import 'dart:io';

import 'publication_journal_file.dart';
import '../domain/entities/local_import.dart';
import '../domain/entities/publisher_ref.dart';
import '../domain/repositories/local_import_gateway.dart';

/// File-backed import receipts and sessions (D4 §5.4, §5.5): atomic writes
/// (temporary file, then rename), bounded, and bound to the account and
/// publisher they were created for. Another account's records are kept in the
/// files but never returned for this one. Receipts map ids only; every status
/// shown next to them is read from the server.
final class FileLocalImportJournal implements LocalImportJournal {
  FileLocalImportJournal({required File receipts, required File sessions})
    : _receipts = PublicationJournalFile<LocalImportReceipt>(
        receipts,
        decode: LocalImportReceipt.fromJson,
        encode: (record) => record.toJson(),
        maxRecords: maxReceipts,
      ),
      _sessions = PublicationJournalFile<LocalImportSession>(
        sessions,
        decode: LocalImportSession.fromJson,
        encode: (record) => record.toJson(),
        maxRecords: maxSessions,
      );

  static const int maxReceipts = 200;
  static const int maxSessions = 20;

  final PublicationJournalFile<LocalImportReceipt> _receipts;
  final PublicationJournalFile<LocalImportSession> _sessions;

  @override
  Future<List<LocalImportReceipt>> receipts(String accountId) async =>
      (await _receipts.read())
          .where((item) => item.accountId == accountId)
          .toList();

  @override
  Future<LocalImportReceipt?> receiptFor({
    required String accountId,
    required PublisherRef publisherRef,
    required String localDraftId,
  }) async {
    for (final LocalImportReceipt record in await _receipts.read()) {
      if (record.localDraftId == localDraftId &&
          record.belongsTo(accountId, publisherRef)) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<void> saveReceipt(LocalImportReceipt receipt) async {
    final List<LocalImportReceipt> records = await _receipts.read()
      ..removeWhere(
        (item) =>
            item.localDraftId == receipt.localDraftId &&
            item.belongsTo(receipt.accountId, receipt.publisherRef),
      )
      ..insert(0, receipt);
    await _receipts.write(records);
  }

  @override
  Future<LocalImportSession?> currentSession(String accountId) async {
    for (final LocalImportSession session in await _sessions.read()) {
      if (session.accountId == accountId) return session;
    }
    return null;
  }

  @override
  Future<void> saveSession(LocalImportSession session) async {
    final List<LocalImportSession> records = await _sessions.read()
      ..removeWhere((item) => item.sessionId == session.sessionId)
      ..insert(0, session);
    await _sessions.write(records);
  }
}
