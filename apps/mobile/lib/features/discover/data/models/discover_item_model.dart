import '../../domain/entities/discover_item_entity.dart';

class DiscoverItemModel extends DiscoverItemEntity {
  const DiscoverItemModel({
    required super.id,
    required super.title,
    required super.subtitle,
    required super.city,
    required super.category,
    required super.startsAtUtc,
    required super.latitude,
    required super.longitude,
    required super.priceAmount,
    required super.distanceKm,
    required super.isFree,
    required super.relevanceScore,
  });

  factory DiscoverItemModel.fromMap(Map<String, Object?> map) {
    return DiscoverItemModel(
      id: map['id']! as String,
      title: map['title']! as String,
      subtitle: map['subtitle']! as String,
      city: map['city']! as String,
      category: map['category']! as String,
      startsAtUtc: DateTime.parse(map['starts_at_utc']! as String),
      latitude: (map['latitude']! as num).toDouble(),
      longitude: (map['longitude']! as num).toDouble(),
      priceAmount: (map['price_amount']! as num).toDouble(),
      distanceKm: (map['distance_km']! as num).toDouble(),
      isFree: map['is_free']! as bool,
      relevanceScore: (map['relevance_score'] as num?)?.toDouble() ?? 0,
    );
  }
}
