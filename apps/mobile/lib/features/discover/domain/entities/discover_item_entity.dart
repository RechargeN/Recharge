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
    this.coverImageUrl = '',
    this.organizerName = '',
    this.organizerHandle = '',
    this.venueName = '',
    this.addressLine = '',
    this.participantsCount = 0,
    this.capacity = 0,
    this.durationMinutes = 0,
    this.ctaLabel = '',
    this.highlights = const <String>[],
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
  final String coverImageUrl;
  final String organizerName;
  final String organizerHandle;
  final String venueName;
  final String addressLine;
  final int participantsCount;
  final int capacity;
  final int durationMinutes;
  final String ctaLabel;
  final List<String> highlights;

  DiscoverItemEntity copyWith({
    double? distanceKm,
    double? relevanceScore,
    String? coverImageUrl,
    String? organizerName,
    String? organizerHandle,
    String? venueName,
    String? addressLine,
    int? participantsCount,
    int? capacity,
    int? durationMinutes,
    String? ctaLabel,
    List<String>? highlights,
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
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      organizerName: organizerName ?? this.organizerName,
      organizerHandle: organizerHandle ?? this.organizerHandle,
      venueName: venueName ?? this.venueName,
      addressLine: addressLine ?? this.addressLine,
      participantsCount: participantsCount ?? this.participantsCount,
      capacity: capacity ?? this.capacity,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      ctaLabel: ctaLabel ?? this.ctaLabel,
      highlights: highlights ?? this.highlights,
    );
  }
}
