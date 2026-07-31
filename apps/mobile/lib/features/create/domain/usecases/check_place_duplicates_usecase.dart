import 'dart:math' as math;

import '../entities/create_draft_entity.dart';
import '../entities/place_duplicate_candidate.dart';

class CheckPlaceDuplicatesUseCase {
  const CheckPlaceDuplicatesUseCase({
    this.candidates = const <PlaceDuplicateCandidate>[],
    this.radiusMeters = 100,
  });

  final List<PlaceDuplicateCandidate> candidates;
  final double radiusMeters;

  List<PlaceDuplicateMatch> call(CreateDraftEntity draft) {
    final double? latitude = draft.placeData?.location.latitude;
    final double? longitude = draft.placeData?.location.longitude;
    if (latitude == null || longitude == null) {
      return const <PlaceDuplicateMatch>[];
    }
    final String normalizedTitle = _normalize(draft.title);
    final String? draftDomain = _domain(draft.placeData?.contacts.websiteUrl);
    final String draftPhone = _phone(draft.placeData?.contacts.phone);
    final List<PlaceDuplicateMatch> matches = <PlaceDuplicateMatch>[];
    for (final PlaceDuplicateCandidate candidate in candidates) {
      final double distance = _distanceMeters(
        latitude,
        longitude,
        candidate.latitude,
        candidate.longitude,
      );
      final List<String> reasons = <String>[];
      final String candidateTitle = _normalize(candidate.title);
      final bool strongTitle =
          normalizedTitle.isNotEmpty &&
          (normalizedTitle == candidateTitle ||
              normalizedTitle.contains(candidateTitle) ||
              candidateTitle.contains(normalizedTitle));
      if (strongTitle) reasons.add('title_match');
      if (candidate.categoryId == draft.mainCategory) {
        reasons.add('category_match');
      }
      if (draftDomain != null && draftDomain == candidate.officialDomain) {
        reasons.add('official_domain_match');
      }
      if (draftPhone.isNotEmpty && draftPhone == _phone(candidate.phone)) {
        reasons.add('phone_match');
      }
      final bool highIdentityRisk =
          reasons.contains('official_domain_match') ||
          reasons.contains('phone_match');
      final bool nearbyTitleRisk = distance <= radiusMeters && strongTitle;
      if (highIdentityRisk || nearbyTitleRisk) {
        matches.add(
          PlaceDuplicateMatch(
            candidate: candidate,
            distanceMeters: distance,
            reasons: List<String>.unmodifiable(reasons),
          ),
        );
      }
    }
    matches.sort(
      (PlaceDuplicateMatch a, PlaceDuplicateMatch b) =>
          a.distanceMeters.compareTo(b.distanceMeters),
    );
    return matches;
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u00c0-\u024f\u0400-\u04ff]+'), ' ')
      .trim();

  static String _phone(String? value) =>
      value?.replaceAll(RegExp(r'\D'), '') ?? '';

  static String? _domain(String? value) {
    if (value == null) return null;
    return Uri.tryParse(value)?.host.toLowerCase().replaceFirst('www.', '');
  }

  static double _distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusMeters = 6371000;
    final double latDelta = _radians(lat2 - lat1);
    final double lonDelta = _radians(lon2 - lon1);
    final double a =
        math.sin(latDelta / 2) * math.sin(latDelta / 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.sin(lonDelta / 2) *
            math.sin(lonDelta / 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}
