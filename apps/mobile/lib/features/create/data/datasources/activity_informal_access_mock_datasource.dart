/// Publisher id -> count of already-published Recharge Activity items with
/// `accessCaution.isInformal == true`. Starts empty — same "fresh feature,
/// no invented history" convention as Visit History v2 and Place duplicate
/// candidates being explicit demo data rather than silently pre-seeded.
const Map<String, int> mockActivityInformalAccessCounts = <String, int>{};
