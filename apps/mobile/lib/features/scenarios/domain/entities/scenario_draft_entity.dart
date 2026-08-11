import '../../../../shared/primitives/money/currency_code.dart';
import '../../../../shared/primitives/money/money.dart';

enum ScenarioMood { calm, social, active }

class ScenarioStepEntity {
  const ScenarioStepEntity({
    this.id = '',
    required this.title,
    required this.subtitle,
    required this.category,
    required this.durationMinutes,
    required this.distanceKm,
    required this.price,
    required this.isFree,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String title;
  final String subtitle;
  final String category;
  final int durationMinutes;
  final double distanceKm;
  final Money price;
  final bool isFree;
  final double latitude;
  final double longitude;

  ScenarioStepEntity copyWith({String? id}) {
    return ScenarioStepEntity(
      id: id ?? this.id,
      title: title,
      subtitle: subtitle,
      category: category,
      durationMinutes: durationMinutes,
      distanceKm: distanceKm,
      price: price,
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
    required this.mood,
    required this.maxDurationMinutes,
    required this.freeOnly,
    required this.walkingOnly,
    required this.sourcePrompt,
    required this.steps,
    this.currency = CurrencyCode.eur,
  });

  final String id;
  final int revision;
  final ScenarioMood mood;
  final int maxDurationMinutes;
  final bool freeOnly;
  final bool walkingOnly;
  final String sourcePrompt;
  final List<ScenarioStepEntity> steps;
  final CurrencyCode currency;

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

  Money get totalPrice {
    return steps.fold<Money>(
      Money.zero(currency),
      (Money total, ScenarioStepEntity step) => total + step.price,
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
    CurrencyCode? currency,
  }) {
    return ScenarioDraftEntity(
      id: id ?? this.id,
      revision: revision ?? this.revision,
      mood: mood ?? this.mood,
      maxDurationMinutes: maxDurationMinutes ?? this.maxDurationMinutes,
      freeOnly: freeOnly ?? this.freeOnly,
      walkingOnly: walkingOnly ?? this.walkingOnly,
      sourcePrompt: sourcePrompt ?? this.sourcePrompt,
      steps: steps ?? this.steps,
      currency: currency ?? this.currency,
    );
  }
}
