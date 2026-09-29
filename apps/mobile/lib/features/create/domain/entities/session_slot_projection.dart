/// Internal-only status of a materialized candidate slot
/// (BOOKABLE_SESSION_CREATE_BLOCK_SPEC.md §11.6). Never exposed as-is to
/// Viewers — the public projector allowlists only [offeredBySchedule].
enum SessionProjectionStatus {
  offeredBySchedule,
  blockedByCreator,
  insideNoticeWindow,
  past,
  dstTransitionSkipped,
  outsideProjectionWindow,
}

/// One materialized slot in the Creator-facing (internal) projection. Not a
/// stored source of truth — always derived from `SessionSchedule` +
/// `SessionAvailabilityException` (§11.2, §16.1 invariant).
class SessionSlotProjection {
  const SessionSlotProjection({
    required this.slotKey,
    required this.scheduleRevision,
    required this.localDate,
    required this.startAtUtc,
    required this.endAtUtc,
    required this.timezoneId,
    required this.internalStatus,
    this.internalReasonCode,
  });

  final String slotKey;
  final int scheduleRevision;
  final String localDate;
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final String timezoneId;
  final SessionProjectionStatus internalStatus;
  final String? internalReasonCode;
}

class PublicSessionOffer {
  const PublicSessionOffer({
    required this.slotKey,
    required this.startAtUtc,
    required this.endAtUtc,
    required this.timezoneId,
  });

  final String slotKey;
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final String timezoneId;
}

/// Allowlist-based public projection (§11.6, §14.1). `offers` never contains
/// slots derived from private exceptions or past/notice-window candidates.
class PublicSessionScheduleProjection {
  const PublicSessionScheduleProjection({
    required this.scheduleRevision,
    required this.generatedAtUtc,
    required this.validUntilUtc,
    required this.offers,
  });

  final int scheduleRevision;
  final DateTime generatedAtUtc;
  final DateTime validUntilUtc;
  final List<PublicSessionOffer> offers;

  /// Always true (§4 terms, §11.6): Recharge never claims to know live
  /// provider availability, only that the Creator declared this time.
  bool get providerAvailabilityUnknown => true;

  bool isFresh(DateTime nowUtc) => nowUtc.isBefore(validUntilUtc);
}
