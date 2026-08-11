import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/data/repositories/timezone_repository_impl.dart';
import 'package:recharge/features/discover/data/repositories/travel_time_repository_impl.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/geo_point.dart';
import 'package:recharge/features/discover/domain/entities/opening_hours_rule.dart';
import 'package:recharge/features/discover/domain/entities/time_fit_evaluation.dart';
import 'package:recharge/features/discover/domain/entities/time_slot.dart';
import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/shared/primitives/money/money.dart';
import 'package:recharge/features/discover/domain/entities/time_window.dart';
import 'package:recharge/features/discover/domain/repositories/travel_time_repository.dart';
import 'package:recharge/features/discover/domain/usecases/apply_time_window_usecase.dart';
import 'package:recharge/features/discover/domain/usecases/calculate_time_fit_score_usecase.dart';
import 'package:recharge/features/discover/domain/usecases/calculate_travel_times_usecase.dart';

void main() {
  test('event exactly inside travel and buffer boundaries fits', () async {
    final ApplyTimeWindowUseCase useCase = _useCase(_fallbackRepository);
    final DiscoverQuery query = _query(includeReturnTrip: true);
    final DiscoverItemEntity item = _item(
      availabilityKind: AvailabilityKind.eventSlots,
      durationMinutes: 108,
      scheduleSlots: <TimeSlot>[
        TimeSlot(
          slotId: 'slot_1',
          startAtUtc: DateTime.utc(2026, 7, 20, 10, 6),
          endAtUtc: DateTime.utc(2026, 7, 20, 11, 54),
        ),
      ],
      bufferBeforeMinutes: 5,
      bufferAfterMinutes: 5,
    );

    final DiscoverItemEntity result = (await useCase(<DiscoverItemEntity>[
      item,
    ], query)).single;

    expect(result.timeFitEvaluation!.timeFitStatus, TimeFitStatus.fits);
    expect(result.timeFitEvaluation!.selectedSlotId, 'slot_1');
    expect(result.timeFitEvaluation!.capacityStatus, CapacityStatus.available);
  });

  test('event can be partial after travel and buffers', () async {
    final ApplyTimeWindowUseCase useCase = _useCase(_fallbackRepository);
    final DiscoverItemEntity item = _item(
      availabilityKind: AvailabilityKind.eventSlots,
      durationMinutes: 60,
      scheduleSlots: <TimeSlot>[
        TimeSlot(
          slotId: 'slot_partial',
          startAtUtc: DateTime.utc(2026, 7, 20, 9, 30),
          endAtUtc: DateTime.utc(2026, 7, 20, 10, 30),
        ),
      ],
      allowsPartialAttendance: true,
      minimumVisitDurationMinutes: 20,
      bufferBeforeMinutes: 5,
      bufferAfterMinutes: 5,
    );

    final DiscoverItemEntity result = (await useCase(<DiscoverItemEntity>[
      item,
    ], _query(includeReturnTrip: true))).single;

    expect(result.timeFitEvaluation!.timeFitStatus, TimeFitStatus.partial);
    expect(result.timeFitEvaluation!.availableMinutes, 24);
  });

  test(
    'place return safety margin is skipped when return is not requested',
    () async {
      final ApplyTimeWindowUseCase useCase = _useCase(_fallbackRepository);
      final DiscoverItemEntity place = _item(
        availabilityKind: AvailabilityKind.openingHours,
        durationMinutes: 115,
        openingHours: <OpeningHoursRule>[
          OpeningHoursRule(
            dayOfWeek: DayOfWeek.monday,
            isClosedAllDay: false,
            openMinutesSinceLocalMidnight: 0,
            closeMinutesSinceLocalMidnight: 23 * 60 + 59,
          ),
        ],
      );

      final List<DiscoverItemEntity> withoutReturn = await useCase(
        <DiscoverItemEntity>[place],
        _query(includeReturnTrip: false),
      );
      final List<DiscoverItemEntity> withReturn = await useCase(
        <DiscoverItemEntity>[place],
        _query(includeReturnTrip: true),
      );

      expect(
        withoutReturn.single.timeFitEvaluation!.timeFitStatus,
        TimeFitStatus.fits,
      );
      expect(withoutReturn.single.timeFitEvaluation!.availableMinutes, 119);
      expect(withReturn, isEmpty);
    },
  );

  test(
    'unavailable requested return produces unknown rather than zero travel',
    () async {
      final ApplyTimeWindowUseCase useCase = _useCase(
        const _UnavailableTravelRepository(),
      );
      final DiscoverItemEntity event = _item(
        availabilityKind: AvailabilityKind.eventSlots,
        durationMinutes: 60,
        scheduleSlots: <TimeSlot>[
          TimeSlot(
            slotId: 'slot_unknown',
            startAtUtc: DateTime.utc(2026, 7, 20, 10, 30),
            endAtUtc: DateTime.utc(2026, 7, 20, 11, 30),
          ),
        ],
      );

      final DiscoverItemEntity result = (await useCase(<DiscoverItemEntity>[
        event,
      ], _query(includeReturnTrip: true))).single;

      expect(result.timeFitEvaluation!.timeFitStatus, TimeFitStatus.unknown);
      expect(result.timeFitEvaluation!.travelMinutes, isNull);
    },
  );

  test(
    'openNow excludes closed but keeps unknown in the second group',
    () async {
      final ApplyTimeWindowUseCase useCase = _useCase(_fallbackRepository);
      final DiscoverItemEntity closed = _item(
        availabilityKind: AvailabilityKind.openingHours,
        durationMinutes: 30,
        openingHours: <OpeningHoursRule>[
          OpeningHoursRule(dayOfWeek: DayOfWeek.monday, isClosedAllDay: true),
        ],
      );
      final DiscoverItemEntity unknown = _item(
        availabilityKind: AvailabilityKind.none,
        durationMinutes: 30,
      );
      final DiscoverQuery query = _query(
        includeReturnTrip: false,
      ).copyWith(openNow: true);

      final List<DiscoverItemEntity> result = await useCase(
        <DiscoverItemEntity>[closed, unknown],
        query,
      );

      expect(result, hasLength(1));
      expect(result.single.availabilityKind, AvailabilityKind.none);
      expect(
        result.single.timeFitEvaluation!.openingStatus,
        OpeningStatus.unknown,
      );
    },
  );

  test('onlyAvailable excludes full and unknown capacity', () async {
    final ApplyTimeWindowUseCase useCase = _useCase(_fallbackRepository);
    final DiscoverItemEntity full = _item(
      availabilityKind: AvailabilityKind.none,
      durationMinutes: 30,
      capacity: 5,
      participantsCount: 5,
    );
    final DiscoverItemEntity unknown = _item(
      availabilityKind: AvailabilityKind.none,
      durationMinutes: 30,
      capacity: null,
      participantsCount: null,
    );

    final List<DiscoverItemEntity> result = await useCase(<DiscoverItemEntity>[
      full,
      unknown,
    ], _query(includeReturnTrip: false).copyWith(onlyAvailable: true));

    expect(result, isEmpty);
  });
}

const TravelTimeRepositoryImpl _fallbackRepository = TravelTimeRepositoryImpl(
  walkingSpeedKmh: 4.8,
  walkingRouteFactor: 1.2,
  drivingSpeedKmh: 25,
  drivingRouteFactor: 1.3,
  transitSpeedKmh: 18,
  transitRouteFactor: 1.35,
);

ApplyTimeWindowUseCase _useCase(TravelTimeRepository repository) =>
    ApplyTimeWindowUseCase(
      calculateTravelTimes: CalculateTravelTimesUseCase(repository),
      timezoneRepository: TimezoneRepositoryImpl(),
      calculateTimeFitScore: const CalculateTimeFitScoreUseCase(
        timeFitWeight: 0.20,
      ),
      placeReturnSafetyRatio: 0.20,
      placeReturnSafetyMinMinutes: 5,
      placeReturnSafetyMaxMinutes: 20,
    );

DiscoverQuery _query({required bool includeReturnTrip}) =>
    DiscoverQuery.defaults(
      marketCityId: 'riga',
      centerLat: 56.9496,
      centerLng: 24.1052,
    ).copyWith(
      timeWindow: TimeWindow(
        startAtUtc: DateTime.utc(2026, 7, 20, 10),
        endAtUtc: DateTime.utc(2026, 7, 20, 12),
        timezoneId: 'UTC',
        mode: TimeWindowMode.exact,
        flexibilityMinutes: 0,
        resolvedAtUtc: DateTime.utc(2026, 7, 20, 9),
      ),
      travelContext: TravelContext(
        originType: TravelOriginType.currentLocation,
        origin: const GeoPoint(latitude: 56.9496, longitude: 24.1052),
        transportMode: TransportMode.walking,
        includeReturnTrip: includeReturnTrip,
      ),
    );

DiscoverItemEntity _item({
  required AvailabilityKind availabilityKind,
  required int durationMinutes,
  List<TimeSlot> scheduleSlots = const <TimeSlot>[],
  List<OpeningHoursRule> openingHours = const <OpeningHoursRule>[],
  bool allowsPartialAttendance = false,
  int? minimumVisitDurationMinutes,
  int bufferBeforeMinutes = 0,
  int bufferAfterMinutes = 0,
  int? capacity = 5,
  int? participantsCount = 4,
}) => DiscoverItemEntity(
  id: 'object_1',
  title: 'Object',
  subtitle: 'Subtitle',
  city: 'Riga',
  category: 'wellness_recharge',
  startsAtUtc: DateTime.utc(2026, 7, 20, 10),
  latitude: 56.9496,
  longitude: 24.1052,
  price: const Money.zero(CurrencyCode.eur),
  distanceKm: 0,
  isFree: true,
  marketCityId: 'riga',
  timezoneId: 'UTC',
  durationMinutes: durationMinutes,
  durationConfidence: DurationConfidence.exact,
  availabilityKind: availabilityKind,
  scheduleSlots: scheduleSlots,
  openingHours: openingHours,
  allowsPartialAttendance: allowsPartialAttendance,
  minimumVisitDurationMinutes: minimumVisitDurationMinutes,
  bufferBeforeMinutes: bufferBeforeMinutes,
  bufferAfterMinutes: bufferAfterMinutes,
  capacity: capacity,
  participantsCount: participantsCount,
);

class _UnavailableTravelRepository implements TravelTimeRepository {
  const _UnavailableTravelRepository();

  @override
  Future<List<TravelTimeEstimate>> estimateBatch(
    TravelTimeBatchRequest request,
  ) async => request.candidates
      .map(
        (TravelCandidate candidate) => TravelTimeEstimate(
          candidateId: candidate.candidateId,
          outboundMinutes: 1,
          returnMinutes: null,
          returnLegStatus: TravelLegStatus.unavailable,
          totalMinutes: null,
          quality: TravelEstimateQuality.unavailable,
        ),
      )
      .toList(growable: false);
}
