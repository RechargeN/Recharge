import '../../domain/entities/favorite_item_entity.dart';

class FavoriteItemModel {
  const FavoriteItemModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.city,
    required this.category,
    required this.startsAtUtcIso,
    required this.distanceKm,
    required this.priceAmount,
    required this.isFree,
    required this.savedAtUtcIso,
  });

  final String id;
  final String title;
  final String subtitle;
  final String city;
  final String category;
  final String startsAtUtcIso;
  final double distanceKm;
  final double priceAmount;
  final bool isFree;
  final String savedAtUtcIso;

  factory FavoriteItemModel.fromJson(Map<String, dynamic> json) {
    return FavoriteItemModel(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      city: json['city'] as String,
      category: json['category'] as String,
      startsAtUtcIso: json['startsAtUtcIso'] as String,
      distanceKm: (json['distanceKm'] as num).toDouble(),
      priceAmount: (json['priceAmount'] as num).toDouble(),
      isFree: json['isFree'] as bool,
      savedAtUtcIso: json['savedAtUtcIso'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'city': city,
      'category': category,
      'startsAtUtcIso': startsAtUtcIso,
      'distanceKm': distanceKm,
      'priceAmount': priceAmount,
      'isFree': isFree,
      'savedAtUtcIso': savedAtUtcIso,
    };
  }

  factory FavoriteItemModel.fromEntity(FavoriteItemEntity entity) {
    return FavoriteItemModel(
      id: entity.id,
      title: entity.title,
      subtitle: entity.subtitle,
      city: entity.city,
      category: entity.category,
      startsAtUtcIso: entity.startsAtUtc.toUtc().toIso8601String(),
      distanceKm: entity.distanceKm,
      priceAmount: entity.priceAmount,
      isFree: entity.isFree,
      savedAtUtcIso: entity.savedAtUtc.toUtc().toIso8601String(),
    );
  }

  FavoriteItemEntity toEntity() {
    return FavoriteItemEntity(
      id: id,
      title: title,
      subtitle: subtitle,
      city: city,
      category: category,
      startsAtUtc: DateTime.parse(startsAtUtcIso).toUtc(),
      distanceKm: distanceKm,
      priceAmount: priceAmount,
      isFree: isFree,
      savedAtUtc: DateTime.parse(savedAtUtcIso).toUtc(),
    );
  }
}
