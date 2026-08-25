import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/adapters/rental_publication_discovery_adapter.dart';
import 'package:recharge/app/application/details_lookup_registry.dart';
import 'package:recharge/app/application/resolve_details_usecase.dart';
import 'package:recharge/features/create/domain/entities/rental_draft_data.dart';
import 'package:recharge/features/create/domain/entities/rental_listing.dart';
import 'package:recharge/features/create/domain/repositories/rental_publication_index_sink.dart';
import 'package:recharge/features/create/domain/usecases/build_rental_public_projection_usecase.dart';
import 'package:recharge/features/discover/data/datasources/published_rental_discovery_local_datasource.dart';
import 'package:recharge/features/discover/data/repositories/rental_details_lookup.dart';
import 'package:recharge/features/discover/domain/entities/published_rental_discovery_entity.dart';
import 'package:recharge/features/discover/domain/repositories/details_lookup_port.dart';
import 'package:recharge/shared/models/catalog_object_ref.dart';

void main() {
  late RentalPublicationDiscoveryAdapter adapter;
  late DetailsLookupRegistry registry;
  late ResolveDetailsUseCase resolve;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    adapter = RentalPublicationDiscoveryAdapter(
      PublishedRentalDiscoveryLocalDataSource(const FlutterSecureStorage()),
    );
    registry = DetailsLookupRegistry(<CatalogObjectType, DetailsLookupPort>{
      CatalogObjectType.rental: RentalDetailsLookup(adapter),
    });
    resolve = ResolveDetailsUseCase(registry);
  });

  RentalListing buildListing() {
    final RentalDraftData draft = RentalDraftData.defaults(
      userId: 'user-1',
      currencyCode: 'EUR',
      timeZoneId: 'Europe/Riga',
    ).copyWith(
      title: 'Mountain bikes',
      shortDescription: 'Trail bikes for rent.',
      fullDescription: 'Long description of the trail bikes available.',
      inventoryGroups: const <RentalInventoryGroup>[
        RentalInventoryGroup(
          id: 'g1',
          label: 'Adult M',
          quantity: 3,
          condition: RentalCondition.good,
        ),
      ],
      handover: const RentalHandoverDraft(
        pickupPlaceName: 'Riga bike shop',
        publicAreaLabel: 'Old Town',
        publicLatitude: 56.95,
        publicLongitude: 24.11,
        scheduleMode: RentalScheduleMode.byArrangement,
      ),
      pricing: RentalPricingPolicy(
        currencyCode: 'EUR',
        billingUnit: RentalBillingUnit.day,
        rateSteps: const <RentalRateStep>[
          RentalRateStep(
            minUnits: 1,
            unitPrice: RentalMoneyDraft(amountMinor: 2500, currencyCode: 'EUR'),
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
    );
    return const BuildRentalPublicProjectionUseCase()(
      id: 'rental-1',
      draft: draft,
    );
  }

  test(
    'publish -> sink.activate -> port.getActiveRental -> loader -> resolver end-to-end',
    () async {
      final RentalListing listing = buildListing();
      final RentalPublicationIndexSink sink = adapter;

      await sink.activate(
        RentalPublishedVersion(
          listing: listing,
          publishedAtUtc: DateTime.utc(2026, 8, 24),
        ),
      );

      // Port (Discover-side) sees it.
      final PublishedRentalDiscoveryEntity? viaPort = await adapter
          .getActiveRental('rental-1');
      expect(viaPort, isNotNull);
      expect(viaPort!.title, 'Mountain bikes');

      // Canonical-route resolver (RentalDetailsLookup registered under
      // CatalogObjectType.rental) sees it too, end-to-end.
      final DetailsResolution result = await resolve(
        DetailsRouteTargetRef(
          const CatalogObjectRef(
            objectType: CatalogObjectType.rental,
            objectId: 'rental-1',
          ),
        ),
      );
      expect(result.status, DetailsResolutionStatus.found);
      expect(result.projection, isA<PublishedRentalDiscoveryEntity>());
      expect(
        (result.projection! as PublishedRentalDiscoveryEntity).rentalId,
        'rental-1',
      );
    },
  );

  test(
    'pending_review (never activated) is not found via the canonical resolver',
    () async {
      // Nothing was ever activated for this id — DTL-OBJ-01's core
      // invariant: sink.activate is the only thing that can make a Rental
      // listing visible, and RNT-PUB-01's pending_review path never calls
      // it.
      final DetailsResolution result = await resolve(
        DetailsRouteTargetRef(
          const CatalogObjectRef(
            objectType: CatalogObjectType.rental,
            objectId: 'never-activated',
          ),
        ),
      );
      expect(result.status, DetailsResolutionStatus.notFound);
    },
  );

  test('archive removes the listing from Discover', () async {
    await adapter.activate(
      RentalPublishedVersion(
        listing: buildListing(),
        publishedAtUtc: DateTime.utc(2026, 8, 24),
      ),
    );
    await adapter.archive('rental-1');

    final PublishedRentalDiscoveryEntity? afterArchive = await adapter
        .getActiveRental('rental-1');
    expect(afterArchive, isNull);
  });

  test(
    'the projection carries no private authoring fields (AC-05/AC-12 shape check)',
    () async {
      final PublishedRentalDiscoveryEntity entity = PublishedRentalDiscoveryEntity(
        rentalId: 'rental-1',
        publisherId: 'user-1',
        title: 't',
        shortDescription: 's',
        fullDescription: 'f',
        categoryId: 'sport',
        subcategoryId: 'cycling',
        inventoryGroups: const <PublishedRentalInventoryGroupRef>[],
        totalUnitsAggregate: 0,
        publicAreaLabel: 'area',
        publicGeoPrecisionMeters: 500,
        deliveryAvailable: false,
        offeredMinMinutes: 60,
        offeredMaxMinutes: 120,
        idRequiredAtHandover: false,
        currencyCode: 'EUR',
        billingUnit: 'day',
        rateSteps: const <PublishedRentalRateStepRef>[],
        hasDeposit: false,
        damagePolicy: 'd',
        cancellationPolicyId: 'standard',
        publishedAtUtc: DateTime.utc(2026, 8, 24),
      );
      // Compile-time shape check, not a runtime assertion: this entity
      // class has no field capable of holding exact private
      // address/geo/handover-instructions — see the class doc comment.
      expect(entity.isCoherent, isTrue);
    },
  );
}
