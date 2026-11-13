import '../entities/legacy_session_schedule.dart';
import '../entities/session_availability_exception.dart';
import '../entities/session_draft_data.dart';
import '../entities/session_price_disclosure.dart';
import '../entities/session_validation_issue.dart';
import 'materialize_session_schedule_usecase.dart';

/// Facts the validator needs but does not own — assembled by the
/// application coordinator from the shared `CreateDraftEntity` envelope
/// (title/cover/category/publisher), so this usecase stays pure and
/// independently testable (BOOKABLE_SESSION_CREATE_BLOCK_SPEC.md §13).
class SessionExternalValidationContext {
  const SessionExternalValidationContext({
    required this.categoryAllowedForSession,
    required this.hasCover,
    required this.publisherEligible,
    this.categoryCriteriaProvided = true,
  });

  final bool categoryAllowedForSession;
  final bool hasCover;
  final bool publisherEligible;

  /// Advisory only (SES-D14) — never produces a blocking issue.
  final bool categoryCriteriaProvided;
}

bool _isHttpsUrl(String value) {
  final Uri? uri = Uri.tryParse(value);
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}

/// One typed validator shared by preview, save-readiness, submit, publish
/// and update (§13). Blocking vs. warning severity mirrors §13.1/§13.2
/// exactly — category-derived dynamic criteria never escalate to blocking
/// (SES-D14, `session_category_criteria_incomplete` is the only issue this
/// usecase raises for them, and it is always a warning).
class ValidateSessionDraftUseCase {
  const ValidateSessionDraftUseCase();

  List<SessionValidationIssue> call(
    SessionDraftData draft, {
    required SessionExternalValidationContext context,
    SessionScheduleMaterializationResult? materialization,
  }) {
    final List<SessionValidationIssue> issues = <SessionValidationIssue>[];
    void blocking(String code, {String? fieldId}) => issues.add(
      SessionValidationIssue(
        code: code,
        severity: SessionValidationSeverity.blocking,
        fieldId: fieldId,
      ),
    );
    void warning(String code, {String? fieldId}) => issues.add(
      SessionValidationIssue(
        code: code,
        severity: SessionValidationSeverity.warning,
        fieldId: fieldId,
      ),
    );

    if (!context.categoryAllowedForSession) {
      blocking(SessionBlockingCode.categoryNotAllowed, fieldId: 'categoryId');
    }
    if (draft.resourceName.trim().isEmpty || draft.timezoneId.trim().isEmpty) {
      blocking(SessionBlockingCode.resourceMissing, fieldId: 'resourceName');
    }
    if (draft.timezoneId.trim().isEmpty || !draft.timezoneConfirmed) {
      blocking(SessionBlockingCode.timezoneInvalid, fieldId: 'timezoneId');
    }
    if (!draft.schedule.hasActiveWeekday) {
      blocking(SessionBlockingCode.scheduleEmpty, fieldId: 'weeklyRules');
    }
    for (final rule in draft.schedule.weeklyRules) {
      if (rule.isoWeekday < 1 || rule.isoWeekday > 7) {
        blocking(SessionBlockingCode.weekdayInvalid, fieldId: 'weeklyRules');
      }
      if (!rule.isStructurallyValid) {
        blocking(SessionBlockingCode.rangeInvalid, fieldId: 'weeklyRules');
      }
    }
    if (draft.schedule.hasOverlappingRanges) {
      blocking(SessionBlockingCode.rangeOverlap, fieldId: 'weeklyRules');
    }
    if (!draft.schedule.durationInRange) {
      blocking(
        SessionBlockingCode.durationOutOfRange,
        fieldId: 'slotDurationMinutes',
      );
    }
    if (!draft.schedule.bufferInRange) {
      blocking(
        SessionBlockingCode.bufferOutOfRange,
        fieldId: 'bufferAfterSlotMinutes',
      );
    }
    if (!draft.schedule.noticeInRange) {
      blocking(
        SessionBlockingCode.noticeOutOfRange,
        fieldId: 'minNoticeMinutes',
      );
    }
    if (materialization?.candidateCapExceeded ?? false) {
      blocking(SessionBlockingCode.projectionOverflow, fieldId: 'weeklyRules');
    }
    for (final exception in draft.exceptions) {
      if (!exception.isStructurallyValid) {
        blocking(SessionBlockingCode.exceptionInvalid, fieldId: 'exceptions');
      }
    }
    if (draft.exceptions.length >
        SessionAvailabilityException.maxActiveExceptions) {
      blocking(SessionBlockingCode.exceptionInvalid, fieldId: 'exceptions');
    }
    if (!draft.maxPartySizeInRange) {
      blocking(
        SessionBlockingCode.partySizeOutOfRange,
        fieldId: 'maxPartySize',
      );
    }
    final bool priceValid = switch (draft.price.mode) {
      SessionPricingMode.free => true,
      SessionPricingMode.fixed => draft.price.isValid,
    };
    if (!priceValid) {
      blocking(SessionBlockingCode.priceInvalid, fieldId: 'price');
    }
    if (!_isHttpsUrl(draft.externalBookingUrl)) {
      blocking(
        SessionBlockingCode.bookingUrlInvalid,
        fieldId: 'externalBookingUrl',
      );
    }
    if (!context.hasCover) {
      blocking(SessionBlockingCode.mediaIncomplete, fieldId: 'cover');
    }
    if (!context.publisherEligible) {
      blocking(
        SessionBlockingCode.publisherIneligible,
        fieldId: 'publisherRef',
      );
    }
    if (draft.legacySchedule != null &&
        draft.legacySchedule!.state == LegacySessionScheduleState.unreviewed &&
        !draft.schedule.hasActiveWeekday) {
      blocking(
        SessionBlockingCode.legacyReviewRequired,
        fieldId: 'legacySchedule',
      );
    }

    if (materialization != null &&
        !materialization.candidateCapExceeded &&
        materialization.offeredCandidates.isEmpty) {
      warning(SessionWarningCode.noOffersInWindow, fieldId: 'weeklyRules');
    }
    if (!context.categoryCriteriaProvided) {
      warning(
        SessionWarningCode.categoryCriteriaIncomplete,
        fieldId: 'categoryCriteria',
      );
    }

    return List<SessionValidationIssue>.unmodifiable(issues);
  }

  bool hasBlockingIssues(List<SessionValidationIssue> issues) =>
      issues.any((SessionValidationIssue issue) => issue.isBlocking);
}
