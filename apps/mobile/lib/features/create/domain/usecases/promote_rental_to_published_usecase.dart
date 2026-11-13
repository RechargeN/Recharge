import '../entities/create_draft_entity.dart';
import '../repositories/rental_promotion_repository.dart';

/// RNT-PUB-01 §1.2. Thin wrapper so `CreateController` can depend on this
/// one optional usecase (nullable, `null` when direct-publish isn't wired —
/// see `RentalPromotionRepository`'s own doc comment) instead of the
/// narrower [RentalPromotionRepository] interface directly.
class PromoteRentalToPublishedUseCase {
  const PromoteRentalToPublishedUseCase(this._repository);

  final RentalPromotionRepository _repository;

  Future<CreateDraftEntity> call({
    required String userId,
    required String rentalId,
    required int expectedRentalRevision,
  }) {
    return _repository.promoteRentalToPublished(
      userId: userId,
      rentalId: rentalId,
      expectedRentalRevision: expectedRentalRevision,
    );
  }
}
