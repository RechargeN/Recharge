import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/rental_draft_data.dart';
import 'package:recharge/features/create/domain/usecases/validate_rental_draft_usecase.dart';

void main() {
  const ValidateRentalDraftUseCase useCase = ValidateRentalDraftUseCase();

  CreateDraftEntity draftWith(RentalDraftData rental) {
    return CreateDraftEntity.defaults(
      organizerId: 'user-1',
      organizerEmail: 'user@example.com',
      organizerName: 'User',
      currency: 'EUR',
      timezone: 'Europe/Riga',
    ).copyWith(objectType: CreateObjectType.rental, rentalData: rental);
  }

  RentalDraftData completeDraft() {
    final RentalDraftData base = RentalDraftData.defaults(
      userId: 'user-1',
      currencyCode: 'EUR',
      timeZoneId: 'Europe/Riga',
    );
    return base.copyWith(
      title: 'Mountain bikes for rent',
      shortDescription:
          'Well maintained trail bikes, several sizes, helmets included.',
      fullDescription:
          'Full description with enough characters to satisfy the fifty '
          'character minimum required by the Rental validation contract.',
      categoryId: 'sport',
      subcategoryId: 'cycling',
      categoryConfirmed: true,
      inventoryGroups: const <RentalInventoryGroup>[
        RentalInventoryGroup(
          id: 'g1',
          label: 'Adult M',
          quantity: 5,
          condition: RentalCondition.good,
          sizeOrVariant: 'M',
        ),
      ],
      availability: RentalAvailabilityCalendar(
        timeZoneId: 'Europe/Riga',
        coverage: RentalAvailabilityCoverage(
          startsAtUtc: DateTime.utc(2026, 8, 1),
          endsAtUtc: DateTime.utc(2026, 11, 1),
          confirmedAtUtc: DateTime.utc(2026, 8, 20),
        ),
      ),
      handover: const RentalHandoverDraft(
        pickupPlaceName: 'Riga bike shop',
        publicAreaLabel: 'Old Town',
        publicLatitude: 56.95,
        publicLongitude: 24.11,
        scheduleMode: RentalScheduleMode.byArrangement,
      ),
      terms: const RentalTerms(
        offeredMinMinutes: 1440,
        offeredMaxMinutes: 4320,
      ),
      pricing: RentalPricingPolicy(
        currencyCode: 'EUR',
        billingUnit: RentalBillingUnit.day,
        rateSteps: const <RentalRateStep>[
          RentalRateStep(
            minUnits: 1,
            unitPrice: RentalMoneyDraft(amountMinor: 2800, currencyCode: 'EUR'),
          ),
        ],
        deposit: const RentalDepositPolicy(
          amount: RentalMoneyDraft(amountMinor: 0, currencyCode: 'EUR'),
          collectionMethod: RentalDepositCollectionMethod.none,
        ),
        damagePolicy: 'Repair cost billed to renter.',
        cancellationPolicyId: 'standard',
      ),
      fulfillment: const RentalExternalFulfillment(
        externalBookingUrl: 'https://example.com/book',
      ),
      attestation: RentalPublisherAttestation(
        policyVersion: '1.0',
        acceptedAtUtc: DateTime.utc(2026, 8, 20),
        acceptedByUserId: 'user-1',
        hasRightToOffer: true,
        listingAccurate: true,
        prohibitedItemsAcknowledged: true,
      ),
    );
  }

  test('a fully completed draft has no blocking issues', () {
    final issues = useCase(draftWith(completeDraft()));
    final blocking = issues.where((i) => i.isBlocking).toList();

    expect(blocking, isEmpty);
  });

  test('empty inventory blocks submit', () {
    final rental = completeDraft().copyWith(
      inventoryGroups: const <RentalInventoryGroup>[],
    );
    final issues = useCase(draftWith(rental));

    expect(
      issues.any(
        (i) => i.code == 'rental_inventory_group_count' && i.isBlocking,
      ),
      isTrue,
    );
  });

  test('category outside the Rental whitelist is rejected', () {
    final rental = completeDraft().copyWith(categoryId: 'food_drinks');
    final issues = useCase(draftWith(rental));

    expect(
      issues.any((i) => i.code == 'rental_category_not_whitelisted'),
      isTrue,
    );
  });

  test('billing unit larger than the offered minimum duration is rejected', () {
    final rental = completeDraft().copyWith(
      terms: const RentalTerms(offeredMinMinutes: 60, offeredMaxMinutes: 4320),
      pricing: completeDraft().pricing.copyWith(
        billingUnit: RentalBillingUnit.week,
      ),
    );
    final issues = useCase(draftWith(rental));

    expect(
      issues.any((i) => i.code == 'rental_billing_unit_exceeds_min_duration'),
      isTrue,
    );
  });

  test('nonzero deposit without a collection method is rejected', () {
    final rental = completeDraft();
    final withDeposit = rental.copyWith(
      pricing: rental.pricing.copyWith(
        deposit: RentalDepositPolicy(
          amount: const RentalMoneyDraft(
            amountMinor: 15000,
            currencyCode: 'EUR',
          ),
          collectionMethod: RentalDepositCollectionMethod.none,
        ),
      ),
    );
    final issues = useCase(draftWith(withDeposit));

    expect(
      issues.any((i) => i.code == 'rental_deposit_nonzero_requires_method'),
      isTrue,
    );
  });

  test('non-https external URL is rejected', () {
    final rental = completeDraft().copyWith(
      fulfillment: const RentalExternalFulfillment(
        externalBookingUrl: 'http://example.com/book',
      ),
    );
    final issues = useCase(draftWith(rental));

    expect(
      issues.any((i) => i.code == 'rental_external_url_not_https'),
      isTrue,
    );
  });

  test('incomplete attestation blocks submit', () {
    final rental = completeDraft().copyWith(
      attestation: const RentalPublisherAttestation(policyVersion: '1.0'),
    );
    final issues = useCase(draftWith(rental));

    expect(
      issues.any((i) => i.code == 'rental_attestation_incomplete'),
      isTrue,
    );
  });

  test('non-Rental drafts are always ignored', () {
    final CreateDraftEntity eventDraft = CreateDraftEntity.defaults(
      organizerId: 'user-1',
      organizerEmail: 'user@example.com',
      organizerName: 'User',
    );

    expect(useCase(eventDraft), isEmpty);
  });
}
