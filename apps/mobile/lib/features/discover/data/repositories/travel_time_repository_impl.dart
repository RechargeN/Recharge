import 'dart:math' as math;

import '../../domain/entities/geo_point.dart';
import '../../domain/entities/time_fit_evaluation.dart';
import '../../domain/entities/time_window.dart';
import '../../domain/repositories/travel_time_repository.dart';

class TravelTimeRepositoryImpl implements TravelTimeRepository {
  const TravelTimeRepositoryImpl({
    required this.walkingSpeedKmh,
    required this.walkingRouteFactor,
    required this.drivingSpeedKmh,
    required this.drivingRouteFactor,
    required this.transitSpeedKmh,
    required this.transitRouteFactor,
  });

  final double walkingSpeedKmh;
  final double walkingRouteFactor;
  final double drivingSpeedKmh;
  final double drivingRouteFactor;
  final double transitSpeedKmh;
  final double transitRouteFactor;

  @override
  Future<List<TravelTimeEstimate>> estimateBatch(
    TravelTimeBatchRequest request,
  ) async {
    return request.candidates
        .map((TravelCandidate candidate) {
          if (!request.origin.isValid || !candidate.destination.isValid) {
            return TravelTimeEstimate(
              candidateId: candidate.candidateId,
              outboundMinutes: null,
              returnMinutes: request.includeReturnTrip ? null : 0,
              returnLegStatus: request.includeReturnTrip
                  ? TravelLegStatus.unavailable
                  : TravelLegStatus.notRequested,
              totalMinutes: null,
              quality: TravelEstimateQuality.unavailable,
            );
          }
          final ({double factor, double speed}) policy =
              switch (request.transportMode) {
                TransportMode.walking => (
                  factor: walkingRouteFactor,
                  speed: walkingSpeedKmh,
                ),
                TransportMode.driving => (
                  factor: drivingRouteFactor,
                  speed: drivingSpeedKmh,
                ),
                TransportMode.transit => (
                  factor: transitRouteFactor,
                  speed: transitSpeedKmh,
                ),
              };
          final int outbound = math.max(
            1,
            (_distanceKm(request.origin, candidate.destination) *
                    policy.factor /
                    policy.speed *
                    60)
                .ceil(),
          );
          final int returnMinutes = request.includeReturnTrip ? outbound : 0;
          return TravelTimeEstimate(
            candidateId: candidate.candidateId,
            outboundMinutes: outbound,
            returnMinutes: returnMinutes,
            returnLegStatus: request.includeReturnTrip
                ? TravelLegStatus.available
                : TravelLegStatus.notRequested,
            totalMinutes: outbound + returnMinutes,
            quality: TravelEstimateQuality.fallback,
          );
        })
        .toList(growable: false);
  }

  double _distanceKm(GeoPoint from, GeoPoint to) {
    const double earthRadiusKm = 6371;
    final double dLat = _radians(to.latitude - from.latitude);
    final double dLng = _radians(to.longitude - from.longitude);
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(from.latitude)) *
            math.cos(_radians(to.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _radians(double degrees) => degrees * math.pi / 180;
}
