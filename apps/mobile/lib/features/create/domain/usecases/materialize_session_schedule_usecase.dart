import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../entities/event_draft_data.dart';
import '../entities/session_draft_data.dart';
import '../entities/session_schedule.dart';
import '../entities/session_slot_projection.dart';
import '../repositories/event_timezone_repository.dart';

/// Stable technical key for a projected slot — not a Booking id, not a
/// secret (BOOKABLE_SESSION_CREATE_BLOCK_SPEC.md §11.5).
String computeSessionSlotKey({
  required String listingId,
  required int scheduleRevision,
  required String localDate,
  required int startMinuteLocal,
  required String timezoneId,
}) {
  final String input =
      'session-slot-v1|$listingId|$scheduleRevision|$localDate|'
      '$startMinuteLocal|$timezoneId';
  final Digest digest = sha256.convert(utf8.encode(input));
  return base64UrlEncode(digest.bytes).replaceAll('=', '');
}

class SessionScheduleMaterializationResult {
  const SessionScheduleMaterializationResult({
    required this.projections,
    required this.candidateCapExceeded,
  });

  final List<SessionSlotProjection> projections;

  /// True if generation stopped early after hitting
  /// [SessionSchedule.maxCandidatesPerMaterialization] — publish must fail
  /// closed on this, not silently truncate (§11.2, `session_projection_overflow`).
  final bool candidateCapExceeded;

  List<SessionSlotProjection> get offeredCandidates => projections
      .where(
        (SessionSlotProjection p) =>
            p.internalStatus == SessionProjectionStatus.offeredBySchedule,
      )
      .toList(growable: false);
}

/// Deterministic bounded materializer: `weeklyRules + slotDuration + buffer
/// + minNotice + exceptions + DST skip-policy → SessionSlotProjection[]`
/// (BOOKABLE_SESSION_CREATE_BLOCK_SPEC.md §11). A pure read-model — never a
/// stored source of truth (§14.1).
class MaterializeSessionScheduleUseCase {
  const MaterializeSessionScheduleUseCase(this._timezoneRepository);

  final EventTimezoneRepository _timezoneRepository;

  SessionScheduleMaterializationResult call({
    required String listingId,
    required SessionDraftData draft,
    DateTime? nowUtc,
  }) {
    final DateTime now = nowUtc ?? DateTime.now().toUtc();
    final SessionSchedule schedule = draft.schedule;
    final int windowDays = schedule.projectionWindowDays > 0
        ? schedule.projectionWindowDays
        : 1;
    final SessionLocalDate startDate = SessionLocalDate.fromDateTime(now);
    final DateTime noticeThreshold = now.add(
      Duration(minutes: schedule.minNoticeMinutes),
    );

    final List<SessionSlotProjection> result = <SessionSlotProjection>[];
    bool capExceeded = false;

    dayLoop:
    for (int offset = 0; offset < windowDays; offset++) {
      final SessionLocalDate date = startDate.addDays(offset);
      final int weekday = date.isoWeekday;
      final List<SessionWeeklyRule> rulesForDay =
          schedule.weeklyRules
              .where((SessionWeeklyRule r) => r.isoWeekday == weekday)
              .toList()
            ..sort(
              (SessionWeeklyRule a, SessionWeeklyRule b) =>
                  a.startMinuteLocal.compareTo(b.startMinuteLocal),
            );

      int? previousProtectedEndMinute;
      for (final SessionWeeklyRule rule in rulesForDay) {
        int cursor = rule.startMinuteLocal;
        while (cursor + schedule.slotDurationMinutes <=
            rule.endMinuteLocalExclusive) {
          if (result.length >=
              SessionSchedule.maxCandidatesPerMaterialization) {
            capExceeded = true;
            break dayLoop;
          }
          final int candidateStart = cursor;
          final int candidateEnd = cursor + schedule.slotDurationMinutes;
          final int protectedEnd =
              candidateEnd + schedule.bufferAfterSlotMinutes;
          cursor +=
              schedule.slotDurationMinutes + schedule.bufferAfterSlotMinutes;

          // Defensive-only: valid drafts never have overlapping ranges
          // (session_range_overlap blocks save), so this should be
          // unreachable in practice.
          if (previousProtectedEndMinute != null &&
              candidateStart < previousProtectedEndMinute) {
            continue;
          }
          previousProtectedEndMinute = protectedEnd;

          final String slotKey = computeSessionSlotKey(
            listingId: listingId,
            scheduleRevision: schedule.scheduleRevision,
            localDate: date.iso,
            startMinuteLocal: candidateStart,
            timezoneId: draft.timezoneId,
          );

          final ResolvedEventLocalTime? resolved = _resolve(
            date,
            candidateStart,
            draft.timezoneId,
          );
          if (resolved == null ||
              resolved.shifted ||
              resolved.ambiguousLocalTime) {
            result.add(
              SessionSlotProjection(
                slotKey: slotKey,
                scheduleRevision: schedule.scheduleRevision,
                localDate: date.iso,
                startAtUtc: DateTime.utc(
                  date.year,
                  date.month,
                  date.day,
                ).add(Duration(minutes: candidateStart)),
                endAtUtc: DateTime.utc(
                  date.year,
                  date.month,
                  date.day,
                ).add(Duration(minutes: candidateEnd)),
                timezoneId: draft.timezoneId,
                internalStatus: SessionProjectionStatus.dstTransitionSkipped,
                internalReasonCode: 'dst_transition_skipped',
              ),
            );
            continue;
          }

          final DateTime startAtUtc = resolved.utc;
          final DateTime endAtUtc = startAtUtc.add(
            Duration(minutes: schedule.slotDurationMinutes),
          );

          final SessionProjectionStatus status;
          final String? reason;
          if (startAtUtc.isBefore(noticeThreshold)) {
            status = SessionProjectionStatus.insideNoticeWindow;
            reason = 'inside_notice_window';
          } else if (!endAtUtc.isAfter(now)) {
            status = SessionProjectionStatus.past;
            reason = 'past';
          } else if (draft.exceptions.any(
            (exception) => exception.closes(
              date: date,
              candidateStartMinute: candidateStart,
              candidateEndMinute: candidateEnd,
            ),
          )) {
            status = SessionProjectionStatus.blockedByCreator;
            reason = null;
          } else {
            status = SessionProjectionStatus.offeredBySchedule;
            reason = null;
          }

          result.add(
            SessionSlotProjection(
              slotKey: slotKey,
              scheduleRevision: schedule.scheduleRevision,
              localDate: date.iso,
              startAtUtc: startAtUtc,
              endAtUtc: endAtUtc,
              timezoneId: draft.timezoneId,
              internalStatus: status,
              internalReasonCode: reason,
            ),
          );
        }
      }
    }

    return SessionScheduleMaterializationResult(
      projections: List<SessionSlotProjection>.unmodifiable(result),
      candidateCapExceeded: capExceeded,
    );
  }

  ResolvedEventLocalTime? _resolve(
    SessionLocalDate date,
    int minuteOfDay,
    String timezoneId,
  ) {
    try {
      return _timezoneRepository.resolve(
        timezoneId: timezoneId,
        year: date.year,
        month: date.month,
        day: date.day,
        minuteOfDay: minuteOfDay,
        gapPolicy: EventDstGapPolicy.reject,
        overlapPolicy: EventDstOverlapPolicy.earlierOffset,
      );
    } on EventLocalTimeException {
      return null;
    }
  }
}
