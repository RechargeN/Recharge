import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/place_create_config.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/place_creation_policy.dart';
import 'package:recharge/features/create/domain/entities/place_draft_data.dart';
import 'package:recharge/features/create/domain/entities/place_validation_issue.dart';
import 'package:recharge/features/create/domain/usecases/validate_place_draft_usecase.dart';
import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/shared/primitives/money/money.dart';

void main() {
  const ValidatePlaceDraftUseCase validate = ValidatePlaceDraftUseCase();

  test('accepts a complete always-open free place', () {
    final CreateDraftEntity draft = _validDraft();

    final List<PlaceValidationIssue> issues = validate(
      draft,
      supportedContentLocales: const <String>{'en', 'ru', 'lv'},
      activeMarketCityId: 'riga',
    );

    expect(
      issues.where(
        (PlaceValidationIssue issue) =>
            issue.severity == PlaceValidationSeverity.error,
      ),
      isEmpty,
    );
  });

  test('rejects implicit overnight and accepts explicit overnight', () {
    final PlaceDraftData base = _validDraft().placeData!;
    final LocalOpeningPeriod invalid = const LocalOpeningPeriod(
      id: 'loc_period',
      dayOfWeek: 5,
      openMinute: 22 * 60,
      closeMinute: 2 * 60,
      closesNextDay: false,
    );
    final CreateDraftEntity invalidDraft = _validDraft().copyWith(
      placeData: base.copyWith(
        hours: PlaceHoursDraft(
          mode: PlaceHoursMode.regular,
          weeklyPeriods: <LocalOpeningPeriod>[invalid],
        ),
      ),
    );

    final List<PlaceValidationIssue> invalidIssues = validate(
      invalidDraft,
      supportedContentLocales: const <String>{'en', 'ru', 'lv'},
      activeMarketCityId: 'riga',
    );
    expect(
      invalidIssues.map((PlaceValidationIssue issue) => issue.code),
      contains('hours_period_invalid'),
    );

    final CreateDraftEntity validDraft = invalidDraft.copyWith(
      placeData: invalidDraft.placeData!.copyWith(
        hours: PlaceHoursDraft(
          mode: PlaceHoursMode.regular,
          weeklyPeriods: <LocalOpeningPeriod>[
            invalid.copyWith().let(
              (LocalOpeningPeriod value) => LocalOpeningPeriod(
                id: value.id,
                dayOfWeek: value.dayOfWeek,
                openMinute: value.openMinute,
                closeMinute: value.closeMinute,
                closesNextDay: true,
              ),
            ),
          ],
        ),
      ),
    );
    final List<PlaceValidationIssue> validIssues = validate(
      validDraft,
      supportedContentLocales: const <String>{'en', 'ru', 'lv'},
      activeMarketCityId: 'riga',
    );
    expect(
      validIssues.map((PlaceValidationIssue issue) => issue.code),
      isNot(contains('hours_period_invalid')),
    );
  });

  test('paid and mixed entry require their normative fields', () {
    final CreateDraftEntity paid = _validDraft().copyWith(
      placeData: _validDraft().placeData!.copyWith(
        pricing: const PlacePricingDraft(
          currency: CurrencyCode.eur,
          entryType: PlaceEntryType.paid,
        ),
      ),
    );
    final List<String> paidCodes = validate(
      paid,
      supportedContentLocales: const <String>{'en', 'ru', 'lv'},
      activeMarketCityId: 'riga',
    ).map((PlaceValidationIssue issue) => issue.code).toList();
    expect(paidCodes, contains('entry_price_required'));

    final CreateDraftEntity mixed = paid.copyWith(
      placeData: paid.placeData!.copyWith(
        pricing: const PlacePricingDraft(
          currency: CurrencyCode.eur,
          entryType: PlaceEntryType.mixed,
          entryPriceFrom: Money(minorUnits: 500, currency: CurrencyCode.eur),
        ),
      ),
    );
    final List<String> mixedCodes = validate(
      mixed,
      supportedContentLocales: const <String>{'en', 'ru', 'lv'},
      activeMarketCityId: 'riga',
    ).map((PlaceValidationIssue issue) => issue.code).toList();
    expect(mixedCodes, contains('mixed_pricing_note_required'));
  });

  test('notApplicable clears entry prices but keeps typical spend', () {
    const PlacePricingDraft paid = PlacePricingDraft(
      currency: CurrencyCode.eur,
      entryType: PlaceEntryType.paid,
      entryPriceFrom: Money(minorUnits: 1000, currency: CurrencyCode.eur),
      entryPriceTo: Money(minorUnits: 2000, currency: CurrencyCode.eur),
      typicalSpendFrom: Money(minorUnits: 700, currency: CurrencyCode.eur),
    );

    final PlacePricingDraft result = paid.copyWith(
      entryType: PlaceEntryType.notApplicable,
    );

    expect(result.entryPriceFrom, isNull);
    expect(result.entryPriceTo, isNull);
    expect(result.typicalSpendFrom?.minorUnits, 700);
  });

  test('simple landmark publishes without venue-only facts', () {
    final CreateDraftEntity draft = _validDraft().copyWith(
      mainCategory: 'art_culture_museums',
      subcategory: 'monument',
      shortDescription: '',
      fullDescription: '',
      media: const MediaEntity(coverImage: '', gallery: <String>[]),
      placeData: _validDraft().placeData!.copyWith(
        placeKind: PlaceKind.pointOfInterest,
        clearRelationshipToPlace: true,
        hours: const PlaceHoursDraft(),
        pricing: const PlacePricingDraft(
          currency: CurrencyCode.eur,
          entryType: PlaceEntryType.paid,
        ),
      ),
    );

    final List<String> codes = validate(
      draft,
      supportedContentLocales: const <String>{'en', 'ru', 'lv'},
      activeMarketCityId: 'riga',
      policy: simplePoiPlacePolicy,
    ).map((PlaceValidationIssue issue) => issue.code).toList();

    expect(codes, isNot(contains('short_description_length')));
    expect(codes, isNot(contains('cover_required')));
    expect(codes, isNot(contains('hours_mode_required')));
    expect(codes, isNot(contains('entry_price_required')));
    expect(codes, isNot(contains('relationship_required')));
  });

  test('managed cultural venue keeps essential visitor facts required', () {
    final CreateDraftEntity draft = _validDraft().copyWith(
      mainCategory: 'art_culture_museums',
      subcategory: 'museum',
      shortDescription: '',
      media: const MediaEntity(coverImage: '', gallery: <String>[]),
      placeData: _validDraft().placeData!.copyWith(
        placeKind: PlaceKind.managedVenue,
        clearRelationshipToPlace: true,
        hours: const PlaceHoursDraft(),
      ),
    );

    final List<String> codes = validate(
      draft,
      supportedContentLocales: const <String>{'en', 'ru', 'lv'},
      activeMarketCityId: 'riga',
      policy: culturalVenuePlacePolicy,
    ).map((PlaceValidationIssue issue) => issue.code).toList();

    expect(codes, contains('short_description_length'));
    expect(codes, contains('cover_required'));
    expect(codes, contains('hours_mode_required'));
    expect(codes, isNot(contains('relationship_required')));
  });

  test(
    'place profiles cover static, public, managed and hospitality cases',
    () {
      expect(
        placeCreationPolicyFor('monument').id,
        PlaceCreationProfileId.simplePoi,
      );
      expect(
        placeCreationPolicyFor('park').id,
        PlaceCreationProfileId.publicSpace,
      );
      expect(
        placeCreationPolicyFor('museum').id,
        PlaceCreationProfileId.culturalVenue,
      );
      expect(
        placeCreationPolicyFor('cafe_visit').id,
        PlaceCreationProfileId.hospitality,
      );
      expect(
        placeCreationPolicyFor('unknown-place').id,
        PlaceCreationProfileId.balanced,
      );
    },
  );
}

CreateDraftEntity _validDraft() {
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
        placeKind: PlaceKind.publicSpace,
        relationshipToPlace: PlaceRelationship.curator,
        categoryConfirmed: true,
        location: const PlaceLocationDraft(
          marketCityId: 'riga',
          countryCode: 'LV',
          city: 'Riga',
          timezoneId: 'Europe/Riga',
          formattedAddress: 'Brivibas iela 1',
          latitude: 56.95,
          longitude: 24.11,
          accuracy: PlaceLocationAccuracy.rooftop,
          pinConfirmed: true,
        ),
        hours: const PlaceHoursDraft(mode: PlaceHoursMode.alwaysOpen),
        pricing: const PlacePricingDraft(
          currency: CurrencyCode.eur,
          entryType: PlaceEntryType.free,
        ),
      );
  return common.copyWith(
    objectType: CreateObjectType.place,
    title: 'Riga Quiet Garden',
    mainCategory: 'wellness_recharge',
    subcategory: 'calm_walk',
    shortDescription: 'A calm public garden for a quiet break in central Riga.',
    placeData: place,
    media: const MediaEntity(
      coverImage: 'local://cover.jpg',
      gallery: <String>[],
    ),
  );
}

extension _Let<T> on T {
  R let<R>(R Function(T value) transform) => transform(this);
}
