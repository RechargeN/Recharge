import '../../../core/config/recharge_taxonomy.dart';

class SmartSearchParseResult {
  const SmartSearchParseResult({
    required this.originalText,
    required this.queryText,
    required this.selectedCategoryIds,
    required this.freeOnly,
    required this.budgetMax,
    required this.datePreset,
    required this.radiusMeters,
    required this.unlimitedRadius,
    required this.explanationChips,
    required this.routeIntent,
  });

  final String originalText;
  final String queryText;
  final List<String> selectedCategoryIds;
  final bool? freeOnly;
  final double? budgetMax;
  final SmartSearchDatePreset? datePreset;
  final double? radiusMeters;
  final bool? unlimitedRadius;
  final List<String> explanationChips;
  final SmartRouteIntent? routeIntent;
}

class SmartRouteIntent {
  const SmartRouteIntent({
    required this.mood,
    required this.durationMinutes,
    required this.freeOnly,
    required this.walkingOnly,
    required this.stepCategories,
    required this.explanationChips,
  });

  final String mood;
  final int durationMinutes;
  final bool freeOnly;
  final bool walkingOnly;
  final List<String> stepCategories;
  final List<String> explanationChips;
}

enum SmartSearchDatePreset { today, tonight }

SmartSearchParseResult parseSmartSearch(String input) {
  final String normalized = input.trim().toLowerCase();
  final List<String> chips = <String>[];
  final Set<String> categories = <String>{};
  var working = normalized;

  void removePhrase(String phrase) {
    working = working.replaceAll(phrase, ' ');
  }

  bool? freeOnly;
  if (_containsAny(working, const <String>[
    'free',
    'no ticket',
    'without ticket',
    'бесплатно',
    'бесплатный',
    'без билета',
  ])) {
    freeOnly = true;
    chips.add('free only');
    for (final String phrase in const <String>[
      'free',
      'no ticket',
      'without ticket',
      'бесплатно',
      'бесплатный',
      'без билета',
    ]) {
      removePhrase(phrase);
    }
  }

  final bool hasRouteIntent = _containsAny(working, const <String>[
    'route',
    'scenario',
    'itinerary',
    'plan route',
    'build route',
    'маршрут',
    'сценарий',
  ]);
  if (hasRouteIntent) {
    chips.add('route');
    for (final String phrase in const <String>[
      'route',
      'scenario',
      'itinerary',
      'plan route',
      'build route',
      'маршрут',
      'сценарий',
    ]) {
      removePhrase(phrase);
    }
  }

  double? budgetMax = _parseBudgetMax(working);
  if (budgetMax != null) {
    chips.add('up to ${budgetMax.toStringAsFixed(0)}');
    working = working.replaceAll(RegExp(r'(under|до|up to)\s*\d+'), ' ');
    working = working.replaceAll(RegExp(r'\d+\s*(eur|euro)'), ' ');
  }

  SmartSearchDatePreset? datePreset;
  if (_containsAny(working, const <String>['tonight', 'evening', 'вечером'])) {
    datePreset = SmartSearchDatePreset.tonight;
    chips.add('tonight');
    for (final String phrase in const <String>[
      'tonight',
      'evening',
      'вечером',
    ]) {
      removePhrase(phrase);
    }
  } else if (_containsAny(working, const <String>['today', 'сегодня'])) {
    datePreset = SmartSearchDatePreset.today;
    chips.add('today');
    for (final String phrase in const <String>['today', 'сегодня']) {
      removePhrase(phrase);
    }
  }

  final int? routeDurationMinutes = _parseRouteDurationMinutes(working);
  if (routeDurationMinutes != null) {
    chips.add('$routeDurationMinutes min');
    working = working.replaceAll(
      RegExp(r'\b\d+\s*(h|hour|hours|hr|hrs|час|часа|часов)\b'),
      ' ',
    );
    working = working.replaceAll(
      RegExp(r'\b\d+\s*(min|mins|minute|minutes|мин|минут)\b'),
      ' ',
    );
  }

  double? radiusMeters;
  bool? unlimitedRadius;
  final RegExpMatch? radiusMatch = RegExp(
    r'(near me|nearby|near|within|radius|в радиусе|рядом)\s*(\d+)?\s*(km|км)?',
  ).firstMatch(working);
  if (radiusMatch != null) {
    final String? rawValue = radiusMatch.group(2);
    radiusMeters = rawValue == null ? 5000 : double.parse(rawValue) * 1000;
    unlimitedRadius = false;
    chips.add('${(radiusMeters / 1000).round()} km');
    working = working.replaceAll(radiusMatch.group(0) ?? '', ' ');
  } else if (_containsAny(working, const <String>['anywhere', 'any area'])) {
    radiusMeters = 200000;
    unlimitedRadius = true;
    chips.add('any area');
    removePhrase('anywhere');
    removePhrase('any area');
  }

  for (final String groupId in _taxonomyGroupsFor(working)) {
    categories.add(groupId);
    chips.add(rechargeContentGroupById(groupId)?.title ?? groupId);
  }

  final String queryText = working
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .split(' ')
      .where((String token) => token.length > 1)
      .where((String token) => !_stopWords.contains(token))
      .join(' ');

  if (queryText.isNotEmpty) {
    chips.insert(0, '"$queryText"');
  }

  final SmartRouteIntent? routeIntent = hasRouteIntent
      ? _routeIntentFor(
          normalized,
          freeOnly: freeOnly ?? false,
          durationMinutes: routeDurationMinutes,
        )
      : null;

  return SmartSearchParseResult(
    originalText: input,
    queryText: queryText,
    selectedCategoryIds: categories.toList(growable: false),
    freeOnly: freeOnly,
    budgetMax: budgetMax,
    datePreset: datePreset,
    radiusMeters: radiusMeters,
    unlimitedRadius: unlimitedRadius,
    explanationChips: chips,
    routeIntent: routeIntent,
  );
}

const Set<String> _stopWords = <String>{
  'a',
  'and',
  'me',
  'for',
  'with',
  'build',
  'create',
  'plan',
  'route',
  'scenario',
  'itinerary',
  'please',
  'find',
  'show',
  'найди',
  'покажи',
};

const Map<String, List<String>> _groupIntentSignals = <String, List<String>>{
  'music_nightlife': <String>[
    'music',
    'concert',
    'party',
    'nightlife',
    'музыка',
    'концерт',
    'вечеринка',
  ],
  'comedy_theatre_performance': <String>[
    'comedy',
    'theatre',
    'standup',
    'performance',
  ],
  'cinema_screenings': <String>['cinema', 'movie', 'film', 'screening'],
  'art_culture_museums': <String>[
    'art',
    'culture',
    'museum',
    'gallery',
    'искусство',
    'культура',
    'музей',
    'галерея',
  ],
  'education_talks': <String>['lecture', 'talk', 'education', 'book club'],
  'business_networking': <String>[
    'business',
    'networking',
    'startup',
    'conference',
  ],
  'workshops_masterclasses': <String>['workshop', 'masterclass', 'craft'],
  'language_social_learning': <String>[
    'language',
    'conversation club',
    'expats',
  ],
  'food_drinks': <String>['food', 'coffee', 'brunch', 'dinner', 'drinks'],
  'games_indoor': <String>['games', 'quiz', 'chess', 'bowling'],
  'sport': <String>['sport', 'tennis', 'football', 'running', 'тренировка'],
  'dance': <String>['dance', 'salsa', 'bachata', 'tango'],
  'outdoor_nature_walking': <String>[
    'outdoor',
    'walk',
    'hiking',
    'nature',
    'прогулка',
    'парк',
    'природа',
    'поход',
  ],
  'water_activities': <String>['water activity', 'kayak', 'sup', 'sailing'],
  'winter_seasonal': <String>['winter', 'skiing', 'snowboard', 'ice skating'],
  'travel_tours': <String>['travel', 'tour', 'trip', 'excursion'],
  'family_kids': <String>[
    'family',
    'kids',
    'children',
    'дети',
    'семья',
    'семейный',
  ],
  'pets_animals': <String>['pets', 'animals', 'dog', 'cat'],
  'community_charity': <String>['community', 'charity', 'volunteer', 'cleanup'],
  'markets_fairs': <String>['market', 'fair', 'flea market'],
  'holidays_seasonal': <String>[
    'holiday',
    'christmas',
    'new year',
    'halloween',
  ],
  'wellness_recharge': <String>[
    'wellness',
    'yoga',
    'calm',
    'recharge',
    'meditation',
    'йога',
    'спокойно',
    'отдых',
  ],
};

bool _containsAny(String source, List<String> values) {
  return values.any((String value) => source.contains(value));
}

Set<String> _taxonomyGroupsFor(String source) {
  final Set<String> directMatches = <String>{};
  for (final MapEntry<String, List<String>> entry
      in _groupIntentSignals.entries) {
    if (entry.value.any(
      (String signal) => _containsTaxonomySignal(source, signal),
    )) {
      directMatches.add(entry.key);
    }
  }
  if (directMatches.isNotEmpty) return directMatches;

  final Set<String> categoryMatches = <String>{};
  for (final RechargeContentGroup group in rechargeVisibleContentGroups) {
    final Iterable<RechargeActivityCategory> groupCategories =
        rechargeActivityCategories.where(
          (RechargeActivityCategory category) =>
              category.contentGroupId == group.id,
        );
    final List<String> signals = <String>[
      group.id,
      group.title,
      for (final RechargeActivityCategory category
          in groupCategories) ...<String>[
        category.slug,
        category.title,
        ...category.aliases,
        ...category.keywordsEn,
        ...category.keywordsRu,
        ...category.keywordsLv,
      ],
    ];
    if (signals.any(
      (String signal) => _containsTaxonomySignal(source, signal),
    )) {
      categoryMatches.add(group.id);
    }
  }
  return categoryMatches;
}

bool _containsTaxonomySignal(String source, String signal) {
  final String normalized = signal.trim().toLowerCase().replaceAll('_', ' ');
  if (normalized.length < 3) return false;
  return RegExp(
    '(^|[^a-zа-яё0-9])${RegExp.escape(normalized)}([^a-zа-яё0-9]|\$)',
    caseSensitive: false,
  ).hasMatch(source);
}

double? _parseBudgetMax(String source) {
  final RegExpMatch? explicit = RegExp(
    r'(under|до|up to)\s*(\d+)',
  ).firstMatch(source);
  if (explicit != null) {
    return double.parse(explicit.group(2)!);
  }
  final RegExpMatch? currency = RegExp(
    r'(\d+)\s*(eur|euro)',
  ).firstMatch(source);
  if (currency != null) {
    return double.parse(currency.group(1)!);
  }
  return null;
}

int? _parseRouteDurationMinutes(String source) {
  final RegExpMatch? hours = RegExp(
    r'\b(\d+)\s*(h|hour|hours|hr|hrs|час|часа|часов)\b',
  ).firstMatch(source);
  if (hours != null) {
    return int.parse(hours.group(1)!) * 60;
  }
  final RegExpMatch? minutes = RegExp(
    r'\b(\d+)\s*(min|mins|minute|minutes|мин|минут)\b',
  ).firstMatch(source);
  if (minutes != null) {
    return int.parse(minutes.group(1)!);
  }
  return null;
}

SmartRouteIntent _routeIntentFor(
  String normalized, {
  required bool freeOnly,
  required int? durationMinutes,
}) {
  final String mood = _routeMoodFor(normalized);
  final bool walkingOnly = !_containsAny(normalized, const <String>[
    'car',
    'drive',
    'taxi',
    'transport',
    'by bus',
    'на машине',
    'такси',
  ]);
  final List<String> steps = _routeStepsFor(normalized, mood);
  return SmartRouteIntent(
    mood: mood,
    durationMinutes: durationMinutes ?? 120,
    freeOnly: freeOnly,
    walkingOnly: walkingOnly,
    stepCategories: steps,
    explanationChips: <String>[
      mood,
      '${durationMinutes ?? 120} min',
      freeOnly ? 'free route' : 'mixed price',
      walkingOnly ? 'walking' : 'flexible transport',
      '${steps.length} stops',
    ],
  );
}

String _routeMoodFor(String normalized) {
  if (_containsAny(normalized, const <String>[
    'active',
    'sport',
    'tennis',
    'run',
    'workout',
    'актив',
    'спорт',
  ])) {
    return 'active';
  }
  if (_containsAny(normalized, const <String>[
    'social',
    'friends',
    'party',
    'drinks',
    'evening',
    'museum',
    'music',
    'company',
    'социаль',
    'друз',
  ])) {
    return 'social';
  }
  return 'calm';
}

List<String> _routeStepsFor(String normalized, String mood) {
  final List<String> steps = <String>[];

  void add(String category) {
    if (!steps.contains(category)) steps.add(category);
  }

  if (_containsAny(normalized, const <String>['coffee', 'cafe', 'кофе'])) {
    add('food_drinks.coffee');
  }
  if (_containsAny(normalized, const <String>['walk', 'park', 'прогулка'])) {
    add('wellness_recharge.calm_walk');
  }
  if (_containsAny(normalized, const <String>['museum', 'art', 'gallery'])) {
    add('art_culture_museums.museum');
  }
  if (_containsAny(normalized, const <String>['game', 'board'])) {
    add('games_indoor.board_games');
  }
  if (_containsAny(normalized, const <String>['drink', 'bar'])) {
    add('music_nightlife.afterwork_drinks');
  }
  if (_containsAny(normalized, const <String>['tennis', 'sport'])) {
    add('sport.tennis');
  }
  if (_containsAny(normalized, const <String>['brunch', 'food'])) {
    add('food_drinks.brunch');
  }

  if (steps.isNotEmpty) return steps.take(4).toList(growable: false);

  switch (mood) {
    case 'active':
      return const <String>['sport.tennis', 'outdoor_nature_walking.city_walk'];
    case 'social':
      return const <String>[
        'games_indoor.board_games',
        'music_nightlife.afterwork_drinks',
      ];
    default:
      return const <String>[
        'food_drinks.coffee',
        'wellness_recharge.calm_walk',
      ];
  }
}
