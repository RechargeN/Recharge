import 'dart:io';

import '../domain/entities/scenario_publication.dart';
import '../domain/repositories/scenario_publication_gateway.dart';
import 'publication_journal_file.dart';

/// File-backed journal of this install's Scenario publications (I3). Records
/// of another account stay in the file but are never returned for this one.
final class FileScenarioPublicationJournal
    implements ScenarioPublicationJournal {
  FileScenarioPublicationJournal(File file)
    : _storage = PublicationJournalFile<ScenarioPublicationRecord>(
        file,
        decode: ScenarioPublicationRecord.fromJson,
        encode: (record) => record.toJson(),
        maxRecords: 100,
      );

  final PublicationJournalFile<ScenarioPublicationRecord> _storage;

  @override
  Future<ScenarioPublicationRecord?> forScenario({
    required String accountId,
    required String scenarioId,
  }) async {
    for (final ScenarioPublicationRecord record in await _storage.read()) {
      if (record.accountId == accountId && record.scenarioId == scenarioId) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<void> save(ScenarioPublicationRecord record) async {
    final List<ScenarioPublicationRecord> records = await _storage.read()
      ..removeWhere(
        (item) =>
            item.accountId == record.accountId &&
            item.scenarioId == record.scenarioId,
      )
      ..insert(0, record);
    await _storage.write(records);
  }
}
