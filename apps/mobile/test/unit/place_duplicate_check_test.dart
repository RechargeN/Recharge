import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/place_draft_data.dart';
import 'package:recharge/features/create/domain/entities/place_duplicate_candidate.dart';
import 'package:recharge/features/create/domain/usecases/check_place_duplicates_usecase.dart';

void main() {
  test('returns a nearby strong title match inside policy radius', () {
    const CheckPlaceDuplicatesUseCase check = CheckPlaceDuplicatesUseCase(
      candidates: <PlaceDuplicateCandidate>[
        PlaceDuplicateCandidate(
          placeId: 'existing-1',
          title: 'Riga Central Market',
          categoryId: 'food_drinks',
          latitude: 56.9437,
          longitude: 24.1147,
        ),
      ],
    );
    final CreateDraftEntity draft = _draft(
      title: 'Riga Central Market',
      latitude: 56.94375,
      longitude: 24.11475,
    );

    final List<PlaceDuplicateMatch> matches = check(draft);

    expect(matches, hasLength(1));
    expect(matches.single.distanceMeters, lessThan(100));
    expect(matches.single.reasons, contains('title_match'));
  });

  test('official domain is high risk even outside 100 meters', () {
    const CheckPlaceDuplicatesUseCase check = CheckPlaceDuplicatesUseCase(
      candidates: <PlaceDuplicateCandidate>[
        PlaceDuplicateCandidate(
          placeId: 'existing-1',
          title: 'Different display title',
          categoryId: 'food_drinks',
          latitude: 56.90,
          longitude: 24.20,
          officialDomain: 'example.lv',
        ),
      ],
    );
    final CreateDraftEntity draft = _draft(
      title: 'New title',
      latitude: 56.95,
      longitude: 24.11,
      websiteUrl: 'https://www.example.lv/visit',
    );

    expect(check(draft).single.reasons, contains('official_domain_match'));
  });
}

CreateDraftEntity _draft({
  required String title,
  required double latitude,
  required double longitude,
  String? websiteUrl,
}) {
  final CreateDraftEntity common = CreateDraftEntity.defaults(
    organizerId: 'user-1',
    organizerEmail: 'creator@example.test',
    organizerName: 'Creator',
    marketCityId: 'riga',
    timezone: 'Europe/Riga',
    country: 'LV',
    city: 'Riga',
    currency: 'EUR',
  );
  final PlaceDraftData place =
      PlaceDraftData.defaults(
        userId: 'user-1',
        marketCityId: 'riga',
        countryCode: 'LV',
        city: 'Riga',
        timezoneId: 'Europe/Riga',
        currencyCode: 'EUR',
      ).copyWith(
        location: PlaceDraftData.defaults(
          userId: 'user-1',
          marketCityId: 'riga',
          countryCode: 'LV',
          city: 'Riga',
          timezoneId: 'Europe/Riga',
          currencyCode: 'EUR',
        ).location.copyWith(latitude: latitude, longitude: longitude),
        contacts: PlaceContactsDraft(websiteUrl: websiteUrl),
      );
  return common.copyWith(
    objectType: CreateObjectType.place,
    title: title,
    mainCategory: 'food_drinks',
    placeData: place,
  );
}
