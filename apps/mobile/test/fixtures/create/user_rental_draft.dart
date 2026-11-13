import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/rental_draft_data.dart';
import 'package:recharge/features/create/domain/usecases/build_rental_content_body.dart';

/// A user's Rental draft as the Create flow stores it (D3.3 §4): Create
/// defaults plus what the user fills in, under the Emulator TEST-ONLY Rental
/// policy (`water_activities/kayak` needs a safety notice). The confirmation,
/// the attestation and the occupancy block come from [accountId] at [anchor],
/// exactly as Create records them (block revision 0, local `loc_*` ids). It is
/// not a backend body.
CreateDraftEntity userRentalDraft({
  required String pageId,
  required String coverPath,
  List<String> galleryPaths = const <String>[],
  String? localId,
  String accountId = compatAccountId,
  DateTime? anchor,
  String title = 'Kipsala sea kayak rental',
}) {
  final DateTime at = anchor ?? compatAnchor;
  final CreateDraftEntity base = CreateDraftEntity.defaults(
    organizerId: accountId,
    organizerEmail: 'user@example.com',
    organizerName: 'Stand Creator',
    marketCityId: 'riga',
    timezone: 'Europe/Riga',
    country: 'LV',
    city: 'Riga',
    currency: 'EUR',
  );
  const String group = 'loc_group_kayak';
  final RentalDraftData rental =
      RentalDraftData.defaults(
        userId: accountId,
        currencyCode: 'EUR',
        timeZoneId: 'Europe/Riga',
        categoryId: 'water_activities',
        subcategoryId: 'kayak',
      ).copyWith(
        publisherRef: PublisherRef(type: PublisherType.page, id: pageId),
        title: title,
        shortDescription:
            'Two-seat sea kayaks with paddles and life vests for day trips',
        fullDescription:
            'Stable two-seat sea kayaks for calm-water trips along the '
            'Daugava. Paddles and life vests are included; a short safety '
            'briefing is given at handover.',
        categoryConfirmed: true,
        inventoryGroups: const <RentalInventoryGroup>[
          RentalInventoryGroup(
            id: group,
            label: 'Two-seat sea kayak',
            quantity: 4,
            condition: RentalCondition.good,
            includedAccessories: <String>['paddle', 'life vest'],
          ),
        ],
        availability: RentalAvailabilityCalendar(
          timeZoneId: 'Europe/Riga',
          coverage: RentalAvailabilityCoverage(
            startsAtUtc: at,
            endsAtUtc: at.add(const Duration(days: 30)),
            confirmedAtUtc: at,
          ),
          blocks: <RentalAvailabilityBlock>[
            RentalAvailabilityBlock(
              id: 'loc_block_maintenance',
              groupId: group,
              startsAtUtc: at.add(const Duration(days: 2)),
              endsAtUtc: at.add(const Duration(days: 3)),
              unitsBlocked: 1,
              source: RentalBlockSource.maintenance,
              createdByUserId: accountId,
              createdAtUtc: at,
              updatedAtUtc: at,
            ),
          ],
        ),
        handover: const RentalHandoverDraft(
          pickupPlaceName: 'Kipsala boat dock',
          publicAreaLabel: 'Kipsala, Riga',
          publicLatitude: 56.9535,
          publicLongitude: 24.079,
          publicGeoPrecisionMeters: 500,
          scheduleMode: RentalScheduleMode.byArrangement,
        ),
        terms: const RentalTerms(
          offeredMinMinutes: 60,
          offeredMaxMinutes: 4320,
          safetyNotice:
              'Life vests are mandatory on the water; stay within the marked '
              'area.',
          includedAccessoriesConfirmation: true,
        ),
        pricing: const RentalPricingPolicy(
          currencyCode: 'EUR',
          billingUnit: RentalBillingUnit.hour,
          rateSteps: <RentalRateStep>[
            RentalRateStep(
              minUnits: 1,
              unitPrice: RentalMoneyDraft(
                amountMinor: 1500,
                currencyCode: 'EUR',
              ),
            ),
          ],
          deposit: RentalDepositPolicy(
            amount: RentalMoneyDraft(amountMinor: 5000, currencyCode: 'EUR'),
            collectionMethod: RentalDepositCollectionMethod.atHandover,
            terms: 'Returned after the kayak is inspected at return.',
          ),
          damagePolicy: 'Damage beyond normal wear is charged at repair cost.',
          cancellationPolicyId: 'standard',
        ),
        fulfillment: const RentalExternalFulfillment(
          externalBookingUrl: 'https://rent.example.lv/kayak',
        ),
        attestation: RentalPublisherAttestation(
          policyVersion: '1.0',
          acceptedAtUtc: at,
          acceptedByUserId: accountId,
          hasRightToOffer: true,
          listingAccurate: true,
          prohibitedItemsAcknowledged: true,
        ),
      );
  return base.copyWith(
    id: localId ?? base.id,
    objectType: CreateObjectType.rental,
    title: title,
    mainCategory: 'water_activities',
    subcategory: 'kayak',
    rentalData: rental,
    media: MediaEntity(coverImage: coverPath, gallery: galleryPaths),
  );
}

/// Inputs shared by the compatibility cases (D3.3 §4) and the fixture file
/// `packages/api_contracts/schema/content/v1/fixtures/rental_create_compat.json`.
const String compatAccountId = 'account-compat-1';
const String compatServerActor = '01HZZZZZZZZZZZZZZZZZZZZZZ1';
const String compatPageId = 'page-compat-1';
const String compatLocalDraftId = 'local-rental-compat-1';
final DateTime compatAnchor = DateTime.utc(2026, 10, 12);
const List<String> compatGallery = <String>[
  'C:/photos/kayak-1.png',
  'C:/photos/kayak-2.png',
];

RentalPublicationScope compatScope() => RentalPublicationScope(
  accountId: compatAccountId,
  publisherRef: const PublisherRef(type: PublisherType.page, id: compatPageId),
  localDraftId: compatLocalDraftId,
);

/// The uploaded assets of the compatibility drafts, by stable attachment id.
Map<String, String> compatAssetIds() {
  final RentalPublicationScope scope = compatScope();
  return <String, String>{
    scope.coverAttachmentId: 'asset-cover',
    scope.galleryAttachmentId(compatGallery[0]): 'asset-gallery-1',
    scope.galleryAttachmentId(compatGallery[1]): 'asset-gallery-2',
  };
}

CreateDraftEntity _compatBase({DateTime? anchor}) => userRentalDraft(
  pageId: compatPageId,
  coverPath: 'C:/photos/kayak-cover.png',
  galleryPaths: compatGallery,
  localId: compatLocalDraftId,
  anchor: anchor,
);

CreateDraftEntity _withRental(
  RentalDraftData Function(RentalDraftData rental) change,
) {
  final CreateDraftEntity draft = _compatBase();
  return draft.copyWith(rentalData: change(draft.rentalData!));
}

/// A Create draft per case: the accepted one, then one per row of §1.4 that
/// the form accepts and the server refuses.
final Map<String, CreateDraftEntity Function()> rentalCompatCases =
    <String, CreateDraftEntity Function()>{
      'valid': _compatBase,
      'cover_missing': () => _compatBase().copyWith(
        media: const MediaEntity(coverImage: '', gallery: <String>[]),
      ),
      'subcategory_empty': () =>
          _withRental((rental) => rental.copyWith(subcategoryId: '')),
      'pair_without_policy': () => _withRental(
        (rental) => rental.copyWith(categoryId: 'sport', subcategoryId: 'yoga'),
      ),
      'coverage_stale': () =>
          _compatBase(anchor: compatAnchor.subtract(const Duration(days: 8))),
      'attestation_policy_version_changed': () => _withRental(
        (rental) => rental.copyWith(
          attestation: rental.attestation.copyWith(policyVersion: '0.9'),
        ),
      ),
      'precision_too_fine': () => _withRental(
        (rental) => rental.copyWith(
          handover: rental.handover.copyWith(publicGeoPrecisionMeters: 100),
        ),
      ),
      'delivery_radius_too_far': () => _withRental(
        (rental) => rental.copyWith(
          handover: rental.handover.copyWith(
            deliveryAvailable: true,
            deliveryRadiusKm: 80,
            deliveryFee: const RentalMoneyDraft(
              amountMinor: 0,
              currencyCode: 'EUR',
            ),
            deliveryTerms: 'Delivered to the shore by arrangement.',
          ),
        ),
      ),
      'external_url_fragment': () => _withRental(
        (rental) => rental.copyWith(
          fulfillment: const RentalExternalFulfillment(
            externalBookingUrl: 'https://rent.example.lv/kayak#book',
          ),
        ),
      ),
      'safety_notice_missing': () => _withRental(
        (rental) => rental.copyWith(
          terms: const RentalTerms(
            offeredMinMinutes: 60,
            offeredMaxMinutes: 4320,
            includedAccessoriesConfirmation: true,
          ),
        ),
      ),
    };
