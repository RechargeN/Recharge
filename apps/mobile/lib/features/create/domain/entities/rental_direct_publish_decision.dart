import 'publisher_ref.dart';

/// RNT-PUB-01 §1.1. Input to [ResolveRentalDirectPublishUseCase] — built by
/// `CreateController.publishDraft()` from the just-published entity's own
/// recorded [draftPublisherRef], never from the controller's current
/// `_activePublisherRef` (which reflects whatever workspace is active *now*,
/// not necessarily the one this specific draft was saved under).
class RentalDirectPublishContext {
  const RentalDirectPublishContext({
    required this.actorUserId,
    required this.isVerifiedCreator,
    required this.capabilities,
    required this.draftPublisherRef,
    required this.isPolicyTrusted,
  });

  final String actorUserId;
  final bool isVerifiedCreator;
  final Set<String> capabilities;
  final PublisherRef draftPublisherRef;
  final bool isPolicyTrusted;
}

/// Ordered reasons a [RentalDirectPublishContext] can fail authorization —
/// the resolver reports the *first* unmet condition, not every unmet one.
enum RentalDirectPublishReasonCode {
  authorized,
  creatorUnverified,
  capabilityMissing,
  policyUntrusted,
  pageMembershipUnsupported,
  notOwner,
}

class RentalDirectPublishDecision {
  const RentalDirectPublishDecision._(this.reasonCode);

  const RentalDirectPublishDecision.authorized()
    : this._(RentalDirectPublishReasonCode.authorized);

  const RentalDirectPublishDecision.notAuthorized(
    RentalDirectPublishReasonCode reasonCode,
  ) : this._(reasonCode);

  final RentalDirectPublishReasonCode reasonCode;

  bool get authorized =>
      reasonCode == RentalDirectPublishReasonCode.authorized;
}
