import 'dart:convert';
import 'dart:io';

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
  FileActivityPublicationJournal(this._file);

  static const int maxRecords = 100;

  final File _file;

  Future<List<ActivityPublicationRecord>> _all() async {
    if (!await _file.exists()) return <ActivityPublicationRecord>[];
    try {
      final Object? decoded = jsonDecode(await _file.readAsString());
      if (decoded is! List) return <ActivityPublicationRecord>[];
      return decoded
          .map(ActivityPublicationRecord.fromJson)
          .whereType<ActivityPublicationRecord>()
          .toList();
    } on FormatException {
      return <ActivityPublicationRecord>[];
    }
  }

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
    final List<ActivityPublicationRecord> bounded = records
        .take(maxRecords)
        .toList();
    await _file.parent.create(recursive: true);
    // Write-then-rename, so an interrupted save never leaves half a file.
    final File temporary = File('${_file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(bounded.map((item) => item.toJson()).toList()),
      flush: true,
    );
    await temporary.rename(_file.path);
  }
}
