import '../entities/event_classification.dart';

enum EventClassificationSuggestionConfidence { high, medium }

class EventClassificationSuggestion {
  const EventClassificationSuggestion({
    required this.archetype,
    required this.reasonCode,
    required this.confidence,
  });

  final EventArchetype archetype;
  final String reasonCode;
  final EventClassificationSuggestionConfidence confidence;
}

class SuggestEventClassificationUseCase {
  const SuggestEventClassificationUseCase();

  static const Map<String, EventArchetype> _subcategorySuggestions =
      <String, EventArchetype>{
        'concert': EventArchetype.performance,
        'live_music': EventArchetype.performance,
        'theatre': EventArchetype.performance,
        'stand_up': EventArchetype.performance,
        'cinema': EventArchetype.screening,
        'movie_screening': EventArchetype.screening,
        'open_air_cinema': EventArchetype.screening,
        'karaoke': EventArchetype.openStage,
        'open_mic_music': EventArchetype.openStage,
        'jam_session': EventArchetype.openStage,
        'business_networking': EventArchetype.networking,
        'hackathon': EventArchetype.competition,
        'workshop': EventArchetype.workshop,
        'masterclass': EventArchetype.workshop,
        'craft_workshop': EventArchetype.workshop,
        'cooking_class': EventArchetype.workshop,
        'food_tasting': EventArchetype.tasting,
        'drink_tasting': EventArchetype.tasting,
        'wine_tasting': EventArchetype.tasting,
        'beer_tasting': EventArchetype.tasting,
        'cocktail_tasting': EventArchetype.tasting,
        'music_festival': EventArchetype.festival,
        'film_festival': EventArchetype.festival,
        'city_festival': EventArchetype.festival,
        'summer_festival': EventArchetype.festival,
        'winter_festival': EventArchetype.festival,
      };

  static const Map<String, EventArchetype> _legacyTypeSuggestions =
      <String, EventArchetype>{
        'concert': EventArchetype.performance,
        'screening': EventArchetype.screening,
        'meetup': EventArchetype.socialMeetup,
        'workshop': EventArchetype.workshop,
        'festival': EventArchetype.festival,
        'competition': EventArchetype.competition,
      };

  EventClassificationSuggestion? call({
    required String subcategoryId,
    required String legacyEventType,
  }) {
    final EventArchetype? fromSubcategory =
        _subcategorySuggestions[subcategoryId.trim().toLowerCase()];
    if (fromSubcategory != null) {
      return EventClassificationSuggestion(
        archetype: fromSubcategory,
        reasonCode: 'canonical_subcategory_exact',
        confidence: EventClassificationSuggestionConfidence.high,
      );
    }
    final EventArchetype? fromLegacy =
        _legacyTypeSuggestions[legacyEventType.trim().toLowerCase()];
    if (fromLegacy == null) return null;
    return EventClassificationSuggestion(
      archetype: fromLegacy,
      reasonCode: 'legacy_event_type_exact',
      confidence: EventClassificationSuggestionConfidence.medium,
    );
  }
}
