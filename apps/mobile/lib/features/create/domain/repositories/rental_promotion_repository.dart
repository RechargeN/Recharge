import '../entities/create_draft_entity.dart';

/// RNT-PUB-01 §1.2. A separate interface, not a new member on
/// [CreateRepository] — mirrors `RouteDraftPersistenceRepository`/
/// `CreateDraftCollectionRepository`, which exist precisely so that adding
/// a type-specific capability doesn't force every `CreateRepository` fake
/// across the test suite to implement it. `CreateRepositoryImpl` implements
/// this alongside `CreateRepository`; `CreateController` depends on it only
/// through the optional `PromoteRentalToPublishedUseCase` (nullable,
/// defaults to unavailable — direct-publish silently falls back to
/// `pending_review` when not wired).
abstract interface class RentalPromotionRepository {
  /// Conditional `pending_review` → `published` promotion for one Rental
  /// draft, called by `CreateController.publishDraft()` immediately after
  /// the generic `CreateRepository.publishDraft()` above, only when
  /// `ResolveRentalDirectPublishUseCase` authorized it. Throws
  /// [RentalPromotionException] on any fail-closed mismatch (missing/wrong
  /// draft, owner mismatch, unexpected state, stale revision) — the caller
  /// is expected to catch it and keep the `pending_review` result already
  /// obtained from `publishDraft` unchanged.
  Future<CreateDraftEntity> promoteRentalToPublished({
    required String userId,
    required String rentalId,
    required int expectedRentalRevision,
  });
}

class RentalPromotionException implements Exception {
  const RentalPromotionException(this.message);

  final String message;

  @override
  String toString() => 'RentalPromotionException: $message';
}
