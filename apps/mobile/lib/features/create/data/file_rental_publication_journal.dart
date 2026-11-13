import 'dart:io';
import 'publication_journal_file.dart';

import '../domain/entities/rental_publication.dart';
import '../domain/entities/publisher_ref.dart';
import '../domain/repositories/rental_publication_gateway.dart';

/// File-backed "my rentals" journal (D3.3 §4): the ids of the Rentals this
/// install created through the publication path, each bound to the account
/// and publisher it was created for; every status is read from the server.
final class FileRentalPublicationJournal implements RentalPublicationJournal {
  FileRentalPublicationJournal(File file)
    : _storage = PublicationJournalFile<RentalPublicationRecord>(
        file,
        decode: RentalPublicationRecord.fromJson,
        encode: (record) => record.toJson(),
        maxRecords: maxRecords,
      );

  static const int maxRecords = 100;

  final PublicationJournalFile<RentalPublicationRecord> _storage;

  Future<List<RentalPublicationRecord>> _all() => _storage.read();

  @override
  Future<List<RentalPublicationRecord>> list(String accountId) async =>
      (await _all()).where((item) => item.accountId == accountId).toList();

  @override
  Future<RentalPublicationRecord?> forLocalDraft({
    required String accountId,
    required PublisherRef publisherRef,
    required String localDraftId,
  }) async {
    for (final RentalPublicationRecord record in await _all()) {
      if (record.localDraftId == localDraftId &&
          record.belongsTo(accountId, publisherRef)) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<void> save(RentalPublicationRecord record) async {
    final List<RentalPublicationRecord> records = await _all()
      ..removeWhere(
        (item) =>
            item.localDraftId == record.localDraftId &&
            item.belongsTo(record.accountId, record.publisherRef),
      )
      ..insert(0, record);
    await _storage.write(records);
  }
}
