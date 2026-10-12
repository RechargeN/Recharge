import 'dart:io';
import 'publication_journal_file.dart';

import '../domain/entities/activity_publication.dart';
import '../domain/entities/publisher_ref.dart';
import '../domain/repositories/activity_publication_gateway.dart';

/// File-backed "my activities" journal (D3.2 §5.6): the ids of the Recharge
/// Activities this install created through the publication path, each bound to
/// the account and publisher it was created for. Records of another account
/// are kept in the file but never returned for this one. It is a list of
/// references, not a source of truth; every status shown next to it is read
/// from the server.
final class FileActivityPublicationJournal
    implements ActivityPublicationJournal {
  FileActivityPublicationJournal(File file)
    : _storage = PublicationJournalFile<ActivityPublicationRecord>(
        file,
        decode: ActivityPublicationRecord.fromJson,
        encode: (record) => record.toJson(),
        maxRecords: maxRecords,
      );

  static const int maxRecords = 100;

  final PublicationJournalFile<ActivityPublicationRecord> _storage;

  Future<List<ActivityPublicationRecord>> _all() => _storage.read();

  @override
  Future<List<ActivityPublicationRecord>> list(String accountId) async =>
      (await _all()).where((item) => item.accountId == accountId).toList();

  @override
  Future<ActivityPublicationRecord?> forLocalDraft({
    required String accountId,
    required PublisherRef publisherRef,
    required String localDraftId,
  }) async {
    for (final ActivityPublicationRecord record in await _all()) {
      if (record.localDraftId == localDraftId &&
          record.belongsTo(accountId, publisherRef)) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<void> save(ActivityPublicationRecord record) async {
    final List<ActivityPublicationRecord> records = await _all()
      ..removeWhere(
        (item) =>
            item.localDraftId == record.localDraftId &&
            item.belongsTo(record.accountId, record.publisherRef),
      )
      ..insert(0, record);
    await _storage.write(records);
  }
}
