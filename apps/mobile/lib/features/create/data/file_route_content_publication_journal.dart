import 'dart:io';

import '../domain/entities/route_content_publication.dart';
import '../domain/repositories/route_content_publication_gateway.dart';
import 'publication_journal_file.dart';

/// File-backed journal of this install's Route publications (J2). Records of
/// another account stay in the file but are never returned for this one.
final class FileRouteContentPublicationJournal
    implements RouteContentPublicationJournal {
  FileRouteContentPublicationJournal(File file)
    : _storage = PublicationJournalFile<RouteContentPublicationRecord>(
        file,
        decode: RouteContentPublicationRecord.fromJson,
        encode: (record) => record.toJson(),
        maxRecords: 100,
      );

  final PublicationJournalFile<RouteContentPublicationRecord> _storage;

  @override
  Future<RouteContentPublicationRecord?> forDraft({
    required String accountId,
    required String localDraftId,
  }) async {
    for (final RouteContentPublicationRecord record in await _storage.read()) {
      if (record.accountId == accountId &&
          record.localDraftId == localDraftId) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<void> save(RouteContentPublicationRecord record) async {
    final List<RouteContentPublicationRecord> records = await _storage.read()
      ..removeWhere(
        (item) =>
            item.accountId == record.accountId &&
            item.localDraftId == record.localDraftId,
      )
      ..insert(0, record);
    await _storage.write(records);
  }
}
