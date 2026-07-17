import '../../domain/repositories/discover_repository.dart';
import '../models/discover_item_model.dart';

abstract class DiscoverRemoteDataSource {
  Future<List<DiscoverItemModel>> getFeedCandidates();
  Future<DiscoverItemModel> getDetails(String itemId);
}

class MockDiscoverRemoteDataSource implements DiscoverRemoteDataSource {
  late final List<Map<String, Object?>> _mockFeedRaw = _buildMockFeed();

  @override
  Future<List<DiscoverItemModel>> getFeedCandidates() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _mockFeedRaw.map(DiscoverItemModel.fromMap).toList(growable: false);
  }

  @override
  Future<DiscoverItemModel> getDetails(String itemId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final Map<String, Object?> map = _mockFeedRaw.firstWhere(
      (Map<String, Object?> item) => item['id'] == itemId,
      orElse: () => throw const DiscoverException(
        code: 'DISCOVER_NOT_FOUND',
        message: 'Объект не найден',
      ),
    );
    return DiscoverItemModel.fromMap(map);
  }

  List<Map<String, Object?>> _buildMockFeed() {
    final List<Map<String, Object?>> seed = <Map<String, Object?>>[
      <String, Object?>{
        'title': 'Утренняя йога в парке',
        'subtitle': 'Легкая практика и дыхание',
        'city': 'Резекне',
        'category': 'wellness_recharge',
        'subcategory': 'yoga',
        'price_amount': 0.0,
        'is_free': true,
        'cover_image_url':
            'https://images.unsplash.com/photo-1506126613408-eca07ce68773'
            '?auto=format&fit=crop&w=1200&q=80',
        'organizer_name': 'Recharge Wellness',
        'organizer_handle': '@recharge_wellness',
        'venue_name': 'Central Park Lawn',
        'address_line': 'Atbrivosanas aleja 93, Rezekne',
        'participants_count': 18,
        'capacity': 32,
        'duration_minutes': 75,
        'cta_label': 'Join session',
        'highlights': <String>[
          'Beginner-friendly breathing practice',
          'Bring a mat or towel',
          'Small group with a local instructor',
        ],
      },
      <String, Object?>{
        'title': 'Кофе и арт-скетч',
        'subtitle': 'Небольшая группа и локальные авторы',
        'city': 'Резекне',
        'category': 'art_culture_museums',
        'subcategory': 'creative_meetup',
        'price_amount': 8.0,
        'is_free': false,
        'cover_image_url':
            'https://images.unsplash.com/photo-1513364776144-60967b0f800f'
            '?auto=format&fit=crop&w=1200&q=80',
        'organizer_name': 'Local Sketch Club',
        'organizer_handle': '@sketch_rezekne',
        'venue_name': 'Mols Coffee Studio',
        'address_line': 'Latgales iela 21, Rezekne',
        'participants_count': 9,
        'capacity': 14,
        'duration_minutes': 120,
        'cta_label': 'Reserve spot',
        'highlights': <String>[
          'Coffee included in the ticket',
          'All sketch materials provided',
          'Meet local artists and travelers',
        ],
      },
      <String, Object?>{
        'title': 'Прогулка у озера',
        'subtitle': 'Маршрут 5 км без спешки',
        'city': 'Резекне',
        'category': 'outdoor_nature_walking',
        'subcategory': 'lake_walk',
        'price_amount': 0.0,
        'is_free': true,
        'cover_image_url':
            'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee'
            '?auto=format&fit=crop&w=1200&q=80',
        'organizer_name': 'Rezekne Walks',
        'organizer_handle': '@rezekne_walks',
        'venue_name': 'Lake Trail Start',
        'address_line': 'Ezermalas taka, Rezekne',
        'participants_count': 24,
        'capacity': 40,
        'duration_minutes': 90,
        'cta_label': 'Start route',
        'highlights': <String>[
          'Easy 5 km walking route',
          'Photo stops by the water',
          'Works well for families and friends',
        ],
      },
      <String, Object?>{
        'title': 'Вечерняя музыка',
        'subtitle': 'Локальные исполнители',
        'city': 'Резекне',
        'category': 'music_nightlife',
        'subcategory': 'live_music',
        'price_amount': 12.0,
        'is_free': false,
        'cover_image_url':
            'https://images.unsplash.com/photo-1501386761578-eac5c94b800a'
            '?auto=format&fit=crop&w=1200&q=80',
        'organizer_name': 'Evenbrite Local',
        'organizer_handle': '@evenbrite_local',
        'venue_name': 'Old Town Stage',
        'address_line': 'Pils iela 4, Rezekne',
        'participants_count': 46,
        'capacity': 80,
        'duration_minutes': 150,
        'cta_label': 'Book ticket',
        'highlights': <String>[
          'Two local performers',
          'Standing and seated areas',
          'Nearby cafes open after the show',
        ],
      },
      <String, Object?>{
        'title': 'Семейный пикник',
        'subtitle': 'Активности для друзей и семьи',
        'city': 'Резекне',
        'category': 'family_kids',
        'subcategory': 'family_picnic',
        'price_amount': 5.0,
        'is_free': false,
        'cover_image_url':
            'https://images.unsplash.com/photo-1507525428034-b723cf961d3e'
            '?auto=format&fit=crop&w=1200&q=80',
        'organizer_name': 'Family Recharge',
        'organizer_handle': '@family_recharge',
        'venue_name': 'Meadow Picnic Area',
        'address_line': 'Stacijas parks, Rezekne',
        'participants_count': 21,
        'capacity': 50,
        'duration_minutes': 180,
        'cta_label': 'Join picnic',
        'highlights': <String>[
          'Games for children and adults',
          'Picnic blankets available',
          'Light snacks included',
        ],
      },
      <String, Object?>{
        'title': 'Наблюдение за закатом',
        'subtitle': 'Красивые точки рядом с городом',
        'city': 'Резекне',
        'category': 'outdoor_nature_walking',
        'subcategory': 'sunset_walk',
        'price_amount': 0.0,
        'is_free': true,
        'cover_image_url':
            'https://images.unsplash.com/photo-1500534314209-a25ddb2bd429'
            '?auto=format&fit=crop&w=1200&q=80',
        'organizer_name': 'Sunset Routes',
        'organizer_handle': '@sunset_routes',
        'venue_name': 'Hill Viewpoint',
        'address_line': 'Pilskalna taka, Rezekne',
        'participants_count': 16,
        'capacity': 28,
        'duration_minutes': 60,
        'cta_label': 'Save route',
        'highlights': <String>[
          'Best viewpoint near the city',
          'Short walk from public transport',
          'Ideal for photos and quiet time',
        ],
      },
    ];

    final DateTime base = DateTime.now().toUtc();
    final List<Map<String, Object?>> result = <Map<String, Object?>>[];

    for (int i = 0; i < 60; i++) {
      final Map<String, Object?> template = seed[i % seed.length];
      final double lat = 56.5099 + ((i % 10) - 5) * 0.0075;
      final double lng = 27.3332 + ((i ~/ 10) - 3) * 0.0105;
      result.add(<String, Object?>{
        'id': 'evt_rez_${i.toString().padLeft(3, '0')}',
        'title': template['title'],
        'subtitle': template['subtitle'],
        'city': template['city'],
        'category': template['category'],
        'starts_at_utc': base.add(Duration(hours: i % 48)).toIso8601String(),
        'latitude': lat,
        'longitude': lng,
        'price_amount': template['price_amount'],
        'distance_km': 0.0,
        'is_free': template['is_free'],
        'relevance_score': 0.0,
        'cover_image_url': template['cover_image_url'],
        'organizer_name': template['organizer_name'],
        'organizer_handle': template['organizer_handle'],
        'venue_name': template['venue_name'],
        'address_line': template['address_line'],
        'participants_count':
            (template['participants_count']! as int) + (i % 5),
        'capacity': template['capacity'],
        'duration_minutes': template['duration_minutes'],
        'cta_label': template['cta_label'],
        'highlights': template['highlights'],
      });
    }
    return result;
  }
}
