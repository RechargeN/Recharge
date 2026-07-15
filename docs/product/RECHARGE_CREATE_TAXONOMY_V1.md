# Recharge Create Taxonomy v1

Status: Source of truth  
Last updated: 2026-05-09  
Owner: Recharge product and engineering

This document defines the stable create taxonomy used by Recharge for create
flows, filters, search, recommendations, moderation, and future API contracts.

The taxonomy must be used as the reference before adding a new create block,
content group, activity category, participation mode, rule, or create preset.

## 1. Core Formula

Every created object follows the same structure:

```text
Create Block -> Content Group -> Activity Category -> Participation Mode -> Details -> Rules / Options
```

Example:

```text
Event -> Sport -> Tennis -> Play -> friendly tennis match -> paid, limited seats
```

## 2. Fixed Create Blocks

Create Block answers: what is the user creating?

```text
event
quick_plan
social_request
private_plan
route
place
venue
bookable_slot
offer
announcement
```

Definitions:

| Create block | Meaning |
|---|---|
| `event` | Public or listed activity with date, time, location, and attendees. |
| `quick_plan` | Lightweight plan for now, today, tonight, or the next few hours. |
| `social_request` | Request to find people for a specific activity. |
| `private_plan` | Invite-only plan for friends, couples, family, team, or closed group. |
| `route` | Path or scenario made of one or more points. |
| `place` | Public spot or map point. |
| `venue` | Business, creator, studio, club, cafe, bar, museum, or activity venue page. |
| `bookable_slot` | Time-based service, court, class, table, tour, session, or availability slot. |
| `offer` | Discount, happy hour, package, guest list, or special deal. |
| `announcement` | Update from a venue, creator, organizer, or community. |

## 3. Fixed Content Groups

Content Group answers: what domain is this about?

```text
music_nightlife
comedy_theatre_performance
cinema_screenings
art_culture_museums
education_talks
business_networking
workshops_masterclasses
language_social_learning
food_drinks
games_indoor
sport
dance
outdoor_nature_walking
water_activities
winter_seasonal
travel_tours
family_kids
pets_animals
community_charity
markets_fairs
holidays_seasonal
wellness_recharge
```

## 4. Participation Modes

Participation Mode answers: what does the user do with the category?

Category names must not contain the action. For example, use `tennis` as the
category and `play`, `watch`, or `book` as the mode.

User modes:

```text
watch
attend
play
learn
practice
meet_people
book
visit
explore
compete
volunteer
shop
eat_drink
travel
claim
```

Creator action modes:

```text
host
organize
publish
guide
teach
perform
sell_slot
create_offer
create_venue_page
create_private_plan
announce
```

Mode groups:

```text
passive_modes:
watch, attend, visit

active_modes:
play, practice, compete, learn, volunteer

social_modes:
meet_people

transaction_modes:
book, claim, shop, eat_drink

discovery_modes:
explore, travel
```

## 5. Rules And Options

Rules answer: under what conditions can the user access or use the object?

Rules are not categories and are not create blocks.

```text
free
paid
registration_required
booking_required
approval_required
guest_list
waitlist
limited_seats
age_limit
dress_code
equipment_included
equipment_available
beginner_friendly
family_friendly
pet_friendly
wheelchair_accessible
rain_cancellation
refund_policy
late_entry_allowed
invite_only
friends_only
hidden_from_public
share_by_link
```

## 6. Category Data Model

Every materialized activity category must expose this full shape to product
logic, UI, search, moderation, and analytics.

```ts
type CategoryStatus = "active" | "seasonal" | "deprecated" | "hidden";
type ModerationLevel = "none" | "standard" | "strict";

type ActivityCategory = {
  id: string;
  title: string;

  content_group: string;
  secondary_groups: string[];

  slug: string;
  aliases: string[];
  search_keywords: string[];

  allowed_create_blocks: string[];
  allowed_participation_modes: string[];

  default_participation_mode: string;
  default_participation_mode_by_create_block?: Record<string, string>;

  is_seasonal: boolean;
  is_family_friendly: boolean;
  is_pet_friendly: boolean;

  status: CategoryStatus;
  moderation_level: ModerationLevel;
};
```

Required generation rules:

```text
id = {content_group}_{slug}
title = human-readable title generated from slug unless overridden
content_group = canonical group from the master list
secondary_groups = extra display/search groups, default []
aliases = normalized synonyms, default []
search_keywords = slug tokens + aliases + curated extra keywords
status = active unless the category is seasonal, deprecated, or hidden
moderation_level = standard unless a category override says otherwise
allowed_create_blocks = inherited from group defaults unless overridden
allowed_participation_modes = inherited from group defaults unless overridden
default_participation_mode = inherited from group defaults unless overridden
```

## 7. Duplicate Policy

Each category has one canonical `content_group`.

The same category can appear in extra discovery surfaces through
`secondary_groups`, but the canonical category object remains one object.

Do not create independent duplicates when the meaning is the same.

Examples:

```ts
{
  id: "pets_animals_dog_walk",
  slug: "dog_walk",
  content_group: "pets_animals",
  secondary_groups: ["outdoor_nature_walking", "wellness_recharge"]
}

{
  id: "sport_swimming",
  slug: "swimming",
  content_group: "sport",
  secondary_groups: ["water_activities"]
}

{
  id: "games_indoor_mini_golf",
  slug: "mini_golf",
  content_group: "games_indoor",
  secondary_groups: ["sport"]
}
```

If two labels are only naming variations, use `aliases`.

If two labels are similar but not the same user intent, use separate categories
and connect them through search keywords or secondary groups.

## 8. Format-Like Category Policy

Some labels are formats, not pure categories. They are allowed as categories
only when users naturally search or filter for them as standalone activities.

Keep as activity categories:

```text
open_air_cinema
museum_night
business_breakfast
bar_crawl
pub_crawl
film_festival
music_festival
christmas_market
night_market
speed_friending
```

Move to `details`, `tags`, or `presets`:

```text
one_day_course
weekend_course
guided_museum_tour
sunset_boat_ride
beginner_class
morning_session
friendly_match
private_screening
public_match_screening
```

Rule:

```text
If it is a common standalone user intent, it can be a category.
If it describes level, size, time, mood, duration, access, or one event variant,
it must be a detail, tag, preset, or rule.
```

## 9. Category Vs Detail Boundary

Activity Category answers: what is it?

Details answer: which version is this?

Do not put these in category names:

```text
group size: 5v5, 2 people, group of 10
level: beginner, intermediate, advanced
time: morning, evening, weekend
mood: calm, romantic, energetic
specific scenario: friendly match, first lesson, private dinner
duration: 1 hour, half-day
price: free, paid, discount
access condition: invite-only, approval required, guest list
```

Examples:

```text
Correct:
Sport -> Tennis -> Play -> friendly tennis match

Incorrect:
Sport -> Friendly Tennis Match
```

```text
Correct:
Cinema Screenings -> Cinema -> Watch -> open-air movie night

Incorrect:
Cinema Screenings -> Watch Open-Air Movie With Friends
```

## 10. Group Boundary Rules

Use these rules when a category could fit multiple groups.

### outdoor_nature_walking vs wellness_recharge

```text
outdoor_nature_walking = place, walk, nature, route, movement, discovery
wellness_recharge = recovery, calm, reset, mental state, low-pressure social
```

Examples:

```text
city_walk -> outdoor_nature_walking
calm_walk -> wellness_recharge
```

### travel_tours vs route

```text
travel_tours = experience, trip, excursion, guide-led/local experience
route = create block that stores path structure and ordered points
```

Example:

```text
city_tour -> travel_tours
coffee_route -> route create block detail, not a content group
```

### sport vs games_indoor

```text
sport = physical activity, training, match, race, competition
games_indoor = board, table, arcade, quest, intellectual or indoor leisure games
```

Examples:

```text
tennis -> sport
board_games -> games_indoor
mini_golf -> games_indoor with secondary group sport
```

### food_drinks vs music_nightlife

```text
food_drinks = eating, drinks, tasting, cafes, restaurants, food routes
music_nightlife = music, parties, clubs, nightlife programming
```

Examples:

```text
cocktail_tasting -> food_drinks
club_night -> music_nightlife
```

## 11. Mapping Matrix Defaults

Each category inherits its mapping from the canonical content group unless a
category override is listed in section 13.

```ts
const groupMappingDefaults = {
  music_nightlife: {
    allowed_create_blocks: ["event", "quick_plan", "social_request", "private_plan", "place", "venue", "bookable_slot", "offer", "announcement"],
    allowed_participation_modes: ["watch", "attend", "meet_people", "book", "visit", "eat_drink", "claim"],
    default_participation_mode: "attend"
  },

  comedy_theatre_performance: {
    allowed_create_blocks: ["event", "quick_plan", "social_request", "private_plan", "place", "venue", "bookable_slot", "offer", "announcement"],
    allowed_participation_modes: ["watch", "attend", "learn", "meet_people", "book", "visit", "claim"],
    default_participation_mode: "watch"
  },

  cinema_screenings: {
    allowed_create_blocks: ["event", "quick_plan", "social_request", "private_plan", "place", "venue", "bookable_slot", "offer", "announcement"],
    allowed_participation_modes: ["watch", "attend", "meet_people", "book", "visit", "claim"],
    default_participation_mode: "watch"
  },

  art_culture_museums: {
    allowed_create_blocks: ["event", "quick_plan", "social_request", "private_plan", "route", "place", "venue", "bookable_slot", "offer", "announcement"],
    allowed_participation_modes: ["visit", "attend", "learn", "explore", "meet_people", "book", "claim"],
    default_participation_mode: "visit"
  },

  education_talks: {
    allowed_create_blocks: ["event", "quick_plan", "social_request", "private_plan", "venue", "bookable_slot", "offer", "announcement"],
    allowed_participation_modes: ["attend", "learn", "meet_people", "book", "claim"],
    default_participation_mode: "learn"
  },

  business_networking: {
    allowed_create_blocks: ["event", "quick_plan", "social_request", "private_plan", "venue", "bookable_slot", "offer", "announcement"],
    allowed_participation_modes: ["attend", "learn", "meet_people", "book", "claim"],
    default_participation_mode: "attend"
  },

  workshops_masterclasses: {
    allowed_create_blocks: ["event", "quick_plan", "social_request", "private_plan", "venue", "bookable_slot", "offer", "announcement"],
    allowed_participation_modes: ["learn", "practice", "attend", "meet_people", "book", "claim"],
    default_participation_mode: "learn"
  },

  language_social_learning: {
    allowed_create_blocks: ["event", "quick_plan", "social_request", "private_plan", "route", "place", "venue", "bookable_slot", "offer", "announcement"],
    allowed_participation_modes: ["practice", "learn", "meet_people", "attend", "book", "explore", "claim"],
    default_participation_mode: "practice"
  },

  food_drinks: {
    allowed_create_blocks: ["event", "quick_plan", "social_request", "private_plan", "route", "place", "venue", "bookable_slot", "offer", "announcement"],
    allowed_participation_modes: ["eat_drink", "meet_people", "visit", "book", "explore", "shop", "claim"],
    default_participation_mode: "eat_drink"
  },

  games_indoor: {
    allowed_create_blocks: ["event", "quick_plan", "social_request", "private_plan", "place", "venue", "bookable_slot", "offer", "announcement"],
    allowed_participation_modes: ["play", "compete", "meet_people", "book", "attend", "visit", "claim"],
    default_participation_mode: "play"
  },

  sport: {
    allowed_create_blocks: ["event", "quick_plan", "social_request", "private_plan", "place", "venue", "bookable_slot", "offer", "announcement"],
    allowed_participation_modes: ["watch", "play", "practice", "learn", "meet_people", "book", "compete", "visit", "claim"],
    default_participation_mode: "play"
  },

  dance: {
    allowed_create_blocks: ["event", "quick_plan", "social_request", "private_plan", "place", "venue", "bookable_slot", "offer", "announcement"],
    allowed_participation_modes: ["learn", "practice", "attend", "watch", "meet_people", "book", "compete", "claim"],
    default_participation_mode: "practice"
  },

  outdoor_nature_walking: {
    allowed_create_blocks: ["event", "quick_plan", "social_request", "private_plan", "route", "place", "venue", "bookable_slot", "offer", "announcement"],
    allowed_participation_modes: ["explore", "visit", "meet_people", "practice", "play", "attend", "travel", "book", "claim"],
    default_participation_mode: "explore"
  },

  water_activities: {
    allowed_create_blocks: ["event", "quick_plan", "social_request", "private_plan", "route", "place", "venue", "bookable_slot", "offer", "announcement"],
    allowed_participation_modes: ["practice", "play", "explore", "travel", "book", "meet_people", "watch", "claim"],
    default_participation_mode: "practice"
  },

  winter_seasonal: {
    allowed_create_blocks: ["event", "quick_plan", "social_request", "private_plan", "route", "place", "venue", "bookable_slot", "offer", "announcement"],
    allowed_participation_modes: ["play", "practice", "explore", "visit", "meet_people", "book", "watch", "claim"],
    default_participation_mode: "explore"
  },

  travel_tours: {
    allowed_create_blocks: ["event", "quick_plan", "social_request", "private_plan", "route", "place", "venue", "bookable_slot", "offer", "announcement"],
    allowed_participation_modes: ["travel", "explore", "visit", "attend", "book", "meet_people", "claim"],
    default_participation_mode: "travel"
  },

  family_kids: {
    allowed_create_blocks: ["event", "quick_plan", "social_request", "private_plan", "route", "place", "venue", "bookable_slot", "offer", "announcement"],
    allowed_participation_modes: ["attend", "play", "learn", "visit", "explore", "book", "meet_people", "claim"],
    default_participation_mode: "attend"
  },

  pets_animals: {
    allowed_create_blocks: ["event", "quick_plan", "social_request", "private_plan", "route", "place", "venue", "bookable_slot", "offer", "announcement"],
    allowed_participation_modes: ["visit", "meet_people", "practice", "learn", "explore", "volunteer", "book", "claim"],
    default_participation_mode: "meet_people"
  },

  community_charity: {
    allowed_create_blocks: ["event", "quick_plan", "social_request", "private_plan", "place", "venue", "bookable_slot", "offer", "announcement"],
    allowed_participation_modes: ["volunteer", "attend", "meet_people", "visit", "shop", "claim"],
    default_participation_mode: "volunteer"
  },

  markets_fairs: {
    allowed_create_blocks: ["event", "quick_plan", "social_request", "private_plan", "route", "place", "venue", "offer", "announcement"],
    allowed_participation_modes: ["shop", "visit", "eat_drink", "attend", "meet_people", "claim"],
    default_participation_mode: "shop"
  },

  holidays_seasonal: {
    allowed_create_blocks: ["event", "quick_plan", "social_request", "private_plan", "route", "place", "venue", "bookable_slot", "offer", "announcement"],
    allowed_participation_modes: ["attend", "visit", "watch", "eat_drink", "shop", "explore", "meet_people", "claim"],
    default_participation_mode: "attend"
  },

  wellness_recharge: {
    allowed_create_blocks: ["event", "quick_plan", "social_request", "private_plan", "route", "place", "venue", "bookable_slot", "offer", "announcement"],
    allowed_participation_modes: ["practice", "explore", "visit", "attend", "meet_people", "book", "claim"],
    default_participation_mode: "practice"
  }
};
```

## 12. Activity Categories Master List

This is the canonical `Content Group -> Activity Category` list for v1.

Unlisted categories are not valid for create flow until added to this document.

```ts
const activityCategoriesMasterList = {
  music_nightlife: [
    "concert",
    "live_music",
    "acoustic_evening",
    "jazz",
    "classical_music",
    "rock_music",
    "pop_music",
    "electronic_music",
    "techno",
    "house_music",
    "latin_music",
    "dj_party",
    "club_night",
    "karaoke",
    "open_mic_music",
    "rooftop_party",
    "beach_party",
    "themed_party",
    "music_festival",
    "listening_party",
    "jam_session",
    "night_bar",
    "afterwork_drinks",
    "late_night_social"
  ],

  comedy_theatre_performance: [
    "standup",
    "comedy_open_mic",
    "theatre",
    "improvisation",
    "magic_show",
    "circus",
    "poetry_night",
    "storytelling",
    "puppet_show",
    "ballet",
    "opera",
    "cabaret",
    "street_performance",
    "performance_art",
    "drag_show",
    "musical",
    "experimental_theatre"
  ],

  cinema_screenings: [
    "cinema",
    "movie_screening",
    "open_air_cinema",
    "film_festival",
    "documentary",
    "short_films",
    "retro_cinema",
    "animation",
    "sports_screening",
    "movie_discussion",
    "premiere",
    "independent_film",
    "cinema_club"
  ],

  art_culture_museums: [
    "exhibition",
    "gallery",
    "museum",
    "museum_night",
    "gallery_walk",
    "artist_talk",
    "art_walk",
    "photography_exhibition",
    "street_art",
    "architecture",
    "cultural_heritage",
    "literature_evening",
    "book_reading",
    "history_walk",
    "design_event",
    "craft_exhibition",
    "public_art",
    "creative_meetup"
  ],

  education_talks: [
    "lecture",
    "public_talk",
    "discussion",
    "debate",
    "panel_discussion",
    "science_talk",
    "history_lecture",
    "psychology_talk",
    "finance_talk",
    "career_talk",
    "legal_info_session",
    "book_club",
    "practical_seminar",
    "self_development",
    "health_talk",
    "technology_talk",
    "startup_talk",
    "parenting_talk",
    "community_discussion"
  ],

  business_networking: [
    "networking",
    "business_breakfast",
    "business_lunch",
    "conference",
    "product_presentation",
    "product_launch",
    "startup_meetup",
    "pitch_night",
    "investor_meetup",
    "job_fair",
    "portfolio_review",
    "freelancers_meetup",
    "demo_day",
    "expo",
    "founder_meetup",
    "industry_meetup",
    "career_networking",
    "coworking_event",
    "business_workshop"
  ],

  workshops_masterclasses: [
    "workshop",
    "masterclass",
    "course",
    "pottery",
    "ceramics",
    "drawing",
    "painting",
    "photography",
    "cooking_class",
    "sewing",
    "floristics",
    "candle_making",
    "public_speaking",
    "creative_class",
    "craft_workshop",
    "writing_workshop",
    "music_lesson",
    "dance_workshop",
    "beauty_workshop",
    "wellness_workshop"
  ],

  language_social_learning: [
    "language_exchange",
    "english_club",
    "dutch_club",
    "latvian_club",
    "conversation_club",
    "international_meetup",
    "expats_meetup",
    "tandem_meeting",
    "language_cafe",
    "language_walk",
    "speed_friending",
    "speaking_club",
    "culture_exchange",
    "newcomers_meetup",
    "study_group"
  ],

  food_drinks: [
    "coffee",
    "breakfast",
    "brunch",
    "lunch",
    "dinner",
    "dessert",
    "street_food",
    "food_tasting",
    "drink_tasting",
    "wine_tasting",
    "beer_tasting",
    "cocktail_tasting",
    "tea_ceremony",
    "bbq",
    "picnic",
    "food_tour",
    "bar_crawl",
    "pub_crawl",
    "happy_hour",
    "cooking_class",
    "restaurant_visit",
    "cafe_visit",
    "bakery_visit",
    "vegan_food",
    "local_food",
    "fine_dining",
    "family_meal"
  ],

  games_indoor: [
    "quiz",
    "board_games",
    "mafia",
    "poker_no_gambling",
    "chess",
    "escape_room",
    "quest",
    "city_game",
    "treasure_hunt",
    "bowling",
    "billiards",
    "darts",
    "mini_golf",
    "arcade",
    "vr_arcade",
    "video_games",
    "table_games",
    "card_games",
    "role_playing_game",
    "indoor_competition"
  ],

  sport: [
    "football",
    "basketball",
    "volleyball",
    "beach_volleyball",
    "tennis",
    "table_tennis",
    "badminton",
    "squash",
    "padel",
    "running",
    "trail_running",
    "cycling",
    "swimming",
    "boxing",
    "martial_arts",
    "climbing",
    "bouldering",
    "fitness",
    "gym",
    "crossfit",
    "calisthenics",
    "yoga",
    "pilates",
    "stretching",
    "dance_fitness",
    "nordic_walking",
    "skating",
    "skateboarding",
    "rollerblading",
    "golf",
    "frisbee",
    "disc_golf",
    "running_race",
    "cycling_race",
    "fitness_challenge",
    "amateur_tournament"
  ],

  dance: [
    "salsa",
    "bachata",
    "kizomba",
    "tango",
    "hip_hop",
    "contemporary_dance",
    "ballroom_dance",
    "folk_dance",
    "dance_social",
    "dance_battle",
    "zumba",
    "partner_dance",
    "latin_dance",
    "heels_dance",
    "street_dance",
    "dance_class",
    "dance_practice",
    "dance_show"
  ],

  outdoor_nature_walking: [
    "hiking",
    "nature_walk",
    "city_walk",
    "historical_walk",
    "sunset_walk",
    "sunrise_walk",
    "forest_walk",
    "lake_walk",
    "river_walk",
    "architecture_walk",
    "hidden_gems_walk",
    "photography_walk",
    "birdwatching",
    "mushroom_picking",
    "berry_picking",
    "picnic_walk",
    "park_walk",
    "beach_walk",
    "promenade_walk",
    "outdoor_workout",
    "nature_escape",
    "slow_walk"
  ],

  water_activities: [
    "sup",
    "kayak",
    "canoe",
    "boat_trip",
    "catamaran",
    "canal_cruise",
    "rowing",
    "sailing",
    "fishing",
    "wakeboarding",
    "water_bike",
    "jet_ski",
    "beach_activity",
    "water_tour",
    "diving",
    "snorkeling",
    "surfing",
    "windsurfing",
    "kitesurfing",
    "beach_day"
  ],

  winter_seasonal: [
    "winter_walk",
    "ice_skating",
    "skiing",
    "snowboarding",
    "sledding",
    "winter_hiking",
    "christmas_market_walk",
    "winter_photo_route",
    "sauna_cold_plunge",
    "ice_fishing",
    "winter_festival",
    "autumn_leaf_walk",
    "spring_blossom_walk",
    "summer_outdoor",
    "seasonal_walk",
    "snow_activity",
    "cold_plunge",
    "holiday_lights_walk"
  ],

  travel_tours: [
    "day_trip",
    "weekend_trip",
    "local_experience",
    "tourist_excursion",
    "city_tour",
    "food_tasting_tour",
    "craft_experience",
    "farm_experience",
    "castle_tour",
    "nature_reserve_tour",
    "coastal_trip",
    "train_day_trip",
    "local_guide_experience",
    "bike_tour",
    "walking_tour",
    "historical_tour",
    "architecture_tour",
    "photo_tour",
    "hidden_gems_tour"
  ],

  family_kids: [
    "family_activity",
    "kids_workshop",
    "playground_event",
    "family_picnic",
    "kids_theatre",
    "kids_museum_event",
    "family_sports_day",
    "parent_child_class",
    "creative_kids_class",
    "kids_cooking_class",
    "kids_outdoor_walk",
    "birthday_activity",
    "family_farm_visit",
    "family_route",
    "kids_party",
    "educational_kids_event",
    "baby_friendly_activity"
  ],

  pets_animals: [
    "dog_walk",
    "dog_meetup",
    "dog_park_meetup",
    "pet_friendly_cafe",
    "dog_training",
    "pet_photo_session",
    "animal_shelter_visit",
    "farm_animal_experience",
    "horse_riding",
    "pony_riding",
    "cat_cafe",
    "pet_adoption",
    "pet_charity",
    "pet_friendly_walk",
    "animal_volunteering",
    "dog_sport",
    "pet_owner_meetup"
  ],

  community_charity: [
    "charity_event",
    "volunteer_activity",
    "community_cleanup",
    "donation_event",
    "neighborhood_event",
    "fundraising_dinner",
    "charity_run",
    "animal_shelter_volunteering",
    "food_bank_volunteering",
    "tree_planting",
    "beach_cleanup",
    "park_cleanup",
    "community_garden",
    "local_community_meetup",
    "mutual_aid",
    "social_impact_event",
    "environmental_action"
  ],

  markets_fairs: [
    "local_market",
    "flea_market",
    "seasonal_market",
    "christmas_market",
    "farmers_market",
    "craft_market",
    "design_market",
    "vintage_market",
    "book_market",
    "food_market",
    "flower_market",
    "art_fair",
    "pop_up_shop",
    "street_market",
    "handmade_fair",
    "charity_market",
    "kids_market",
    "night_market",
    "local_brands_market"
  ],

  holidays_seasonal: [
    "christmas",
    "new_year",
    "halloween",
    "easter",
    "valentines_day",
    "jani",
    "city_festival",
    "summer_festival",
    "autumn_event",
    "spring_event",
    "school_holiday",
    "national_holiday",
    "local_tradition",
    "midsummer",
    "fireworks",
    "public_celebration"
  ],

  wellness_recharge: [
    "recharge_walk",
    "calm_walk",
    "mindful_walk",
    "coffee_walk",
    "tea_walk",
    "sunset_reset",
    "nature_reset",
    "digital_detox",
    "slow_morning",
    "evening_reset",
    "sauna",
    "spa",
    "massage",
    "breathwork",
    "meditation",
    "sound_healing",
    "wellness_class",
    "relaxation_session",
    "mental_health_meetup",
    "quiet_social",
    "couple_recharge",
    "solo_recharge",
    "friends_recharge"
  ]
};
```

## 13. Category Overrides

Use overrides when a category differs from its content group default.

```ts
const categoryOverrides = {
  sport_football: {
    aliases: ["soccer"],
    search_keywords: ["match", "team sport", "5v5", "11v11", "field", "screening"],
    default_participation_mode: "play",
    default_participation_mode_by_create_block: {
      event: "play",
      quick_plan: "play",
      social_request: "meet_people",
      private_plan: "play",
      bookable_slot: "book",
      place: "visit",
      venue: "visit",
      offer: "claim",
      announcement: "attend"
    }
  },

  sport_tennis: {
    aliases: ["lawn_tennis"],
    search_keywords: ["court", "racket", "singles", "doubles", "coach", "tournament"],
    default_participation_mode: "play",
    default_participation_mode_by_create_block: {
      event: "play",
      quick_plan: "play",
      social_request: "meet_people",
      private_plan: "play",
      bookable_slot: "book",
      place: "visit",
      venue: "visit",
      offer: "claim",
      announcement: "attend"
    }
  },

  sport_swimming: {
    secondary_groups: ["water_activities"],
    search_keywords: ["pool", "open water", "training", "lane", "swim session"]
  },

  games_indoor_mini_golf: {
    secondary_groups: ["sport"],
    search_keywords: ["miniature golf", "putting", "indoor game", "family game"]
  },

  food_drinks_coffee: {
    aliases: ["cafe", "coffee_meetup"],
    search_keywords: ["espresso", "latte", "cafe", "quick coffee", "coffee companion"],
    default_participation_mode_by_create_block: {
      event: "eat_drink",
      quick_plan: "meet_people",
      social_request: "meet_people",
      private_plan: "eat_drink",
      route: "explore",
      place: "visit",
      venue: "visit",
      bookable_slot: "book",
      offer: "claim",
      announcement: "attend"
    }
  },

  cinema_screenings_cinema: {
    aliases: ["movie", "film"],
    search_keywords: ["screening", "movie night", "cinema buddy", "premiere"]
  },

  cinema_screenings_movie_screening: {
    aliases: ["film_screening"],
    search_keywords: ["movie", "film", "screening", "discussion"]
  },

  cinema_screenings_open_air_cinema: {
    is_seasonal: true,
    status: "seasonal",
    search_keywords: ["outdoor movie", "summer cinema", "park screening"]
  },

  art_culture_museums_museum: {
    aliases: ["museum_visit"],
    search_keywords: ["exhibit", "collection", "guided tour", "museum companion"]
  },

  art_culture_museums_museum_night: {
    search_keywords: ["night at museum", "late museum", "special museum event"],
    default_participation_mode: "attend"
  },

  pets_animals_dog_walk: {
    secondary_groups: ["outdoor_nature_walking", "wellness_recharge"],
    aliases: ["pet_walk"],
    search_keywords: ["dog owner", "walk with dog", "pet friendly walk", "dog companion"],
    default_participation_mode_by_create_block: {
      event: "meet_people",
      quick_plan: "meet_people",
      social_request: "meet_people",
      private_plan: "explore",
      route: "explore",
      place: "visit",
      venue: "visit",
      bookable_slot: "book",
      offer: "claim",
      announcement: "attend"
    }
  },

  comedy_theatre_performance_puppet_show: {
    secondary_groups: ["family_kids"],
    is_family_friendly: true,
    search_keywords: ["kids show", "family show", "puppets"]
  },

  markets_fairs_christmas_market: {
    secondary_groups: ["holidays_seasonal", "winter_seasonal"],
    is_seasonal: true,
    status: "seasonal",
    search_keywords: ["holiday market", "winter market", "christmas fair"]
  },

  markets_fairs_charity_market: {
    secondary_groups: ["community_charity"],
    search_keywords: ["fundraising", "charity sale", "community market"]
  },

  wellness_recharge_coffee_walk: {
    secondary_groups: ["outdoor_nature_walking", "food_drinks"],
    search_keywords: ["walk and coffee", "slow walk", "quiet social", "reset walk"]
  },

  wellness_recharge_sauna: {
    search_keywords: ["spa", "heat", "cold plunge", "wellness session"],
    allowed_participation_modes: ["visit", "book", "practice", "meet_people", "claim"],
    default_participation_mode: "book"
  },

  wellness_recharge_spa: {
    search_keywords: ["wellness", "relaxation", "massage", "treatment"],
    allowed_participation_modes: ["visit", "book", "practice", "claim"],
    default_participation_mode: "book"
  }
};
```

## 14. Details Examples

Details are examples and user-editable text, not category IDs.

Use details to describe level, group size, time, mood, route shape, or scenario.

```text
sport.tennis:
friendly tennis match
beginner tennis practice
doubles tennis game
tennis court booking
private tennis lesson
amateur tennis tournament

sport.football:
5v5 football
friendly football game
football practice
public match screening
amateur football tournament

food_drinks.coffee:
quick coffee today
coffee companion
coffee and short walk
table for two
coffee route stop

cinema_screenings.cinema:
movie night
open-air movie screening
cinema buddy plan
premiere night
movie discussion after screening

water_activities.sup:
group SUP session
sunset SUP session
lake SUP route
beginner SUP class

art_culture_museums.museum:
museum visit
museum night
guided tour slot
museum companion
family museum visit

wellness_recharge.calm_walk:
90-minute reset walk
quiet walk with tea stop
evening decompression walk
solo-friendly walk
```

## 15. Rules Presets

Rules presets are reusable combinations. They do not replace the base rules.

```ts
const rulesPresets = {
  public_free_event: ["free", "registration_required"],
  public_paid_event: ["paid", "registration_required", "limited_seats"],
  approval_based_event: ["registration_required", "approval_required", "limited_seats"],
  guest_list_event: ["guest_list", "limited_seats", "late_entry_allowed"],
  private_invite_only: ["invite_only", "hidden_from_public", "share_by_link"],
  friends_only_plan: ["friends_only", "hidden_from_public", "share_by_link"],
  bookable_paid_slot: ["paid", "booking_required", "limited_seats", "refund_policy"],
  venue_visit: ["family_friendly", "wheelchair_accessible"],
  outdoor_weather_sensitive: ["rain_cancellation"],
  beginner_friendly_activity: ["beginner_friendly", "equipment_available"],
  family_friendly_activity: ["family_friendly", "beginner_friendly"],
  pet_friendly_activity: ["pet_friendly"],
  offer_claim: ["limited_seats"],
  announcement_public: []
};
```

## 16. Implementation Notes

1. UI must show create blocks first, not categories first.
2. After create block selection, UI can show content groups and category search.
3. Category selection must materialize the full `ActivityCategory` object.
4. Participation modes must be filtered by selected category and create block.
5. Details must remain editable and must not create new taxonomy values.
6. Rules must be attached to the created object, not to the category itself.
7. Categories not listed in this document require product review before use.
8. Deprecated categories remain readable for old objects but hidden from new create.
9. Seasonal categories can be shown or boosted by calendar and locale.
10. Equipment availability is an option or amenity on `venue`, `place`, or `bookable_slot`.

