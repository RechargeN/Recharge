enum ScenarioMood {
  calm,
  social,
  active,
}

class ScenarioStepEntity {
  const ScenarioStepEntity({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.durationMinutes,
    required this.distanceKm,
    required this.priceAmount,
    required this.isFree,
    required this.latitude,
    required this.longitude,
  });

  final String title;
  final String subtitle;
  final String category;
  final int durationMinutes;
  final double distanceKm;
  final double priceAmount;
  final bool isFree;
  final double latitude;
  final double longitude;
}

class ScenarioDraftEntity {
  const ScenarioDraftEntity({
    required this.mood,
    required this.maxDurationMinutes,
    required this.freeOnly,
    required this.walkingOnly,
    required this.sourcePrompt,
    required this.steps,
  });

  final ScenarioMood mood;
  final int maxDurationMinutes;
  final bool freeOnly;
  final bool walkingOnly;
  final String sourcePrompt;
  final List<ScenarioStepEntity> steps;

  int get totalDurationMinutes {
    return steps.fold<int>(
      0,
      (int total, ScenarioStepEntity step) => total + step.durationMinutes,
    );
  }

  double get totalDistanceKm {
    return steps.fold<double>(
      0,
      (double total, ScenarioStepEntity step) => total + step.distanceKm,
    );
  }

  double get totalPriceAmount {
    return steps.fold<double>(
      0,
      (double total, ScenarioStepEntity step) => total + step.priceAmount,
    );
  }

  ScenarioDraftEntity copyWith({
    ScenarioMood? mood,
    int? maxDurationMinutes,
    bool? freeOnly,
    bool? walkingOnly,
    String? sourcePrompt,
    List<ScenarioStepEntity>? steps,
  }) {
    return ScenarioDraftEntity(
      mood: mood ?? this.mood,
      maxDurationMinutes: maxDurationMinutes ?? this.maxDurationMinutes,
      freeOnly: freeOnly ?? this.freeOnly,
      walkingOnly: walkingOnly ?? this.walkingOnly,
      sourcePrompt: sourcePrompt ?? this.sourcePrompt,
      steps: steps ?? this.steps,
    );
  }
}
