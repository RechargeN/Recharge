import 'dart:io';
import 'publication_journal_file.dart';

import '../domain/entities/collection_content_publication.dart';
import '../domain/entities/publisher_ref.dart';
import '../domain/repositories/collection_content_publication_gateway.dart';

/// File-backed "my collections" journal (D3.4 §5.6): the ids of the
/// Collections this install created through the publication path, each bound
/// to the account and publisher it was created for. Records of another account
/// are kept in the file but never returned for this one. It is a list of
/// references, not a source of truth; every status shown next to it is read
/// from the server.
final class FileCollectionPublicationJournal
    implements CollectionPublicationJournal {
  FileCollectionPublicationJournal(File file)
    : _storage = PublicationJournalFile<CollectionPublicationRecord>(
        file,
        decode: CollectionPublicationRecord.fromJson,
        encode: (record) => record.toJson(),
        maxRecords: maxRecords,
      );

  static const int maxRecords = 100;

  final PublicationJournalFile<CollectionPublicationRecord> _storage;

  Future<List<CollectionPublicationRecord>> _all() => _storage.read();

  @override
  Future<List<CollectionPublicationRecord>> list(String accountId) async =>
      (await _all()).where((item) => item.accountId == accountId).toList();

  @override
  Future<CollectionPublicationRecord?> forLocalDraft({
    required String accountId,
    required PublisherRef publisherRef,
    required String localDraftId,
  }) async {
    for (final CollectionPublicationRecord record in await _all()) {
      if (record.localDraftId == localDraftId &&
          record.belongsTo(accountId, publisherRef)) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<void> save(CollectionPublicationRecord record) async {
    final List<CollectionPublicationRecord> records = await _all()
      ..removeWhere(
        (item) =>
            item.localDraftId == record.localDraftId &&
            item.belongsTo(record.accountId, record.publisherRef),
      )
      ..insert(0, record);
    await _storage.write(records);
  }
}
