import 'dart:io';

import '../domain/entities/find_people_publication.dart';
import '../domain/entities/publisher_ref.dart';
import '../domain/repositories/find_people_publication_gateway.dart';
import 'publication_journal_file.dart';

/// File-backed "my Find People requests" journal (D3.7): the ids of the
/// requests this install created through the publication path, each bound to
/// the account and publisher it was created for. Apart from the body of a
/// write still waiting for its answer (the author's own draft data on the
/// author's device, cleared once answered) it holds ids only, and every status
/// shown next to it is read from the server.
final class FileFindPeoplePublicationJournal
    implements FindPeoplePublicationJournal {
  FileFindPeoplePublicationJournal(File file)
    : _storage = PublicationJournalFile<FindPeoplePublicationRecord>(
        file,
        decode: FindPeoplePublicationRecord.fromJson,
        encode: (record) => record.toJson(),
        maxRecords: maxRecords,
      );

  static const int maxRecords = 100;

  final PublicationJournalFile<FindPeoplePublicationRecord> _storage;

  Future<List<FindPeoplePublicationRecord>> _all() => _storage.read();

  @override
  Future<List<FindPeoplePublicationRecord>> list(String accountId) async =>
      (await _all()).where((item) => item.accountId == accountId).toList();

  @override
  Future<FindPeoplePublicationRecord?> forLocalDraft({
    required String accountId,
    required PublisherRef publisherRef,
    required String localDraftId,
  }) async {
    for (final FindPeoplePublicationRecord record in await _all()) {
      if (record.localDraftId == localDraftId &&
          record.belongsTo(accountId, publisherRef)) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<void> save(FindPeoplePublicationRecord record) async {
    final List<FindPeoplePublicationRecord> records = await _all()
      ..removeWhere(
        (item) =>
            item.localDraftId == record.localDraftId &&
            item.belongsTo(record.accountId, record.publisherRef),
      )
      ..insert(0, record);
    await _storage.write(records);
  }
}
