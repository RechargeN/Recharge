import 'dart:async';

import 'package:http/http.dart' as http;

class LatviaGtfsProviderConfig {
  const LatviaGtfsProviderConfig({
    required this.code,
    required this.displayName,
    required this.sourceUrl,
    required this.licenseName,
    required this.freshnessMaxAge,
    this.enabled = true,
  });

  final String code;
  final String displayName;
  final String sourceUrl;
  final String licenseName;
  final Duration freshnessMaxAge;
  final bool enabled;
}

class LatviaGtfsProviderRegistry {
  const LatviaGtfsProviderRegistry({
    this.networkRefreshEnabled = true,
    this.providers = officialLatviaGtfsProviders,
  });

  final bool networkRefreshEnabled;
  final List<LatviaGtfsProviderConfig> providers;

  LatviaGtfsProviderConfig? byCode(String code) {
    for (final provider in providers) {
      if (provider.code == code) return provider;
    }
    return null;
  }
}

const officialLatviaGtfsProviders = <LatviaGtfsProviderConfig>[
  LatviaGtfsProviderConfig(
    code: 'lv_atd_bus',
    displayName: 'Autotransporta direkcija',
    sourceUrl: 'https://www.atd.lv/sites/default/files/GTFS/gtfs-latvia-lv.zip',
    licenseName: 'CC0 1.0',
    freshnessMaxAge: Duration(hours: 48),
  ),
  LatviaGtfsProviderConfig(
    code: 'lv_vivi_train',
    displayName: 'Vivi',
    sourceUrl: 'https://vivi.lv/uploads/GTFS.zip',
    licenseName: 'CC0 1.0',
    freshnessMaxAge: Duration(days: 45),
  ),
];

class DownloadedGtfsArchive {
  const DownloadedGtfsArchive({
    required this.bytes,
    required this.retrievedAtUtc,
    required this.sourceUrl,
  });

  final List<int> bytes;
  final DateTime retrievedAtUtc;
  final String sourceUrl;
}

class LatviaGtfsRemoteDataSource {
  LatviaGtfsRemoteDataSource({
    required http.Client client,
    DateTime Function()? nowUtc,
    this.maxDownloadBytes = 64 * 1024 * 1024,
    this.requestTimeout = const Duration(seconds: 30),
  }) : _client = client,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final http.Client _client;
  final DateTime Function() _nowUtc;
  final int maxDownloadBytes;
  final Duration requestTimeout;

  Future<DownloadedGtfsArchive> download(
    LatviaGtfsProviderConfig provider,
  ) async {
    final uri = Uri.parse(provider.sourceUrl);
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      throw StateError('GTFS provider ${provider.code} must use HTTPS.');
    }
    final request = http.Request('GET', uri)
      ..followRedirects = true
      ..maxRedirects = 3
      ..headers['Accept'] = '*/*'
      ..headers['User-Agent'] = 'Recharge/1.0 (GTFS schedule importer)';
    final response = await _client.send(request).timeout(requestTimeout);
    final finalUri = response.request?.url ?? uri;
    if (finalUri.scheme != 'https') {
      throw StateError('GTFS redirect must remain on HTTPS.');
    }
    if (response.statusCode != 200) {
      throw StateError(
        'GTFS provider ${provider.code} returned ${response.statusCode}.',
      );
    }
    final declaredLength = response.contentLength;
    if (declaredLength != null &&
        (declaredLength <= 0 || declaredLength > maxDownloadBytes)) {
      throw StateError('GTFS download size is outside the allowed range.');
    }

    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(requestTimeout)) {
      if (bytes.length + chunk.length > maxDownloadBytes) {
        throw StateError('GTFS download exceeded the size limit.');
      }
      bytes.addAll(chunk);
    }
    if (bytes.isEmpty) {
      throw StateError('GTFS provider returned an empty archive.');
    }
    return DownloadedGtfsArchive(
      bytes: List<int>.unmodifiable(bytes),
      retrievedAtUtc: _nowUtc().toUtc(),
      sourceUrl: finalUri.toString(),
    );
  }
}
