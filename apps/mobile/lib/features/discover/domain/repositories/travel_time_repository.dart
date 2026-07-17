import '../entities/geo_point.dart';
import '../entities/time_fit_evaluation.dart';
import '../entities/time_window.dart';

enum TravelTimingKind { departAt, arriveBy }

enum TravelLegStatus { notRequested, available, unavailable }

class TravelTiming {
  const TravelTiming({required this.kind, required this.atUtc});

  final TravelTimingKind kind;
  final DateTime atUtc;
}

class TravelCandidate {
  const TravelCandidate({
    required this.candidateId,
    required this.objectId,
    this.slotId,
    required this.destination,
    required this.outboundTiming,
    this.returnDepartureAtUtc,
  });

  final String candidateId;
  final String objectId;
  final String? slotId;
  final GeoPoint destination;
  final TravelTiming outboundTiming;
  final DateTime? returnDepartureAtUtc;
}

class TravelTimeBatchRequest {
  const TravelTimeBatchRequest({
    required this.origin,
    required this.transportMode,
    required this.includeReturnTrip,
    required this.candidates,
  });

  final GeoPoint origin;
  final TransportMode transportMode;
  final bool includeReturnTrip;
  final List<TravelCandidate> candidates;
}

class TravelTimeEstimate {
  const TravelTimeEstimate({
    required this.candidateId,
    required this.outboundMinutes,
    required this.returnMinutes,
    required this.returnLegStatus,
    required this.totalMinutes,
    required this.quality,
  });

  final String candidateId;
  final int? outboundMinutes;
  final int? returnMinutes;
  final TravelLegStatus returnLegStatus;
  final int? totalMinutes;
  final TravelEstimateQuality quality;
}

abstract class TravelTimeRepository {
  Future<List<TravelTimeEstimate>> estimateBatch(
    TravelTimeBatchRequest request,
  );
}
