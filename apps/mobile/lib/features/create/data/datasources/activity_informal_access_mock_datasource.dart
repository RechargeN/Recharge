/// Actor Creator user id -> count of already-published Recharge Activity
/// items with `accessCaution.isInformal == true` (counted per authenticated
/// actor, not per `PublisherRef`, per RECHARGE_ACTIVITY_CREATE_BLOCK_SPEC.md
/// v1.4 §10). Starts empty — same "fresh feature, no invented history"
/// convention as Visit History v2 and Place duplicate candidates being
/// explicit demo data rather than silently pre-seeded.
const Map<String, int> mockActivityInformalAccessCounts = <String, int>{};
