import 'dart:io';
import 'publication_journal_file.dart';

import '../domain/entities/session_publication.dart';
import '../domain/entities/publisher_ref.dart';
import '../domain/repositories/session_publication_gateway.dart';

/// File-backed "my sessions" journal (D3.5 §5.6): the ids of the Sessions this
/// install created through the publication path, each bound to the account
/// and publisher it was created for. Records of another account are kept in
/// the file but never returned for this one. It is a list of references, not a
/// source of truth; every status shown next to it is read from the server.
final class FileSessionPublicationJournal implements SessionPublicationJournal {
  FileSessionPublicationJournal(File file)
    : _storage = PublicationJournalFile<SessionPublicationRecord>(
        file,
        decode: SessionPublicationRecord.fromJson,
        encode: (record) => record.toJson(),
        maxRecords: maxRecords,
      );

  static const int maxRecords = 100;

  final PublicationJournalFile<SessionPublicationRecord> _storage;

  Future<List<SessionPublicationRecord>> _all() => _storage.read();

  @override
  Future<List<SessionPublicationRecord>> list(String accountId) async =>
      (await _all()).where((item) => item.accountId == accountId).toList();

  @override
  Future<SessionPublicationRecord?> forLocalDraft({
    required String accountId,
    required PublisherRef publisherRef,
    required String localDraftId,
  }) async {
    for (final SessionPublicationRecord record in await _all()) {
      if (record.localDraftId == localDraftId &&
          record.belongsTo(accountId, publisherRef)) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<void> save(SessionPublicationRecord record) async {
    final List<SessionPublicationRecord> records = await _all()
      ..removeWhere(
        (item) =>
            item.localDraftId == record.localDraftId &&
            item.belongsTo(record.accountId, record.publisherRef),
      )
      ..insert(0, record);
    await _storage.write(records);
  }
}
