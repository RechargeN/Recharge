/// Public, denormalized verification badge state for a
/// `PublishedEventDiscoveryEntity` publisher
/// (`docs/product/discover/DTL_EVT_01_EVENT_DETAILS_SLICE_SPEC.md` §2.3).
///
/// Never a live Identity-domain lookup — Discover does not import
/// Identity-domain types. An adapter collapses Identity's five-state
/// `verificationStatus` (`unverified | pending | verified | rejected |
/// revoked`, `IDENTITY_PUBLISHER_SLICE_SPEC.md:278`) into one of the three
/// values below at publish time:
///
/// - `verified` + a Creator publisher → [verifiedCreator];
/// - `verified` + a Page publisher → [verifiedPage];
/// - everything else — including `revoked`, deliberately not conflated
///   with "never verified" the way a nullable timestamp would —
///   → [none].
///
/// A verified badge renders if and only if this is not [none]
/// (`IDENTITY_PUBLISHER_SLICE_SPEC.md:642`: "separate Creator/page
/// verification badges").
enum PublisherVerificationDisplayState { none, verifiedCreator, verifiedPage }
