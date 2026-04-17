import '../../domain/repositories/discover_repository.dart';
import '../models/discover_item_model.dart';

abstract class DiscoverRemoteDataSource {
  Future<List<DiscoverItemModel>> getFeed();
  Future<DiscoverItemModel> getDetails(String itemId);
}

class MockDiscoverRemoteDataSource implements DiscoverRemoteDataSource {
  static const List<Map<String, Object?>> _mockFeedRaw =
      <Map<String, Object?>>[
    <String, Object?>{
      'id': 'evt_park_yoga_001',
      'title': 'Утренняя йога в парке',
      'subtitle': 'Легкая практика на свежем воздухе',
      'city': 'Москва',
      'category': 'wellness',
      'starts_at_utc': '2026-04-18T07:00:00Z',
      'distance_km': 1.2,
      'is_free': true,
    },
    <String, Object?>{
      'id': 'evt_art_meet_002',
      'title': 'Арт-встреча в лофте',
      'subtitle': 'Небольшая группа и локальные авторы',
      'city': 'Москва',
      'category': 'art',
      'starts_at_utc': '2026-04-18T16:30:00Z',
      'distance_km': 2.8,
      'is_free': false,
    },
    <String, Object?>{
      'id': 'evt_lake_walk_003',
      'title': 'Вечерняя прогулка у воды',
      'subtitle': 'Маршрут без спешки, 5 км',
      'city': 'Москва',
      'category': 'outdoor',
      'starts_at_utc': '2026-04-18T18:00:00Z',
      'distance_km': 4.6,
      'is_free': true,
    },
  ];

  @override
  Future<List<DiscoverItemModel>> getFeed() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _mockFeedRaw
        .map(DiscoverItemModel.fromMap)
        .toList(growable: false);
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
}

