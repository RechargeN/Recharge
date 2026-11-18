import '../../../../shared/primitives/time/local_date.dart';
import '../../../../shared/primitives/time/utc_instant.dart';
import '../../../../shared/primitives/time/iana_time_zone.dart';

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
  SessionSlotProjection({
    required this.slotKey,
    required this.scheduleRevision,
    required String localDate,
    required this.startMinuteLocal,
    required this.endMinuteLocal,
    required DateTime? startAtUtc,
    required DateTime? endAtUtc,
    required String timezoneId,
    required this.internalStatus,
    this.internalReasonCode,
  }) : date = LocalDate.parse(localDate),
       zone = IanaTimeZone.parse(timezoneId),
       _start = startAtUtc == null ? null : UtcInstant(startAtUtc),
       _end = endAtUtc == null ? null : UtcInstant(endAtUtc) {
    if (startMinuteLocal < 0 ||
        startMinuteLocal >= 1440 ||
        endMinuteLocal <= startMinuteLocal ||
        endMinuteLocal > 1440) {
      throw ArgumentError('Invalid local slot bounds');
    }
    date.addDays(endMinuteLocal ~/ 1440);
    if (internalStatus == SessionProjectionStatus.dstTransitionSkipped) {
      if (_start != null || _end != null) {
        throw ArgumentError('A skipped local slot has no resolved UTC bounds');
      }
    } else if (_start == null ||
        _end == null ||
        !_end.value.isAfter(_start.value)) {
      throw ArgumentError('A resolved slot requires positive UTC bounds');
    }
  }

  final String slotKey;
  final int scheduleRevision;
  final LocalDate date;
  final IanaTimeZone zone;
  final int startMinuteLocal;
  final int endMinuteLocal;
  final UtcInstant? _start;
  final UtcInstant? _end;
  String get localDate => date.toString();
  String get timezoneId => zone.value;
  DateTime? get startAtUtc => _start?.value;
  DateTime? get endAtUtc => _end?.value;
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
