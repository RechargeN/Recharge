import '../../domain/entities/scenario_draft_entity.dart';
import '../../../../shared/primitives/money/money.dart';

enum ScenarioBuilderStatus { ready }

class ScenarioBuilderState {
  const ScenarioBuilderState({required this.status, required this.draft});

  factory ScenarioBuilderState.initial({
    required String draftId,
    required String Function() generateId,
  }) {
    return ScenarioBuilderState(
      status: ScenarioBuilderStatus.ready,
      draft: ScenarioDraftEntity(
        id: draftId,
        revision: 0,
        mood: ScenarioMood.calm,
        maxDurationMinutes: 150,
        freeOnly: false,
        walkingOnly: true,
        sourcePrompt: '',
        currencyCode: 'EUR',
        steps:
            scenarioStepsFor(
                  mood: ScenarioMood.calm,
                  maxDurationMinutes: 150,
                  freeOnly: false,
                  walkingOnly: true,
                )
                .map(
                  (ScenarioStepEntity step) => step.copyWith(id: generateId()),
                )
                .toList(growable: false),
      ),
    );
  }

  final ScenarioBuilderStatus status;
  final ScenarioDraftEntity draft;

  ScenarioRouteFit get routeFit => scenarioRouteFitFor(draft);

  ScenarioBuilderState copyWith({
    ScenarioBuilderStatus? status,
    ScenarioDraftEntity? draft,
  }) {
    return ScenarioBuilderState(
      status: status ?? this.status,
      draft: draft ?? this.draft,
    );
  }
}

/// L4.6: how well a Quick Plan route fits; the builder turns it into text.
enum ScenarioFitLevel { needsStops, ready, goodWithTweaks, needsTuning }

enum ScenarioFitInsightKind {
  noStops,
  trimMinutes,
  fitsMinutes,
  roomForStop,
  removePaidStops,
  freeRoute,
  totalPrice,
  shortenTransfers,
  totalDistance,
}

class ScenarioFitInsight {
  const ScenarioFitInsight(
    this.kind, {
    this.minutes = 0,
    this.price,
    this.distanceKm = 0,
  });

  final ScenarioFitInsightKind kind;
  final int minutes;
  final Money? price;
  final double distanceKm;

  @override
  bool operator ==(Object other) =>
      other is ScenarioFitInsight &&
      other.kind == kind &&
      other.minutes == minutes &&
      other.price == price &&
      other.distanceKm == distanceKm;

  @override
  int get hashCode => Object.hash(kind, minutes, price, distanceKm);
}

class ScenarioRouteFit {
  const ScenarioRouteFit({
    required this.score,
    required this.level,
    required this.insights,
  });

  final int score;
  final ScenarioFitLevel level;
  final List<ScenarioFitInsight> insights;
}

ScenarioRouteFit scenarioRouteFitFor(ScenarioDraftEntity draft) {
  if (draft.steps.isEmpty) {
    return const ScenarioRouteFit(
      score: 0,
      level: ScenarioFitLevel.needsStops,
      insights: <ScenarioFitInsight>[
        ScenarioFitInsight(ScenarioFitInsightKind.noStops),
      ],
    );
  }

  final List<ScenarioFitInsight> insights = <ScenarioFitInsight>[];
  var score = 100;
  final int durationOver =
      draft.totalDurationMinutes - draft.maxDurationMinutes;
  final int durationUnder =
      (draft.maxDurationMinutes * 0.45).round() - draft.totalDurationMinutes;
  final bool hasPaidStep = draft.steps.any(
    (ScenarioStepEntity step) => !step.isFree,
  );
  final bool hasLongTransfer = draft.steps.any(
    (ScenarioStepEntity step) => step.distanceKm > 2.2,
  );

  if (durationOver > 0) {
    score -= durationOver >= 45 ? 32 : 22;
    insights.add(
      ScenarioFitInsight(
        ScenarioFitInsightKind.trimMinutes,
        minutes: durationOver,
      ),
    );
  } else {
    insights.add(
      ScenarioFitInsight(
        ScenarioFitInsightKind.fitsMinutes,
        minutes: draft.maxDurationMinutes,
      ),
    );
  }

  if (durationUnder > 0 && draft.steps.length < 3) {
    score -= 8;
    insights.add(const ScenarioFitInsight(ScenarioFitInsightKind.roomForStop));
  }

  if (draft.freeOnly && hasPaidStep) {
    score -= 28;
    insights.add(
      const ScenarioFitInsight(ScenarioFitInsightKind.removePaidStops),
    );
  } else if (draft.totalPriceAmount.minorUnits == 0) {
    insights.add(const ScenarioFitInsight(ScenarioFitInsightKind.freeRoute));
  } else {
    insights.add(
      ScenarioFitInsight(
        ScenarioFitInsightKind.totalPrice,
        price: draft.totalPriceAmount,
      ),
    );
  }

  if (draft.walkingOnly && hasLongTransfer) {
    score -= 18;
    insights.add(
      const ScenarioFitInsight(ScenarioFitInsightKind.shortenTransfers),
    );
  } else {
    insights.add(
      ScenarioFitInsight(
        ScenarioFitInsightKind.totalDistance,
        distanceKm: draft.totalDistanceKm,
      ),
    );
  }

  final int boundedScore = score.clamp(0, 100).toInt();
  final ScenarioFitLevel level = boundedScore >= 85
      ? ScenarioFitLevel.ready
      : boundedScore >= 65
      ? ScenarioFitLevel.goodWithTweaks
      : ScenarioFitLevel.needsTuning;
  return ScenarioRouteFit(
    score: boundedScore,
    level: level,
    insights: insights.take(4).toList(growable: false),
  );
}

List<ScenarioStepEntity> scenarioStepsFor({
  required ScenarioMood mood,
  required int maxDurationMinutes,
  required bool freeOnly,
  required bool walkingOnly,
}) {
  final List<ScenarioStepEntity> source = switch (mood) {
    ScenarioMood.calm => _calmSteps,
    ScenarioMood.social => _socialSteps,
    ScenarioMood.active => _activeSteps,
  };

  final List<ScenarioStepEntity> filtered = source
      .where((ScenarioStepEntity step) {
        if (freeOnly && !step.isFree) return false;
        if (walkingOnly && step.distanceKm > 2.2) return false;
        return true;
      })
      .toList(growable: false);

  final List<ScenarioStepEntity> selected = <ScenarioStepEntity>[];
  var totalMinutes = 0;
  for (final ScenarioStepEntity step in filtered) {
    if (totalMinutes + step.durationMinutes > maxDurationMinutes &&
        selected.isNotEmpty) {
      break;
    }
    selected.add(step);
    totalMinutes += step.durationMinutes;
  }
  return selected;
}

List<ScenarioStepEntity> scenarioSuggestionsFor(ScenarioDraftEntity draft) {
  final int remainingMinutes =
      draft.maxDurationMinutes - draft.totalDurationMinutes;

  return _allSteps
      .where((ScenarioStepEntity step) {
        if (draft.freeOnly && !step.isFree) return false;
        if (draft.walkingOnly && step.distanceKm > 2.2) return false;
        if (remainingMinutes > 0 && step.durationMinutes > remainingMinutes) {
          return false;
        }
        return true;
      })
      .take(4)
      .toList(growable: false);
}

List<ScenarioStepEntity> optimizedScenarioStepsFor(ScenarioDraftEntity draft) {
  List<ScenarioStepEntity> selected = draft.steps
      .where((ScenarioStepEntity step) {
        if (draft.freeOnly && !step.isFree) return false;
        if (draft.walkingOnly && step.distanceKm > 2.2) return false;
        return true;
      })
      .toList(growable: true);

  if (selected.isEmpty) {
    selected = scenarioStepsFor(
      mood: draft.mood,
      maxDurationMinutes: draft.maxDurationMinutes,
      freeOnly: draft.freeOnly,
      walkingOnly: draft.walkingOnly,
    ).toList(growable: true);
  }

  while (selected.length > 1 &&
      _totalDuration(selected) > draft.maxDurationMinutes) {
    var longestIndex = 0;
    for (var index = 1; index < selected.length; index++) {
      if (selected[index].durationMinutes >
          selected[longestIndex].durationMinutes) {
        longestIndex = index;
      }
    }
    selected.removeAt(longestIndex);
  }

  var optimizedDraft = draft.copyWith(steps: selected);
  while (optimizedDraft.totalDurationMinutes <
      (optimizedDraft.maxDurationMinutes * 0.55).round()) {
    final List<ScenarioStepEntity> suggestions = scenarioSuggestionsFor(
      optimizedDraft,
    );
    if (suggestions.isEmpty) break;
    selected = <ScenarioStepEntity>[...selected, suggestions.first];
    optimizedDraft = optimizedDraft.copyWith(steps: selected);
  }

  return List<ScenarioStepEntity>.from(selected, growable: false);
}

int _totalDuration(List<ScenarioStepEntity> steps) {
  return steps.fold<int>(
    0,
    (int total, ScenarioStepEntity step) => total + step.durationMinutes,
  );
}

List<ScenarioStepEntity> scenarioStepsByCategories(List<String> categories) {
  final List<ScenarioStepEntity> steps = <ScenarioStepEntity>[];
  for (final String category in categories) {
    for (final ScenarioStepEntity step in _allSteps) {
      if (step.category == category) {
        steps.add(step);
        break;
      }
    }
  }
  return steps;
}

const List<ScenarioStepEntity> _allSteps = <ScenarioStepEntity>[
  ..._calmSteps,
  ..._socialSteps,
  ..._activeSteps,
];

const List<ScenarioStepEntity> _calmSteps = <ScenarioStepEntity>[
  ScenarioStepEntity(
    title:
        'Slow coffee start', // l10n-ignore: demo stop library of the legacy Quick Plan (mock content)
    subtitle:
        'A quiet cafe stop before the walk.', // l10n-ignore: demo stop library of the legacy Quick Plan (mock content)
    category: 'food_drinks.coffee',
    durationMinutes: 35,
    distanceKm: 0.4,
    priceAmount: Money(minorUnits: 400, currencyCode: 'EUR'),
    isFree: false,
    latitude: 56.5097,
    longitude: 27.3352,
  ),
  ScenarioStepEntity(
    title:
        'Calm city walk', // l10n-ignore: demo stop library of the legacy Quick Plan (mock content)
    subtitle:
        'Low-pressure route through the old center.', // l10n-ignore: demo stop library of the legacy Quick Plan (mock content)
    category: 'wellness_recharge.calm_walk',
    durationMinutes: 55,
    distanceKm: 1.6,
    priceAmount: Money(minorUnits: 0, currencyCode: 'EUR'),
    isFree: true,
    latitude: 56.5112,
    longitude: 27.3304,
  ),
  ScenarioStepEntity(
    title:
        'Museum reset', // l10n-ignore: demo stop library of the legacy Quick Plan (mock content)
    subtitle:
        'Short culture stop with indoor recovery time.', // l10n-ignore: demo stop library of the legacy Quick Plan (mock content)
    category: 'art_culture_museums.museum',
    durationMinutes: 50,
    distanceKm: 0.9,
    priceAmount: Money(minorUnits: 600, currencyCode: 'EUR'),
    isFree: false,
    latitude: 56.5069,
    longitude: 27.3318,
  ),
];

const List<ScenarioStepEntity> _socialSteps = <ScenarioStepEntity>[
  ScenarioStepEntity(
    title:
        'Board game table', // l10n-ignore: demo stop library of the legacy Quick Plan (mock content)
    subtitle:
        'Meet people around a simple shared activity.', // l10n-ignore: demo stop library of the legacy Quick Plan (mock content)
    category: 'games_indoor.board_games',
    durationMinutes: 70,
    distanceKm: 1.2,
    priceAmount: Money(minorUnits: 0, currencyCode: 'EUR'),
    isFree: true,
    latitude: 56.5108,
    longitude: 27.3385,
  ),
  ScenarioStepEntity(
    title:
        'Afterwork drinks', // l10n-ignore: demo stop library of the legacy Quick Plan (mock content)
    subtitle:
        'Easy social continuation nearby.', // l10n-ignore: demo stop library of the legacy Quick Plan (mock content)
    category: 'music_nightlife.afterwork_drinks',
    durationMinutes: 55,
    distanceKm: 0.7,
    priceAmount: Money(minorUnits: 1200, currencyCode: 'EUR'),
    isFree: false,
    latitude: 56.5086,
    longitude: 27.3401,
  ),
  ScenarioStepEntity(
    title:
        'Live acoustic set', // l10n-ignore: demo stop library of the legacy Quick Plan (mock content)
    subtitle:
        'Small evening event with a relaxed crowd.', // l10n-ignore: demo stop library of the legacy Quick Plan (mock content)
    category: 'music_nightlife.live_music',
    durationMinutes: 75,
    distanceKm: 1.8,
    priceAmount: Money(minorUnits: 1000, currencyCode: 'EUR'),
    isFree: false,
    latitude: 56.5074,
    longitude: 27.3430,
  ),
];

const List<ScenarioStepEntity> _activeSteps = <ScenarioStepEntity>[
  ScenarioStepEntity(
    title:
        'Tennis warm-up', // l10n-ignore: demo stop library of the legacy Quick Plan (mock content)
    subtitle:
        'Beginner-friendly court time.', // l10n-ignore: demo stop library of the legacy Quick Plan (mock content)
    category: 'sport.tennis',
    durationMinutes: 60,
    distanceKm: 1.5,
    priceAmount: Money(minorUnits: 800, currencyCode: 'EUR'),
    isFree: false,
    latitude: 56.5134,
    longitude: 27.3290,
  ),
  ScenarioStepEntity(
    title:
        'Park recovery walk', // l10n-ignore: demo stop library of the legacy Quick Plan (mock content)
    subtitle:
        'Cool down without leaving the route.', // l10n-ignore: demo stop library of the legacy Quick Plan (mock content)
    category: 'outdoor_nature_walking.city_walk',
    durationMinutes: 35,
    distanceKm: 1.1,
    priceAmount: Money(minorUnits: 0, currencyCode: 'EUR'),
    isFree: true,
    latitude: 56.5161,
    longitude: 27.3262,
  ),
  ScenarioStepEntity(
    title:
        'Healthy brunch', // l10n-ignore: demo stop library of the legacy Quick Plan (mock content)
    subtitle:
        'Food stop after movement.', // l10n-ignore: demo stop library of the legacy Quick Plan (mock content)
    category: 'food_drinks.brunch',
    durationMinutes: 55,
    distanceKm: 0.8,
    priceAmount: Money(minorUnits: 1400, currencyCode: 'EUR'),
    isFree: false,
    latitude: 56.5118,
    longitude: 27.3360,
  ),
];
