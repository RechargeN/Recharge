enum EventArchetype {
  performance('performance'),
  screening('screening'),
  exhibition('exhibition'),
  openStage('open_stage'),
  meetGreet('meet_greet'),
  talk('talk'),
  discussion('discussion'),
  conference('conference'),
  networking('networking'),
  socialMeetup('social_meetup'),
  hostedGame('hosted_game'),
  openPlay('open_play'),
  competition('competition'),
  classSession('class_session'),
  workshop('workshop'),
  retreatCamp('retreat_camp'),
  wellnessSession('wellness_session'),
  tasting('tasting'),
  sharedMeal('shared_meal'),
  party('party'),
  celebration('celebration'),
  festival('festival'),
  marketFair('market_fair'),
  auction('auction'),
  launchPromotion('launch_promotion'),
  openDay('open_day'),
  tourExcursion('tour_excursion'),
  outdoorGathering('outdoor_gathering'),
  communityAction('community_action'),
  volunteering('volunteering'),
  fundraiser('fundraiser'),
  familyProgram('family_program'),
  ceremony('ceremony'),
  other('other');

  const EventArchetype(this.wireName);

  final String wireName;

  static EventArchetype? fromWireName(Object? value) {
    for (final EventArchetype archetype in EventArchetype.values) {
      if (archetype.wireName == value) return archetype;
    }
    return null;
  }
}

enum ParticipationMode {
  watch('watch'),
  attend('attend'),
  play('play'),
  compete('compete'),
  perform('perform'),
  practice('practice'),
  learn('learn'),
  create('create'),
  meetPeople('meet_people'),
  date('date'),
  visit('visit'),
  explore('explore'),
  eatDrink('eat_drink'),
  shop('shop'),
  support('support'),
  volunteer('volunteer'),
  travel('travel');

  const ParticipationMode(this.wireName);

  final String wireName;

  static ParticipationMode? fromWireName(Object? value) {
    for (final ParticipationMode mode in ParticipationMode.values) {
      if (mode.wireName == value) return mode;
    }
    return null;
  }
}

/// A complete and valid visitor-role selection.
class EventParticipation {
  EventParticipation({
    required this.primary,
    Set<ParticipationMode> additional = const <ParticipationMode>{},
  }) : additional = Set<ParticipationMode>.unmodifiable(additional) {
    if (this.additional.length > 3) {
      throw ArgumentError.value(
        additional,
        'additional',
        'At most three additional participation modes are allowed.',
      );
    }
    if (this.additional.contains(primary)) {
      throw ArgumentError.value(
        additional,
        'additional',
        'The primary participation mode cannot also be additional.',
      );
    }
  }

  final ParticipationMode primary;
  final Set<ParticipationMode> additional;
}

/// Editable classification state. It may be incomplete while a draft is open.
class EventClassificationDraft {
  EventClassificationDraft({
    this.archetype,
    this.primaryParticipationMode,
    Set<ParticipationMode> additionalParticipationModes =
        const <ParticipationMode>{},
    this.otherReason,
  }) : additionalParticipationModes = Set<ParticipationMode>.unmodifiable(
         additionalParticipationModes,
       );

  final EventArchetype? archetype;
  final ParticipationMode? primaryParticipationMode;
  final Set<ParticipationMode> additionalParticipationModes;
  final String? otherReason;

  bool get isComplete =>
      archetype != null &&
      primaryParticipationMode != null &&
      additionalParticipationModes.length <= 3 &&
      !additionalParticipationModes.contains(primaryParticipationMode) &&
      (archetype != EventArchetype.other ||
          (otherReason?.trim().isNotEmpty ?? false));

  EventParticipation? get participation {
    final ParticipationMode? primary = primaryParticipationMode;
    if (primary == null ||
        additionalParticipationModes.length > 3 ||
        additionalParticipationModes.contains(primary)) {
      return null;
    }
    return EventParticipation(
      primary: primary,
      additional: additionalParticipationModes,
    );
  }

  EventClassificationDraft copyWith({
    EventArchetype? archetype,
    bool clearArchetype = false,
    ParticipationMode? primaryParticipationMode,
    bool clearPrimaryParticipationMode = false,
    Set<ParticipationMode>? additionalParticipationModes,
    String? otherReason,
    bool clearOtherReason = false,
  }) {
    return EventClassificationDraft(
      archetype: clearArchetype ? null : (archetype ?? this.archetype),
      primaryParticipationMode: clearPrimaryParticipationMode
          ? null
          : (primaryParticipationMode ?? this.primaryParticipationMode),
      additionalParticipationModes:
          additionalParticipationModes ?? this.additionalParticipationModes,
      otherReason: clearOtherReason ? null : (otherReason ?? this.otherReason),
    );
  }
}
