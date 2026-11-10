import '../../../../shared/primitives/money/currency_code.dart';
import '../../../../shared/primitives/money/money.dart';

enum ScenarioMood { calm, social, active }

class ScenarioStepEntity {
  ScenarioStepEntity({
    this.id = '',
    this.sourceObjectId,
    this.sourceObjectType,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.durationMinutes,
    required this.distanceKm,
    required this.priceAmount,
    required this.isFree,
    required this.latitude,
    required this.longitude,
  }) {
    if (priceAmount.minorUnits < 0) {
      throw ArgumentError('Price must be nonnegative');
    }
  }

  final String id;
  final String? sourceObjectId;
  final String? sourceObjectType;
  final String title;
  final String subtitle;
  final String category;
  final int durationMinutes;
  final double distanceKm;
  final Money priceAmount;
  final bool isFree;
  final double latitude;
  final double longitude;

  ScenarioStepEntity copyWith({
    String? id,
    String? sourceObjectId,
    String? sourceObjectType,
  }) {
    return ScenarioStepEntity(
      id: id ?? this.id,
      sourceObjectId: sourceObjectId ?? this.sourceObjectId,
      sourceObjectType: sourceObjectType ?? this.sourceObjectType,
      title: title,
      subtitle: subtitle,
      category: category,
      durationMinutes: durationMinutes,
      distanceKm: distanceKm,
      priceAmount: priceAmount,
      isFree: isFree,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

class ScenarioDraftEntity {
  const ScenarioDraftEntity({
    required this.id,
    required this.revision,
    required this.currency,
    required this.mood,
    required this.maxDurationMinutes,
    required this.freeOnly,
    required this.walkingOnly,
    required this.sourcePrompt,
    required this.steps,
  });

  final String id;
  final int revision;
  final CurrencyCode currency;
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

  Money get totalPriceAmount => totalPriceOf(steps, currency: currency);

  bool get isFree => steps.every((step) => step.isFree);

  static Money totalPriceOf(
    Iterable<ScenarioStepEntity> steps, {
    required CurrencyCode currency,
  }) {
    return steps.fold<Money>(
      Money(minorUnits: 0, currency: currency),
      (total, step) => total + step.priceAmount,
    );
  }

  ScenarioDraftEntity copyWith({
    String? id,
    int? revision,
    ScenarioMood? mood,
    int? maxDurationMinutes,
    bool? freeOnly,
    bool? walkingOnly,
    String? sourcePrompt,
    List<ScenarioStepEntity>? steps,
  }) {
    return ScenarioDraftEntity(
      id: id ?? this.id,
      revision: revision ?? this.revision,
      currency: currency,
      mood: mood ?? this.mood,
      maxDurationMinutes: maxDurationMinutes ?? this.maxDurationMinutes,
      freeOnly: freeOnly ?? this.freeOnly,
      walkingOnly: walkingOnly ?? this.walkingOnly,
      sourcePrompt: sourcePrompt ?? this.sourcePrompt,
      steps: steps ?? this.steps,
    );
  }
}
