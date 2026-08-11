import '../../../../shared/primitives/money/money.dart';

class FavoriteItemEntity {
  const FavoriteItemEntity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.city,
    required this.category,
    required this.startsAtUtc,
    required this.distanceKm,
    required this.price,
    required this.isFree,
    required this.savedAtUtc,
    required this.targetRoute,
    this.coverImageUrl = '',
  });

  final String id;
  final String title;
  final String subtitle;
  final String city;
  final String category;
  final DateTime startsAtUtc;
  final double distanceKm;
  final Money price;
  final bool isFree;
  final DateTime savedAtUtc;
  final String? targetRoute;
  final String coverImageUrl;

  FavoriteItemEntity copyWith({
    DateTime? savedAtUtc,
    String? targetRoute,
    String? coverImageUrl,
    bool clearTargetRoute = false,
  }) {
    return FavoriteItemEntity(
      id: id,
      title: title,
      subtitle: subtitle,
      city: city,
      category: category,
      startsAtUtc: startsAtUtc,
      distanceKm: distanceKm,
      price: price,
      isFree: isFree,
      savedAtUtc: savedAtUtc ?? this.savedAtUtc,
      targetRoute: clearTargetRoute ? null : (targetRoute ?? this.targetRoute),
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
    );
  }
}
