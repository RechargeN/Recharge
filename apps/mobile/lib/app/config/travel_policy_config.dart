class TravelPolicyConfig {
  const TravelPolicyConfig({
    this.placeReturnSafetyRatio = 0.20,
    this.placeReturnSafetyMinMinutes = 5,
    this.placeReturnSafetyMaxMinutes = 20,
    this.walkingSpeedKmh = 4.8,
    this.walkingRouteFactor = 1.20,
    this.drivingSpeedKmh = 25.0,
    this.drivingRouteFactor = 1.30,
    this.transitSpeedKmh = 18.0,
    this.transitRouteFactor = 1.35,
    this.timeFitRankingEnabled = true,
    this.timeFitWeight = 0.20,
  });

  final double placeReturnSafetyRatio;
  final int placeReturnSafetyMinMinutes;
  final int placeReturnSafetyMaxMinutes;
  final double walkingSpeedKmh;
  final double walkingRouteFactor;
  final double drivingSpeedKmh;
  final double drivingRouteFactor;
  final double transitSpeedKmh;
  final double transitRouteFactor;
  final bool timeFitRankingEnabled;
  final double timeFitWeight;

  double get effectiveTimeFitWeight {
    if (!timeFitRankingEnabled || timeFitWeight < 0 || timeFitWeight > 0.30) {
      return 0;
    }
    return timeFitWeight;
  }
}
