enum FavoritePlanningTargetKind { quickPlan, scenario, route }

class FavoriteItemEntity {
  const FavoriteItemEntity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.city,
    required this.category,
    required this.startsAtUtc,
    required this.distanceKm,
    required this.priceAmount,
    required this.isFree,
    required this.savedAtUtc,
    required this.targetRoute,
    this.planningTargetKind,
    this.planningTargetId,
    this.coverImageUrl = '',
  });

  final String id;
  final String title;
  final String subtitle;
  final String city;
  final String category;
  final DateTime startsAtUtc;
  final double distanceKm;
  final double priceAmount;
  final bool isFree;
  final DateTime savedAtUtc;
  final String? targetRoute;
  final FavoritePlanningTargetKind? planningTargetKind;
  final String? planningTargetId;
  final String coverImageUrl;

  FavoriteItemEntity copyWith({
    DateTime? savedAtUtc,
    String? targetRoute,
    String? coverImageUrl,
    FavoritePlanningTargetKind? planningTargetKind,
    String? planningTargetId,
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
      priceAmount: priceAmount,
      isFree: isFree,
      savedAtUtc: savedAtUtc ?? this.savedAtUtc,
      targetRoute: clearTargetRoute ? null : (targetRoute ?? this.targetRoute),
      planningTargetKind: planningTargetKind ?? this.planningTargetKind,
      planningTargetId: planningTargetId ?? this.planningTargetId,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
    );
  }
}
