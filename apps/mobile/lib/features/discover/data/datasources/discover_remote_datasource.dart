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

  List<Map<String, Object?>> _buildMockFeed() {
    final List<Map<String, Object?>> seed = <Map<String, Object?>>[
      <String, Object?>{
        'title': 'Утренняя йога в парке',
        'subtitle': 'Легкая практика и дыхание',
        'city': 'Резекне',
        'category': 'wellness',
        'price_amount': 0.0,
        'is_free': true,
      },
      <String, Object?>{
        'title': 'Кофе и арт-скетч',
        'subtitle': 'Небольшая группа и локальные авторы',
        'city': 'Резекне',
        'category': 'art',
        'price_amount': 8.0,
        'is_free': false,
      },
      <String, Object?>{
        'title': 'Прогулка у озера',
        'subtitle': 'Маршрут 5 км без спешки',
        'city': 'Резекне',
        'category': 'outdoor',
        'price_amount': 0.0,
        'is_free': true,
      },
      <String, Object?>{
        'title': 'Вечерняя музыка',
        'subtitle': 'Локальные исполнители',
        'city': 'Резекне',
        'category': 'music',
        'price_amount': 12.0,
        'is_free': false,
      },
      <String, Object?>{
        'title': 'Семейный пикник',
        'subtitle': 'Активности для друзей и семьи',
        'city': 'Резекне',
        'category': 'family',
        'price_amount': 5.0,
        'is_free': false,
      },
      <String, Object?>{
        'title': 'Наблюдение за закатом',
        'subtitle': 'Красивые точки рядом с городом',
        'city': 'Резекне',
        'category': 'outdoor',
        'price_amount': 0.0,
        'is_free': true,
      },
    ];

    final DateTime base = DateTime.now().toUtc();
    final List<Map<String, Object?>> result = <Map<String, Object?>>[];

    for (int i = 0; i < 60; i++) {
      final Map<String, Object?> template = seed[i % seed.length];
      final double lat = 56.5099 + ((i % 10) - 5) * 0.0075;
      final double lng = 27.3332 + ((i ~/ 10) - 3) * 0.0105;
      result.add(
        <String, Object?>{
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
        },
      );
    }
    return result;
  }
}

