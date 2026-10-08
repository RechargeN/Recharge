import 'dart:math' as math;

import '../../domain/entities/event_occurrence.dart';
import '../../domain/entities/published_event_discovery_entity.dart';
import '../../domain/repositories/discover_repository.dart';
import '../../domain/repositories/published_event_discovery_port.dart';
import '../datasources/catalog_query_port.dart';
import '../models/catalog_wire_models.dart';
import 'catalog_snapshot_session.dart';

/// Event Details over the server Catalog (E2, Emulator-only). The object is
/// read against the snapshot the listing came from: a different or
/// unconfirmable revision is marked [PublishedEventDiscoveryEntity.changedSinceListing],
/// and hidden content (excluded or absent) is `null`, never a stale copy.
final class CatalogPublishedEventDiscovery
    implements PublishedEventDiscoveryPort {
  CatalogPublishedEventDiscovery({
    required CatalogQueryPort port,
    required CatalogSnapshotSession session,
    required String currencyCode,
    DateTime Function()? nowUtc,
    String Function()? newRequestId,
  }) : _port = port,
       _session = session,
       _currencyCode = currencyCode,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _newRequestId = newRequestId ?? _randomRequestId;

  final CatalogQueryPort _port;
  final CatalogSnapshotSession _session;
  final String _currencyCode;
  final DateTime Function() _nowUtc;
  final String Function() _newRequestId;

  @override
  Future<PublishedEventDiscoveryEntity?> getActiveEvent(String eventId) async {
    final String? token = _session.snapshotToken;
    final Map<String, Object?>? query = _session.query;
    CatalogAnswer answer = await _ask(<String, Object?>{
      'contentId': eventId,
      if (token != null && query != null) ...<String, Object?>{
        'snapshotToken': token,
        'query': query,
      },
    });
    bool unconfirmed = false;
    if (answer.kind == 'stale' && token != null) {
      // The listing snapshot expired or was superseded: read the current
      // object, but the revision can no longer be confirmed as the listed one.
      unconfirmed = true;
      answer = await _ask(<String, Object?>{'contentId': eventId});
    }
    if (!answer.succeeded) {
      throw DiscoverException(
        code: 'CATALOG_${answer.kind.toUpperCase()}:${answer.code}',
        message: 'Каталог отклонил запрос',
      );
    }
    final CatalogDetails details;
    try {
      details = CatalogDetails.fromWire(answer.body);
    } on FormatException {
      throw const DiscoverException(
        code: 'CATALOG_CONTRACT_INVALID',
        message: 'Неподдерживаемый ответ каталога',
      );
    }
    final CatalogEventItem? item = details.item;
    if (item == null) return null;
    return _entity(item, unconfirmed || details.changedSinceSnapshot);
  }

  Future<CatalogAnswer> _ask(Map<String, Object?> payload) async {
    try {
      return CatalogAnswer.fromWire(
        await _port.query(<String, Object?>{
          'schemaVersion': 1,
          'requestId': _newRequestId(),
          'queryType': 'details',
          'payload': payload,
        }),
      );
    } on CatalogTransportFailure catch (failure) {
      throw DiscoverException(
        code: 'CATALOG_TRANSPORT_${failure.code}',
        message: 'Каталог недоступен',
      );
    } on FormatException {
      throw const DiscoverException(
        code: 'CATALOG_CONTRACT_INVALID',
        message: 'Неподдерживаемый ответ каталога',
      );
    }
  }

  PublishedEventDiscoveryEntity _entity(CatalogEventItem item, bool changed) {
    final DateTime now = _nowUtc();
    final List<EventOccurrence> occurrences = item.occurrences
        .map(
          (CatalogOccurrenceWire occurrence) => EventOccurrence(
            id: occurrence.id,
            startAtUtc: occurrence.startAtUtc,
            endAtUtc: occurrence.endAtUtc,
            status: EventOccurrenceStatus.scheduled,
            bookingRef: occurrence.bookingRef == null
                ? null
                : EventBookingRef(
                    eventId: occurrence.bookingRef!.eventId,
                    occurrenceId: occurrence.bookingRef!.occurrenceId,
                    channel: occurrence.bookingRef!.channel,
                  ),
          ),
        )
        .toList(growable: false);
    // The nearest occurrence that has not ended, as the Catalog lists it.
    final EventOccurrence display = occurrences.firstWhere(
      (EventOccurrence occurrence) => occurrence.endAtUtc.isAfter(now),
      orElse: () => occurrences.last,
    );
    final CatalogPrice? price = item.price;
    final bool fixed = price != null && !price.free;
    final int minutes = display.endAtUtc
        .difference(display.startAtUtc)
        .inMinutes;
    return PublishedEventDiscoveryEntity(
      eventId: item.contentId,
      publisherId: item.publisherId,
      publisherType: item.publisherType,
      // The Catalog carries no publisher display name; never invented.
      publisherName: '',
      title: item.title,
      subtitle: item.shortDescription,
      fullDescription: item.fullDescription,
      category: item.categoryId,
      subcategory: item.subcategoryId,
      city: item.city ?? '',
      venueName: item.venueName ?? '',
      latitude: item.point?.latitude ?? double.nan,
      longitude: item.point?.longitude ?? double.nan,
      distanceKm: 0,
      priceAmount: fixed ? price.amountMinor / 100 : 0,
      isFree: price?.free ?? false,
      currencyCode: fixed ? price.currencyCode! : _currencyCode,
      durationMinutes: minutes > 0 ? minutes : null,
      scheduleMode: EventScheduleMode.values.byName(item.scheduleMode),
      occurrences: occurrences,
      displayOccurrenceId: display.id,
      timezoneId: item.timezoneId,
      publishedAtUtc: item.publishedAtUtc,
      revisionRef: item.publishedRevisionId,
      changedSinceListing: changed,
    );
  }
}

final math.Random _random = math.Random.secure();

String _randomRequestId() {
  final String suffix = List<String>.generate(
    16,
    (_) => _random.nextInt(16).toRadixString(16),
  ).join();
  return 'discover-$suffix';
}
