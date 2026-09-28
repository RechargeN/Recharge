enum SessionValidationSeverity { blocking, warning }

/// A single validator finding, keyed by a stable code
/// (BOOKABLE_SESSION_CREATE_BLOCK_SPEC.md §13). Category-derived dynamic
/// criteria fields (skill_level, equipment_provided, ...) never produce a
/// `blocking` issue for Session — see `session_category_criteria_incomplete`,
/// which is `warning`-only by construction (SES-D14).
class SessionValidationIssue {
  const SessionValidationIssue({
    required this.code,
    required this.severity,
    this.fieldId,
  });

  final String code;
  final SessionValidationSeverity severity;
  final String? fieldId;

  bool get isBlocking => severity == SessionValidationSeverity.blocking;

  @override
  bool operator ==(Object other) =>
      other is SessionValidationIssue &&
      code == other.code &&
      severity == other.severity &&
      fieldId == other.fieldId;

  @override
  int get hashCode => Object.hash(code, severity, fieldId);

  @override
  String toString() => 'SessionValidationIssue($code, $severity)';
}

/// Canonical §13.1 blocking codes.
abstract final class SessionBlockingCode {
  static const String categoryNotAllowed = 'session_category_not_allowed';
  static const String resourceMissing = 'session_resource_missing';
  static const String timezoneInvalid = 'session_timezone_invalid';
  static const String scheduleEmpty = 'session_schedule_empty';
  static const String weekdayInvalid = 'session_weekday_invalid';
  static const String rangeInvalid = 'session_range_invalid';
  static const String rangeOverlap = 'session_range_overlap';
  static const String durationOutOfRange = 'session_duration_out_of_range';
  static const String bufferOutOfRange = 'session_buffer_out_of_range';
  static const String noticeOutOfRange = 'session_notice_out_of_range';
  static const String projectionOverflow = 'session_projection_overflow';
  static const String exceptionInvalid = 'session_exception_invalid';
  static const String partySizeOutOfRange = 'session_party_size_out_of_range';
  static const String priceInvalid = 'session_price_invalid';
  static const String bookingUrlInvalid = 'session_booking_url_invalid';
  static const String mediaIncomplete = 'session_media_incomplete';
  static const String publisherIneligible = 'session_publisher_ineligible';
  static const String legacyReviewRequired = 'session_legacy_review_required';
}

/// Canonical §13.2 warning codes.
abstract final class SessionWarningCode {
  static const String noOffersInWindow = 'session_no_offers_in_window';
  static const String candidatesDroppedForBuffer =
      'session_candidates_dropped_for_buffer';
  static const String dstSlotsSkipped = 'session_dst_slots_skipped';
  static const String externalStateUnknown = 'session_external_state_unknown';
  static const String materialRevision = 'session_material_revision';
  static const String categoryCriteriaIncomplete =
      'session_category_criteria_incomplete';
}
