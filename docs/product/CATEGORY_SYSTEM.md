# RECHARGE — CATEGORY SYSTEM (полная спецификация)

Версия: v1.4.1 (2026-07-17). Статус: Accepted (канонический).
История правок: v1.1 — явный счёт категорий, профиль volunteer_action,
согласование ContentType с 10 Create-блоками; v1.2 — устранён дубль
animal_volunteering, уточнён счётчик aliases, seasonality добавлена
в модель Subcategory, в миграцию включены legacy-типы черновиков;
v1.3 — добиты остаточные 517→516, bookableSlot в маппинге, принято
решение offer → session (с флагом review_as_rental); v1.4 — уточнён
учёт cooking_class и зафиксировано хранение review_as_rental; v1.4.1 —
implementation-аудит уточнил 36 field ID и 5 категорий с impliedFacets.
Состав: **27 пользовательских категорий + 1 служебная (`other`) = 28**;
516 подкатегорий.
Заменяет собой: CATEGORY_CATALOG.md + CATEGORY_CATALOG_ADDITIONS.md
(их содержимое влито сюда как канонический реестр).
Приоритет: уровень slice spec. Продуктовые принципы — VISION.md.
Реализация: seed-данные (см. §11), НЕ хардкод в виджетах.

---

## §1. Роль категорий в продукте

Категории — единый справочник, который обслуживают ЧЕТЫРЕ функции:

| Функция | Где | Что берёт из справочника |
|---|---|---|
| Навигация | Home (горизонтальный скролл), Categories page | верхний уровень: имя, иконка, порядок |
| Фильтрация | Search, Map, Feed (единый filter flow) | категория/подкатегория как фильтр-условие |
| Создание | Create Hub → dynamic_criteria_section | criteria-профиль подкатегории → набор полей формы |
| Smart Search | SmartQueryParser (rule-based, 3 языка) | keywords подкатегорий → распознавание запроса |

Инвариант VISION («search → filters → map → feed → details, одно
состояние») означает: выбранная категория — часть общего FilterState,
все четыре поверхности читают её из одного места.

---

## §2. Принципы

1. **Один канонический дом.** Каждая подкатегория живёт ровно в одной
   категории. Пересечения — через `aliases` (см. §8), не через дубли.
2. **Стабильные ID.** ID подкатегории не зависит от родителя
   и не меняется никогда (см. §3). Перенос между категориями
   не ломает ссылки.
3. **Данные, не код.** Справочник — seed/конфиг, редактируется без
   изменения логики. Текущий `recharge_taxonomy.dart` — временный
   носитель seed'а (осознанный компромисс MVP, план выноса — §11).
4. **Категория ≠ фасет.** Оси «с кем», «когда», «сезон» — фильтры.
   Подкатегории-сценарии, пересекающиеся с фасетами, декларируют
   `impliedFacets` и не создают параллельный механизм (§9).
5. **Профили вместо пер-категорийных форм.** 516 подкатегорий
   ссылаются на ~20 criteria-профилей (§6). Новая подкатегория
   почти никогда не требует нового профиля.
6. **l10n-ключи, не строки.** Все названия — ключи en/ru/lv.

---

## §3. Модель данных

```dart
class Category {
  final String id;              // напр. 'music_nightlife' — неизменен
  final String l10nKey;         // 'category.music_nightlife'
  final String icon;            // имя ассета из assets/icons/
  final int sortOrder;          // порядок на Home
  final List<ContentType> applicableTypes;   // default для детей
  final String defaultProfileId;             // default для детей
  final Seasonality? seasonality;            // ранжирование (§9)
  final CatalogStatus status;   // active | hidden | deprecated
}

class Subcategory {
  final String id;              // ГЛОБАЛЬНО уникальный slug, БЕЗ
                                // префикса категории: 'mafia', 'sup'
  final String categoryId;      // принадлежность — отдельное поле
  final String l10nKey;
  final String? profileId;      // null → наследует у категории
  final List<ContentType>? applicableTypes;  // null → наследует
  final List<String> aliases;   // кроссвязи (§8)
  final Map<Facet, String> impliedFacets;    // §9
  final Seasonality? seasonality;   // null → наследует у Category;
                                    // индивидуально для подкатегорий
                                    // winter_seasonal, holidays (§9)
  final List<String> keywordsEn, keywordsRu, keywordsLv;  // §10
  final CatalogStatus status;
}

enum ContentType { event, activity, route, place, session,
                   quickPlan, findPeople, classWorkshop, rental,
                   collection }
```

### Соответствие ContentType ↔ 10 Create-блоков

Enum взаимно однозначно отображается на create-типы VISION:

| enum | Create-блок | в applicableTypes реестра §7 |
|---|---|---|
| `event` | Event | да (E) |
| `activity` | Recharge Activity | да (A) |
| `route` | Route / Scenario | да (R) |
| `place` | Place / Business | да (P) |
| `session` | Bookable Session | да (S) |
| `classWorkshop` | Class / Workshop / Experience | да (C) |
| `quickPlan` | Quick Plan | нет — правило ниже |
| `findPeople` | Find People | нет — правило ниже |
| `rental` | Rental / Equipment | нет — правило ниже |
| `collection` | Collection / Guide | нет — правило ниже |

Правило для четырёх типов, не перечисляемых в applicableTypes:

1. `quickPlan`, `findPeople`, `collection` — принимают **любую**
   категорию каталога: категория описывает содержание (план про что,
   компания для чего, подборка о чём). Проверка applicableTypes
   для них не выполняется.
2. `rental` — собственный whitelist категорий, задаётся
   в CreateTypeConfig типа Rental (стартовый набор: sport,
   water_activities, winter_seasonal, adrenaline_entertainment,
   auto_moto), НЕ в каталоге. Каталог не знает про аренду;
   тип сам ограничивает выбор.

Инвариант: appearsIn(applicableTypes) проверяется только для шести
типов из верхней части таблицы.

### Миграция ID (одно решение, принять до появления реальных данных)

Старая схема `<category_id>_<slug>` хрупкая: перенос подкатегории
меняет ID → рвутся объекты, избранное, deep links. Новая: **ID = slug,
глобально уникальный, без префикса**. Проверка текущего каталога
выявила одну коллизию: `cooking_class` (workshops + food_drinks).
Решение: канонический дом — `workshops_masterclasses`
(это класс → профиль hands_on_class); в food_drinks — alias.
После разрешения коллизии все 516 канонических slug'ов уникальны;
миграция однозначна.

---

## §4. Словарь полей (shared field dictionary)

Поля определяются ОДИН раз, профили ссылаются на них по id.

| field id | тип | значения / диапазон |
|---|---|---|
| `language` | multiselect | en / ru / lv / other |
| `skill_level` | select | any / beginner / intermediate / advanced |
| `experience_level` | select | newcomers_welcome / regulars / mixed |
| `age_restriction` | select | none / 12+ / 16+ / 18+ |
| `age_range` | range | 0–17 (детские) |
| `min_age` | number | 3–18 (допуск на активность) |
| `equipment_provided` | select | provided / bring_own / rental_onsite |
| `venue_type` | select | indoor / outdoor / mixed |
| `team_format` | select | опции задаёт подкатегория (5x5, 11x11…) |
| `players_min` / `players_max` | number | 2–100 |
| `difficulty` | select | easy / medium / hard |
| `distance_km` | number | 0.5–100 |
| `pace` | select | relaxed / moderate / fast |
| `terrain` | select | forest / coast / urban / mixed |
| `dietary_options` | multiselect | vegan / vegetarian / halal / gluten_free / none |
| `tasting_type` | select | wine / beer / coffee / cocktail / food |
| `dress_code` | select | none / smart_casual / themed |
| `parental_presence` | select | required / optional |
| `supervision_provided` | bool | |
| `genre` | select | справочник genres (отдельный seed) |
| `music_genre` | select | справочник music_genres |
| `topic` | select | справочник topics |
| `format` | select | talk / discussion / open_meetup |
| `seating` | select | standing / seated / free |
| `entry_type` | select | free / ticket / guest_list / registration |
| `transport_to_start` | select | own / shared / included |
| `swimming_required` | bool | |
| `weather_dependent` | bool | |
| `safety_briefing` | bool | инструктаж включён |
| `reservation_needed` | bool | |
| `venue_booked` | bool | место уже забронировано организатором |
| `own_games_welcome` | bool | |
| `pet_size` | multiselect | small / medium / large / any |
| `vaccination_required` | bool | |
| `on_leash` | select | required / free_area / mixed |

Правило players vs capacity: `capacity` (общая секция Participants) —
лимит записи; `players_min/max` — игровой минимум/максимум для старта.
Оба существуют; players показывается только профилем game_session.

---

## §5. Как профиль попадает в форму (механика)

1. Creator выбирает тип контента (Event…) → форма собирается
   из секций по CreateTypeConfig (см. CREATE_HUB_SPEC).
2. В секции категории Creator выбирает подкатегорию.
3. `dynamic_criteria_section` берёт `subcategory.profileId`
   (или default категории) → `get_category_criteria_usecase`
   возвращает список полей профиля → секция рендерит их.
4. Значения пишутся в `draft.sectionData['criteria']`
   как `Map<fieldId, value>`.
5. В Details выбранные критерии отображаются бейджами/иконками;
   в Filters они же доступны как уточняющие фильтры внутри категории.

---

## §6. Criteria-профили (21 + fallback)

`*` — обязательное поле.

| # | profile id | поля | типовые носители |
|---|---|---|---|
| 1 | `physical_activity` | skill_level*, equipment_provided, venue_type, pace | инд. спорт, танцы, фитнес |
| 2 | `team_game` | team_format*, skill_level*, venue_type, equipment_provided | футбол, баскетбол, волейбол |
| 3 | `competition` | skill_level, entry_type*, age_restriction | забеги, турниры, батлы, хакатоны |
| 4 | `game_session` | players_min*, players_max*, language*, experience_level, own_games_welcome | мафия, настолки, TCG, LAN |
| 5 | `venue_game` | venue_type, reservation_needed, min_age | боулинг, бильярд, аркады, мини-гольф |
| 6 | `adrenaline_activity` | age_restriction*, equipment_provided, safety_briefing, weather_dependent | лазертаг, картинг, прыжки, зиплайн |
| 7 | `performance_show` | genre, age_restriction, seating, language | концерты, театр, стендап, кино |
| 8 | `exhibition_visit` | venue_type, language | музеи, выставки, аттракционы |
| 9 | `talk_lecture` | topic, language*, format, experience_level | лекции, дискуссии, конференции |
| 10 | `networking_social` | language*, experience_level, dress_code | нетворкинг, клубы, дейтинг |
| 11 | `hands_on_class` | skill_level*, equipment_provided*, language, age_restriction | мастер-классы, курсы |
| 12 | `food_gathering` | dietary_options, language, venue_booked | ужины, пикники, бранчи |
| 13 | `tasting` | tasting_type*, age_restriction*, dietary_options | дегустации, bar crawl |
| 14 | `guided_tour` | language*, distance_km, transport_to_start, difficulty | экскурсии, туры, food tour |
| 15 | `outdoor_activity` | distance_km, difficulty*, terrain, weather_dependent | походы, прогулки, stargazing |
| 16 | `water_activity` | equipment_provided*, swimming_required*, difficulty, weather_dependent | SUP, каяк, сёрф |
| 17 | `kids_event` | age_range*, parental_presence*, supervision_provided | всё детское |
| 18 | `pet_event` | pet_size, vaccination_required, on_leash | всё с питомцами |
| 19 | `wellness_session` | skill_level, equipment_provided, language, venue_type | йога, сауна, медитация |
| 20 | `market_fair` | entry_type, venue_type | рынки, ярмарки, фестивали, con'ы |
| 21 | `volunteer_action` | min_age, equipment_provided, weather_dependent | субботники, посадки, волонтёрство |
| 0 | `open_event` | — (ноль полей) | fallback: праздники, салюты, «Other» |

Правило: новый профиль создаётся ТОЛЬКО если ни один существующий
не покрывает подкатегорию даже с необязательными полями.

---

## §7. Канонический реестр (27 пользовательских + 1 служебная категория / 516 подкатегорий)

Формат каждой категории:
- метаданные: default profile, default types
- полный состав (id-slug'и)
- исключения (подкатегории, переопределяющие profile/types)

Условные обозначения типов: E=event, A=activity, R=route, P=place,
S=session(bookable), C=class/workshop.

### 7.1 `music_nightlife` — Music & nightlife (26)
default: `performance_show` · types: [E]

concert, live_music, acoustic_evening, jazz, classical_music,
rock_music, pop_music, electronic_music, techno, house_music,
latin_music, dj_party, club_night, karaoke, open_mic_music,
rooftop_party, beach_party, themed_party, music_festival,
listening_party, jam_session, night_bar, afterwork_drinks,
late_night_social, group_singing, organ_concert

| исключение | profile | types |
|---|---|---|
| night_bar | networking_social | [E, P] |
| afterwork_drinks, late_night_social | networking_social | |
| karaoke, jam_session, group_singing | networking_social | |
| music_festival | market_fair | |

### 7.2 `comedy_theatre_performance` — Comedy & performance (17)
default: `performance_show` · types: [E]

standup, comedy_open_mic, theatre, improvisation, magic_show, circus,
poetry_night, storytelling, puppet_show, ballet, opera, cabaret,
street_performance, performance_art, drag_show, musical,
experimental_theatre

Исключений нет.

### 7.3 `cinema_screenings` — Cinema & screenings (13)
default: `performance_show` · types: [E]

cinema, movie_screening, open_air_cinema, film_festival, documentary,
short_films, retro_cinema, animation, sports_screening,
movie_discussion, premiere, independent_film, cinema_club

| исключение | profile | types |
|---|---|---|
| movie_discussion, cinema_club | talk_lecture | |
| cinema | exhibition_visit | [P, E] |
| film_festival | market_fair | |

### 7.4 `art_culture_museums` — Art, culture & museums (19)
default: `exhibition_visit` · types: [E, P]

exhibition, gallery, museum, museum_night, gallery_walk, artist_talk,
art_walk, photography_exhibition, street_art, architecture,
cultural_heritage, literature_evening, book_reading, history_walk,
design_event, craft_exhibition, public_art, creative_meetup,
fashion_event

| исключение | profile | types |
|---|---|---|
| artist_talk, literature_evening, book_reading | talk_lecture | [E] |
| gallery_walk, art_walk, history_walk | guided_tour | [E, R] |
| creative_meetup | networking_social | [E] |
| fashion_event | performance_show | [E] |

### 7.5 `education_talks` — Education & talks (19)
default: `talk_lecture` · types: [E]

lecture, public_talk, discussion, debate, panel_discussion,
science_talk, history_lecture, psychology_talk, finance_talk,
career_talk, legal_info_session, book_club, practical_seminar,
self_development, health_talk, technology_talk, startup_talk,
parenting_talk, community_discussion

| исключение | profile |
|---|---|
| book_club | networking_social |
| practical_seminar | hands_on_class |

### 7.6 `business_networking` — Business & networking (19)
default: `networking_social` · types: [E]

networking, business_breakfast, business_lunch, conference,
product_presentation, product_launch, startup_meetup, pitch_night,
investor_meetup, job_fair, portfolio_review, freelancers_meetup,
demo_day, expo, founder_meetup, industry_meetup, career_networking,
coworking_event, business_workshop

| исключение | profile |
|---|---|
| conference, product_presentation, product_launch, demo_day | talk_lecture |
| pitch_night | competition |
| expo, job_fair | market_fair |
| business_workshop | hands_on_class |

### 7.7 `workshops_masterclasses` — Workshops & masterclasses (20)
default: `hands_on_class` · types: [E, C, S]

workshop, masterclass, course, pottery, ceramics, drawing, painting,
photography, cooking_class, sewing, floristics, candle_making,
public_speaking, creative_class, craft_workshop, writing_workshop,
music_lesson, dance_workshop, beauty_workshop, wellness_workshop

Исключений нет. `cooking_class` — канонический дом здесь
(alias из food_drinks, §8).

### 7.8 `language_social_learning` — Languages & social learning (15)
default: `networking_social` · types: [E]

language_exchange, english_club, dutch_club, latvian_club,
conversation_club, international_meetup, expats_meetup,
tandem_meeting, language_cafe, language_walk, speed_friending,
speaking_club, culture_exchange, newcomers_meetup, study_group

| исключение | profile | types |
|---|---|---|
| language_walk | guided_tour | [E, A] |
| study_group | talk_lecture | |

### 7.9 `food_drinks` — Food & drinks (26)
default: `food_gathering` · types: [E]

coffee, breakfast, brunch, lunch, dinner, dessert, street_food,
food_tasting, drink_tasting, wine_tasting, beer_tasting,
cocktail_tasting, tea_ceremony, bbq, picnic, food_tour, bar_crawl,
pub_crawl, happy_hour, restaurant_visit, cafe_visit, bakery_visit,
vegan_food, local_food, fine_dining, family_meal

(было 27; `cooking_class` переехал в 7.7, здесь alias)

| исключение | profile | types |
|---|---|---|
| food_tasting, drink_tasting, wine_tasting, beer_tasting, cocktail_tasting, bar_crawl, pub_crawl, happy_hour | tasting | |
| food_tour | guided_tour | [E, R] |
| restaurant_visit, cafe_visit, bakery_visit | food_gathering | [P, E] |

### 7.10 `games_indoor` — Games & indoor (20)
default: `game_session` · types: [E]

quiz, board_games, mafia, poker_no_gambling, chess, escape_room,
quest, city_game, treasure_hunt, bowling, billiards, darts, mini_golf,
arcade, vr_arcade, video_games, table_games, card_games,
role_playing_game, indoor_competition

| исключение | profile | types |
|---|---|---|
| bowling, billiards, darts, mini_golf, arcade, vr_arcade | venue_game | [E, P] |
| escape_room | venue_game | [E, P, S] |
| city_game, treasure_hunt | outdoor_activity | [E, R] |
| indoor_competition, quiz | competition | |

### 7.11 `sport` — Sport (36)
default: `physical_activity` · types: [E, A, S]

football, basketball, volleyball, beach_volleyball, tennis,
table_tennis, badminton, squash, padel, running, trail_running,
cycling, swimming, boxing, martial_arts, climbing, bouldering,
fitness, gym, crossfit, calisthenics, yoga, pilates, stretching,
dance_fitness, nordic_walking, skating, skateboarding, rollerblading,
golf, frisbee, disc_golf, running_race, cycling_race,
fitness_challenge, amateur_tournament

| исключение | profile | types |
|---|---|---|
| football, basketball, volleyball, beach_volleyball, frisbee | team_game | [E] |
| running_race, cycling_race, fitness_challenge, amateur_tournament | competition | [E] |
| yoga, pilates, stretching | wellness_session | |
| gym | physical_activity | [P, S] |

### 7.12 `dance` — Dance (18)
default: `physical_activity` · types: [E, C, S]

salsa, bachata, kizomba, tango, hip_hop, contemporary_dance,
ballroom_dance, folk_dance, dance_social, dance_battle, zumba,
partner_dance, latin_dance, heels_dance, street_dance, dance_class,
dance_practice, dance_show

| исключение | profile | types |
|---|---|---|
| dance_social | networking_social | [E] |
| dance_battle | competition | [E] |
| dance_show | performance_show | [E] |

### 7.13 `outdoor_nature_walking` — Outdoor, nature & walking (25)
default: `outdoor_activity` · types: [E, A, R]

hiking, nature_walk, city_walk, historical_walk, sunset_walk,
sunrise_walk, forest_walk, lake_walk, river_walk, architecture_walk,
hidden_gems_walk, photography_walk, birdwatching, mushroom_picking,
berry_picking, picnic_walk, park_walk, beach_walk, promenade_walk,
outdoor_workout, nature_escape, slow_walk, stargazing,
northern_lights_watch, meteor_shower_watch

| исключение | profile |
|---|---|
| historical_walk, architecture_walk, hidden_gems_walk | guided_tour |
| outdoor_workout | physical_activity |

impliedFacets: sunset_walk → timeOfDay=evening;
sunrise_walk → timeOfDay=morning (§9).

### 7.14 `water_activities` — Water activities (20)
default: `water_activity` · types: [E, A, S]

sup, kayak, canoe, boat_trip, catamaran, canal_cruise, rowing,
sailing, fishing, wakeboarding, water_bike, jet_ski, beach_activity,
water_tour, diving, snorkeling, surfing, windsurfing, kitesurfing,
beach_day

| исключение | profile | types |
|---|---|---|
| beach_activity, beach_day | outdoor_activity | [E, A] |
| boat_trip, canal_cruise, water_tour | guided_tour | [E, S] |

### 7.15 `winter_seasonal` — Winter & seasonal (18)
default: `outdoor_activity` · types: [E, A] · seasonality: по подкатегории

winter_walk, ice_skating, skiing, snowboarding, sledding,
winter_hiking, christmas_market_walk, winter_photo_route,
sauna_cold_plunge, ice_fishing, winter_festival, autumn_leaf_walk,
spring_blossom_walk, summer_outdoor, seasonal_walk, snow_activity,
cold_plunge, holiday_lights_walk

| исключение | profile | types |
|---|---|---|
| ice_skating, skiing, snowboarding | physical_activity | [E, A, S] |
| sauna_cold_plunge, cold_plunge | wellness_session | [E, S] |
| winter_festival | market_fair | [E] |
| winter_photo_route | outdoor_activity | [R, E] |

impliedFacets: season на каждой подкатегории (winter/autumn/
spring/summer) — §9.

### 7.16 `travel_tours` — Travel & tours (19)
default: `guided_tour` · types: [E, R]

day_trip, weekend_trip, local_experience, tourist_excursion,
city_tour, food_tasting_tour, craft_experience, farm_experience,
castle_tour, nature_reserve_tour, coastal_trip, train_day_trip,
local_guide_experience, bike_tour, walking_tour, historical_tour,
architecture_tour, photo_tour, hidden_gems_tour

Исключений нет.

### 7.17 `family_kids` — Family & kids (24)
default: `kids_event` · types: [E]

family_activity, kids_workshop, playground_event, family_picnic,
kids_theatre, kids_museum_event, family_sports_day,
parent_child_class, creative_kids_class, kids_cooking_class,
kids_outdoor_walk, birthday_activity, family_farm_visit, family_route,
kids_party, educational_kids_event, baby_friendly_activity, kids_camp,
day_camp, teen_meetup, teen_event, kids_quest, kids_science_event,
kids_disco

| исключение | types |
|---|---|
| family_route | [R, E] |
| kids_camp, day_camp | [E, S] |

impliedFacets: вся категория → withWhom=family.

### 7.18 `pets_animals` — Pets & animals (21)
default: `pet_event` · types: [E]

dog_walk, dog_meetup, dog_park_meetup, pet_friendly_cafe,
dog_training, pet_photo_session, animal_shelter_visit,
farm_animal_experience, horse_riding, pony_riding, cat_cafe,
pet_adoption, pet_charity, pet_friendly_walk,
dog_sport, pet_owner_meetup, dog_show, pet_exhibition, pet_fair,
pet_care_talk, animal_therapy

`animal_volunteering` в составе НЕТ — это alias на
`animal_shelter_volunteering` (7.19), см. §8.

| исключение | profile | types |
|---|---|---|
| pet_friendly_cafe, cat_cafe | pet_event | [P, E] |
| animal_shelter_visit, pet_charity | volunteer_action | |
| pet_care_talk | talk_lecture | |
| dog_show, pet_exhibition, pet_fair | market_fair | |
| horse_riding, pony_riding | adrenaline_activity | [E, S] |
| pet_photo_session | pet_event | [E, S] |

### 7.19 `community_charity` — Community & charity (17)
default: `volunteer_action` · types: [E]

charity_event, volunteer_activity, community_cleanup, donation_event,
neighborhood_event, fundraising_dinner, charity_run,
animal_shelter_volunteering, food_bank_volunteering, tree_planting,
beach_cleanup, park_cleanup, community_garden, local_community_meetup,
mutual_aid, social_impact_event, environmental_action

| исключение | profile |
|---|---|
| fundraising_dinner | food_gathering |
| charity_run | competition |
| local_community_meetup | networking_social |

`animal_shelter_volunteering` — канонический дом здесь;
`animal_volunteering` (7.18) — alias на него (§8).

### 7.20 `markets_fairs` — Markets & fairs (20)
default: `market_fair` · types: [E]

local_market, flea_market, seasonal_market, christmas_market,
farmers_market, craft_market, design_market, vintage_market,
book_market, food_market, flower_market, art_fair, pop_up_shop,
street_market, handmade_fair, charity_market, kids_market,
night_market, local_brands_market, clothing_swap

Исключений нет.

### 7.21 `holidays_seasonal` — Holidays & seasonal (16)
default: `open_event` · types: [E] · seasonality: по подкатегории

christmas, new_year, halloween, easter, valentines_day, jani,
city_festival, summer_festival, autumn_event, spring_event,
school_holiday, national_holiday, local_tradition, midsummer,
fireworks, public_celebration

| исключение | profile |
|---|---|
| city_festival, summer_festival | market_fair |

### 7.22 `wellness_recharge` — Wellness & recharge (25)
default: `wellness_session` · types: [E, A, S]

recharge_walk, calm_walk, mindful_walk, coffee_walk, tea_walk,
sunset_reset, nature_reset, digital_detox, slow_morning,
evening_reset, sauna, spa, massage, breathwork, meditation,
sound_healing, wellness_class, relaxation_session,
mental_health_meetup, quiet_social, couple_recharge, solo_recharge,
friends_recharge, pirts_ritual, retreat

| исключение | profile | types |
|---|---|---|
| recharge_walk, calm_walk, mindful_walk, coffee_walk, tea_walk | outdoor_activity | [A, E, R] |
| mental_health_meetup, quiet_social | networking_social | [E] |
| spa, massage, sauna, pirts_ritual | wellness_session | [S, E, P] |

impliedFacets: couple_recharge → withWhom=couple;
solo_recharge → withWhom=solo; friends_recharge → withWhom=friends;
sunset_reset → timeOfDay=evening; slow_morning → timeOfDay=morning.

### 7.23 `adrenaline_entertainment` — Adrenaline & entertainment (16)
default: `adrenaline_activity` · types: [E, S]

laser_tag, paintball, airsoft, karting, shooting_range, archery,
axe_throwing, trampoline_park, rope_park, zipline, wind_tunnel,
hot_air_balloon, skydiving, bungee_jumping, parkour, obstacle_course

| исключение | types |
|---|---|
| trampoline_park, rope_park | [E, P, S] |
| parkour | [E, A, C] |

### 7.24 `attractions` — Attractions (12)
default: `exhibition_visit` · types: [P, E]

zoo, petting_zoo, aquarium, amusement_park, water_park,
adventure_park, botanical_garden, planetarium, science_center,
observation_deck, ferris_wheel, seasonal_attraction

Исключений нет. Категория — единственная с default types [P, E]:
это в первую очередь места, события — на их базе.

### 7.25 `auto_moto` — Auto & moto (12)
default: `networking_social` · types: [E]

car_meetup, retro_cars, car_show, auto_exhibition, tuning_meetup,
drift_event, offroad_trip, motorcycle_ride, motorcycle_meetup,
scooter_meetup, car_photo_meet, drive_in_cinema

| исключение | profile | types |
|---|---|---|
| car_show, auto_exhibition | market_fair | |
| drift_event | performance_show | |
| offroad_trip, motorcycle_ride | outdoor_activity | [E, R] |
| drive_in_cinema | performance_show | |

### 7.26 `geek_tech` — Geek & tech (14)
default: `networking_social` · types: [E]

anime_meetup, cosplay_event, comic_con, esports_tournament, lan_party,
retro_gaming, tabletop_wargames, trading_card_games, hackathon,
game_dev_meetup, tech_meetup, robotics_event, fandom_meetup,
collectors_meetup

| исключение | profile |
|---|---|
| lan_party, retro_gaming, tabletop_wargames, trading_card_games | game_session |
| esports_tournament, hackathon | competition |
| comic_con | market_fair |

### 7.27 `dating_singles` — Dating & singles (8)
default: `networking_social` · types: [E]

speed_dating, singles_party, singles_mixer, singles_dinner,
blind_date_event, dating_game_event, singles_activity,
matchmaking_event

Исключений нет. impliedFacets: вся категория → withWhom=solo
(участник приходит один).

### 7.28 Служебная: `other` — Other (1)
default: `open_event` · types: все

other_event — fallback, чтобы Creator никогда не был заблокирован
отсутствием категории. Скрыта из навигации Home, доступна только
в форме создания. Объекты в `other` — сигнал для расширения каталога.

---

## §8. Кроссвязи (aliases) — разрешение дублей

Alias — указатель: подкатегория A в контексте категории X ведёт
на каноническую B. В выдаче объект существует один раз (по canonical),
alias влияет на: поиск внутри категории X, keywords, браузинг.

### Aliases (переадресация, 5)

| контекст | alias → canonical |
|---|---|
| food_drinks | cooking_class → workshops: cooking_class |
| business_networking | hackathon → geek_tech: hackathon |
| auto_moto | karting → adrenaline: karting |
| cinema_screenings | drive_in_cinema → auto_moto: drive_in_cinema |
| pets_animals | animal_volunteering → community_charity: animal_shelter_volunteering |

Alias НЕ является подкатегорией и не входит в счёт 516; он влияет
только на поиск/браузинг внутри своей категории и на keywords.

### Родственные связи и примечания (НЕ aliases, 2)

| запись | пояснение |
|---|---|
| christmas_market_walk (winter) ↔ christmas_market (markets) | родственные, но разные сущности: прогулка-маршрут vs рынок. Обе — полноценные подкатегории |
| sports_screening | фиксация канонического дома: cinema_screenings; просмотр в баре — тот же id, отдельной записи нет |

Правило на будущее: обнаружен дубль → выбрать канонический дом
по профилю (где живёт форма создания) → второй превратить в alias.

---

## §9. Категории и фасеты — правило разграничения

Фасеты (оси общего FilterState из VISION): `withWhom`
(solo/couple/friends/family/group), `when` + `timeOfDay`, `budget`,
`mood`, `timeAvailable`, `season`.

Правила:
1. Подкатегория-сценарий, совпадающая с фасетом (couple_recharge,
   sunset_walk, вся family_kids), объявляет `impliedFacets`.
   Выбор такой подкатегории Creator'ом автоматически проставляет
   фасет объекту; выбор её User'ом в поиске — включает фасет-фильтр.
   ОДИН механизм, две точки входа.
2. `seasonality` — метаданные для ранжирования (зимние подкатегории
   опускаются в выдаче летом, не скрываются: sauna_cold_plunge
   актуальна круглый год).
3. Новые «сценарные» подкатегории допустимы ТОЛЬКО с impliedFacets —
   никогда как параллельный фасету механизм.

---

## §10. Keywords для Smart Search

Назначение: rule-based SmartQueryParser сопоставляет свободный текст
(en/ru/lv) с подкатегориями. Каждая подкатегория несёт 3 списка
keywords. Правила заполнения:

1. Ключи — леммы/основы, парсер матчит по вхождению основы
   («настолк» покрывает настолки/настолок/настолках).
2. Включать: синонимы, разговорные формы, транслит, бренды-нарицательные.
3. НЕ включать: слова-омонимы без контекста («игра» — слишком широко,
   привязывается к категории games_indoor, не к подкатегории).
4. Латышский — с диакритикой И без (пользователи пишут по-разному).

Примеры (образец для seed, полное наполнение — отдельная задача):

| id | ru | en | lv |
|---|---|---|---|
| board_games | настолк, настольн игр, дндшка | board game, tabletop | galda spēl, galda spel |
| mafia | мафия, мафи | mafia, werewolf | mafija |
| sup | сап, сапборд, сап-борд | sup, paddleboard, paddle board | sup, airu dēl, airu del |
| pirts_ritual | пиртс, баня с банщиком, парение | pirts, latvian sauna ritual | pirts, pēriens, periens |
| speed_dating | быстрые свидания, спид дейтинг | speed dating | ātrie randiņi, atrie randini |

Категория тоже несёт keywords (широкие: «спорт», «поесть», «гулять») —
парсер сначала пытается матчить подкатегорию, при неудаче — категорию.

---

## §11. Хранение и governance

**MVP:** seed в `recharge_taxonomy.dart` (текущее место) — осознанный
компромисс: изменение каталога = релиз приложения.
**План выноса (post-MVP, до выхода за пределы Латвии):** каталог как
удалённый конфиг с версией (`taxonomyVersion`), локальный кэш,
фоновое обновление. Модель §3 к этому готова — менять код не придётся.

Правила изменений:
1. Добавление подкатегории — свободно (данные).
2. Переименование — только l10n, id неизменен.
3. Перенос между категориями — смена categoryId, id тот же.
4. Удаление запрещено; только status=deprecated (объекты со старым
   id продолжают работать, из пикеров и навигации скрыто).
5. Новый профиль — через ревью против §6 (не покрыт ли существующим).
6. Регион-специфичные подкатегории (jani, pirts_ritual) при выходе
   в новые страны получают region-scope (поле `regions` — добавить
   в модель при первой необходимости, не сейчас).

### Миграция 22/434 → данная спецификация (управляемая замена)

Старый каталог заменяется целиком, НЕ расширяется поверх. Шаги:

1. **Freeze** старого `recharge_taxonomy.dart` — новые правки только
   в новую структуру.
2. **Генерация mapping-таблицы** old→new id: правило тривиально —
   отрезание префикса категории (`music_nightlife_concert` →
   `concert`); единственное ручное исключение —
   `food_drinks_cooking_class` → `cooking_class`
   (canonical в workshops) и `pets_animals_animal_volunteering` →
   `animal_shelter_volunteering`.
3. **Новый seed** по модели §3 (Category/Subcategory с профилями,
   aliases, impliedFacets, status).
4. **Прогон автопроверок** §12 как unit-тестов ДО первого коммита
   seed'а.
5. Если на старые id уже есть ссылки (объекты, черновики) —
   конвертация по mapping-таблице; если ссылок ещё нет (текущий
   этап MVP) — п. 5 пропускается, что и есть главный аргумент
   провести миграцию СЕЙЧАС.
6. Mapping-таблица сохраняется в docs/ навсегда (страховка для
   любых внешних ссылок и аналитики).
7. **Legacy-типы черновиков.** Текущий код
   (`create_draft_entity.dart`) использует старый набор типов:
   `socialRequest`, `privatePlan`, `venue`, `offer`, `announcement`.
   Предлагаемый маппинг на канонические ContentType:

   | legacy | → ContentType | комментарий |
   |---|---|---|
   | socialRequest | findPeople | поиск компании |
   | privatePlan | quickPlan | личный план на сейчас |
   | venue | place | место/заведение |
   | bookableSlot | session | прямое соответствие |
   | offer | session | РЕШЕНО: все offer → session, см. ниже |
   | announcement | event | объявление-событие |

   **Решение по `offer` (все → session, без ветки rental):**
   Rental структурно требует данных InventorySection (единицы, залог),
   которых в legacy-черновиках offer нет — автоконвертация в rental
   создала бы невалидные черновики. Session — безопасный супертип
   (услуга/слот). Правило мигратора: все offer → session; черновики,
   чья категория входит в rental-whitelist (sport, water_activities,
   winter_seasonal, adrenaline_entertainment, auto_moto), мигратор
   помечает флагом `review_as_rental` — Creator увидит подсказку
   «возможно, это аренда» и при желании пересоздаст объект как Rental.
   Флаг хранится как bool в
   `draft.sectionData['migration']['review_as_rental']` и удаляется
   после явного решения Creator. Данные не теряются, ручной разбор
   не блокирует миграцию.

   Сохранённые черновики конвертируются одноразовым мигратором при
   первом запуске новой версии; legacy-enum удаляется из кода после
   конвертации.

---

## §12. Свод и контроль целостности

| метрика | значение |
|---|---|
| Категорий (пользовательских) | 27 |
| Категорий (служебных) | 1 (`other`) — итого 28 |
| Подкатегорий | 516 (включая other_event; канонический cooking_class учтён один раз в workshops_masterclasses; food_drinks:cooking_class и pets_animals:animal_volunteering — контекстные aliases и отдельно не считаются) |
| Criteria-профилей | 21 + fallback (`open_event`) |
| Полей в словаре | 36 (35 строк; players_min / players_max — два ID) |
| Категорий с impliedFacets | 5 (outdoor, wellness, winter, family_kids, dating) |
| Aliases | 5 (+2 родственные связи/примечания, §8) |

Автопроверки для seed (тест в test/unit/):
1. Все subcategory.id глобально уникальны
2. Каждый profileId существует в реестре профилей
3. Каждый alias указывает на существующий canonical id
4. У каждой подкатегории непустой l10nKey для en/ru/lv
5. impliedFacets ссылаются только на существующие фасеты

## §13. Открытые вопросы (сознательно отложено)

1. Полное наполнение keywords 516 × 3 языка — отдельная задача
   после утверждения этого документа (можно генерировать пакетно
   и ревьюить).
2. Справочники genres / music_genres / topics — при наполнении seed.
3. Иконки категорий — с дизайном (assets/icons/, по id категории).
4. Порог, при котором объекты из `other` превращаются в новую
   подкатегорию (предложение: 10+ объектов схожего типа).
