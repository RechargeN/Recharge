import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:recharge/features/create/data/datasources/latvia_gtfs_datasource.dart';
import 'package:recharge/features/create/data/gtfs/gtfs_archive_parser.dart';

Future<void> main(List<String> arguments) async {
  final requestedCodes = arguments.toSet();
  final providers = officialLatviaGtfsProviders.where(
    (provider) =>
        requestedCodes.isEmpty || requestedCodes.contains(provider.code),
  );
  if (providers.isEmpty) {
    throw ArgumentError(
      'Pass a known provider code: '
      '${officialLatviaGtfsProviders.map((provider) => provider.code).join(', ')}',
    );
  }

  final client = http.Client();
  try {
    final remote = LatviaGtfsRemoteDataSource(client: client);
    const parser = GtfsArchiveParser();
    for (final provider in providers) {
      final downloaded = await remote.download(provider);
      final index = parser.parse(
        archiveBytes: downloaded.bytes,
        providerCode: provider.code,
        providerDisplayName: provider.displayName,
        licenseName: provider.licenseName,
        sourceUrl: downloaded.sourceUrl,
        retrievedAtUtc: downloaded.retrievedAtUtc,
        freshnessMaxAge: provider.freshnessMaxAge,
      );
      stdout.writeln(
        jsonEncode(<String, Object?>{
          'provider': provider.code,
          'source': downloaded.sourceUrl,
          'retrieved_at_utc': downloaded.retrievedAtUtc.toIso8601String(),
          'sha256': index.manifest.sha256,
          'freshness': index.manifest.freshness.name,
          'stops': index.stopCount,
          'routes': index.routeCount,
          'trips': index.tripCount,
          'services': index.serviceCount,
        }),
      );
    }
  } finally {
    client.close();
  }
}
