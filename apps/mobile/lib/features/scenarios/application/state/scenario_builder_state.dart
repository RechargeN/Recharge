import '../../domain/entities/scenario_draft_entity.dart';

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

class ScenarioRouteFit {
  const ScenarioRouteFit({
    required this.score,
    required this.label,
    required this.summary,
    required this.insights,
  });

  final int score;
  final String label;
  final String summary;
  final List<String> insights;
}

ScenarioRouteFit scenarioRouteFitFor(ScenarioDraftEntity draft) {
  if (draft.steps.isEmpty) {
    return const ScenarioRouteFit(
      score: 0,
      label: 'Needs stops',
      summary: 'Add at least one stop to make this route useful.',
      insights: <String>['No stops selected'],
    );
  }

  final List<String> insights = <String>[];
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
    insights.add('Trim about $durationOver min');
  } else {
    insights.add('Fits ${draft.maxDurationMinutes} min');
  }

  if (durationUnder > 0 && draft.steps.length < 3) {
    score -= 8;
    insights.add('Room for one more stop');
  }

  if (draft.freeOnly && hasPaidStep) {
    score -= 28;
    insights.add('Remove paid stops for free-only mode');
  } else if (draft.totalPriceAmount == 0) {
    insights.add('Free route');
  } else {
    insights.add('${draft.totalPriceAmount.toStringAsFixed(0)} EUR total');
  }

  if (draft.walkingOnly && hasLongTransfer) {
    score -= 18;
    insights.add('Shorten transfers for walking mode');
  } else {
    insights.add('${draft.totalDistanceKm.toStringAsFixed(1)} km total');
  }

  final int boundedScore = score.clamp(0, 100).toInt();
  final String label = boundedScore >= 85
      ? 'Ready'
      : boundedScore >= 65
      ? 'Good with tweaks'
      : 'Needs tuning';
  final String summary = boundedScore >= 85
      ? 'This route is ready for map or publishing.'
      : boundedScore >= 65
      ? 'A small optimization can make this route easier to follow.'
      : 'Optimize the route before sending it to Map or Create.';
  return ScenarioRouteFit(
    score: boundedScore,
    label: label,
    summary: summary,
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
  final Set<String> selectedCategories = draft.steps
      .map((ScenarioStepEntity step) => step.category)
      .toSet();
  final int remainingMinutes =
      draft.maxDurationMinutes - draft.totalDurationMinutes;

  return _allSteps
      .where((ScenarioStepEntity step) {
        if (selectedCategories.contains(step.category)) return false;
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
    title: 'Slow coffee start',
    subtitle: 'A quiet cafe stop before the walk.',
    category: 'food_drinks.coffee',
    durationMinutes: 35,
    distanceKm: 0.4,
    priceAmount: 4,
    isFree: false,
    latitude: 56.5097,
    longitude: 27.3352,
  ),
  ScenarioStepEntity(
    title: 'Calm city walk',
    subtitle: 'Low-pressure route through the old center.',
    category: 'wellness_recharge.calm_walk',
    durationMinutes: 55,
    distanceKm: 1.6,
    priceAmount: 0,
    isFree: true,
    latitude: 56.5112,
    longitude: 27.3304,
  ),
  ScenarioStepEntity(
    title: 'Museum reset',
    subtitle: 'Short culture stop with indoor recovery time.',
    category: 'art_culture_museums.museum',
    durationMinutes: 50,
    distanceKm: 0.9,
    priceAmount: 6,
    isFree: false,
    latitude: 56.5069,
    longitude: 27.3318,
  ),
];

const List<ScenarioStepEntity> _socialSteps = <ScenarioStepEntity>[
  ScenarioStepEntity(
    title: 'Board game table',
    subtitle: 'Meet people around a simple shared activity.',
    category: 'games_indoor.board_games',
    durationMinutes: 70,
    distanceKm: 1.2,
    priceAmount: 0,
    isFree: true,
    latitude: 56.5108,
    longitude: 27.3385,
  ),
  ScenarioStepEntity(
    title: 'Afterwork drinks',
    subtitle: 'Easy social continuation nearby.',
    category: 'music_nightlife.afterwork_drinks',
    durationMinutes: 55,
    distanceKm: 0.7,
    priceAmount: 12,
    isFree: false,
    latitude: 56.5086,
    longitude: 27.3401,
  ),
  ScenarioStepEntity(
    title: 'Live acoustic set',
    subtitle: 'Small evening event with a relaxed crowd.',
    category: 'music_nightlife.live_music',
    durationMinutes: 75,
    distanceKm: 1.8,
    priceAmount: 10,
    isFree: false,
    latitude: 56.5074,
    longitude: 27.3430,
  ),
];

const List<ScenarioStepEntity> _activeSteps = <ScenarioStepEntity>[
  ScenarioStepEntity(
    title: 'Tennis warm-up',
    subtitle: 'Beginner-friendly court time.',
    category: 'sport.tennis',
    durationMinutes: 60,
    distanceKm: 1.5,
    priceAmount: 8,
    isFree: false,
    latitude: 56.5134,
    longitude: 27.3290,
  ),
  ScenarioStepEntity(
    title: 'Park recovery walk',
    subtitle: 'Cool down without leaving the route.',
    category: 'outdoor_nature_walking.city_walk',
    durationMinutes: 35,
    distanceKm: 1.1,
    priceAmount: 0,
    isFree: true,
    latitude: 56.5161,
    longitude: 27.3262,
  ),
  ScenarioStepEntity(
    title: 'Healthy brunch',
    subtitle: 'Food stop after movement.',
    category: 'food_drinks.brunch',
    durationMinutes: 55,
    distanceKm: 0.8,
    priceAmount: 14,
    isFree: false,
    latitude: 56.5118,
    longitude: 27.3360,
  ),
];
