import 'dart:isolate';

import 'gtfs_archive_parser.dart';
import 'gtfs_schedule_index.dart';

class GtfsParserExecutor {
  const GtfsParserExecutor({
    this.parser = const GtfsArchiveParser(),
    this.runInBackground = true,
  });

  final GtfsArchiveParser parser;
  final bool runInBackground;

  Future<GtfsScheduleIndex> parse({
    required List<int> archiveBytes,
    required String providerCode,
    required String providerDisplayName,
    required String licenseName,
    required String sourceUrl,
    required DateTime retrievedAtUtc,
    required Duration freshnessMaxAge,
    required DateTime nowUtc,
  }) {
    GtfsScheduleIndex operation() => parser.parse(
      archiveBytes: archiveBytes,
      providerCode: providerCode,
      providerDisplayName: providerDisplayName,
      licenseName: licenseName,
      sourceUrl: sourceUrl,
      retrievedAtUtc: retrievedAtUtc,
      freshnessMaxAge: freshnessMaxAge,
      nowUtc: nowUtc,
    );

    if (!runInBackground) {
      return Future<GtfsScheduleIndex>.sync(operation);
    }
    return Isolate.run(operation);
  }
}
