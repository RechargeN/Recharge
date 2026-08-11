import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/data/models/discover_item_model.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/shared/primitives/money/money.dart';

void main() {
  test('fromMap parses details v2 fields', () {
    final DiscoverItemModel item = DiscoverItemModel.fromMap(<String, Object?>{
      'id': 'evt_1',
      'title': 'Sunset Tennis Meetup',
      'subtitle': 'Friendly tennis at sunset',
      'city': 'Dubai',
      'category': 'outdoor',
      'starts_at_utc': '2026-06-21T18:00:00Z',
      'latitude': 25.2048,
      'longitude': 55.2708,
      'price_amount': 0.0,
      'distance_km': 1.4,
      'is_free': true,
      'object_kind': 'place',
      'relevance_score': 0.9,
      'cover_image_url': 'https://example.com/cover.jpg',
      'organizer_name': 'Marine Tennis Club',
      'organizer_handle': '@marinetennis',
      'venue_name': 'Marine Tennis Club',
      'address_line': 'Dubai Marina',
      'participants_count': 32,
      'capacity': 48,
      'duration_minutes': 150,
      'cta_label': 'Join meetup',
      'highlights': <String>['Warm-up games', 'Friendly tournament'],
    }, legacyCurrency: CurrencyCode.eur);

    expect(item.coverImageUrl, 'https://example.com/cover.jpg');
    expect(item.objectKind, DiscoverObjectKind.place);
    expect(item.organizerName, 'Marine Tennis Club');
    expect(item.participantsCount, 32);
    expect(item.capacity, 48);
    expect(item.durationMinutes, 150);
    expect(item.highlights, <String>['Warm-up games', 'Friendly tournament']);
  });

  test('copyWith preserves details v2 fields', () {
    final DiscoverItemModel item = DiscoverItemModel.fromMap(<String, Object?>{
      'id': 'evt_1',
      'title': 'Sunset Tennis Meetup',
      'subtitle': 'Friendly tennis at sunset',
      'city': 'Dubai',
      'category': 'outdoor',
      'starts_at_utc': '2026-06-21T18:00:00Z',
      'latitude': 25.2048,
      'longitude': 55.2708,
      'price_amount': 0.0,
      'distance_km': 1.4,
      'is_free': true,
      'object_kind': 'event',
      'relevance_score': 0.9,
      'organizer_name': 'Marine Tennis Club',
      'participants_count': 32,
      'highlights': <String>['Warm-up games'],
    }, legacyCurrency: CurrencyCode.eur);

    final copy = item.copyWith(distanceKm: 2.0, relevanceScore: 0.7);

    expect(copy.distanceKm, 2.0);
    expect(copy.relevanceScore, 0.7);
    expect(copy.organizerName, 'Marine Tennis Club');
    expect(copy.objectKind, DiscoverObjectKind.event);
    expect(copy.participantsCount, 32);
    expect(copy.highlights, <String>['Warm-up games']);
  });

  test(
    'legacy zero values normalize without losing explicit participants zero',
    () {
      DiscoverItemModel parse(Map<String, Object?> values) =>
          DiscoverItemModel.fromMap(<String, Object?>{
            'id': 'evt_legacy',
            'title': 'Legacy',
            'subtitle': 'Legacy item',
            'city': 'Riga',
            'category': 'other',
            'starts_at_utc': '2026-07-20T10:00:00Z',
            'latitude': 56.9496,
            'longitude': 24.1052,
            'price_amount': 0.0,
            'distance_km': 0.0,
            'is_free': true,
            ...values,
          }, legacyCurrency: CurrencyCode.eur);

      final DiscoverItemModel explicitZero = parse(<String, Object?>{
        'duration_minutes': 0,
        'capacity': 0,
        'participants_count': 0,
      });
      final DiscoverItemModel absent = parse(const <String, Object?>{});

      expect(explicitZero.durationMinutes, isNull);
      expect(explicitZero.capacity, isNull);
      expect(explicitZero.participantsCount, 0);
      expect(absent.participantsCount, isNull);
      expect(absent.objectKind, DiscoverObjectKind.activity);
    },
  );

  test('canonical price is exact and fractional minor units fail closed', () {
    final Map<String, Object?> map = <String, Object?>{
      'id': 'evt_money',
      'title': 'Money fixture',
      'subtitle': 'Canonical',
      'city': 'Riga',
      'category': 'other',
      'starts_at_utc': '2026-07-20T10:00:00Z',
      'latitude': 56.9496,
      'longitude': 24.1052,
      'price_minor_units': 1234,
      'currency_code': 'EUR',
      'distance_km': 1.0,
      'is_free': false,
    };

    expect(
      DiscoverItemModel.fromMap(map, legacyCurrency: CurrencyCode.usd).price,
      const Money(minorUnits: 1234, currency: CurrencyCode.eur),
    );
    expect(
      () => DiscoverItemModel.fromMap(<String, Object?>{
        ...map,
        'price_minor_units': 12.5,
      }, legacyCurrency: CurrencyCode.eur),
      throwsFormatException,
    );
  });
}
