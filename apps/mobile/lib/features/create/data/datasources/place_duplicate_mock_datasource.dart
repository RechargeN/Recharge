import '../../domain/entities/place_duplicate_candidate.dart';

const List<PlaceDuplicateCandidate> mockPlaceDuplicateCandidates =
    <PlaceDuplicateCandidate>[
      PlaceDuplicateCandidate(
        placeId: 'mock-riga-central-market',
        title: 'Riga Central Market',
        categoryId: 'food_drinks',
        latitude: 56.9437,
        longitude: 24.1147,
        officialDomain: 'rct.lv',
      ),
      PlaceDuplicateCandidate(
        placeId: 'mock-freedom-monument',
        title: 'Freedom Monument',
        categoryId: 'art_culture_museums',
        latitude: 56.9515,
        longitude: 24.1133,
      ),
    ];
