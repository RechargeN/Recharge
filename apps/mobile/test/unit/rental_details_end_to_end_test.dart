import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recharge/app/adapters/rental_publication_discovery_adapter.dart';
import 'package:recharge/app/application/details_lookup_registry.dart';
import 'package:recharge/app/application/details_resolution_providers.dart';
import 'package:recharge/app/application/resolve_details_usecase.dart';
import 'package:recharge/app/router/app_router.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/domain/entities/create_availability.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/rental_direct_publish_policy.dart';
import 'package:recharge/features/create/domain/entities/rental_draft_data.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/repositories/rental_promotion_repository.dart';
import 'package:recharge/features/create/domain/repositories/rental_publication_index_sink.dart';
import 'package:recharge/features/create/domain/usecases/build_rental_public_projection_usecase.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/promote_rental_to_published_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/discover/data/datasources/published_rental_discovery_local_datasource.dart';
import 'package:recharge/features/discover/data/repositories/rental_details_lookup.dart';
import 'package:recharge/features/discover/domain/entities/published_rental_discovery_entity.dart';
import 'package:recharge/features/discover/domain/repositories/details_lookup_port.dart';
import 'package:recharge/shared/models/catalog_object_ref.dart';

import '../support/event_create_test_support.dart';
import '../widget/widget_test_viewport.dart';

/// `CreateRepository` + `RentalPromotionRepository` fake, mirroring
/// `rental_direct_publish_controller_test.dart`'s pattern — the only
/// thing standing in for real persistence is the local draft slot;
/// `RentalPublicationIndexSink` below is the *real*
/// `RentalPublicationDiscoveryAdapter`, backed by real in-memory
/// `FlutterSecureStorage`, not a fake.
class _FakeCreateRepository implements CreateRepository, RentalPromotionRepository {
  CreateDraftEntity? _stored;

  void seed(CreateDraftEntity draft) => _stored = draft;

  @override
  Future<CreateDraftEntity?> loadDraft(String userId) async => _stored;

  @override
  Future<void> saveDraft(String userId, CreateDraftEntity draft) async {
    _stored = draft;
  }

  @override
  Future<CreateDraftEntity> publishDraft(
    String userId,
    CreateDraftEntity draft,
  ) async {
    final now = DateTime.now().toUtc();
    _stored = draft.copyWith(
      draftStatus: DraftStatus.pendingReview,
      moderationStatus: ModerationStatus.pending,
      publishStatus: PublishStatus.pendingReview,
      publishedAtUtc: now,
      updatedAtUtc: now,
    );
    return _stored!;
  }

  @override
  Future<CreateDraftEntity> promoteRentalToPublished({
    required String userId,
    required String rentalId,
    required int expectedRentalRevision,
  }) async {
    final CreateDraftEntity? current = _stored;
    if (current == null ||
        current.id != rentalId ||
        current.rentalData == null ||
        current.rentalData!.revision != expectedRentalRevision) {
      throw const RentalPromotionException('conflict');
    }
    final CreateDraftEntity promoted = current.copyWith(
      draftStatus: DraftStatus.published,
      publishStatus: PublishStatus.published,
      moderationStatus: ModerationStatus.none,
      publishedAtUtc: DateTime.now().toUtc(),
    );
    _stored = promoted;
    return promoted;
  }
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

void main() {
  late _FakeCreateRepository repository;
  late RentalPublicationDiscoveryAdapter adapter;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    repository = _FakeCreateRepository();
    adapter = RentalPublicationDiscoveryAdapter(
      PublishedRentalDiscoveryLocalDataSource(const FlutterSecureStorage()),
    );
  });

  CreateController buildController() {
    return CreateController(
      loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
      saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
      publishCreateDraftUseCase: PublishCreateDraftUseCase(repository),
      analyticsService: _NoopAnalyticsService(),
      eventCreateCoordinator: createTestEventCoordinator(),
      runtimeDefaults: const CreateRuntimeDefaults(
        marketCityId: 'riga',
        timezone: 'Europe/Riga',
        country: 'LV',
        city: 'Riga',
        currency: 'EUR',
      ),
      rentalDirectPublishPolicy: const RentalDirectPublishPolicy(
        isTrusted: true,
      ),
      promoteRentalToPublished: PromoteRentalToPublishedUseCase(repository),
      // The real adapter, not a fake — a successful publish must reach
      // real Discover-side storage, the same storage RentalDetailsLookup
      // reads from below.
      rentalPublicationIndexSink: adapter,
    );
  }

  CreateDraftEntity completeRentalDraft() {
    final RentalDraftData rentalData = RentalDraftData.defaults(
      userId: 'user-1',
      currencyCode: 'EUR',
      timeZoneId: 'Europe/Riga',
    ).copyWith(
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
      attestation: RentalPublisherAttestation(
        policyVersion: '1.0',
        acceptedAtUtc: DateTime.utc(2026, 8, 20),
        acceptedByUserId: 'user-1',
        hasRightToOffer: true,
        listingAccurate: true,
        prohibitedItemsAcknowledged: true,
      ),
    );
    return CreateDraftEntity.defaults(
      organizerId: 'user-1',
      organizerEmail: 'user@example.test',
      organizerName: 'User',
      currency: 'EUR',
      timezone: 'Europe/Riga',
      city: 'Riga',
    ).copyWith(
      id: 'rental-1',
      objectType: CreateObjectType.rental,
      title: 'Mountain bikes for rent',
      mainCategory: 'sport',
      subcategory: 'cycling',
      availabilityKind: CreateAvailabilityKind.none,
      media: const MediaEntity(coverImage: 'cover.jpg', gallery: <String>[]),
      clearEventData: true,
      rentalData: rentalData,
    );
  }

  test(
    'controller.publishDraft() direct-publishes and reaches the real sink '
    '(proves DTL-OBJ-01 §3.5 is actually wired, not just callable in '
    'isolation)',
    () async {
      repository.seed(completeRentalDraft());
      final CreateController controller = buildController();
      await controller.ensureLoaded(
        userId: 'user-1',
        organizerEmail: 'user@example.test',
        organizerName: 'User',
        capabilities: const <String>['publish.rental.direct'],
        isVerifiedCreator: true,
      );

      final bool ok = await controller.publishDraft();

      expect(ok, isTrue);
      expect(
        controller.state.publishedDraft?.publishStatus,
        PublishStatus.published,
      );
      // Nobody called sink.activate directly here — this confirms the
      // controller itself triggered it.
      final PublishedRentalDiscoveryEntity? indexed = await adapter
          .getActiveRental('rental-1');
      expect(indexed, isNotNull);
      expect(indexed!.title, 'Mountain bikes for rent');
      expect(indexed.publisherId, 'user-1');
      expect(indexed.publisherType, 'user');
      controller.dispose();
    },
  );

  fullPageTestWidgets(
    'the same publish, resolved through the real canonical-route dispatch '
    'widget, renders RentalDetailsPage content (publish -> sink -> '
    'resolver -> router -> widget, not a manual sink.activate shortcut)',
    (WidgetTester tester) async {
      repository.seed(completeRentalDraft());
      final CreateController controller = buildController();
      await controller.ensureLoaded(
        userId: 'user-1',
        organizerEmail: 'user@example.test',
        organizerName: 'User',
        capabilities: const <String>['publish.rental.direct'],
        isVerifiedCreator: true,
      );
      final bool ok = await controller.publishDraft();
      expect(ok, isTrue);
      controller.dispose();

      // Real DetailsLookupRegistry/ResolveDetailsUseCase, real
      // RentalDetailsLookup wrapping the same adapter the controller just
      // published through — nobody calls sink.activate or the port
      // directly in this test.
      final DetailsLookupRegistry registry = DetailsLookupRegistry(
        <CatalogObjectType, DetailsLookupPort>{
          CatalogObjectType.rental: RentalDetailsLookup(adapter),
        },
      );

      // Mirrors app_router.dart's real canonical-route registration
      // (name/path/builder shape) — exercises the same ResolvedDetailsRoute
      // widget production actually uses, not a private re-implementation
      // of its dispatch logic.
      final GoRouter router = GoRouter(
        initialLocation: '/discover/details/rental/rental-1',
        routes: <RouteBase>[
          GoRoute(
            path: '/discover/details/:objectType/:objectId',
            builder: (context, state) {
              final DetailsRouteTarget target = DetailsRouteTargetRef(
                CatalogObjectRef(
                  objectType: CatalogObjectType.rental,
                  objectId: state.pathParameters['objectId'] ?? '',
                ),
              );
              return ResolvedDetailsRoute(target: target);
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            detailsLookupRegistryProvider.overrideWithValue(registry),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mountain bikes for rent'), findsOneWidget);
      expect(find.textContaining('Adult M'), findsOneWidget);
    },
  );

  test(
    'a draft that only ever reached pending_review (never promoted, so '
    'sink.activate was never called) stays notFound through the resolver — '
    'DTL-OBJ-01\'s core invariant',
    () async {
      // No capability -> generic publish stops at pending_review, the
      // RNT-PUB-01 promotion branch never runs, sink.activate is never
      // reached.
      repository.seed(completeRentalDraft());
      final CreateController controller = buildController();
      await controller.ensureLoaded(
        userId: 'user-1',
        organizerEmail: 'user@example.test',
        organizerName: 'User',
        capabilities: const <String>[],
        isVerifiedCreator: true,
      );
      final bool ok = await controller.publishDraft();
      expect(ok, isTrue);
      expect(
        controller.state.publishedDraft?.publishStatus,
        PublishStatus.pendingReview,
      );
      controller.dispose();

      final ResolveDetailsUseCase resolve = ResolveDetailsUseCase(
        DetailsLookupRegistry(<CatalogObjectType, DetailsLookupPort>{
          CatalogObjectType.rental: RentalDetailsLookup(adapter),
        }),
      );
      final DetailsResolution result = await resolve(
        DetailsRouteTargetRef(
          const CatalogObjectRef(
            objectType: CatalogObjectType.rental,
            objectId: 'rental-1',
          ),
        ),
      );
      expect(result.status, DetailsResolutionStatus.notFound);
    },
  );

  test('archive removes the listing from Discover', () async {
    // Uses the same complete, non-empty-title fixture as the other tests —
    // a bare RentalDraftData.defaults() has an empty title, which fails
    // PublishedRentalDiscoveryEntity.isCoherent.
    final RentalDraftData rentalData = completeRentalDraft().rentalData!;
    await adapter.activate(
      RentalPublishedVersion(
        listing: BuildRentalPublicProjectionUseCase()(
          id: 'rental-1',
          draft: rentalData,
        ),
        publishedAtUtc: DateTime.utc(2026, 8, 24),
      ),
    );
    await adapter.archive('rental-1');

    final PublishedRentalDiscoveryEntity? afterArchive = await adapter
        .getActiveRental('rental-1');
    expect(afterArchive, isNull);
  });
}
