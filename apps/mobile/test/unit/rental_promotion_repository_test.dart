import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/rental_draft_data.dart';
import 'package:recharge/features/create/domain/repositories/rental_promotion_repository.dart';

class _FixedIdGenerator implements IdGenerator {
  const _FixedIdGenerator();
  @override
  String generate() => 'fixed-id';
}

void main() {
  late CreateLocalDataSource dataSource;
  late CreateRepositoryImpl repository;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    dataSource = CreateLocalDataSource(const FlutterSecureStorage());
    repository = CreateRepositoryImpl(
      localDataSource: dataSource,
      idGenerator: const _FixedIdGenerator(),
    );
  });

  CreateDraftEntity pendingReviewRental() {
    final RentalDraftData rentalData = RentalDraftData.defaults(
      userId: 'user-1',
      currencyCode: 'EUR',
      timeZoneId: 'Europe/Riga',
    );
    return CreateDraftEntity.defaults(
      organizerId: 'user-1',
      organizerEmail: 'user@example.test',
      organizerName: 'User',
    ).copyWith(
      id: 'rental-1',
      objectType: CreateObjectType.rental,
      clearEventData: true,
      rentalData: rentalData,
      draftStatus: DraftStatus.pendingReview,
      publishStatus: PublishStatus.pendingReview,
    );
  }

  test('maps a successful promotion to the promoted entity', () async {
    final entity = pendingReviewRental();
    // Seeded through the datasource directly, not `repository.saveDraft` —
    // the latter deliberately resets status to `draft` (autosave
    // semantics), which would defeat this fixture's `pending_review` setup.
    await dataSource.saveDraft(
      'user-1',
      CreateDraftModel.fromEntity(entity),
    );

    final CreateDraftEntity promoted = await repository
        .promoteRentalToPublished(
          userId: 'user-1',
          rentalId: 'rental-1',
          expectedRentalRevision: entity.rentalData!.revision,
        );

    expect(promoted.publishStatus, PublishStatus.published);
    expect(promoted.draftStatus, DraftStatus.published);
    expect(promoted.moderationStatus, ModerationStatus.none);
  });

  test(
    'maps a stale-revision conflict to RentalPromotionException, no write',
    () async {
      final entity = pendingReviewRental();
      // Seeded through the datasource directly, not `repository.saveDraft`
      // — the latter deliberately resets status to `draft` (autosave
      // semantics), which would defeat this fixture's `pending_review`
      // setup.
      await dataSource.saveDraft(
        'user-1',
        CreateDraftModel.fromEntity(entity),
      );

      expect(
        () => repository.promoteRentalToPublished(
          userId: 'user-1',
          rentalId: 'rental-1',
          expectedRentalRevision: entity.rentalData!.revision + 1,
        ),
        throwsA(isA<RentalPromotionException>()),
      );
    },
  );

  test(
    'maps a missing draft to RentalPromotionException',
    () async {
      expect(
        () => repository.promoteRentalToPublished(
          userId: 'nobody',
          rentalId: 'rental-1',
          expectedRentalRevision: 0,
        ),
        throwsA(isA<RentalPromotionException>()),
      );
    },
  );
}
