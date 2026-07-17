import 'dart:math' as math;

import '../entities/discover_item_entity.dart';
import '../entities/discover_query.dart';
import '../entities/geo_point.dart';
import '../entities/local_date.dart';
import '../entities/opening_hours_rule.dart';
import '../entities/time_fit_evaluation.dart';
import '../entities/time_slot.dart';
import '../repositories/timezone_repository.dart';
import '../repositories/travel_time_repository.dart';
import 'calculate_time_fit_score_usecase.dart';
import 'calculate_travel_times_usecase.dart';

class ApplyTimeWindowUseCase {
  const ApplyTimeWindowUseCase({
    required CalculateTravelTimesUseCase calculateTravelTimes,
    required TimezoneRepository timezoneRepository,
    required CalculateTimeFitScoreUseCase calculateTimeFitScore,
    required double placeReturnSafetyRatio,
    required int placeReturnSafetyMinMinutes,
    required int placeReturnSafetyMaxMinutes,
    void Function(String objectId)? onInvalidOpeningRule,
  }) : _calculateTravelTimes = calculateTravelTimes,
       _timezoneRepository = timezoneRepository,
       _calculateTimeFitScore = calculateTimeFitScore,
       _placeReturnSafetyRatio = placeReturnSafetyRatio,
       _placeReturnSafetyMinMinutes = placeReturnSafetyMinMinutes,
       _placeReturnSafetyMaxMinutes = placeReturnSafetyMaxMinutes,
       _onInvalidOpeningRule = onInvalidOpeningRule;

  final CalculateTravelTimesUseCase _calculateTravelTimes;
  final TimezoneRepository _timezoneRepository;
  final CalculateTimeFitScoreUseCase _calculateTimeFitScore;
  final double _placeReturnSafetyRatio;
  final int _placeReturnSafetyMinMinutes;
  final int _placeReturnSafetyMaxMinutes;
  final void Function(String objectId)? _onInvalidOpeningRule;

  Future<List<DiscoverItemEntity>> call(
    List<DiscoverItemEntity> items,
    DiscoverQuery query,
  ) async {
    final timeWindow = query.timeWindow;
    final travelContext = query.travelContext;
    if (timeWindow == null || travelContext == null) return items;

    final List<TravelCandidate> candidates = <TravelCandidate>[];
    for (final DiscoverItemEntity item in items) {
      final GeoPoint destination = GeoPoint(
        latitude: item.latitude,
        longitude: item.longitude,
      );
      if (item.availabilityKind == AvailabilityKind.eventSlots) {
        for (final TimeSlot slot in item.scheduleSlots) {
          candidates.add(
            TravelCandidate(
              candidateId: '${item.id}:${slot.slotId}',
              objectId: item.id,
              slotId: slot.slotId,
              destination: destination,
              outboundTiming: TravelTiming(
                kind: TravelTimingKind.arriveBy,
                atUtc: slot.startAtUtc.subtract(
                  Duration(minutes: item.bufferBeforeMinutes),
                ),
              ),
              returnDepartureAtUtc: travelContext.includeReturnTrip
                  ? slot.endAtUtc.add(
                      Duration(minutes: item.bufferAfterMinutes),
                    )
                  : null,
            ),
          );
        }
      } else if (item.availabilityKind == AvailabilityKind.openingHours) {
        candidates.add(
          TravelCandidate(
            candidateId: '${item.id}:place',
            objectId: item.id,
            destination: destination,
            outboundTiming: TravelTiming(
              kind: TravelTimingKind.departAt,
              atUtc: timeWindow.effectiveStartAtUtc,
            ),
            returnDepartureAtUtc: travelContext.includeReturnTrip
                ? timeWindow.effectiveEndAtUtc
                : null,
          ),
        );
      }
    }

    final Map<String, TravelTimeEstimate> estimates = candidates.isEmpty
        ? const <String, TravelTimeEstimate>{}
        : await _calculateTravelTimes(
            TravelTimeBatchRequest(
              origin: travelContext.origin,
              transportMode: travelContext.transportMode,
              includeReturnTrip: travelContext.includeReturnTrip,
              candidates: candidates,
            ),
          );

    final List<DiscoverItemEntity> evaluated = <DiscoverItemEntity>[];
    for (final DiscoverItemEntity item in items) {
      final CapacityStatus capacityStatus = _capacityStatus(item);
      final TimeFitEvaluation evaluation = switch (item.availabilityKind) {
        AvailabilityKind.eventSlots => _evaluateEvent(
          item,
          query,
          estimates,
          capacityStatus,
        ),
        AvailabilityKind.openingHours => _evaluatePlace(
          item,
          query,
          estimates,
          capacityStatus,
        ),
        AvailabilityKind.none => TimeFitEvaluation(
          objectId: item.id,
          timeFitStatus: TimeFitStatus.unknown,
          travelFitStatus: TravelFitStatus.unknown,
          openingStatus: OpeningStatus.unknown,
          capacityStatus: capacityStatus,
          requiredMinutes: item.durationMinutes,
        ),
      };
      if (evaluation.timeFitStatus == TimeFitStatus.doesNotFit) continue;
      if (query.openNow && evaluation.openingStatus == OpeningStatus.closed) {
        continue;
      }
      if (query.onlyAvailable &&
          evaluation.capacityStatus != CapacityStatus.available) {
        continue;
      }
      evaluated.add(
        item.copyWith(
          timeFitEvaluation: evaluation,
          relevanceScore: _calculateTimeFitScore(
            baseScore: item.relevanceScore,
            evaluation: evaluation,
          ),
        ),
      );
    }

    evaluated.sort((DiscoverItemEntity a, DiscoverItemEntity b) {
      final bool aConfirmed = a.timeFitEvaluation?.isConfirmed ?? false;
      final bool bConfirmed = b.timeFitEvaluation?.isConfirmed ?? false;
      if (aConfirmed != bConfirmed) return aConfirmed ? -1 : 1;
      final int score = b.relevanceScore.compareTo(a.relevanceScore);
      if (score != 0) return score;
      return a.startsAtUtc.compareTo(b.startsAtUtc);
    });
    return evaluated;
  }

  TimeFitEvaluation _evaluateEvent(
    DiscoverItemEntity item,
    DiscoverQuery query,
    Map<String, TravelTimeEstimate> estimates,
    CapacityStatus capacityStatus,
  ) {
    if (item.scheduleSlots.isEmpty) {
      return _unknown(item, capacityStatus);
    }
    final DateTime effectiveStart = query.timeWindow!.effectiveStartAtUtc;
    final DateTime effectiveEnd = query.timeWindow!.effectiveEndAtUtc;
    _EventCandidateResult? bestFull;
    _EventCandidateResult? bestPartial;
    bool hasUsableTravel = false;
    TravelEstimateQuality? lastQuality;
    for (final TimeSlot slot in item.scheduleSlots) {
      final String candidateId = '${item.id}:${slot.slotId}';
      final TravelTimeEstimate? estimate = estimates[candidateId];
      if (!_isTravelUsable(estimate, query.travelContext!.includeReturnTrip)) {
        continue;
      }
      hasUsableTravel = true;
      lastQuality = estimate!.quality;
      final int outbound = estimate.outboundMinutes!;
      final int returnMinutes = query.travelContext!.includeReturnTrip
          ? estimate.returnMinutes!
          : 0;
      final DateTime attendanceStart = effectiveStart.add(
        Duration(minutes: outbound + item.bufferBeforeMinutes),
      );
      final DateTime attendanceEnd = effectiveEnd.subtract(
        Duration(minutes: returnMinutes + item.bufferAfterMinutes),
      );
      final bool full =
          !slot.startAtUtc.isBefore(attendanceStart) &&
          !slot.endAtUtc.isAfter(attendanceEnd);
      final DateTime intersectionStart = _later(
        slot.startAtUtc,
        attendanceStart,
      );
      final DateTime intersectionEnd = _earlier(slot.endAtUtc, attendanceEnd);
      final int attendableMinutes = math.max(
        0,
        intersectionEnd.difference(intersectionStart).inMinutes,
      );
      final int windowMinutes = math.max(
        0,
        attendanceEnd.difference(attendanceStart).inMinutes,
      );
      final _EventCandidateResult candidate = _EventCandidateResult(
        candidateId: candidateId,
        slotId: slot.slotId,
        availableMinutes: attendableMinutes,
        travelMinutes: estimate.totalMinutes,
        quality: estimate.quality,
        slackMinutes:
            windowMinutes - slot.endAtUtc.difference(slot.startAtUtc).inMinutes,
      );
      if (full &&
          (bestFull == null ||
              candidate.slackMinutes < bestFull.slackMinutes)) {
        bestFull = candidate;
      } else if (!full &&
          item.allowsPartialAttendance &&
          attendableMinutes >= (item.minimumVisitDurationMinutes ?? 1) &&
          (bestPartial == null ||
              candidate.availableMinutes > bestPartial.availableMinutes)) {
        bestPartial = candidate;
      }
    }
    final _EventCandidateResult? selected = bestFull ?? bestPartial;
    if (selected != null) {
      return TimeFitEvaluation(
        objectId: item.id,
        selectedCandidateId: selected.candidateId,
        selectedSlotId: selected.slotId,
        timeFitStatus: bestFull != null
            ? TimeFitStatus.fits
            : TimeFitStatus.partial,
        travelFitStatus: TravelFitStatus.fits,
        openingStatus: OpeningStatus.open,
        capacityStatus: capacityStatus,
        requiredMinutes: bestFull != null
            ? item.durationMinutes ??
                  item.scheduleSlots
                      .firstWhere(
                        (TimeSlot slot) => slot.slotId == selected.slotId,
                      )
                      .endAtUtc
                      .difference(
                        item.scheduleSlots
                            .firstWhere(
                              (TimeSlot slot) => slot.slotId == selected.slotId,
                            )
                            .startAtUtc,
                      )
                      .inMinutes
            : item.minimumVisitDurationMinutes,
        availableMinutes: selected.availableMinutes,
        travelMinutes: selected.travelMinutes,
        quality: selected.quality,
      );
    }
    if (!hasUsableTravel) {
      return _unknown(item, capacityStatus, quality: lastQuality);
    }
    return TimeFitEvaluation(
      objectId: item.id,
      timeFitStatus: TimeFitStatus.doesNotFit,
      travelFitStatus: TravelFitStatus.doesNotFit,
      openingStatus: OpeningStatus.open,
      capacityStatus: capacityStatus,
      requiredMinutes: item.durationMinutes,
      quality: lastQuality,
    );
  }

  TimeFitEvaluation _evaluatePlace(
    DiscoverItemEntity item,
    DiscoverQuery query,
    Map<String, TravelTimeEstimate> estimates,
    CapacityStatus capacityStatus,
  ) {
    final TravelTimeEstimate? estimate = estimates['${item.id}:place'];
    if (!_isTravelUsable(estimate, query.travelContext!.includeReturnTrip) ||
        item.openingHours.isEmpty ||
        item.durationMinutes == null) {
      return _unknown(item, capacityStatus, quality: estimate?.quality);
    }
    final String timezoneId = item.timezoneId.isEmpty
        ? query.timeWindow!.timezoneId
        : item.timezoneId;
    if (!_timezoneRepository.isValidTimezone(timezoneId)) {
      return _unknown(item, capacityStatus, quality: estimate!.quality);
    }
    final DateTime effectiveStart = query.timeWindow!.effectiveStartAtUtc;
    final DateTime effectiveEnd = query.timeWindow!.effectiveEndAtUtc;
    final LocalDate startDate = _timezoneRepository
        .toLocal(effectiveStart, timezoneId)
        .date;
    final LocalDate endDate = _timezoneRepository
        .toLocal(effectiveEnd, timezoneId)
        .date;
    final int outbound = estimate!.outboundMinutes!;
    final int returnWithMargin = query.travelContext!.includeReturnTrip
        ? estimate.returnMinutes! + _returnSafetyMargin(estimate.returnMinutes!)
        : 0;
    int bestMinutes = 0;
    bool hasValidRule = false;
    bool invalidRule = false;
    for (
      LocalDate date = startDate;
      date.compareTo(endDate) <= 0;
      date = date.addDays(1)
    ) {
      final List<OpeningHoursRule> rules = _rulesForDate(
        item.openingHours,
        date,
      );
      for (final OpeningHoursRule rule in rules) {
        if (rule.isClosedAllDay) {
          hasValidRule = true;
          continue;
        }
        final int openMinutes = rule.openMinutesSinceLocalMidnight!;
        final int closeMinutes = rule.closeMinutesSinceLocalMidnight!;
        final LocalTimeResolution open = _timezoneRepository.resolveLocal(
          date: date,
          minutesSinceMidnight: openMinutes,
          timezoneId: timezoneId,
          policy: LocalBoundaryPolicy.openingStart,
        );
        final bool overnight = closeMinutes < openMinutes;
        final LocalTimeResolution close = _timezoneRepository.resolveLocal(
          date: overnight ? date.addDays(1) : date,
          minutesSinceMidnight: closeMinutes,
          timezoneId: timezoneId,
          policy: LocalBoundaryPolicy.openingEnd,
        );
        if (!open.isValid ||
            !close.isValid ||
            !open.instantUtc!.isBefore(close.instantUtc!)) {
          invalidRule = true;
          _onInvalidOpeningRule?.call(item.id);
          continue;
        }
        hasValidRule = true;
        final DateTime visitStart = _later(
          open.instantUtc!,
          effectiveStart.add(Duration(minutes: outbound)),
        );
        final DateTime visitEnd = _earlier(
          close.instantUtc!,
          effectiveEnd.subtract(Duration(minutes: returnWithMargin)),
        );
        bestMinutes = math.max(
          bestMinutes,
          math.max(0, visitEnd.difference(visitStart).inMinutes),
        );
      }
    }
    if (invalidRule && !hasValidRule) {
      return _unknown(item, capacityStatus, quality: estimate.quality);
    }
    final TimeFitStatus status;
    if (bestMinutes >= item.durationMinutes!) {
      status = TimeFitStatus.fits;
    } else if (item.allowsPartialAttendance &&
        bestMinutes >= (item.minimumVisitDurationMinutes ?? 1)) {
      status = TimeFitStatus.partial;
    } else {
      status = TimeFitStatus.doesNotFit;
    }
    return TimeFitEvaluation(
      objectId: item.id,
      selectedCandidateId: '${item.id}:place',
      timeFitStatus: status,
      travelFitStatus: status == TimeFitStatus.doesNotFit
          ? TravelFitStatus.doesNotFit
          : TravelFitStatus.fits,
      openingStatus: hasValidRule && bestMinutes > 0
          ? OpeningStatus.open
          : OpeningStatus.closed,
      capacityStatus: capacityStatus,
      requiredMinutes: status == TimeFitStatus.partial
          ? item.minimumVisitDurationMinutes
          : item.durationMinutes,
      availableMinutes: bestMinutes,
      travelMinutes: estimate.totalMinutes,
      quality: estimate.quality,
    );
  }

  List<OpeningHoursRule> _rulesForDate(
    List<OpeningHoursRule> rules,
    LocalDate date,
  ) {
    final List<OpeningHoursRule> exceptions = rules
        .where((OpeningHoursRule rule) => rule.exceptionDate == date)
        .toList(growable: false);
    if (exceptions.isNotEmpty) return exceptions;
    final int weekday = date.asUtcMidnight.weekday;
    return rules
        .where(
          (OpeningHoursRule rule) =>
              rule.exceptionDate == null &&
              rule.dayOfWeek?.index == weekday - 1,
        )
        .toList(growable: false);
  }

  bool _isTravelUsable(TravelTimeEstimate? estimate, bool includeReturnTrip) {
    if (estimate == null || estimate.outboundMinutes == null) return false;
    if (!includeReturnTrip) {
      return estimate.returnLegStatus == TravelLegStatus.notRequested &&
          estimate.returnMinutes == 0;
    }
    return estimate.returnLegStatus == TravelLegStatus.available &&
        estimate.returnMinutes != null;
  }

  int _returnSafetyMargin(int rawReturnMinutes) => math.max(
    _placeReturnSafetyMinMinutes,
    math.min(
      _placeReturnSafetyMaxMinutes,
      (rawReturnMinutes * _placeReturnSafetyRatio).ceil(),
    ),
  );

  CapacityStatus _capacityStatus(DiscoverItemEntity item) {
    final int? capacity = item.capacity;
    final int? participants = item.participantsCount;
    if (capacity == null || participants == null) return CapacityStatus.unknown;
    return participants < capacity
        ? CapacityStatus.available
        : CapacityStatus.full;
  }

  TimeFitEvaluation _unknown(
    DiscoverItemEntity item,
    CapacityStatus capacityStatus, {
    TravelEstimateQuality? quality,
  }) => TimeFitEvaluation(
    objectId: item.id,
    timeFitStatus: TimeFitStatus.unknown,
    travelFitStatus: TravelFitStatus.unknown,
    openingStatus: OpeningStatus.unknown,
    capacityStatus: capacityStatus,
    requiredMinutes: item.durationMinutes,
    quality: quality,
  );

  DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
  DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
}

class _EventCandidateResult {
  const _EventCandidateResult({
    required this.candidateId,
    required this.slotId,
    required this.availableMinutes,
    required this.travelMinutes,
    required this.quality,
    required this.slackMinutes,
  });

  final String candidateId;
  final String slotId;
  final int availableMinutes;
  final int? travelMinutes;
  final TravelEstimateQuality quality;
  final int slackMinutes;
}
