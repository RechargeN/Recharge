import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../domain/entities/event_publication.dart';
import '../domain/repositories/event_publication_gateway.dart';

/// File-backed "my objects" journal: the ids of the objects this install
/// created through the publication path. It is a local list of references, not
/// a source of truth; every status shown next to it is read from the server.
final class FileEventPublicationJournal implements EventPublicationJournal {
  FileEventPublicationJournal(this._file);

  static const int maxRecords = 50;

  final File _file;

  @override
  Future<List<EventPublicationRecord>> list() async {
    if (!await _file.exists()) return <EventPublicationRecord>[];
    try {
      final Object? decoded = jsonDecode(await _file.readAsString());
      if (decoded is! List) return <EventPublicationRecord>[];
      return decoded
          .map(EventPublicationRecord.fromJson)
          .whereType<EventPublicationRecord>()
          .toList();
    } on FormatException {
      return <EventPublicationRecord>[];
    }
  }

  @override
  Future<EventPublicationRecord?> forLocalDraft(String localDraftId) async {
    for (final EventPublicationRecord record in await list()) {
      if (record.localDraftId == localDraftId) return record;
    }
    return null;
  }

  @override
  Future<void> save(EventPublicationRecord record) async {
    final List<EventPublicationRecord> records = await list()
      ..removeWhere((item) => item.localDraftId == record.localDraftId)
      ..insert(0, record);
    final List<EventPublicationRecord> bounded = records
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

/// Reads the cover the Create draft refers to: a local file path. Anything
/// that is not a readable local file yields null (nothing is uploaded).
final class FileEventCoverSource implements EventCoverSource {
  const FileEventCoverSource();

  @override
  Future<Uint8List?> read(String reference) async {
    if (reference.trim().isEmpty) return null;
    // A Windows path such as `C:\x.png` parses as a URI with scheme `c`, so only
    // an explicit `file:` URI is read as a URI; any other `scheme://` is remote.
    final File file;
    if (reference.startsWith('file:')) {
      final Uri? uri = Uri.tryParse(reference);
      if (uri == null) return null;
      file = File.fromUri(uri);
    } else if (reference.contains('://')) {
      return null;
    } else {
      file = File(reference);
    }
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }
}
