import 'dart:math' as math;

import '../../../../core/config/recharge_taxonomy.dart';
import '../../../../shared/primitives/money/money.dart';
import '../../domain/entities/discover_item_entity.dart';
import '../../domain/entities/discover_query.dart';
import '../../domain/entities/time_slot.dart';
import '../../domain/repositories/discover_repository.dart';
import '../datasources/catalog_query_port.dart';
import '../models/catalog_wire_models.dart';
import 'catalog_snapshot_session.dart';

/// Discover listing over the server Catalog (E2, Emulator-only). Feed, Search
/// and Map read one snapshot: every page of a listing reuses the snapshot token
/// of its first page, and the token is kept for Details. Filters the Catalog
/// cannot apply are refused by name, never dropped silently.
final class CatalogDiscoverRepository implements DiscoverRepository {
  CatalogDiscoverRepository({
    required CatalogQueryPort port,
    required CatalogSnapshotSession session,
    required String marketId,
    required String currencyCode,
    this.maxPages = 5,
    this.activityEnabled = false,
    this.findPeopleEnabled = false,
    this.routeEnabled = false,
    String Function()? newRequestId,
  }) : _port = port,
       _session = session,
       _marketId = marketId,
       _currencyCode = currencyCode,
       _newRequestId = newRequestId ?? _randomRequestId;

  final CatalogQueryPort _port;
  final CatalogSnapshotSession _session;
  final String _marketId;
  final String _currencyCode;
  final String Function() _newRequestId;

  /// Upper bound of pages read for one listing (test-only Catalog config).
  final int maxPages;
  final bool activityEnabled;

  /// D3.7: Find People requests are listed only while their own test entry is on.
  final bool findPeopleEnabled;

  /// DTL-RTE-02 RD-06: Routes are read from the Catalog only while their own
  /// test entry is on; otherwise Discover keeps the local RTE-08 path.
  final bool routeEnabled;

  @override
  Future<List<DiscoverItemEntity>> getFeed(DiscoverQuery query) async {
    final Map<String, Object?> wire = catalogWireQuery(
      query,
      marketId: _marketId,
      activityEnabled: activityEnabled,
      findPeopleEnabled: findPeopleEnabled,
      routeEnabled: routeEnabled,
    );
    final String queryType = wire.containsKey('literalText')
        ? 'search'
        : 'feed';
    final List<DiscoverItemEntity> items = <DiscoverItemEntity>[];
    String? snapshotToken;
    String? cursor;
    for (int page = 0; page < maxPages; page += 1) {
      final Object? body = await _ask(queryType, <String, Object?>{
        'query': wire,
        if (snapshotToken != null) 'snapshotToken': snapshotToken,
        if (cursor != null) 'cursor': cursor,
      });
      final CatalogFeedPage result = _parse(
        () => CatalogFeedPage.fromWire(body),
      );
      snapshotToken ??= result.snapshotToken;
      items.addAll(result.cards.map(_card));
      cursor = result.nextCursor;
      if (cursor == null) break;
    }
    _session.remember(snapshotToken!, wire);
    return List<DiscoverItemEntity>.unmodifiable(items);
  }

  @override
  Future<DiscoverItemEntity> getDetails(String itemId) async {
    final Object? detailsBody = await _ask('details', <String, Object?>{
      'contentId': itemId,
      if (_session.snapshotToken != null &&
          _session.query != null) ...<String, Object?>{
        'snapshotToken': _session.snapshotToken,
        'query': _session.query,
      },
    });
    final CatalogDetails details = _parse(
      () => CatalogDetails.fromWire(detailsBody),
    );
    if (details.route != null) {
      if (details.changedSinceSnapshot) {
        // RD-07: the listing showed an older revision. The snapshot is
        // dropped so "Обновить" reads the current revision, never the old one.
        _session.forget();
        throw const DiscoverException(code: routeRevisionChangedCode);
      }
      return _route(details.route!, null);
    }
    if (details.findPeople != null) {
      if (details.changedSinceSnapshot) {
        throw const DiscoverException(code: 'CATALOG_REVISION_CHANGED');
      }
      return _findPeople(details.findPeople!, null);
    }
    if (details.activity != null) {
      if (details.changedSinceSnapshot) {
        throw const DiscoverException(code: 'CATALOG_REVISION_CHANGED');
      }
      return _activity(details.activity!, null);
    }
    final CatalogEventItem? item = details.item;
    if (item == null) {
      throw const DiscoverException(code: 'DISCOVER_NOT_FOUND');
    }
    final CatalogOccurrenceWire occurrence = item.occurrences.firstWhere(
      (CatalogOccurrenceWire entry) =>
          entry.endAtUtc.isAfter(DateTime.now().toUtc()),
      orElse: () => item.occurrences.last,
    );
    return _event(
      contentId: item.contentId,
      revisionId: item.publishedRevisionId,
      title: item.title,
      subtitle: item.shortDescription,
      categoryId: item.categoryId,
      subcategoryId: item.subcategoryId,
      city: item.city,
      venueName: item.venueName,
      point: item.point,
      timezoneId: item.timezoneId,
      occurrenceId: occurrence.id,
      startAtUtc: occurrence.startAtUtc,
      endAtUtc: occurrence.endAtUtc,
      price: item.price,
      distanceMeters: null,
    );
  }

  /// A body the client does not know (for Find People also any private
  /// meeting field) is a typed refusal, never a partial listing.
  static T _parse<T>(T Function() read) {
    try {
      return read();
    } on FormatException {
      throw const DiscoverException(code: 'CATALOG_CONTRACT_INVALID');
    }
  }

  Future<Object?> _ask(String queryType, Map<String, Object?> payload) async {
    final Map<String, Object?> raw;
    try {
      raw = await _port.query(<String, Object?>{
        'schemaVersion': 1,
        'requestId': _newRequestId(),
        'queryType': queryType,
        'payload': payload,
      });
    } on CatalogTransportFailure catch (failure) {
      throw DiscoverException(code: 'CATALOG_TRANSPORT_${failure.code}');
    }
    final CatalogAnswer answer;
    try {
      answer = CatalogAnswer.fromWire(raw);
    } on FormatException {
      throw const DiscoverException(code: 'CATALOG_CONTRACT_INVALID');
    }
    if (!answer.succeeded) {
      throw DiscoverException(
        code: 'CATALOG_${answer.kind.toUpperCase()}:${answer.code}',
      );
    }
    return answer.body;
  }

  DiscoverItemEntity _card(CatalogCard card) => card.route != null
      ? _route(card.route!, card.distanceMeters)
      : card.findPeople != null
      ? _findPeople(card.findPeople!, card.distanceMeters)
      : card.activity != null
      ? _activity(card.activity!, card.distanceMeters)
      : _event(
          contentId: card.contentId,
          revisionId: card.publishedRevisionId,
          title: card.title,
          subtitle: card.shortDescription,
          categoryId: card.categoryId,
          subcategoryId: card.subcategoryId,
          city: card.city,
          venueName: card.venueName,
          point: card.point,
          timezoneId: card.timezoneId,
          occurrenceId: card.occurrenceId,
          startAtUtc: card.startAtUtc!,
          endAtUtc: card.endAtUtc!,
          price: card.price,
          distanceMeters: card.distanceMeters,
        );

  /// D3.7: the MapObject point is exactly the server's ~1 km cell centre; the
  /// client never moves it, never refines it and never reads device location.
  DiscoverItemEntity _findPeople(CatalogFindPeopleItem item, double? distance) {
    if (!findPeopleEnabled) {
      throw const DiscoverException(code: 'CATALOG_FIND_PEOPLE_DISABLED');
    }
    final int duration = item.endAtUtc.difference(item.startAtUtc).inMinutes;
    final int? spend = item.expectedSpendMinor;
    return DiscoverItemEntity(
      id: item.contentId,
      title: item.title,
      subtitle: item.shortDescription,
      city: '',
      category: item.categoryId,
      subcategory: item.subcategoryId,
      startsAtUtc: item.startAtUtc,
      latitude: item.point.latitude,
      longitude: item.point.longitude,
      priceAmount: spend != null && item.currencyCode != null
          ? Money(minorUnits: spend, currencyCode: item.currencyCode!)
          : Money.zero(_currencyCode),
      distanceKm: (distance ?? 0) / 1000,
      isFree: item.costType == 'free',
      objectKind: DiscoverObjectKind.findPeople,
      venueName: item.publicAreaLabel,
      timezoneId: item.timezoneId,
      durationMinutes: duration > 0 ? duration : null,
      durationConfidence: DurationConfidence.exact,
      availabilityKind: AvailabilityKind.eventSlots,
      scheduleSlots: <TimeSlot>[
        TimeSlot(
          slotId: item.occurrenceId,
          startAtUtc: item.startAtUtc,
          endAtUtc: item.endAtUtc,
        ),
      ],
      revisionRef: item.publishedRevisionId,
    );
  }

  /// DTL-RTE-02: a Route is a map object at the start of its trimmed track.
  /// No date, price, duration or bounds exist for it, and none are invented.
  DiscoverItemEntity _route(CatalogRouteItem item, double? distance) {
    if (!routeEnabled) {
      throw const DiscoverException(code: 'CATALOG_ROUTE_DISABLED');
    }
    return DiscoverItemEntity(
      id: item.contentId,
      title: item.title,
      subtitle: item.shortDescription,
      city: '',
      category: item.categoryId,
      subcategory: item.subcategoryId,
      startsAtUtc: null,
      latitude: item.facts.start.latitude,
      longitude: item.facts.start.longitude,
      priceAmount: null,
      distanceKm: (distance ?? 0) / 1000,
      isFree: false,
      objectKind: DiscoverObjectKind.route,
      availabilityKind: AvailabilityKind.none,
      revisionRef: item.publishedRevisionId,
      routeCatalog: item.facts,
    );
  }

  DiscoverItemEntity _activity(CatalogActivityItem item, double? distance) {
    if (!activityEnabled) {
      throw const DiscoverException(code: 'CATALOG_ACTIVITY_DISABLED');
    }
    return DiscoverItemEntity(
      id: item.contentId,
      title: item.title,
      subtitle: item.shortDescription,
      city: '',
      category: item.categoryId,
      subcategory: item.subcategoryId,
      startsAtUtc: null,
      latitude: item.point.latitude,
      longitude: item.point.longitude,
      priceAmount: null,
      distanceKm: (distance ?? 0) / 1000,
      isFree: false,
      objectKind: DiscoverObjectKind.activity,
      availabilityKind: AvailabilityKind.none,
      durationMinutes: item.facts.durationMinMinutes,
      durationConfidence: DurationConfidence.estimated,
      addressLine: item.facts.addressLine,
      revisionRef: item.publishedRevisionId,
      activityCatalog: item.facts,
    );
  }

  DiscoverItemEntity _event({
    required String contentId,
    required String revisionId,
    required String title,
    required String subtitle,
    required String categoryId,
    required String subcategoryId,
    required String? city,
    required String? venueName,
    required CatalogPoint? point,
    required String timezoneId,
    required String occurrenceId,
    required DateTime startAtUtc,
    required DateTime endAtUtc,
    required CatalogPrice? price,
    required double? distanceMeters,
  }) {
    final int duration = endAtUtc.difference(startAtUtc).inMinutes;
    return DiscoverItemEntity(
      id: contentId,
      title: title,
      subtitle: subtitle,
      city: city ?? '',
      category: categoryId,
      subcategory: subcategoryId,
      startsAtUtc: startAtUtc,
      // No public point (online or unpinned): not a place on the map. Never a
      // fake coordinate; Details and Map treat non-finite values as no point.
      latitude: point?.latitude ?? double.nan,
      longitude: point?.longitude ?? double.nan,
      priceAmount: price != null && !price.free
          ? Money(
              minorUnits: price.amountMinor,
              currencyCode: price.currencyCode!,
            )
          : Money.zero(_currencyCode),
      // Unknown distance (no point) is shown as no distance, like Routes.
      distanceKm: distanceMeters == null ? 0 : distanceMeters / 1000,
      isFree: price?.free ?? false,
      objectKind: DiscoverObjectKind.event,
      venueName: venueName ?? '',
      timezoneId: timezoneId,
      durationMinutes: duration > 0 ? duration : null,
      durationConfidence: DurationConfidence.exact,
      availabilityKind: AvailabilityKind.eventSlots,
      scheduleSlots: <TimeSlot>[
        TimeSlot(
          slotId: occurrenceId,
          startAtUtc: startAtUtc,
          endAtUtc: endAtUtc,
        ),
      ],
      revisionRef: revisionId,
    );
  }
}

/// The `DiscoverQueryV1` the Catalog receives for [query]. Throws a typed
/// [DiscoverException] for a filter the Catalog does not apply: nothing is
/// mapped to a default and no filter is dropped.
Map<String, Object?> catalogWireQuery(
  DiscoverQuery query, {
  required String marketId,
  bool activityEnabled = false,
  bool findPeopleEnabled = false,
  bool routeEnabled = false,
}) {
  final List<String> unsupported = <String>[
    if (query.budgetMin != null) 'budgetMin',
    if (query.peopleCount != null) 'peopleCount',
    if (query.availableDurationMinutes != null) 'availableDurationMinutes',
    if (query.timeWindow == null &&
        (query.dateFrom == null) != (query.dateTo == null))
      'openDateRange',
    if (query.freeOnly && query.budgetMax != null) 'freeWithBudget',
  ];
  if (unsupported.isNotEmpty) {
    throw DiscoverException(
      code: 'CATALOG_FILTER_UNSUPPORTED:${unsupported.join(',')}',
    );
  }
  final String text = query.queryText.trim();
  final DateTime? from = query.timeWindow == null ? query.dateFrom : null;
  final DateTime? to = query.timeWindow == null ? query.dateTo : null;
  final Money? budgetMax = query.budgetMax;
  return <String, Object?>{
    'schemaVersion': 1,
    'marketId': marketId,
    'typeIds': <String>[
      'event',
      if (activityEnabled) 'activity',
      if (findPeopleEnabled) 'find_people',
      // RD-05: like RTE-08, the default feed has no Routes; a query that
      // asks for something (text, category, filters) includes them.
      if (routeEnabled && query.requestsPublishedRoutes) 'route',
    ],
    if (query.selectedCategoryIds.isNotEmpty)
      'categoryIds': query.selectedCategoryIds
          .map(normalizeRechargeContentGroupId)
          .toSet()
          .toList(),
    if (query.selectedSubcategoryIds.isNotEmpty)
      'subcategoryIds': query.selectedSubcategoryIds
          .map(normalizeRechargeLegacySubcategoryId)
          .toSet()
          .toList(),
    if (from != null && to != null)
      'timeWindow': <String, Object?>{
        'fromUtc': from.toUtc().toIso8601String(),
        'toUtc': to.toUtc().toIso8601String(),
      },
    'geo': <String, Object?>{
      'center': <String, Object?>{
        'latitude': query.centerLat,
        'longitude': query.centerLng,
      },
      if (!query.unlimitedRadius) 'radiusKm': query.radiusMeters / 1000,
    },
    if (query.freeOnly) 'price': const <String, Object?>{'free': true},
    if (budgetMax != null)
      'price': <String, Object?>{
        'maxAmountMinor': budgetMax.minorUnits,
        'currencyCode': budgetMax.currencyCode,
      },
    if (text.isNotEmpty) 'literalText': text,
    // Booking availability is not part of the Catalog: the server refuses it
    // by name instead of the client pretending to filter.
    if (query.onlyAvailable) 'onlyAvailable': true,
  };
}

final math.Random _random = math.Random.secure();

String _randomRequestId() {
  final String suffix = List<String>.generate(
    16,
    (_) => _random.nextInt(16).toRadixString(16),
  ).join();
  return 'discover-$suffix';
}
