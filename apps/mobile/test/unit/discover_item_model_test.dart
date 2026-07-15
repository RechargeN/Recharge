import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/data/models/discover_item_model.dart';

void main() {
  test('fromMap parses details v2 fields', () {
    final DiscoverItemModel item = DiscoverItemModel.fromMap(
      <String, Object?>{
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
        'highlights': <String>[
          'Warm-up games',
          'Friendly tournament',
        ],
      },
    );

    expect(item.coverImageUrl, 'https://example.com/cover.jpg');
    expect(item.organizerName, 'Marine Tennis Club');
    expect(item.participantsCount, 32);
    expect(item.capacity, 48);
    expect(item.durationMinutes, 150);
    expect(item.highlights, <String>['Warm-up games', 'Friendly tournament']);
  });

  test('copyWith preserves details v2 fields', () {
    final DiscoverItemModel item = DiscoverItemModel.fromMap(
      <String, Object?>{
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
        'relevance_score': 0.9,
        'organizer_name': 'Marine Tennis Club',
        'participants_count': 32,
        'highlights': <String>['Warm-up games'],
      },
    );

    final copy = item.copyWith(distanceKm: 2.0, relevanceScore: 0.7);

    expect(copy.distanceKm, 2.0);
    expect(copy.relevanceScore, 0.7);
    expect(copy.organizerName, 'Marine Tennis Club');
    expect(copy.participantsCount, 32);
    expect(copy.highlights, <String>['Warm-up games']);
  });
}
