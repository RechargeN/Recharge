import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/rental_draft_data.dart';

void main() {
  late CreateLocalDataSource dataSource;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    dataSource = CreateLocalDataSource(const FlutterSecureStorage());
  });

  CreateDraftEntity pendingReviewRental({
    String userId = 'user-1',
    String id = 'rental-1',
    PublisherRef? publisherRef,
  }) {
    final RentalDraftData rentalData = RentalDraftData.defaults(
      userId: userId,
      currencyCode: 'EUR',
      timeZoneId: 'Europe/Riga',
    ).copyWith(publisherRef: publisherRef);
    return CreateDraftEntity.defaults(
      organizerId: userId,
      organizerEmail: 'user@example.test',
      organizerName: 'User',
    ).copyWith(
      id: id,
      objectType: CreateObjectType.rental,
      clearEventData: true,
      rentalData: rentalData,
      draftStatus: DraftStatus.pendingReview,
      publishStatus: PublishStatus.pendingReview,
    );
  }

  Future<void> seed(CreateDraftEntity entity, {required String userId}) {
    return dataSource.saveDraft(userId, CreateDraftModel.fromEntity(entity));
  }

  group('promoteRentalDraftIfCurrent', () {
    test('promotes a matching pending_review draft to published', () async {
      final entity = pendingReviewRental();
      await seed(entity, userId: 'user-1');

      final result = await dataSource.promoteRentalDraftIfCurrent(
        userId: 'user-1',
        expectedRentalId: 'rental-1',
        expectedRentalRevision: entity.rentalData!.revision,
      );

      expect(result.status, RentalPromotionStatus.promoted);
      expect(result.persisted?.publishStatus, 'published');
      expect(result.persisted?.draftStatus, 'published');
      expect(result.persisted?.moderationStatus, 'none');
      expect(result.persisted?.publishedAtUtcIso, isNotNull);
    });

    test(
      'repeat call on an already-published draft is idempotent and keeps publishedAtUtc',
      () async {
        final entity = pendingReviewRental();
        await seed(entity, userId: 'user-1');
        final first = await dataSource.promoteRentalDraftIfCurrent(
          userId: 'user-1',
          expectedRentalId: 'rental-1',
          expectedRentalRevision: entity.rentalData!.revision,
        );
        final firstPublishedAt = first.persisted!.publishedAtUtcIso;

        final second = await dataSource.promoteRentalDraftIfCurrent(
          userId: 'user-1',
          expectedRentalId: 'rental-1',
          // Deliberately stale revision — alreadyPublished must not check it.
          expectedRentalRevision: -999,
        );

        expect(second.status, RentalPromotionStatus.alreadyPublished);
        expect(second.persisted?.publishedAtUtcIso, firstPublishedAt);
      },
    );

    test('id mismatch is invalidExistingData and writes nothing', () async {
      final entity = pendingReviewRental();
      await seed(entity, userId: 'user-1');

      final result = await dataSource.promoteRentalDraftIfCurrent(
        userId: 'user-1',
        expectedRentalId: 'some-other-rental',
        expectedRentalRevision: entity.rentalData!.revision,
      );

      expect(result.status, RentalPromotionStatus.invalidExistingData);
      final CreateDraftModel? persisted = await dataSource.loadDraft(
        'user-1',
      );
      expect(persisted?.publishStatus, 'pendingReview');
    });

    test('no draft at all is invalidExistingData', () async {
      final result = await dataSource.promoteRentalDraftIfCurrent(
        userId: 'nobody',
        expectedRentalId: 'rental-1',
        expectedRentalRevision: 0,
      );

      expect(result.status, RentalPromotionStatus.invalidExistingData);
    });

    test('owner mismatch is conflict and writes nothing', () async {
      final entity = pendingReviewRental(
        publisherRef: const PublisherRef(
          type: PublisherType.user,
          id: 'someone-else',
        ),
      );
      await seed(entity, userId: 'user-1');

      final result = await dataSource.promoteRentalDraftIfCurrent(
        userId: 'user-1',
        expectedRentalId: 'rental-1',
        expectedRentalRevision: entity.rentalData!.revision,
      );

      expect(result.status, RentalPromotionStatus.conflict);
      final CreateDraftModel? persisted = await dataSource.loadDraft(
        'user-1',
      );
      expect(persisted?.publishStatus, 'pendingReview');
    });

    test(
      'unexpected lifecycle state (not pending_review/published) is conflict',
      () async {
        final entity = pendingReviewRental().copyWith(
          draftStatus: DraftStatus.draft,
          publishStatus: PublishStatus.draft,
        );
        await seed(entity, userId: 'user-1');

        final result = await dataSource.promoteRentalDraftIfCurrent(
          userId: 'user-1',
          expectedRentalId: 'rental-1',
          expectedRentalRevision: entity.rentalData!.revision,
        );

        expect(result.status, RentalPromotionStatus.conflict);
      },
    );

    test('stale expectedRentalRevision is conflict and writes nothing', () async {
      final entity = pendingReviewRental();
      await seed(entity, userId: 'user-1');

      final result = await dataSource.promoteRentalDraftIfCurrent(
        userId: 'user-1',
        expectedRentalId: 'rental-1',
        expectedRentalRevision: entity.rentalData!.revision + 1,
      );

      expect(result.status, RentalPromotionStatus.conflict);
      final CreateDraftModel? persisted = await dataSource.loadDraft(
        'user-1',
      );
      expect(persisted?.publishStatus, 'pendingReview');
    });

    test(
      'a concurrent plain saveDraft for the same user does not race with promotion',
      () async {
        final entity = pendingReviewRental();
        await seed(entity, userId: 'user-1');

        // Fire both without awaiting individually — both are queued on the
        // same per-user key (RNT-PUB-01 v0.4 §1.2.0); no lost update.
        final promotionFuture = dataSource.promoteRentalDraftIfCurrent(
          userId: 'user-1',
          expectedRentalId: 'rental-1',
          expectedRentalRevision: entity.rentalData!.revision,
        );
        final saveFuture = dataSource.saveDraft(
          'user-1',
          CreateDraftModel.fromEntity(
            entity.copyWith(
              rentalData: entity.rentalData!.copyWith(
                shortDescription: 'Updated concurrently',
              ),
            ),
          ),
        );

        await Future.wait<void>(<Future<void>>[promotionFuture, saveFuture]);

        // Whichever order the queue actually ran them in, the persisted
        // state must be internally consistent (not a torn write) and the
        // datasource must not have thrown.
        final CreateDraftModel? persisted = await dataSource.loadDraft(
          'user-1',
        );
        expect(persisted, isNotNull);
        expect(persisted!.id, 'rental-1');
      },
    );
  });
}
