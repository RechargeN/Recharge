import '../../domain/entities/activity_catalog_facts.dart';
// Strict readers for the Emulator-only `discoverQuery` v1 answers (E2). A
// shape the client does not know is a FormatException, never a guess.

Map<String, Object?> _map(Object? value, String field) {
  if (value is Map) return value.cast<String, Object?>();
  throw FormatException('catalog.$field must be an object');
}

String _string(Map<String, Object?> map, String field) {
  final Object? value = map[field];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('catalog.$field must be a non-empty string');
}

String? _optionalString(Map<String, Object?> map, String field) {
  final Object? value = map[field];
  if (value == null) return null;
  if (value is String) return value.isEmpty ? null : value;
  throw FormatException('catalog.$field must be a string or null');
}

int _int(Map<String, Object?> map, String field) {
  final Object? value = map[field];
  if (value is int) return value;
  throw FormatException('catalog.$field must be an integer');
}

double? _optionalDouble(Map<String, Object?> map, String field) {
  final Object? value = map[field];
  if (value == null) return null;
  if (value is num) return value.toDouble();
  throw FormatException('catalog.$field must be a number or null');
}

DateTime _instant(Map<String, Object?> map, String field) {
  final DateTime? parsed = DateTime.tryParse(_string(map, field));
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('catalog.$field must be a UTC instant');
  }
  return parsed;
}

String _scheduleMode(String value) {
  if (value == 'oneTime' || value == 'multiDate' || value == 'recurring') {
    return value;
  }
  throw FormatException('catalog.item.scheduleMode $value is not supported');
}

List<Object?> _list(Map<String, Object?> map, String field) {
  final Object? value = map[field];
  if (value is List) return value;
  throw FormatException('catalog.$field must be a list');
}

final class CatalogPoint {
  const CatalogPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  static CatalogPoint? read(Object? value) {
    if (value == null) return null;
    final Map<String, Object?> map = _map(value, 'point');
    final double? latitude = _optionalDouble(map, 'latitude');
    final double? longitude = _optionalDouble(map, 'longitude');
    if (latitude == null || longitude == null) {
      throw const FormatException('catalog.point needs both coordinates');
    }
    return CatalogPoint(latitude, longitude);
  }
}

/// `free`, `fixed` with an exact minor amount, or unknown (`null` on the wire).
final class CatalogPrice {
  const CatalogPrice.free() : amountMinor = 0, currencyCode = null, free = true;

  const CatalogPrice.fixed({
    required this.amountMinor,
    required String this.currencyCode,
  }) : free = false;

  final bool free;
  final int amountMinor;
  final String? currencyCode;

  static CatalogPrice? read(Object? value) {
    if (value == null) return null;
    final Map<String, Object?> map = _map(value, 'price');
    final String mode = _string(map, 'mode');
    if (mode == 'free') return const CatalogPrice.free();
    if (mode == 'fixed') {
      return CatalogPrice.fixed(
        amountMinor: _int(map, 'amountMinor'),
        currencyCode: _string(map, 'currencyCode'),
      );
    }
    throw FormatException('catalog.price.mode $mode is not supported');
  }
}

/// One Feed/Search card: the deciding occurrence of one published revision.
final class CatalogCard {
  const CatalogCard({
    required this.contentId,
    required this.publishedRevisionId,
    required this.title,
    required this.shortDescription,
    required this.categoryId,
    required this.subcategoryId,
    required this.city,
    required this.venueName,
    required this.point,
    required this.timezoneId,
    required this.occurrenceId,
    required this.startAtUtc,
    required this.endAtUtc,
    required this.price,
    required this.distanceMeters,
    this.activity,
  });

  factory CatalogCard.fromWire(Object? value) {
    final Map<String, Object?> map = _map(value, 'card');
    final Map<String, Object?> ref = _map(map['ref'], 'card.ref');
    if (ref['typeId'] == 'activity') {
      final CatalogActivityItem item = CatalogActivityItem.fromWire(
        <String, Object?>{
          ...map,
          'typeId': 'activity',
          'contentId': ref['contentId'],
        },
      );
      return CatalogCard(
        contentId: item.contentId,
        publishedRevisionId: item.publishedRevisionId,
        title: item.title,
        shortDescription: item.shortDescription,
        categoryId: item.categoryId,
        subcategoryId: item.subcategoryId,
        city: null,
        venueName: null,
        point: item.point,
        timezoneId: '',
        occurrenceId: '',
        startAtUtc: null,
        endAtUtc: null,
        price: null,
        distanceMeters: _optionalDouble(map, 'distanceMeters'),
        activity: item,
      );
    }
    if (ref['typeId'] != 'event') {
      throw FormatException('catalog.card.ref.typeId ${ref['typeId']}');
    }
    final Map<String, Object?> occurrence = _map(
      map['occurrence'],
      'card.occurrence',
    );
    return CatalogCard(
      contentId: _string(ref, 'contentId'),
      publishedRevisionId: _string(map, 'publishedRevisionId'),
      title: _string(map, 'title'),
      shortDescription: _string(map, 'shortDescription'),
      categoryId: _string(map, 'categoryId'),
      subcategoryId: _string(map, 'subcategoryId'),
      city: _optionalString(map, 'city'),
      venueName: _optionalString(map, 'venueName'),
      point: CatalogPoint.read(map['point']),
      timezoneId: _string(map, 'timezoneId'),
      occurrenceId: _string(occurrence, 'id'),
      startAtUtc: _instant(occurrence, 'startAtUtc'),
      endAtUtc: _instant(occurrence, 'endAtUtc'),
      price: CatalogPrice.read(map['price']),
      distanceMeters: _optionalDouble(map, 'distanceMeters'),
    );
  }

  final String contentId;
  final String publishedRevisionId;
  final String title;
  final String shortDescription;
  final String categoryId;
  final String subcategoryId;
  final String? city;
  final String? venueName;
  final CatalogPoint? point;
  final String timezoneId;
  final String occurrenceId;
  final DateTime? startAtUtc;
  final DateTime? endAtUtc;
  final CatalogPrice? price;
  final double? distanceMeters;
  final CatalogActivityItem? activity;
}

final class CatalogFeedPage {
  const CatalogFeedPage({
    required this.snapshotToken,
    required this.projectionSetRevision,
    required this.cards,
    required this.nextCursor,
  });

  factory CatalogFeedPage.fromWire(Object? value) {
    final Map<String, Object?> map = _map(value, 'page');
    return CatalogFeedPage(
      snapshotToken: _string(map, 'snapshotToken'),
      projectionSetRevision: _int(map, 'projectionSetRevision'),
      cards: _list(map, 'items').map(CatalogCard.fromWire).toList(),
      nextCursor: _optionalString(map, 'nextCursor'),
    );
  }

  final String snapshotToken;
  final int projectionSetRevision;
  final List<CatalogCard> cards;
  final String? nextCursor;
}

final class CatalogOccurrenceWire {
  const CatalogOccurrenceWire(
    this.id,
    this.startAtUtc,
    this.endAtUtc, {
    this.bookingRef,
  });

  final String id;
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final CatalogBookingRef? bookingRef;
}

/// v3: reference to free internal Booking of one occurrence.
final class CatalogBookingRef {
  const CatalogBookingRef({
    required this.eventId,
    required this.occurrenceId,
    this.channel,
  });

  static CatalogBookingRef? read(Object? value) {
    if (value == null) return null;
    final Map<String, Object?> map = _map(value, 'bookingRef');
    final String? channel = _optionalString(map, 'channel');
    if (channel != null && channel != 'onsite') {
      throw FormatException('catalog.bookingRef.channel $channel');
    }
    return CatalogBookingRef(
      eventId: _string(map, 'eventId'),
      occurrenceId: _string(map, 'occurrenceId'),
      channel: channel,
    );
  }

  final String eventId;
  final String occurrenceId;
  final String? channel;
}

/// The listed Details item: one exact published revision.
final class CatalogEventItem {
  const CatalogEventItem({
    required this.contentId,
    required this.publishedRevisionId,
    required this.publisherType,
    required this.publisherId,
    required this.title,
    required this.shortDescription,
    required this.fullDescription,
    required this.categoryId,
    required this.subcategoryId,
    required this.city,
    required this.venueName,
    required this.point,
    required this.timezoneId,
    required this.scheduleMode,
    required this.occurrences,
    required this.price,
    required this.publishedAtUtc,
  });

  factory CatalogEventItem.fromWire(Object? value) {
    final Map<String, Object?> map = _map(value, 'item');
    if (map['typeId'] != 'event') {
      throw FormatException('catalog.item.typeId ${map['typeId']}');
    }
    final Map<String, Object?> publisher = _map(
      map['publisherRef'],
      'item.publisherRef',
    );
    final List<CatalogOccurrenceWire> occurrences = _list(map, 'occurrences')
        .map((Object? entry) {
          final Map<String, Object?> occurrence = _map(entry, 'occurrence');
          return CatalogOccurrenceWire(
            _string(occurrence, 'id'),
            _instant(occurrence, 'startAtUtc'),
            _instant(occurrence, 'endAtUtc'),
            bookingRef: CatalogBookingRef.read(occurrence['bookingRef']),
          );
        })
        .toList();
    if (occurrences.isEmpty) {
      throw const FormatException('catalog.item.occurrences must not be empty');
    }
    return CatalogEventItem(
      contentId: _string(map, 'contentId'),
      publishedRevisionId: _string(map, 'publishedRevisionId'),
      publisherType: _string(publisher, 'type'),
      publisherId: _string(publisher, 'id'),
      title: _string(map, 'title'),
      shortDescription: _string(map, 'shortDescription'),
      fullDescription: _string(map, 'fullDescription'),
      categoryId: _string(map, 'categoryId'),
      subcategoryId: _string(map, 'subcategoryId'),
      city: _optionalString(map, 'city'),
      venueName: _optionalString(map, 'venueName'),
      point: CatalogPoint.read(map['point']),
      timezoneId: _string(map, 'timezoneId'),
      scheduleMode: _scheduleMode(_string(map, 'scheduleMode')),
      occurrences: occurrences,
      price: CatalogPrice.read(map['price']),
      publishedAtUtc: _instant(map, 'publishedAtUtc'),
    );
  }

  final String contentId;
  final String publishedRevisionId;
  final String publisherType;
  final String publisherId;
  final String title;
  final String shortDescription;
  final String fullDescription;
  final String categoryId;
  final String subcategoryId;
  final String? city;
  final String? venueName;
  final CatalogPoint? point;
  final String timezoneId;
  final String scheduleMode;
  final List<CatalogOccurrenceWire> occurrences;
  final CatalogPrice? price;
  final DateTime publishedAtUtc;
}

final class CatalogActivityItem {
  const CatalogActivityItem({
    required this.contentId,
    required this.publishedRevisionId,
    required this.title,
    required this.shortDescription,
    required this.categoryId,
    required this.subcategoryId,
    required this.point,
    required this.facts,
  });
  factory CatalogActivityItem.fromWire(Object? value) {
    final Map<String, Object?> map = _map(value, 'activity');
    if (map['typeId'] != 'activity' ||
        map['schemaRevision'] != 'catalog-activity-projection-v1') {
      throw const FormatException('catalog.activity.schema');
    }
    for (final String field in <String>[
      'occurrences',
      'price',
      'timezoneId',
      'bookingRef',
      'criteria',
    ]) {
      if (map.containsKey(field)) {
        throw FormatException('catalog.activity.forbidden:$field');
      }
    }
    final Map<String, Object?> refs = _map(
      map['referenceRevisions'],
      'referenceRevisions',
    );
    if (_string(refs, 'taxonomyRevisionId') !=
        'taxonomy-1.4.3-sha256:d5d4472629d52b8f3db883d9a449bcbfd5fa18e5f87a6d6aa26ae5b98168c822') {
      throw const FormatException('catalog.activity.taxonomy');
    }
    final Map<String, Object?> duration = _map(
      map['typicalDurationMinutes'],
      'duration',
    );
    final int min = _int(duration, 'min'), max = _int(duration, 'max');
    if (min <= 0 || max < min) {
      throw const FormatException('catalog.activity.duration');
    }
    final Map<String, Object?>? group = map['suggestedGroupSize'] == null
        ? null
        : _map(map['suggestedGroupSize'], 'suggestedGroupSize');
    if (group != null &&
        (_int(group, 'min') <= 0 || _int(group, 'max') < _int(group, 'min'))) {
      throw const FormatException('catalog.activity.group');
    }
    final CatalogPoint? point = CatalogPoint.read(map['point']);
    if (point == null ||
        !point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude.abs() > 90 ||
        point.longitude.abs() > 180) {
      throw const FormatException('catalog.activity.point');
    }
    final Map<String, Object?> best = map['bestTime'] == null
        ? <String, Object?>{}
        : _map(map['bestTime'], 'bestTime');
    final String? time = _optionalString(best, 'timeOfDay'),
        season = _optionalString(best, 'season');
    if (time != null &&
            !<String>[
              'morning',
              'afternoon',
              'evening',
              'night',
              'any',
            ].contains(time) ||
        season != null &&
            !<String>[
              'winter',
              'spring',
              'summer',
              'autumn',
              'any',
            ].contains(season)) {
      throw const FormatException('catalog.activity.bestTime');
    }
    final Map<String, Object?> caution = map['accessCaution'] == null
        ? <String, Object?>{}
        : _map(map['accessCaution'], 'accessCaution');
    final Map<String, Object?>? contribution =
        map['optionalContribution'] == null
        ? null
        : _map(map['optionalContribution'], 'optionalContribution');
    final Map<String, Object?>? amount = contribution?['amountHint'] == null
        ? null
        : _map(contribution!['amountHint'], 'amountHint');
    if (contribution != null &&
        !<String>[
          'purchase',
          'donation',
          'other',
        ].contains(contribution['kind'])) {
      throw const FormatException('catalog.activity.contribution');
    }
    if (amount != null && _int(amount, 'amountMinor') <= 0) {
      throw const FormatException('catalog.activity.amount');
    }
    final List<String> gallery = _list(map, 'galleryMediaIds')
        .map((Object? id) {
          if (id is! String || id.isEmpty) {
            throw const FormatException('catalog.activity.gallery');
          }
          return id;
        })
        .toList(growable: false);
    return CatalogActivityItem(
      contentId: _string(map, 'contentId'),
      publishedRevisionId: _string(map, 'publishedRevisionId'),
      title: _string(map, 'title'),
      shortDescription: _string(map, 'shortDescription'),
      categoryId: _string(map, 'categoryId'),
      subcategoryId: _string(map, 'subcategoryId'),
      point: point,
      facts: ActivityCatalogFacts(
        durationMinMinutes: min,
        durationMaxMinutes: max,
        suggestedGroupMin: group == null ? null : _int(group, 'min'),
        suggestedGroupMax: group == null ? null : _int(group, 'max'),
        fullDescription: _optionalString(map, 'fullDescription') ?? '',
        addressLine: _optionalString(map, 'addressLine') ?? '',
        accessNotes: _optionalString(map, 'accessNotes') ?? '',
        isInformal: caution['isInformal'] == true,
        cautionNote: _optionalString(caution, 'note') ?? '',
        timeOfDay: time,
        season: season,
        contributionKind: contribution == null
            ? null
            : _string(contribution, 'kind'),
        contributionNote: contribution == null
            ? null
            : _string(contribution, 'note'),
        amountMinor: amount == null ? null : _int(amount, 'amountMinor'),
        currencyCode: amount == null ? null : _string(amount, 'currencyCode'),
        galleryMediaIds: gallery,
        linkedPlaceId: map['linkedPlace'] == null ? null : _string(_map(map['linkedPlace'], 'linkedPlace'), 'contentId'),
        linkedPlaceTitle: map['linkedPlace'] == null ? null : _string(_map(map['linkedPlace'], 'linkedPlace'), 'title'),
      ),
    );
  }
  final String contentId,
      publishedRevisionId,
      title,
      shortDescription,
      categoryId,
      subcategoryId;
  final CatalogPoint point;
  final ActivityCatalogFacts facts;
}

/// `listed` carries the item; `excluded`/`absent` never do.
final class CatalogDetails {
  const CatalogDetails({
    required this.state,
    required this.reason,
    required this.item,
    required this.changedSinceSnapshot,
    this.activity,
  });

  factory CatalogDetails.fromWire(Object? value) {
    final Map<String, Object?> map = _map(value, 'details');
    final String state = _string(map, 'state');
    if (state != 'listed' && state != 'excluded' && state != 'absent') {
      throw FormatException('catalog.details.state $state');
    }
    if (state == 'listed' &&
        !<String>[
          'event',
          'activity',
        ].contains(_map(map['item'], 'item')['typeId'])) {
      throw const FormatException('catalog.details.typeId');
    }
    final Object? changed = map['changedSinceSnapshot'];
    if (changed is! bool) {
      throw const FormatException('catalog.details.changedSinceSnapshot');
    }
    return CatalogDetails(
      state: state,
      reason: _optionalString(map, 'reason'),
      item: state == 'listed' && _map(map['item'], 'item')['typeId'] == 'event'
          ? CatalogEventItem.fromWire(map['item'])
          : null,
      activity:
          state == 'listed' && _map(map['item'], 'item')['typeId'] == 'activity'
          ? CatalogActivityItem.fromWire(map['item'])
          : null,
      changedSinceSnapshot: changed,
    );
  }

  final String state;
  final String? reason;
  final CatalogEventItem? item;
  final CatalogActivityItem? activity;
  final bool changedSinceSnapshot;
}

/// The envelope: `succeeded` with exactly one body, or a typed refusal.
final class CatalogAnswer {
  const CatalogAnswer._({required this.kind, this.code, this.body});

  factory CatalogAnswer.fromWire(Map<String, Object?> map) {
    if (map['schemaVersion'] != 1) {
      throw const FormatException('catalog.schemaVersion must be 1');
    }
    final String kind = _string(map, 'kind');
    if (kind == 'succeeded') {
      final Object? body = map['page'] ?? map['map'] ?? map['details'];
      if (body == null) {
        throw const FormatException('catalog: a success needs a body');
      }
      return CatalogAnswer._(kind: kind, body: body);
    }
    return CatalogAnswer._(kind: kind, code: _string(map, 'code'));
  }

  final String kind;
  final String? code;
  final Object? body;

  bool get succeeded => kind == 'succeeded';
}
