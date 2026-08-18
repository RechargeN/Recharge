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
        'object_kind': 'event',
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
        'address_line': 'Brivibas bulvaris 23, Riga',
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
        'object_kind': 'event',
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
        'address_line': 'Kalku iela 11, Riga',
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
        'object_kind': 'route',
        'category': 'outdoor_nature_walking',
        'subcategory': 'lake_walk',
        'price_amount': 0.0,
        'is_free': true,
        'cover_image_url':
            'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee'
            '?auto=format&fit=crop&w=1200&q=80',
        'organizer_name': 'Riga Walks',
        'organizer_handle': '@rezekne_walks',
        'venue_name': 'Lake Trail Start',
        'address_line': 'Kisezera taka, Riga',
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
        'object_kind': 'event',
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
        'address_line': 'Pils iela 4, Riga',
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
        'object_kind': 'event',
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
        'address_line': 'Esplanade, Riga',
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
        'object_kind': 'route',
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
        'address_line': 'Bastejkalna taka, Riga',
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
      <String, Object?>{
        'title': 'Latvian National Library',
        'subtitle': 'Architecture, reading rooms and city views',
        'city': 'Riga',
        'object_kind': 'place',
        'category': 'art_culture_museums',
        'subcategory': 'libraries',
        'price_amount': 0.0,
        'is_free': true,
        'cover_image_url':
            'https://images.unsplash.com/photo-1521587760476-6c12a4b040da'
            '?auto=format&fit=crop&w=1200&q=80',
        'organizer_name': 'Recharge Places',
        'organizer_handle': '@recharge_places',
        'venue_name': 'Latvian National Library',
        'address_line': 'Mukusalas iela 3, Riga',
        'participants_count': 0,
        'capacity': 200,
        'duration_minutes': 90,
        'cta_label': 'Plan a visit',
        'highlights': <String>[
          'Public reading and exhibition spaces',
          'Daugava and Old Riga views',
          'Easy access by public transport',
        ],
      },
    ];

    final DateTime base = DateTime.now().toUtc();
    final List<Map<String, Object?>> result = <Map<String, Object?>>[];

    for (int i = 0; i < 60; i++) {
      final Map<String, Object?> template = seed[i % seed.length];
      final double lat = 56.9496 + ((i % 10) - 5) * 0.0075;
      final double lng = 24.1052 + ((i ~/ 10) - 3) * 0.0105;
      final DateTime startsAt = base.add(Duration(hours: i % 48));
      final int durationMinutes = template['duration_minutes']! as int;
      final bool usesOpeningHours = i.isOdd;
      result.add(<String, Object?>{
        'id': 'evt_rig_${i.toString().padLeft(3, '0')}',
        'title': template['title'],
        'subtitle': template['subtitle'],
        'city': 'Riga',
        'category': template['category'],
        'subcategory': template['subcategory'],
        'starts_at_utc': startsAt.toIso8601String(),
        'latitude': lat,
        'longitude': lng,
        'price_amount': template['price_amount'],
        'distance_km': 0.0,
        'is_free': template['is_free'],
        'object_kind': template['object_kind'],
        'relevance_score': 0.0,
        'cover_image_url': template['cover_image_url'],
        'organizer_name': template['organizer_name'],
        'organizer_handle': template['organizer_handle'],
        'venue_name': template['venue_name'],
        'address_line': template['address_line'],
        'participants_count':
            (template['participants_count']! as int) + (i % 5),
        'capacity': template['capacity'],
        'duration_minutes': durationMinutes,
        'duration_confidence': 'exact',
        'market_city_id': 'riga',
        'timezone_id': 'Europe/Riga',
        'availability_kind': usesOpeningHours ? 'openingHours' : 'eventSlots',
        'schedule_slots': usesOpeningHours
            ? const <Map<String, Object?>>[]
            : <Map<String, Object?>>[
                <String, Object?>{
                  'slot_id':
                      '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
                  'start_at_utc': startsAt.toIso8601String(),
                  'end_at_utc': startsAt
                      .add(Duration(minutes: durationMinutes))
                      .toIso8601String(),
                },
              ],
        'opening_hours': usesOpeningHours
            ? <Map<String, Object?>>[
                for (final String day in <String>[
                  'monday',
                  'tuesday',
                  'wednesday',
                  'thursday',
                  'friday',
                  'saturday',
                  'sunday',
                ])
                  <String, Object?>{
                    'day_of_week': day,
                    'is_closed_all_day': false,
                    'open_minutes': 8 * 60,
                    'close_minutes': 23 * 60,
                  },
              ]
            : const <Map<String, Object?>>[],
        'allows_partial_attendance': true,
        'minimum_visit_duration_minutes': 30,
        'buffer_before_minutes': usesOpeningHours ? 0 : 10,
        'buffer_after_minutes': usesOpeningHours ? 0 : 10,
        'cta_label': template['cta_label'],
        'highlights': template['highlights'],
      });
    }

    // Recharge Activity (ACT-CRT-01, spec AC #7): self-directed, evergreen,
    // no Booking — unlike the event/place templates cycled above, it must
    // NOT get an eventSlots/openingHours availability_kind or a real
    // starts_at_utc. starts_at_utc mirrors DiscoverRepositoryImpl._routeItem's
    // technique for the same non-nullable-but-semantically-inapplicable
    // field on another date-less object type: a fixed technical timestamp,
    // not a real start time.
    result.add(<String, Object?>{
      'id': 'mock-activity-coffee-walk',
      'title': 'Coffee walk by the canal',
      'subtitle': 'Casual self-guided stroll, drop in anytime',
      'city': 'Riga',
      'category': 'wellness_recharge',
      'subcategory': 'recharge_walk',
      'starts_at_utc': base.toIso8601String(),
      'latitude': 56.9496,
      'longitude': 24.1052,
      'price_amount': 0.0,
      'distance_km': 0.0,
      'is_free': true,
      'object_kind': 'activity',
      'relevance_score': 0.0,
      'cover_image_url':
          'https://images.unsplash.com/photo-1447933601403-0c6688de566e'
          '?auto=format&fit=crop&w=1200&q=80',
      'organizer_name': 'Recharge Wellness',
      'organizer_handle': '@recharge_wellness',
      'venue_name': 'Canal embankment',
      'address_line': 'Along the City Canal, Riga',
      'market_city_id': 'riga',
      'timezone_id': 'Europe/Riga',
      'duration_minutes': 45,
      'duration_confidence': 'estimated',
      'availability_kind': 'none',
      'schedule_slots': const <Map<String, Object?>>[],
      'opening_hours': const <Map<String, Object?>>[],
      'allows_partial_attendance': false,
      'cta_label': 'View activity',
      'highlights': const <String>[
        'No sign-up, no fixed time',
        'Easy access from the Old Town',
      ],
    });

    return result;
  }
}
