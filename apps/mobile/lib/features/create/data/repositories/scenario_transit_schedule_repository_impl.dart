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
      throw StateError('GTFS network refresh is disabled for $providerCode.');
    }
    final downloaded = await _remoteDataSource.download(provider);
    final index = await _parserExecutor.parse(
      archiveBytes: downloaded.bytes,
      providerCode: provider.code,
      providerDisplayName: provider.displayName,
      licenseName: provider.licenseName,
      sourceUrl: downloaded.sourceUrl,
      retrievedAtUtc: downloaded.retrievedAtUtc,
      freshnessMaxAge: provider.freshnessMaxAge,
      nowUtc: _nowUtc(),
    );
    await _cacheDataSource.write(
      CachedGtfsArchive(
        providerCode: provider.code,
        sourceUrl: downloaded.sourceUrl,
        retrievedAtUtc: downloaded.retrievedAtUtc,
        sha256: index.manifest.sha256,
        bytes: downloaded.bytes,
      ),
    );
    _indexes[provider.code] = index;
    return index.manifest;
  }

  @override
  Future<ScenarioTransitFeedManifest?> loadLastKnownGood(
    String providerCode,
  ) async {
    final existing = _indexes[providerCode];
    if (existing != null) return existing.manifest;
    final provider = _provider(providerCode);
    final cached = await _cacheDataSource.read(providerCode);
    if (cached == null) return null;
    try {
      final index = await _parserExecutor.parse(
        archiveBytes: cached.bytes,
        providerCode: provider.code,
        providerDisplayName: provider.displayName,
        licenseName: provider.licenseName,
        sourceUrl: cached.sourceUrl,
        retrievedAtUtc: cached.retrievedAtUtc,
        freshnessMaxAge: provider.freshnessMaxAge,
        nowUtc: _nowUtc(),
      );
      _indexes[provider.code] = index;
      return index.manifest;
    } on FormatException {
      return null;
    }
  }

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
      throw ArgumentError.value(code, 'providerCode', 'Unknown provider.');
    }
    return provider;
  }

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
