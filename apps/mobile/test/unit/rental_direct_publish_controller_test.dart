import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/domain/entities/create_availability.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/rental_direct_publish_policy.dart';
import 'package:recharge/features/create/domain/entities/rental_draft_data.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/repositories/rental_promotion_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/promote_rental_to_published_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';

import '../support/event_create_test_support.dart';

void main() {
  late _FakeRentalRepository repository;

  CreateController buildController({
    RentalDirectPublishPolicy policy = const RentalDirectPublishPolicy(
      isTrusted: true,
    ),
    bool wirePromotion = true,
  }) {
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
      rentalDirectPublishPolicy: policy,
      promoteRentalToPublished: wirePromotion
          ? PromoteRentalToPublishedUseCase(repository)
          : null,
    );
  }

  setUp(() {
    repository = _FakeRentalRepository();
  });

  RentalDraftData completeRentalData({
    PublisherRef? publisherRef,
  }) {
    final RentalDraftData base = RentalDraftData.defaults(
      userId: 'user-1',
      currencyCode: 'EUR',
      timeZoneId: 'Europe/Riga',
    );
    return base
        .copyWith(
          title: 'Mountain bikes for rent',
          shortDescription:
              'Well maintained trail bikes, several sizes, helmets included.',
          fullDescription:
              'Full description with enough characters to satisfy the '
              'fifty character minimum required by the Rental validation '
              'contract.',
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
                unitPrice: RentalMoneyDraft(
                  amountMinor: 2800,
                  currencyCode: 'EUR',
                ),
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
        )
        .copyWith(publisherRef: publisherRef);
  }

  CreateDraftEntity completeRentalDraft({PublisherRef? publisherRef}) {
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
      // CreateController._validate() has no dedicated Rental branch — it
      // falls through to the generic path, which checks these top-level
      // entity fields, not the nested rentalData ones.
      title: 'Mountain bikes for rent',
      mainCategory: 'sport',
      subcategory: 'cycling',
      // Defaults to eventSlots (which then requires scheduleSlots) — Rental
      // doesn't use generic availability at all, it has its own
      // rentalData.availability.
      availabilityKind: CreateAvailabilityKind.none,
      media: const MediaEntity(coverImage: 'cover.jpg', gallery: <String>[]),
      clearEventData: true,
      rentalData: completeRentalData(publisherRef: publisherRef),
    );
  }

  test(
    'personal + verified + trusted + capability publishes directly',
    () async {
      repository.seed(completeRentalDraft());
      final controller = buildController();
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
      controller.dispose();
    },
  );

  test(
    'active workspace switching after save does not change authorization',
    () async {
      // The draft's own recorded PublisherRef is personal/user-1; the
      // active workspace at publish time is switched to a different
      // (still personal, different id) PublisherRef — must not matter,
      // since RNT-PUB-01 §1.4 authorizes against the saved
      // rentalData.publisherRef, not the current active one.
      repository.seed(completeRentalDraft());
      final controller = buildController();
      await controller.ensureLoaded(
        userId: 'user-1',
        organizerEmail: 'user@example.test',
        organizerName: 'User',
        capabilities: const <String>['publish.rental.direct'],
        activePublisherRef: const PublisherRef(
          type: PublisherType.user,
          id: 'a-different-active-workspace',
        ),
        isVerifiedCreator: true,
      );

      final bool ok = await controller.publishDraft();

      expect(ok, isTrue);
      expect(
        controller.state.publishedDraft?.publishStatus,
        PublishStatus.published,
      );
      controller.dispose();
    },
  );

  test('page publisher stays pending_review (fail-closed)', () async {
    repository.seed(
      completeRentalDraft(
        publisherRef: const PublisherRef(type: PublisherType.page, id: 'p1'),
      ),
    );
    final controller = buildController();
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
      PublishStatus.pendingReview,
    );
    controller.dispose();
  });

  test('isVerifiedCreator == false stays pending_review', () async {
    repository.seed(completeRentalDraft());
    final controller = buildController();
    await controller.ensureLoaded(
      userId: 'user-1',
      organizerEmail: 'user@example.test',
      organizerName: 'User',
      capabilities: const <String>['publish.rental.direct'],
      isVerifiedCreator: false,
    );

    final bool ok = await controller.publishDraft();

    expect(ok, isTrue);
    expect(
      controller.state.publishedDraft?.publishStatus,
      PublishStatus.pendingReview,
    );
    controller.dispose();
  });

  test(
    'isTrusted == false (constructor default) stays pending_review',
    () async {
      repository.seed(completeRentalDraft());
      final controller = buildController(
        policy: const RentalDirectPublishPolicy(),
      );
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
        PublishStatus.pendingReview,
      );
      controller.dispose();
    },
  );

  test('missing publish.rental.direct capability stays pending_review', () async {
    repository.seed(completeRentalDraft());
    final controller = buildController();
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
  });

  test(
    'a rental draft with no typed rentalData never crashes publishDraft',
    () async {
      repository.seed(completeRentalDraft());
      // Forces the generic publish path to hand back an entity with
      // objectType == rental but rentalData == null, exercising the
      // explicit null-guard in CreateController.publishDraft() rather than
      // an assumed invariant.
      repository.forcePublishedRentalDataToNull = true;
      final controller = buildController();
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
        PublishStatus.pendingReview,
      );
      controller.dispose();
    },
  );
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

/// Combines `CreateRepository` (generic publish) and
/// `RentalPromotionRepository` (RNT-PUB-01 promotion) — mirrors how
/// `CreateRepositoryImpl` implements both, without requiring every other
/// `CreateRepository` fake across the suite to gain this method.
class _FakeRentalRepository
    implements CreateRepository, RentalPromotionRepository {
  CreateDraftEntity? _stored;
  bool forcePublishedRentalDataToNull = false;

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
    CreateDraftEntity published = draft.copyWith(
      draftStatus: DraftStatus.pendingReview,
      moderationStatus: ModerationStatus.pending,
      publishStatus: PublishStatus.pendingReview,
      publishedAtUtc: now,
      updatedAtUtc: now,
    );
    if (forcePublishedRentalDataToNull) {
      published = published.copyWith(clearRentalData: true);
    }
    _stored = published;
    return published;
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
        current.objectType != CreateObjectType.rental ||
        current.rentalData == null) {
      throw const RentalPromotionException('invalidExistingData');
    }
    final PublisherRef ref = current.rentalData!.publisherRef;
    if (ref.type != PublisherType.user || ref.id != userId) {
      throw const RentalPromotionException('conflict: owner mismatch');
    }
    if (current.publishStatus == PublishStatus.published) {
      return current;
    }
    if (current.publishStatus != PublishStatus.pendingReview) {
      throw const RentalPromotionException('conflict: unexpected state');
    }
    if (current.rentalData!.revision != expectedRentalRevision) {
      throw const RentalPromotionException('conflict: stale revision');
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
