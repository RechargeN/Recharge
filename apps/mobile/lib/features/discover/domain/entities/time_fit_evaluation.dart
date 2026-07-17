enum TimeFitStatus { fits, partial, doesNotFit, unknown }

enum TravelFitStatus { fits, doesNotFit, unknown }

enum OpeningStatus { open, closed, unknown }

enum CapacityStatus { available, full, unknown }

enum TravelEstimateQuality { liveTraffic, modeled, fallback, unavailable }

class TimeFitEvaluation {
  const TimeFitEvaluation({
    required this.objectId,
    this.selectedCandidateId,
    this.selectedSlotId,
    required this.timeFitStatus,
    required this.travelFitStatus,
    required this.openingStatus,
    required this.capacityStatus,
    this.requiredMinutes,
    this.availableMinutes,
    this.travelMinutes,
    this.quality,
  });

  final String objectId;
  final String? selectedCandidateId;
  final String? selectedSlotId;
  final TimeFitStatus timeFitStatus;
  final TravelFitStatus travelFitStatus;
  final OpeningStatus openingStatus;
  final CapacityStatus capacityStatus;
  final int? requiredMinutes;
  final int? availableMinutes;
  final int? travelMinutes;
  final TravelEstimateQuality? quality;

  bool get isConfirmed =>
      timeFitStatus == TimeFitStatus.fits ||
      timeFitStatus == TimeFitStatus.partial;

  double get normalizedTimeFitScore {
    if (timeFitStatus == TimeFitStatus.fits) {
      if (requiredMinutes == null || availableMinutes == null) return 1;
      final int slack = availableMinutes! - requiredMinutes!;
      return (1 - (slack.clamp(0, 180) / 360)).clamp(0.5, 1);
    }
    if (timeFitStatus == TimeFitStatus.partial) return 0.5;
    return 0;
  }
}
