import '../entities/publisher_ref.dart';
import '../entities/rental_direct_publish_decision.dart';

/// RNT-PUB-01 §1.1. Pure, no I/O — six ordered checks, first failing one
/// wins. `isVerifiedCreator` is checked first, matching the order the
/// canonical RENTAL_EQUIPMENT_CREATE_BLOCK_SPEC.md §4.2 Operation matrix
/// names its personal-column conditions ("Verified Creator + `<capability>`").
class ResolveRentalDirectPublishUseCase {
  const ResolveRentalDirectPublishUseCase();

  RentalDirectPublishDecision call(RentalDirectPublishContext context) {
    if (!context.isVerifiedCreator) {
      return const RentalDirectPublishDecision.notAuthorized(
        RentalDirectPublishReasonCode.creatorUnverified,
      );
    }
    if (!context.capabilities.contains('publish.rental.direct')) {
      return const RentalDirectPublishDecision.notAuthorized(
        RentalDirectPublishReasonCode.capabilityMissing,
      );
    }
    if (!context.isPolicyTrusted) {
      return const RentalDirectPublishDecision.notAuthorized(
        RentalDirectPublishReasonCode.policyUntrusted,
      );
    }
    if (context.draftPublisherRef.type == PublisherType.page) {
      // Deliberate, disclosed fail-closed (RNT-PUB-01 "Что изменилось в
      // v0.2"): no page-scoped membership signal reaches CreateController
      // for any Rental operation today. Real Page-publisher direct-publish
      // authorization is a separate, larger prerequisite, not this slice.
      return const RentalDirectPublishDecision.notAuthorized(
        RentalDirectPublishReasonCode.pageMembershipUnsupported,
      );
    }
    if (context.draftPublisherRef.type == PublisherType.user &&
        context.draftPublisherRef.id != context.actorUserId) {
      return const RentalDirectPublishDecision.notAuthorized(
        RentalDirectPublishReasonCode.notOwner,
      );
    }
    return const RentalDirectPublishDecision.authorized();
  }
}
