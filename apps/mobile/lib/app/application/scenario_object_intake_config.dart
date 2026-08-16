import '../../features/create/domain/entities/scenario_object_intake.dart';

/// One versioned, validated policy for every external Add to Scenario entry.
class ScenarioObjectIntakeConfig {
  const ScenarioObjectIntakeConfig({
    this.schemaVersion = currentSchemaVersion,
    this.enabled = true,
    this.detailsEnabled = true,
    this.searchEnabled = true,
    this.mapEnabled = true,
    this.multiSelectEnabled = true,
    this.createNewTargetEnabled = true,
    this.maxBatchSize = 20,
    this.intentTtl = const Duration(minutes: 30),
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final bool enabled;
  final bool detailsEnabled;
  final bool searchEnabled;
  final bool mapEnabled;
  final bool multiSelectEnabled;
  final bool createNewTargetEnabled;
  final int maxBatchSize;
  final Duration intentTtl;

  bool get isValid =>
      schemaVersion == currentSchemaVersion &&
      maxBatchSize >= 1 &&
      maxBatchSize <= 20 &&
      intentTtl > Duration.zero &&
      intentTtl <= const Duration(hours: 24);

  ScenarioObjectIntakeConfig validated() {
    if (!isValid) {
      throw StateError('Invalid ScenarioObjectIntakeConfig.');
    }
    return this;
  }

  bool allowsSurface(ScenarioIntakeSourceSurface surface) {
    if (!enabled) return false;
    return switch (surface) {
      ScenarioIntakeSourceSurface.details => detailsEnabled,
      ScenarioIntakeSourceSurface.search => searchEnabled,
      ScenarioIntakeSourceSurface.map => mapEnabled,
    };
  }

  bool allowsIntent(ScenarioObjectIntakeIntent intent) {
    final count = intent.candidates.length;
    return allowsSurface(intent.sourceSurface) &&
        count >= 1 &&
        count <= maxBatchSize &&
        (count == 1 || multiSelectEnabled);
  }
}
