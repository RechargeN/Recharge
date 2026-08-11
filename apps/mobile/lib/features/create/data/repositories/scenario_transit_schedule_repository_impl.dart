import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/entities/scenario_transit_schedule.dart';
import '../../domain/repositories/scenario_transit_schedule_repository.dart';
import '../datasources/gtfs_cache_datasource.dart';
import '../datasources/latvia_gtfs_datasource.dart';
import '../gtfs/gtfs_archive_parser.dart';
import '../gtfs/gtfs_parser_executor.dart';
import '../gtfs/gtfs_schedule_index.dart';

class ScenarioTransitScheduleRepositoryImpl
    implements ScenarioTransitScheduleRepository {
  ScenarioTransitScheduleRepositoryImpl({
    required LatviaGtfsProviderRegistry registry,
    required LatviaGtfsRemoteDataSource remoteDataSource,
    required GtfsCacheDataSource cacheDataSource,
    GtfsArchiveParser parser = const GtfsArchiveParser(),
    bool parseInBackground = true,
    DateTime Function()? nowUtc,
  }) : _registry = registry,
       _remoteDataSource = remoteDataSource,
       _cacheDataSource = cacheDataSource,
       _parserExecutor = GtfsParserExecutor(
         parser: parser,
         runInBackground: parseInBackground,
       ),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final LatviaGtfsProviderRegistry _registry;
  final LatviaGtfsRemoteDataSource _remoteDataSource;
  final GtfsCacheDataSource _cacheDataSource;
  final GtfsParserExecutor _parserExecutor;
  final DateTime Function() _nowUtc;
  final Map<String, GtfsScheduleIndex> _indexes = <String, GtfsScheduleIndex>{};
  final Map<String, Future<ScenarioTransitFeedManifest>> _refreshes =
      <String, Future<ScenarioTransitFeedManifest>>{};

  @override
  List<ScenarioTransitProviderDescriptor> get providers =>
      List<ScenarioTransitProviderDescriptor>.unmodifiable(
        _registry.providers.map(
          (provider) => ScenarioTransitProviderDescriptor(
            code: provider.code,
            displayName: provider.displayName,
            licenseName: provider.licenseName,
            sourceUrl: provider.sourceUrl,
            refreshEnabled: _registry.networkRefreshEnabled && provider.enabled,
          ),
        ),
      );

  @override
  Future<ScenarioTransitFeedManifest> refreshProvider(String providerCode) {
    final existing = _refreshes[providerCode];
    if (existing != null) return existing;
    late final Future<ScenarioTransitFeedManifest> operation;
    operation = _refreshProvider(providerCode).whenComplete(() {
      if (identical(_refreshes[providerCode], operation)) {
        _refreshes.remove(providerCode);
      }
    });
    _refreshes[providerCode] = operation;
    return operation;
  }

  Future<ScenarioTransitFeedManifest> _refreshProvider(
    String providerCode,
  ) async {
    final provider = _provider(providerCode);
    if (!_registry.networkRefreshEnabled || !provider.enabled) {
      throw ScenarioTransitScheduleException(
        code: ScenarioTransitScheduleFailureCode.networkDisabled,
        providerCode: providerCode,
      );
    }
    late final DownloadedGtfsArchive downloaded;
    try {
      downloaded = await _remoteDataSource.download(provider);
    } on TimeoutException {
      throw ScenarioTransitScheduleException(
        code: ScenarioTransitScheduleFailureCode.offline,
        providerCode: providerCode,
      );
    } on SocketException {
      throw ScenarioTransitScheduleException(
        code: ScenarioTransitScheduleFailureCode.offline,
        providerCode: providerCode,
      );
    } on http.ClientException {
      throw ScenarioTransitScheduleException(
        code: ScenarioTransitScheduleFailureCode.offline,
        providerCode: providerCode,
      );
    } on Object {
      throw ScenarioTransitScheduleException(
        code: ScenarioTransitScheduleFailureCode.downloadFailed,
        providerCode: providerCode,
      );
    }
    late final GtfsScheduleIndex index;
    try {
      index = await _parserExecutor.parse(
        archiveBytes: downloaded.bytes,
        providerCode: provider.code,
        providerDisplayName: provider.displayName,
        licenseName: provider.licenseName,
        sourceUrl: downloaded.sourceUrl,
        retrievedAtUtc: downloaded.retrievedAtUtc,
        freshnessMaxAge: provider.freshnessMaxAge,
        nowUtc: _nowUtc(),
      );
    } on FormatException {
      throw ScenarioTransitScheduleException(
        code: ScenarioTransitScheduleFailureCode.invalidFeed,
        providerCode: providerCode,
      );
    } on Object {
      throw ScenarioTransitScheduleException(
        code: ScenarioTransitScheduleFailureCode.invalidFeed,
        providerCode: providerCode,
      );
    }
    try {
      await _cacheDataSource.write(
        CachedGtfsArchive(
          providerCode: provider.code,
          sourceUrl: downloaded.sourceUrl,
          retrievedAtUtc: downloaded.retrievedAtUtc,
          sha256: index.manifest.sha256,
          bytes: downloaded.bytes,
        ),
      );
    } on Object {
      throw ScenarioTransitScheduleException(
        code: ScenarioTransitScheduleFailureCode.cacheWriteFailed,
        providerCode: providerCode,
      );
    }
    _indexes[provider.code] = index;
    return index.manifest;
  }

  @override
  Future<ScenarioTransitCacheInspection> inspectCache(
    String providerCode,
  ) async {
    final provider = _provider(providerCode);
    final existing = _indexes[providerCode];
    if (existing != null) {
      return _inspection(existing.manifest);
    }
    late final GtfsCacheReadResult cached;
    try {
      cached = await _cacheDataSource.inspect(providerCode);
    } on Object {
      return ScenarioTransitCacheInspection(
        providerCode: providerCode,
        status: ScenarioTransitCacheStatus.failed,
      );
    }
    if (cached.status == GtfsCacheReadStatus.missing) {
      return ScenarioTransitCacheInspection(
        providerCode: providerCode,
        status: ScenarioTransitCacheStatus.missing,
      );
    }
    if (cached.status == GtfsCacheReadStatus.corrupt ||
        cached.archive == null) {
      return ScenarioTransitCacheInspection(
        providerCode: providerCode,
        status: ScenarioTransitCacheStatus.corrupt,
      );
    }
    try {
      final archive = cached.archive!;
      final index = await _parserExecutor.parse(
        archiveBytes: archive.bytes,
        providerCode: provider.code,
        providerDisplayName: provider.displayName,
        licenseName: provider.licenseName,
        sourceUrl: archive.sourceUrl,
        retrievedAtUtc: archive.retrievedAtUtc,
        freshnessMaxAge: provider.freshnessMaxAge,
        nowUtc: _nowUtc(),
      );
      _indexes[provider.code] = index;
      return _inspection(index.manifest);
    } on FormatException {
      return ScenarioTransitCacheInspection(
        providerCode: providerCode,
        status: ScenarioTransitCacheStatus.corrupt,
      );
    } on Object {
      return ScenarioTransitCacheInspection(
        providerCode: providerCode,
        status: ScenarioTransitCacheStatus.failed,
      );
    }
  }

  @override
  Future<ScenarioTransitFeedManifest?> loadLastKnownGood(
    String providerCode,
  ) async => (await inspectCache(providerCode)).manifest;

  @override
  Future<List<ScenarioTransitStop>> searchStops({
    required String query,
    Set<String> providerCodes = const <String>{},
    int limit = 20,
  }) async {
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit');
    }
    final codes = _selectedCodes(providerCodes);
    await _loadMissing(codes);
    final results = <ScenarioTransitStop>[];
    for (final code in codes) {
      results.addAll(
        _indexes[code]?.searchStops(query, limit: limit) ?? const [],
      );
    }
    final normalizedQuery = query.trim().toLowerCase();
    results.sort((left, right) {
      final leftName = left.name.toLowerCase();
      final rightName = right.name.toLowerCase();
      final prefixOrder = (rightName.startsWith(normalizedQuery) ? 1 : 0)
          .compareTo(leftName.startsWith(normalizedQuery) ? 1 : 0);
      if (prefixOrder != 0) return prefixOrder;
      final nameOrder = left.name.toLowerCase().compareTo(
        right.name.toLowerCase(),
      );
      if (nameOrder != 0) return nameOrder;
      final providerOrder = left.providerCode.compareTo(right.providerCode);
      if (providerOrder != 0) return providerOrder;
      return left.id.compareTo(right.id);
    });
    return List<ScenarioTransitStop>.unmodifiable(results.take(limit));
  }

  @override
  Future<ScenarioTransitSearchResult> searchServices(
    ScenarioTransitSearchQuery query,
  ) async {
    final codes = _selectedCodes(query.providerCodes);
    await _loadMissing(codes);
    final options = <ScenarioTransitServiceOption>[];
    final loaded = <String>{};
    final unavailable = <String>{};
    for (final code in codes) {
      final index = _indexes[code];
      if (index == null) {
        unavailable.add(code);
        continue;
      }
      loaded.add(code);
      options.addAll(index.searchServices(query));
    }
    options.sort((left, right) {
      var order = left.departure.compareTo(right.departure);
      if (order != 0) return order;
      order = left.arrival.compareTo(right.arrival);
      if (order != 0) return order;
      order = left.providerCode.compareTo(right.providerCode);
      if (order != 0) return order;
      return left.tripId.compareTo(right.tripId);
    });
    return ScenarioTransitSearchResult(
      options: List<ScenarioTransitServiceOption>.unmodifiable(
        options.take(query.limit),
      ),
      loadedProviders: Set<String>.unmodifiable(loaded),
      unavailableProviders: Set<String>.unmodifiable(unavailable),
    );
  }

  LatviaGtfsProviderConfig _provider(String code) {
    final provider = _registry.byCode(code);
    if (provider == null) {
      throw ScenarioTransitScheduleException(
        code: ScenarioTransitScheduleFailureCode.unknownProvider,
        providerCode: code,
      );
    }
    return provider;
  }

  ScenarioTransitCacheInspection _inspection(
    ScenarioTransitFeedManifest manifest,
  ) => ScenarioTransitCacheInspection(
    providerCode: manifest.providerCode,
    status: switch (manifest.freshness) {
      ScenarioTransitFreshness.current => ScenarioTransitCacheStatus.current,
      ScenarioTransitFreshness.stale => ScenarioTransitCacheStatus.stale,
      ScenarioTransitFreshness.unknown => ScenarioTransitCacheStatus.unknown,
      ScenarioTransitFreshness.unavailable => ScenarioTransitCacheStatus.failed,
    },
    manifest: manifest.freshness == ScenarioTransitFreshness.unavailable
        ? null
        : manifest,
  );

  Set<String> _selectedCodes(Set<String> requested) {
    final codes = requested.isEmpty
        ? _registry.providers.map((provider) => provider.code).toSet()
        : requested;
    for (final code in codes) {
      _provider(code);
    }
    return Set<String>.unmodifiable(codes);
  }

  Future<void> _loadMissing(Set<String> codes) async {
    for (final code in codes) {
      if (!_indexes.containsKey(code)) {
        await loadLastKnownGood(code);
      }
    }
  }
}
