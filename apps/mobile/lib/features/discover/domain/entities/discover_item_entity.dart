class DiscoverItemEntity {
  const DiscoverItemEntity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.city,
    required this.category,
    required this.startsAtUtc,
    required this.latitude,
    required this.longitude,
    required this.priceAmount,
    required this.distanceKm,
    required this.isFree,
    this.relevanceScore = 0,
  });

  final String id;
  final String title;
  final String subtitle;
  final String city;
  final String category;
  final DateTime startsAtUtc;
  final double latitude;
  final double longitude;
  final double priceAmount;
  final double distanceKm;
  final bool isFree;
  final double relevanceScore;

  DiscoverItemEntity copyWith({
    double? distanceKm,
    double? relevanceScore,
  }) {
    return DiscoverItemEntity(
      id: id,
      title: title,
      subtitle: subtitle,
      city: city,
      category: category,
      startsAtUtc: startsAtUtc,
      latitude: latitude,
      longitude: longitude,
      priceAmount: priceAmount,
      distanceKm: distanceKm ?? this.distanceKm,
      isFree: isFree,
      relevanceScore: relevanceScore ?? this.relevanceScore,
    );
  }
}
