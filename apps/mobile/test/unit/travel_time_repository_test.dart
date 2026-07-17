import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/data/repositories/travel_time_repository_impl.dart';
import 'package:recharge/features/discover/domain/entities/geo_point.dart';
import 'package:recharge/features/discover/domain/entities/time_fit_evaluation.dart';
import 'package:recharge/features/discover/domain/entities/time_window.dart';
import 'package:recharge/features/discover/domain/repositories/travel_time_repository.dart';

void main() {
  const TravelTimeRepositoryImpl repository = TravelTimeRepositoryImpl(
    walkingSpeedKmh: 4.8,
    walkingRouteFactor: 1.2,
    drivingSpeedKmh: 25,
    drivingRouteFactor: 1.3,
    transitSpeedKmh: 18,
    transitRouteFactor: 1.35,
  );
  final TravelCandidate candidate = TravelCandidate(
    candidateId: 'object:slot',
    objectId: 'object',
    slotId: 'slot',
    destination: const GeoPoint(latitude: 56.9496, longitude: 24.1052),
    outboundTiming: TravelTiming(
      kind: TravelTimingKind.arriveBy,
      atUtc: DateTime.utc(2026, 7, 20, 10),
    ),
  );

  test(
    'return not requested uses explicit zero and fallback quality',
    () async {
      final List<TravelTimeEstimate> result = await repository.estimateBatch(
        TravelTimeBatchRequest(
          origin: const GeoPoint(latitude: 56.9496, longitude: 24.1052),
          transportMode: TransportMode.walking,
          includeReturnTrip: false,
          candidates: <TravelCandidate>[candidate],
        ),
      );

      expect(result.single.outboundMinutes, 1);
      expect(result.single.returnLegStatus, TravelLegStatus.notRequested);
      expect(result.single.returnMinutes, 0);
      expect(result.single.totalMinutes, 1);
      expect(result.single.quality, TravelEstimateQuality.fallback);
    },
  );

  test('requested return is available and included in total', () async {
    final TravelTimeEstimate result = (await repository.estimateBatch(
      TravelTimeBatchRequest(
        origin: const GeoPoint(latitude: 56.9496, longitude: 24.1052),
        transportMode: TransportMode.walking,
        includeReturnTrip: true,
        candidates: <TravelCandidate>[candidate],
      ),
    )).single;

    expect(result.returnLegStatus, TravelLegStatus.available);
    expect(result.returnMinutes, 1);
    expect(result.totalMinutes, 2);
  });
}
