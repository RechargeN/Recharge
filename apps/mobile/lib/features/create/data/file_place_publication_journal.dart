import 'dart:convert';
import 'dart:io';

import '../domain/entities/place_publication.dart';
import '../domain/entities/publisher_ref.dart';
import '../domain/repositories/place_publication_gateway.dart';

/// File-backed "my places" journal (D3.1 §5.6): the ids of the Places this
/// install created through the publication path, each bound to the account
/// and publisher it was created for. Records of another account are kept in
/// the file but never returned for this one. It is a list of references, not a
/// source of truth; every status shown next to it is read from the server.
final class FilePlacePublicationJournal implements PlacePublicationJournal {
  FilePlacePublicationJournal(this._file);

  static const int maxRecords = 100;

  final File _file;

  Future<List<PlacePublicationRecord>> _all() async {
    if (!await _file.exists()) return <PlacePublicationRecord>[];
    try {
      final Object? decoded = jsonDecode(await _file.readAsString());
      if (decoded is! List) return <PlacePublicationRecord>[];
      return decoded
          .map(PlacePublicationRecord.fromJson)
          .whereType<PlacePublicationRecord>()
          .toList();
    } on FormatException {
      return <PlacePublicationRecord>[];
    }
  }

  @override
  Future<List<PlacePublicationRecord>> list(String accountId) async =>
      (await _all()).where((item) => item.accountId == accountId).toList();

  @override
  Future<PlacePublicationRecord?> forLocalDraft({
    required String accountId,
    required PublisherRef publisherRef,
    required String localDraftId,
  }) async {
    for (final PlacePublicationRecord record in await _all()) {
      if (record.localDraftId == localDraftId &&
          record.belongsTo(accountId, publisherRef)) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<void> save(PlacePublicationRecord record) async {
    final List<PlacePublicationRecord> records = await _all()
      ..removeWhere(
        (item) =>
            item.localDraftId == record.localDraftId &&
            item.belongsTo(record.accountId, record.publisherRef),
      )
      ..insert(0, record);
    final List<PlacePublicationRecord> bounded = records
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
