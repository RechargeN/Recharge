import 'dart:io';
import 'publication_journal_file.dart';

import '../domain/entities/class_workshop_publication.dart';
import '../domain/entities/publisher_ref.dart';
import '../domain/repositories/class_workshop_publication_gateway.dart';

/// File-backed "my classes" journal (D3.6 §5.6): the ids of the Classes this
/// install created through the publication path, each bound to the account
/// and publisher it was created for. Records of another account are kept in
/// the file but never returned for this one. It is a list of references, not a
/// source of truth; every status shown next to it is read from the server.
final class FileClassWorkshopPublicationJournal
    implements ClassWorkshopPublicationJournal {
  FileClassWorkshopPublicationJournal(File file)
    : _storage = PublicationJournalFile<ClassWorkshopPublicationRecord>(
        file,
        decode: ClassWorkshopPublicationRecord.fromJson,
        encode: (record) => record.toJson(),
        maxRecords: maxRecords,
      );

  static const int maxRecords = 100;

  final PublicationJournalFile<ClassWorkshopPublicationRecord> _storage;

  Future<List<ClassWorkshopPublicationRecord>> _all() => _storage.read();

  @override
  Future<List<ClassWorkshopPublicationRecord>> list(String accountId) async =>
      (await _all()).where((item) => item.accountId == accountId).toList();

  @override
  Future<ClassWorkshopPublicationRecord?> forLocalDraft({
    required String accountId,
    required PublisherRef publisherRef,
    required String localDraftId,
  }) async {
    for (final ClassWorkshopPublicationRecord record in await _all()) {
      if (record.localDraftId == localDraftId &&
          record.belongsTo(accountId, publisherRef)) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<void> save(ClassWorkshopPublicationRecord record) async {
    final List<ClassWorkshopPublicationRecord> records = await _all()
      ..removeWhere(
        (item) =>
            item.localDraftId == record.localDraftId &&
            item.belongsTo(record.accountId, record.publisherRef),
      )
      ..insert(0, record);
    await _storage.write(records);
  }
}
