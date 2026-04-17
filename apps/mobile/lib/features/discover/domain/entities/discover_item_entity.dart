class DiscoverItemEntity {
  const DiscoverItemEntity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.city,
    required this.category,
    required this.startsAtUtc,
    required this.distanceKm,
    required this.isFree,
  });

  final String id;
  final String title;
  final String subtitle;
  final String city;
  final String category;
  final DateTime startsAtUtc;
  final double distanceKm;
  final bool isFree;
}

