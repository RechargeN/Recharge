class PlaceDuplicateCandidate {
  const PlaceDuplicateCandidate({
    required this.placeId,
    required this.title,
    required this.categoryId,
    required this.latitude,
    required this.longitude,
    this.officialDomain,
    this.phone,
  });

  final String placeId;
  final String title;
  final String categoryId;
  final double latitude;
  final double longitude;
  final String? officialDomain;
  final String? phone;
}

class PlaceDuplicateMatch {
  const PlaceDuplicateMatch({
    required this.candidate,
    required this.distanceMeters,
    required this.reasons,
  });

  final PlaceDuplicateCandidate candidate;
  final double distanceMeters;
  final List<String> reasons;
}
