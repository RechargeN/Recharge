import '../config/recharge_taxonomy.dart';
import 'l10n_context.dart';

/// L4.9.5: the display name of a Category System category or subcategory in
/// the reader's language. Ids never change; an unknown id or path keeps the
/// old English label. `taxonomy_labels_test.dart` checks every id is here.
String taxonomyLabel(AppLocalizations l10n, String idOrPath) {
  final String normalized = idOrPath.trim().toLowerCase();
  final String id = normalized.contains('.')
      ? normalized.split('.').last
      : normalized;
  final String Function(AppLocalizations)? group =
      taxonomyCategoryLabels[normalized];
  if (group != null) return group(l10n);
  final String Function(AppLocalizations)? sub = taxonomySubcategoryLabels[id];
  if (sub != null) return sub(l10n);
  return rechargeTaxonomyLabel(idOrPath);
}

/// Category id → localized name.
const Map<String, String Function(AppLocalizations)> taxonomyCategoryLabels =
    <String, String Function(AppLocalizations)>{
      'music_nightlife': _taxCategoryMusicNightlife,
      'comedy_theatre_performance': _taxCategoryComedyTheatrePerformance,
      'cinema_screenings': _taxCategoryCinemaScreenings,
      'art_culture_museums': _taxCategoryArtCultureMuseums,
      'education_talks': _taxCategoryEducationTalks,
      'business_networking': _taxCategoryBusinessNetworking,
      'workshops_masterclasses': _taxCategoryWorkshopsMasterclasses,
      'language_social_learning': _taxCategoryLanguageSocialLearning,
      'food_drinks': _taxCategoryFoodDrinks,
      'games_indoor': _taxCategoryGamesIndoor,
      'sport': _taxCategorySport,
      'dance': _taxCategoryDance,
      'outdoor_nature_walking': _taxCategoryOutdoorNatureWalking,
      'water_activities': _taxCategoryWaterActivities,
      'winter_seasonal': _taxCategoryWinterSeasonal,
      'travel_tours': _taxCategoryTravelTours,
      'family_kids': _taxCategoryFamilyKids,
      'pets_animals': _taxCategoryPetsAnimals,
      'community_charity': _taxCategoryCommunityCharity,
      'markets_fairs': _taxCategoryMarketsFairs,
      'holidays_seasonal': _taxCategoryHolidaysSeasonal,
      'wellness_recharge': _taxCategoryWellnessRecharge,
      'adrenaline_entertainment': _taxCategoryAdrenalineEntertainment,
      'attractions': _taxCategoryAttractions,
      'auto_moto': _taxCategoryAutoMoto,
      'geek_tech': _taxCategoryGeekTech,
      'dating_singles': _taxCategoryDatingSingles,
      'other': _taxCategoryOther,
    };

/// Subcategory id → localized name.
const Map<String, String Function(AppLocalizations)> taxonomySubcategoryLabels =
    <String, String Function(AppLocalizations)>{
      'concert': _taxSubcategoryConcert,
      'live_music': _taxSubcategoryLiveMusic,
      'acoustic_evening': _taxSubcategoryAcousticEvening,
      'jazz': _taxSubcategoryJazz,
      'classical_music': _taxSubcategoryClassicalMusic,
      'rock_music': _taxSubcategoryRockMusic,
      'pop_music': _taxSubcategoryPopMusic,
      'electronic_music': _taxSubcategoryElectronicMusic,
      'techno': _taxSubcategoryTechno,
      'house_music': _taxSubcategoryHouseMusic,
      'latin_music': _taxSubcategoryLatinMusic,
      'dj_party': _taxSubcategoryDjParty,
      'club_night': _taxSubcategoryClubNight,
      'karaoke': _taxSubcategoryKaraoke,
      'open_mic_music': _taxSubcategoryOpenMicMusic,
      'rooftop_party': _taxSubcategoryRooftopParty,
      'beach_party': _taxSubcategoryBeachParty,
      'themed_party': _taxSubcategoryThemedParty,
      'music_festival': _taxSubcategoryMusicFestival,
      'listening_party': _taxSubcategoryListeningParty,
      'jam_session': _taxSubcategoryJamSession,
      'night_bar': _taxSubcategoryNightBar,
      'afterwork_drinks': _taxSubcategoryAfterworkDrinks,
      'late_night_social': _taxSubcategoryLateNightSocial,
      'group_singing': _taxSubcategoryGroupSinging,
      'organ_concert': _taxSubcategoryOrganConcert,
      'standup': _taxSubcategoryStandup,
      'comedy_open_mic': _taxSubcategoryComedyOpenMic,
      'theatre': _taxSubcategoryTheatre,
      'improvisation': _taxSubcategoryImprovisation,
      'magic_show': _taxSubcategoryMagicShow,
      'circus': _taxSubcategoryCircus,
      'poetry_night': _taxSubcategoryPoetryNight,
      'storytelling': _taxSubcategoryStorytelling,
      'puppet_show': _taxSubcategoryPuppetShow,
      'ballet': _taxSubcategoryBallet,
      'opera': _taxSubcategoryOpera,
      'cabaret': _taxSubcategoryCabaret,
      'street_performance': _taxSubcategoryStreetPerformance,
      'performance_art': _taxSubcategoryPerformanceArt,
      'drag_show': _taxSubcategoryDragShow,
      'musical': _taxSubcategoryMusical,
      'experimental_theatre': _taxSubcategoryExperimentalTheatre,
      'cinema': _taxSubcategoryCinema,
      'movie_screening': _taxSubcategoryMovieScreening,
      'open_air_cinema': _taxSubcategoryOpenAirCinema,
      'film_festival': _taxSubcategoryFilmFestival,
      'documentary': _taxSubcategoryDocumentary,
      'short_films': _taxSubcategoryShortFilms,
      'retro_cinema': _taxSubcategoryRetroCinema,
      'animation': _taxSubcategoryAnimation,
      'sports_screening': _taxSubcategorySportsScreening,
      'movie_discussion': _taxSubcategoryMovieDiscussion,
      'premiere': _taxSubcategoryPremiere,
      'independent_film': _taxSubcategoryIndependentFilm,
      'cinema_club': _taxSubcategoryCinemaClub,
      'exhibition': _taxSubcategoryExhibition,
      'gallery': _taxSubcategoryGallery,
      'museum': _taxSubcategoryMuseum,
      'museum_night': _taxSubcategoryMuseumNight,
      'gallery_walk': _taxSubcategoryGalleryWalk,
      'artist_talk': _taxSubcategoryArtistTalk,
      'art_walk': _taxSubcategoryArtWalk,
      'photography_exhibition': _taxSubcategoryPhotographyExhibition,
      'street_art': _taxSubcategoryStreetArt,
      'architecture': _taxSubcategoryArchitecture,
      'cultural_heritage': _taxSubcategoryCulturalHeritage,
      'monument': _taxSubcategoryMonument,
      'memorial': _taxSubcategoryMemorial,
      'sculpture': _taxSubcategorySculpture,
      'historic_landmark': _taxSubcategoryHistoricLandmark,
      'literature_evening': _taxSubcategoryLiteratureEvening,
      'book_reading': _taxSubcategoryBookReading,
      'history_walk': _taxSubcategoryHistoryWalk,
      'design_event': _taxSubcategoryDesignEvent,
      'craft_exhibition': _taxSubcategoryCraftExhibition,
      'public_art': _taxSubcategoryPublicArt,
      'creative_meetup': _taxSubcategoryCreativeMeetup,
      'fashion_event': _taxSubcategoryFashionEvent,
      'lecture': _taxSubcategoryLecture,
      'public_talk': _taxSubcategoryPublicTalk,
      'discussion': _taxSubcategoryDiscussion,
      'debate': _taxSubcategoryDebate,
      'panel_discussion': _taxSubcategoryPanelDiscussion,
      'science_talk': _taxSubcategoryScienceTalk,
      'history_lecture': _taxSubcategoryHistoryLecture,
      'psychology_talk': _taxSubcategoryPsychologyTalk,
      'finance_talk': _taxSubcategoryFinanceTalk,
      'career_talk': _taxSubcategoryCareerTalk,
      'legal_info_session': _taxSubcategoryLegalInfoSession,
      'book_club': _taxSubcategoryBookClub,
      'practical_seminar': _taxSubcategoryPracticalSeminar,
      'self_development': _taxSubcategorySelfDevelopment,
      'health_talk': _taxSubcategoryHealthTalk,
      'technology_talk': _taxSubcategoryTechnologyTalk,
      'startup_talk': _taxSubcategoryStartupTalk,
      'parenting_talk': _taxSubcategoryParentingTalk,
      'community_discussion': _taxSubcategoryCommunityDiscussion,
      'networking': _taxSubcategoryNetworking,
      'business_breakfast': _taxSubcategoryBusinessBreakfast,
      'business_lunch': _taxSubcategoryBusinessLunch,
      'conference': _taxSubcategoryConference,
      'product_presentation': _taxSubcategoryProductPresentation,
      'product_launch': _taxSubcategoryProductLaunch,
      'startup_meetup': _taxSubcategoryStartupMeetup,
      'pitch_night': _taxSubcategoryPitchNight,
      'investor_meetup': _taxSubcategoryInvestorMeetup,
      'job_fair': _taxSubcategoryJobFair,
      'portfolio_review': _taxSubcategoryPortfolioReview,
      'freelancers_meetup': _taxSubcategoryFreelancersMeetup,
      'demo_day': _taxSubcategoryDemoDay,
      'expo': _taxSubcategoryExpo,
      'founder_meetup': _taxSubcategoryFounderMeetup,
      'industry_meetup': _taxSubcategoryIndustryMeetup,
      'career_networking': _taxSubcategoryCareerNetworking,
      'coworking_event': _taxSubcategoryCoworkingEvent,
      'business_workshop': _taxSubcategoryBusinessWorkshop,
      'workshop': _taxSubcategoryWorkshop,
      'masterclass': _taxSubcategoryMasterclass,
      'course': _taxSubcategoryCourse,
      'pottery': _taxSubcategoryPottery,
      'ceramics': _taxSubcategoryCeramics,
      'drawing': _taxSubcategoryDrawing,
      'painting': _taxSubcategoryPainting,
      'photography': _taxSubcategoryPhotography,
      'cooking_class': _taxSubcategoryCookingClass,
      'sewing': _taxSubcategorySewing,
      'floristics': _taxSubcategoryFloristics,
      'candle_making': _taxSubcategoryCandleMaking,
      'public_speaking': _taxSubcategoryPublicSpeaking,
      'creative_class': _taxSubcategoryCreativeClass,
      'craft_workshop': _taxSubcategoryCraftWorkshop,
      'writing_workshop': _taxSubcategoryWritingWorkshop,
      'music_lesson': _taxSubcategoryMusicLesson,
      'dance_workshop': _taxSubcategoryDanceWorkshop,
      'beauty_workshop': _taxSubcategoryBeautyWorkshop,
      'wellness_workshop': _taxSubcategoryWellnessWorkshop,
      'language_exchange': _taxSubcategoryLanguageExchange,
      'english_club': _taxSubcategoryEnglishClub,
      'dutch_club': _taxSubcategoryDutchClub,
      'latvian_club': _taxSubcategoryLatvianClub,
      'conversation_club': _taxSubcategoryConversationClub,
      'international_meetup': _taxSubcategoryInternationalMeetup,
      'expats_meetup': _taxSubcategoryExpatsMeetup,
      'tandem_meeting': _taxSubcategoryTandemMeeting,
      'language_cafe': _taxSubcategoryLanguageCafe,
      'language_walk': _taxSubcategoryLanguageWalk,
      'speed_friending': _taxSubcategorySpeedFriending,
      'speaking_club': _taxSubcategorySpeakingClub,
      'culture_exchange': _taxSubcategoryCultureExchange,
      'newcomers_meetup': _taxSubcategoryNewcomersMeetup,
      'study_group': _taxSubcategoryStudyGroup,
      'coffee': _taxSubcategoryCoffee,
      'breakfast': _taxSubcategoryBreakfast,
      'brunch': _taxSubcategoryBrunch,
      'lunch': _taxSubcategoryLunch,
      'dinner': _taxSubcategoryDinner,
      'dessert': _taxSubcategoryDessert,
      'street_food': _taxSubcategoryStreetFood,
      'food_tasting': _taxSubcategoryFoodTasting,
      'drink_tasting': _taxSubcategoryDrinkTasting,
      'wine_tasting': _taxSubcategoryWineTasting,
      'beer_tasting': _taxSubcategoryBeerTasting,
      'cocktail_tasting': _taxSubcategoryCocktailTasting,
      'tea_ceremony': _taxSubcategoryTeaCeremony,
      'bbq': _taxSubcategoryBbq,
      'picnic': _taxSubcategoryPicnic,
      'food_tour': _taxSubcategoryFoodTour,
      'bar_crawl': _taxSubcategoryBarCrawl,
      'pub_crawl': _taxSubcategoryPubCrawl,
      'happy_hour': _taxSubcategoryHappyHour,
      'restaurant_visit': _taxSubcategoryRestaurantVisit,
      'cafe_visit': _taxSubcategoryCafeVisit,
      'bakery_visit': _taxSubcategoryBakeryVisit,
      'vegan_food': _taxSubcategoryVeganFood,
      'local_food': _taxSubcategoryLocalFood,
      'fine_dining': _taxSubcategoryFineDining,
      'family_meal': _taxSubcategoryFamilyMeal,
      'quiz': _taxSubcategoryQuiz,
      'board_games': _taxSubcategoryBoardGames,
      'mafia': _taxSubcategoryMafia,
      'poker_no_gambling': _taxSubcategoryPokerNoGambling,
      'chess': _taxSubcategoryChess,
      'escape_room': _taxSubcategoryEscapeRoom,
      'quest': _taxSubcategoryQuest,
      'city_game': _taxSubcategoryCityGame,
      'treasure_hunt': _taxSubcategoryTreasureHunt,
      'bowling': _taxSubcategoryBowling,
      'billiards': _taxSubcategoryBilliards,
      'darts': _taxSubcategoryDarts,
      'mini_golf': _taxSubcategoryMiniGolf,
      'arcade': _taxSubcategoryArcade,
      'vr_arcade': _taxSubcategoryVrArcade,
      'video_games': _taxSubcategoryVideoGames,
      'table_games': _taxSubcategoryTableGames,
      'card_games': _taxSubcategoryCardGames,
      'role_playing_game': _taxSubcategoryRolePlayingGame,
      'indoor_competition': _taxSubcategoryIndoorCompetition,
      'football': _taxSubcategoryFootball,
      'basketball': _taxSubcategoryBasketball,
      'volleyball': _taxSubcategoryVolleyball,
      'beach_volleyball': _taxSubcategoryBeachVolleyball,
      'tennis': _taxSubcategoryTennis,
      'table_tennis': _taxSubcategoryTableTennis,
      'badminton': _taxSubcategoryBadminton,
      'squash': _taxSubcategorySquash,
      'padel': _taxSubcategoryPadel,
      'running': _taxSubcategoryRunning,
      'trail_running': _taxSubcategoryTrailRunning,
      'cycling': _taxSubcategoryCycling,
      'swimming': _taxSubcategorySwimming,
      'boxing': _taxSubcategoryBoxing,
      'martial_arts': _taxSubcategoryMartialArts,
      'climbing': _taxSubcategoryClimbing,
      'bouldering': _taxSubcategoryBouldering,
      'fitness': _taxSubcategoryFitness,
      'gym': _taxSubcategoryGym,
      'crossfit': _taxSubcategoryCrossfit,
      'calisthenics': _taxSubcategoryCalisthenics,
      'yoga': _taxSubcategoryYoga,
      'pilates': _taxSubcategoryPilates,
      'stretching': _taxSubcategoryStretching,
      'dance_fitness': _taxSubcategoryDanceFitness,
      'nordic_walking': _taxSubcategoryNordicWalking,
      'skating': _taxSubcategorySkating,
      'skateboarding': _taxSubcategorySkateboarding,
      'rollerblading': _taxSubcategoryRollerblading,
      'golf': _taxSubcategoryGolf,
      'frisbee': _taxSubcategoryFrisbee,
      'disc_golf': _taxSubcategoryDiscGolf,
      'running_race': _taxSubcategoryRunningRace,
      'cycling_race': _taxSubcategoryCyclingRace,
      'fitness_challenge': _taxSubcategoryFitnessChallenge,
      'amateur_tournament': _taxSubcategoryAmateurTournament,
      'salsa': _taxSubcategorySalsa,
      'bachata': _taxSubcategoryBachata,
      'kizomba': _taxSubcategoryKizomba,
      'tango': _taxSubcategoryTango,
      'hip_hop': _taxSubcategoryHipHop,
      'contemporary_dance': _taxSubcategoryContemporaryDance,
      'ballroom_dance': _taxSubcategoryBallroomDance,
      'folk_dance': _taxSubcategoryFolkDance,
      'dance_social': _taxSubcategoryDanceSocial,
      'dance_battle': _taxSubcategoryDanceBattle,
      'zumba': _taxSubcategoryZumba,
      'partner_dance': _taxSubcategoryPartnerDance,
      'latin_dance': _taxSubcategoryLatinDance,
      'heels_dance': _taxSubcategoryHeelsDance,
      'street_dance': _taxSubcategoryStreetDance,
      'dance_class': _taxSubcategoryDanceClass,
      'dance_practice': _taxSubcategoryDancePractice,
      'dance_show': _taxSubcategoryDanceShow,
      'hiking': _taxSubcategoryHiking,
      'nature_walk': _taxSubcategoryNatureWalk,
      'city_walk': _taxSubcategoryCityWalk,
      'historical_walk': _taxSubcategoryHistoricalWalk,
      'sunset_walk': _taxSubcategorySunsetWalk,
      'sunrise_walk': _taxSubcategorySunriseWalk,
      'forest_walk': _taxSubcategoryForestWalk,
      'lake_walk': _taxSubcategoryLakeWalk,
      'river_walk': _taxSubcategoryRiverWalk,
      'architecture_walk': _taxSubcategoryArchitectureWalk,
      'hidden_gems_walk': _taxSubcategoryHiddenGemsWalk,
      'photography_walk': _taxSubcategoryPhotographyWalk,
      'birdwatching': _taxSubcategoryBirdwatching,
      'mushroom_picking': _taxSubcategoryMushroomPicking,
      'berry_picking': _taxSubcategoryBerryPicking,
      'picnic_walk': _taxSubcategoryPicnicWalk,
      'park_walk': _taxSubcategoryParkWalk,
      'beach_walk': _taxSubcategoryBeachWalk,
      'promenade_walk': _taxSubcategoryPromenadeWalk,
      'park': _taxSubcategoryPark,
      'beach': _taxSubcategoryBeach,
      'promenade': _taxSubcategoryPromenade,
      'viewpoint': _taxSubcategoryViewpoint,
      'forest': _taxSubcategoryForest,
      'lake': _taxSubcategoryLake,
      'waterfall': _taxSubcategoryWaterfall,
      'cave': _taxSubcategoryCave,
      'natural_landmark': _taxSubcategoryNaturalLandmark,
      'outdoor_workout': _taxSubcategoryOutdoorWorkout,
      'nature_escape': _taxSubcategoryNatureEscape,
      'slow_walk': _taxSubcategorySlowWalk,
      'stargazing': _taxSubcategoryStargazing,
      'northern_lights_watch': _taxSubcategoryNorthernLightsWatch,
      'meteor_shower_watch': _taxSubcategoryMeteorShowerWatch,
      'sup': _taxSubcategorySup,
      'kayak': _taxSubcategoryKayak,
      'canoe': _taxSubcategoryCanoe,
      'boat_trip': _taxSubcategoryBoatTrip,
      'catamaran': _taxSubcategoryCatamaran,
      'canal_cruise': _taxSubcategoryCanalCruise,
      'rowing': _taxSubcategoryRowing,
      'sailing': _taxSubcategorySailing,
      'fishing': _taxSubcategoryFishing,
      'wakeboarding': _taxSubcategoryWakeboarding,
      'water_bike': _taxSubcategoryWaterBike,
      'jet_ski': _taxSubcategoryJetSki,
      'beach_activity': _taxSubcategoryBeachActivity,
      'water_tour': _taxSubcategoryWaterTour,
      'diving': _taxSubcategoryDiving,
      'snorkeling': _taxSubcategorySnorkeling,
      'surfing': _taxSubcategorySurfing,
      'windsurfing': _taxSubcategoryWindsurfing,
      'kitesurfing': _taxSubcategoryKitesurfing,
      'beach_day': _taxSubcategoryBeachDay,
      'winter_walk': _taxSubcategoryWinterWalk,
      'ice_skating': _taxSubcategoryIceSkating,
      'skiing': _taxSubcategorySkiing,
      'snowboarding': _taxSubcategorySnowboarding,
      'sledding': _taxSubcategorySledding,
      'winter_hiking': _taxSubcategoryWinterHiking,
      'christmas_market_walk': _taxSubcategoryChristmasMarketWalk,
      'winter_photo_route': _taxSubcategoryWinterPhotoRoute,
      'sauna_cold_plunge': _taxSubcategorySaunaColdPlunge,
      'ice_fishing': _taxSubcategoryIceFishing,
      'winter_festival': _taxSubcategoryWinterFestival,
      'autumn_leaf_walk': _taxSubcategoryAutumnLeafWalk,
      'spring_blossom_walk': _taxSubcategorySpringBlossomWalk,
      'summer_outdoor': _taxSubcategorySummerOutdoor,
      'seasonal_walk': _taxSubcategorySeasonalWalk,
      'snow_activity': _taxSubcategorySnowActivity,
      'cold_plunge': _taxSubcategoryColdPlunge,
      'holiday_lights_walk': _taxSubcategoryHolidayLightsWalk,
      'day_trip': _taxSubcategoryDayTrip,
      'weekend_trip': _taxSubcategoryWeekendTrip,
      'local_experience': _taxSubcategoryLocalExperience,
      'tourist_excursion': _taxSubcategoryTouristExcursion,
      'city_tour': _taxSubcategoryCityTour,
      'food_tasting_tour': _taxSubcategoryFoodTastingTour,
      'craft_experience': _taxSubcategoryCraftExperience,
      'farm_experience': _taxSubcategoryFarmExperience,
      'castle_tour': _taxSubcategoryCastleTour,
      'nature_reserve_tour': _taxSubcategoryNatureReserveTour,
      'coastal_trip': _taxSubcategoryCoastalTrip,
      'train_day_trip': _taxSubcategoryTrainDayTrip,
      'local_guide_experience': _taxSubcategoryLocalGuideExperience,
      'bike_tour': _taxSubcategoryBikeTour,
      'walking_tour': _taxSubcategoryWalkingTour,
      'historical_tour': _taxSubcategoryHistoricalTour,
      'architecture_tour': _taxSubcategoryArchitectureTour,
      'photo_tour': _taxSubcategoryPhotoTour,
      'hidden_gems_tour': _taxSubcategoryHiddenGemsTour,
      'family_activity': _taxSubcategoryFamilyActivity,
      'kids_workshop': _taxSubcategoryKidsWorkshop,
      'playground_event': _taxSubcategoryPlaygroundEvent,
      'family_picnic': _taxSubcategoryFamilyPicnic,
      'kids_theatre': _taxSubcategoryKidsTheatre,
      'kids_museum_event': _taxSubcategoryKidsMuseumEvent,
      'family_sports_day': _taxSubcategoryFamilySportsDay,
      'parent_child_class': _taxSubcategoryParentChildClass,
      'creative_kids_class': _taxSubcategoryCreativeKidsClass,
      'kids_cooking_class': _taxSubcategoryKidsCookingClass,
      'kids_outdoor_walk': _taxSubcategoryKidsOutdoorWalk,
      'birthday_activity': _taxSubcategoryBirthdayActivity,
      'family_farm_visit': _taxSubcategoryFamilyFarmVisit,
      'family_route': _taxSubcategoryFamilyRoute,
      'kids_party': _taxSubcategoryKidsParty,
      'educational_kids_event': _taxSubcategoryEducationalKidsEvent,
      'baby_friendly_activity': _taxSubcategoryBabyFriendlyActivity,
      'kids_camp': _taxSubcategoryKidsCamp,
      'day_camp': _taxSubcategoryDayCamp,
      'teen_meetup': _taxSubcategoryTeenMeetup,
      'teen_event': _taxSubcategoryTeenEvent,
      'kids_quest': _taxSubcategoryKidsQuest,
      'kids_science_event': _taxSubcategoryKidsScienceEvent,
      'kids_disco': _taxSubcategoryKidsDisco,
      'dog_walk': _taxSubcategoryDogWalk,
      'dog_meetup': _taxSubcategoryDogMeetup,
      'dog_park_meetup': _taxSubcategoryDogParkMeetup,
      'pet_friendly_cafe': _taxSubcategoryPetFriendlyCafe,
      'dog_training': _taxSubcategoryDogTraining,
      'pet_photo_session': _taxSubcategoryPetPhotoSession,
      'animal_shelter_visit': _taxSubcategoryAnimalShelterVisit,
      'farm_animal_experience': _taxSubcategoryFarmAnimalExperience,
      'horse_riding': _taxSubcategoryHorseRiding,
      'pony_riding': _taxSubcategoryPonyRiding,
      'cat_cafe': _taxSubcategoryCatCafe,
      'pet_adoption': _taxSubcategoryPetAdoption,
      'pet_charity': _taxSubcategoryPetCharity,
      'pet_friendly_walk': _taxSubcategoryPetFriendlyWalk,
      'dog_sport': _taxSubcategoryDogSport,
      'pet_owner_meetup': _taxSubcategoryPetOwnerMeetup,
      'dog_show': _taxSubcategoryDogShow,
      'pet_exhibition': _taxSubcategoryPetExhibition,
      'pet_fair': _taxSubcategoryPetFair,
      'pet_care_talk': _taxSubcategoryPetCareTalk,
      'animal_therapy': _taxSubcategoryAnimalTherapy,
      'charity_event': _taxSubcategoryCharityEvent,
      'volunteer_activity': _taxSubcategoryVolunteerActivity,
      'community_cleanup': _taxSubcategoryCommunityCleanup,
      'donation_event': _taxSubcategoryDonationEvent,
      'neighborhood_event': _taxSubcategoryNeighborhoodEvent,
      'fundraising_dinner': _taxSubcategoryFundraisingDinner,
      'charity_run': _taxSubcategoryCharityRun,
      'animal_shelter_volunteering': _taxSubcategoryAnimalShelterVolunteering,
      'food_bank_volunteering': _taxSubcategoryFoodBankVolunteering,
      'tree_planting': _taxSubcategoryTreePlanting,
      'beach_cleanup': _taxSubcategoryBeachCleanup,
      'park_cleanup': _taxSubcategoryParkCleanup,
      'community_garden': _taxSubcategoryCommunityGarden,
      'public_square': _taxSubcategoryPublicSquare,
      'local_community_meetup': _taxSubcategoryLocalCommunityMeetup,
      'mutual_aid': _taxSubcategoryMutualAid,
      'social_impact_event': _taxSubcategorySocialImpactEvent,
      'environmental_action': _taxSubcategoryEnvironmentalAction,
      'local_market': _taxSubcategoryLocalMarket,
      'flea_market': _taxSubcategoryFleaMarket,
      'seasonal_market': _taxSubcategorySeasonalMarket,
      'christmas_market': _taxSubcategoryChristmasMarket,
      'farmers_market': _taxSubcategoryFarmersMarket,
      'craft_market': _taxSubcategoryCraftMarket,
      'design_market': _taxSubcategoryDesignMarket,
      'vintage_market': _taxSubcategoryVintageMarket,
      'book_market': _taxSubcategoryBookMarket,
      'food_market': _taxSubcategoryFoodMarket,
      'flower_market': _taxSubcategoryFlowerMarket,
      'art_fair': _taxSubcategoryArtFair,
      'pop_up_shop': _taxSubcategoryPopUpShop,
      'street_market': _taxSubcategoryStreetMarket,
      'handmade_fair': _taxSubcategoryHandmadeFair,
      'charity_market': _taxSubcategoryCharityMarket,
      'kids_market': _taxSubcategoryKidsMarket,
      'night_market': _taxSubcategoryNightMarket,
      'local_brands_market': _taxSubcategoryLocalBrandsMarket,
      'clothing_swap': _taxSubcategoryClothingSwap,
      'christmas': _taxSubcategoryChristmas,
      'new_year': _taxSubcategoryNewYear,
      'halloween': _taxSubcategoryHalloween,
      'easter': _taxSubcategoryEaster,
      'valentines_day': _taxSubcategoryValentinesDay,
      'jani': _taxSubcategoryJani,
      'city_festival': _taxSubcategoryCityFestival,
      'summer_festival': _taxSubcategorySummerFestival,
      'autumn_event': _taxSubcategoryAutumnEvent,
      'spring_event': _taxSubcategorySpringEvent,
      'school_holiday': _taxSubcategorySchoolHoliday,
      'national_holiday': _taxSubcategoryNationalHoliday,
      'local_tradition': _taxSubcategoryLocalTradition,
      'midsummer': _taxSubcategoryMidsummer,
      'fireworks': _taxSubcategoryFireworks,
      'public_celebration': _taxSubcategoryPublicCelebration,
      'recharge_walk': _taxSubcategoryRechargeWalk,
      'calm_walk': _taxSubcategoryCalmWalk,
      'mindful_walk': _taxSubcategoryMindfulWalk,
      'coffee_walk': _taxSubcategoryCoffeeWalk,
      'tea_walk': _taxSubcategoryTeaWalk,
      'sunset_reset': _taxSubcategorySunsetReset,
      'nature_reset': _taxSubcategoryNatureReset,
      'digital_detox': _taxSubcategoryDigitalDetox,
      'slow_morning': _taxSubcategorySlowMorning,
      'evening_reset': _taxSubcategoryEveningReset,
      'sauna': _taxSubcategorySauna,
      'spa': _taxSubcategorySpa,
      'massage': _taxSubcategoryMassage,
      'breathwork': _taxSubcategoryBreathwork,
      'meditation': _taxSubcategoryMeditation,
      'sound_healing': _taxSubcategorySoundHealing,
      'wellness_class': _taxSubcategoryWellnessClass,
      'relaxation_session': _taxSubcategoryRelaxationSession,
      'mental_health_meetup': _taxSubcategoryMentalHealthMeetup,
      'quiet_social': _taxSubcategoryQuietSocial,
      'couple_recharge': _taxSubcategoryCoupleRecharge,
      'solo_recharge': _taxSubcategorySoloRecharge,
      'friends_recharge': _taxSubcategoryFriendsRecharge,
      'pirts_ritual': _taxSubcategoryPirtsRitual,
      'retreat': _taxSubcategoryRetreat,
      'laser_tag': _taxSubcategoryLaserTag,
      'paintball': _taxSubcategoryPaintball,
      'airsoft': _taxSubcategoryAirsoft,
      'karting': _taxSubcategoryKarting,
      'shooting_range': _taxSubcategoryShootingRange,
      'archery': _taxSubcategoryArchery,
      'axe_throwing': _taxSubcategoryAxeThrowing,
      'trampoline_park': _taxSubcategoryTrampolinePark,
      'rope_park': _taxSubcategoryRopePark,
      'zipline': _taxSubcategoryZipline,
      'wind_tunnel': _taxSubcategoryWindTunnel,
      'hot_air_balloon': _taxSubcategoryHotAirBalloon,
      'skydiving': _taxSubcategorySkydiving,
      'bungee_jumping': _taxSubcategoryBungeeJumping,
      'parkour': _taxSubcategoryParkour,
      'obstacle_course': _taxSubcategoryObstacleCourse,
      'zoo': _taxSubcategoryZoo,
      'petting_zoo': _taxSubcategoryPettingZoo,
      'aquarium': _taxSubcategoryAquarium,
      'amusement_park': _taxSubcategoryAmusementPark,
      'water_park': _taxSubcategoryWaterPark,
      'adventure_park': _taxSubcategoryAdventurePark,
      'botanical_garden': _taxSubcategoryBotanicalGarden,
      'planetarium': _taxSubcategoryPlanetarium,
      'science_center': _taxSubcategoryScienceCenter,
      'observation_deck': _taxSubcategoryObservationDeck,
      'ferris_wheel': _taxSubcategoryFerrisWheel,
      'seasonal_attraction': _taxSubcategorySeasonalAttraction,
      'car_meetup': _taxSubcategoryCarMeetup,
      'retro_cars': _taxSubcategoryRetroCars,
      'car_show': _taxSubcategoryCarShow,
      'auto_exhibition': _taxSubcategoryAutoExhibition,
      'tuning_meetup': _taxSubcategoryTuningMeetup,
      'drift_event': _taxSubcategoryDriftEvent,
      'offroad_trip': _taxSubcategoryOffroadTrip,
      'motorcycle_ride': _taxSubcategoryMotorcycleRide,
      'motorcycle_meetup': _taxSubcategoryMotorcycleMeetup,
      'scooter_meetup': _taxSubcategoryScooterMeetup,
      'car_photo_meet': _taxSubcategoryCarPhotoMeet,
      'drive_in_cinema': _taxSubcategoryDriveInCinema,
      'anime_meetup': _taxSubcategoryAnimeMeetup,
      'cosplay_event': _taxSubcategoryCosplayEvent,
      'comic_con': _taxSubcategoryComicCon,
      'esports_tournament': _taxSubcategoryEsportsTournament,
      'lan_party': _taxSubcategoryLanParty,
      'retro_gaming': _taxSubcategoryRetroGaming,
      'tabletop_wargames': _taxSubcategoryTabletopWargames,
      'trading_card_games': _taxSubcategoryTradingCardGames,
      'hackathon': _taxSubcategoryHackathon,
      'game_dev_meetup': _taxSubcategoryGameDevMeetup,
      'tech_meetup': _taxSubcategoryTechMeetup,
      'robotics_event': _taxSubcategoryRoboticsEvent,
      'fandom_meetup': _taxSubcategoryFandomMeetup,
      'collectors_meetup': _taxSubcategoryCollectorsMeetup,
      'speed_dating': _taxSubcategorySpeedDating,
      'singles_party': _taxSubcategorySinglesParty,
      'singles_mixer': _taxSubcategorySinglesMixer,
      'singles_dinner': _taxSubcategorySinglesDinner,
      'blind_date_event': _taxSubcategoryBlindDateEvent,
      'dating_game_event': _taxSubcategoryDatingGameEvent,
      'singles_activity': _taxSubcategorySinglesActivity,
      'matchmaking_event': _taxSubcategoryMatchmakingEvent,
      'other_event': _taxSubcategoryOtherEvent,
    };

String _taxCategoryMusicNightlife(AppLocalizations l) =>
    l.taxCategoryMusicNightlife;
String _taxCategoryComedyTheatrePerformance(AppLocalizations l) =>
    l.taxCategoryComedyTheatrePerformance;
String _taxCategoryCinemaScreenings(AppLocalizations l) =>
    l.taxCategoryCinemaScreenings;
String _taxCategoryArtCultureMuseums(AppLocalizations l) =>
    l.taxCategoryArtCultureMuseums;
String _taxCategoryEducationTalks(AppLocalizations l) =>
    l.taxCategoryEducationTalks;
String _taxCategoryBusinessNetworking(AppLocalizations l) =>
    l.taxCategoryBusinessNetworking;
String _taxCategoryWorkshopsMasterclasses(AppLocalizations l) =>
    l.taxCategoryWorkshopsMasterclasses;
String _taxCategoryLanguageSocialLearning(AppLocalizations l) =>
    l.taxCategoryLanguageSocialLearning;
String _taxCategoryFoodDrinks(AppLocalizations l) => l.taxCategoryFoodDrinks;
String _taxCategoryGamesIndoor(AppLocalizations l) => l.taxCategoryGamesIndoor;
String _taxCategorySport(AppLocalizations l) => l.taxCategorySport;
String _taxCategoryDance(AppLocalizations l) => l.taxCategoryDance;
String _taxCategoryOutdoorNatureWalking(AppLocalizations l) =>
    l.taxCategoryOutdoorNatureWalking;
String _taxCategoryWaterActivities(AppLocalizations l) =>
    l.taxCategoryWaterActivities;
String _taxCategoryWinterSeasonal(AppLocalizations l) =>
    l.taxCategoryWinterSeasonal;
String _taxCategoryTravelTours(AppLocalizations l) => l.taxCategoryTravelTours;
String _taxCategoryFamilyKids(AppLocalizations l) => l.taxCategoryFamilyKids;
String _taxCategoryPetsAnimals(AppLocalizations l) => l.taxCategoryPetsAnimals;
String _taxCategoryCommunityCharity(AppLocalizations l) =>
    l.taxCategoryCommunityCharity;
String _taxCategoryMarketsFairs(AppLocalizations l) =>
    l.taxCategoryMarketsFairs;
String _taxCategoryHolidaysSeasonal(AppLocalizations l) =>
    l.taxCategoryHolidaysSeasonal;
String _taxCategoryWellnessRecharge(AppLocalizations l) =>
    l.taxCategoryWellnessRecharge;
String _taxCategoryAdrenalineEntertainment(AppLocalizations l) =>
    l.taxCategoryAdrenalineEntertainment;
String _taxCategoryAttractions(AppLocalizations l) => l.taxCategoryAttractions;
String _taxCategoryAutoMoto(AppLocalizations l) => l.taxCategoryAutoMoto;
String _taxCategoryGeekTech(AppLocalizations l) => l.taxCategoryGeekTech;
String _taxCategoryDatingSingles(AppLocalizations l) =>
    l.taxCategoryDatingSingles;
String _taxCategoryOther(AppLocalizations l) => l.taxCategoryOther;
String _taxSubcategoryConcert(AppLocalizations l) => l.taxSubcategoryConcert;
String _taxSubcategoryLiveMusic(AppLocalizations l) =>
    l.taxSubcategoryLiveMusic;
String _taxSubcategoryAcousticEvening(AppLocalizations l) =>
    l.taxSubcategoryAcousticEvening;
String _taxSubcategoryJazz(AppLocalizations l) => l.taxSubcategoryJazz;
String _taxSubcategoryClassicalMusic(AppLocalizations l) =>
    l.taxSubcategoryClassicalMusic;
String _taxSubcategoryRockMusic(AppLocalizations l) =>
    l.taxSubcategoryRockMusic;
String _taxSubcategoryPopMusic(AppLocalizations l) => l.taxSubcategoryPopMusic;
String _taxSubcategoryElectronicMusic(AppLocalizations l) =>
    l.taxSubcategoryElectronicMusic;
String _taxSubcategoryTechno(AppLocalizations l) => l.taxSubcategoryTechno;
String _taxSubcategoryHouseMusic(AppLocalizations l) =>
    l.taxSubcategoryHouseMusic;
String _taxSubcategoryLatinMusic(AppLocalizations l) =>
    l.taxSubcategoryLatinMusic;
String _taxSubcategoryDjParty(AppLocalizations l) => l.taxSubcategoryDjParty;
String _taxSubcategoryClubNight(AppLocalizations l) =>
    l.taxSubcategoryClubNight;
String _taxSubcategoryKaraoke(AppLocalizations l) => l.taxSubcategoryKaraoke;
String _taxSubcategoryOpenMicMusic(AppLocalizations l) =>
    l.taxSubcategoryOpenMicMusic;
String _taxSubcategoryRooftopParty(AppLocalizations l) =>
    l.taxSubcategoryRooftopParty;
String _taxSubcategoryBeachParty(AppLocalizations l) =>
    l.taxSubcategoryBeachParty;
String _taxSubcategoryThemedParty(AppLocalizations l) =>
    l.taxSubcategoryThemedParty;
String _taxSubcategoryMusicFestival(AppLocalizations l) =>
    l.taxSubcategoryMusicFestival;
String _taxSubcategoryListeningParty(AppLocalizations l) =>
    l.taxSubcategoryListeningParty;
String _taxSubcategoryJamSession(AppLocalizations l) =>
    l.taxSubcategoryJamSession;
String _taxSubcategoryNightBar(AppLocalizations l) => l.taxSubcategoryNightBar;
String _taxSubcategoryAfterworkDrinks(AppLocalizations l) =>
    l.taxSubcategoryAfterworkDrinks;
String _taxSubcategoryLateNightSocial(AppLocalizations l) =>
    l.taxSubcategoryLateNightSocial;
String _taxSubcategoryGroupSinging(AppLocalizations l) =>
    l.taxSubcategoryGroupSinging;
String _taxSubcategoryOrganConcert(AppLocalizations l) =>
    l.taxSubcategoryOrganConcert;
String _taxSubcategoryStandup(AppLocalizations l) => l.taxSubcategoryStandup;
String _taxSubcategoryComedyOpenMic(AppLocalizations l) =>
    l.taxSubcategoryComedyOpenMic;
String _taxSubcategoryTheatre(AppLocalizations l) => l.taxSubcategoryTheatre;
String _taxSubcategoryImprovisation(AppLocalizations l) =>
    l.taxSubcategoryImprovisation;
String _taxSubcategoryMagicShow(AppLocalizations l) =>
    l.taxSubcategoryMagicShow;
String _taxSubcategoryCircus(AppLocalizations l) => l.taxSubcategoryCircus;
String _taxSubcategoryPoetryNight(AppLocalizations l) =>
    l.taxSubcategoryPoetryNight;
String _taxSubcategoryStorytelling(AppLocalizations l) =>
    l.taxSubcategoryStorytelling;
String _taxSubcategoryPuppetShow(AppLocalizations l) =>
    l.taxSubcategoryPuppetShow;
String _taxSubcategoryBallet(AppLocalizations l) => l.taxSubcategoryBallet;
String _taxSubcategoryOpera(AppLocalizations l) => l.taxSubcategoryOpera;
String _taxSubcategoryCabaret(AppLocalizations l) => l.taxSubcategoryCabaret;
String _taxSubcategoryStreetPerformance(AppLocalizations l) =>
    l.taxSubcategoryStreetPerformance;
String _taxSubcategoryPerformanceArt(AppLocalizations l) =>
    l.taxSubcategoryPerformanceArt;
String _taxSubcategoryDragShow(AppLocalizations l) => l.taxSubcategoryDragShow;
String _taxSubcategoryMusical(AppLocalizations l) => l.taxSubcategoryMusical;
String _taxSubcategoryExperimentalTheatre(AppLocalizations l) =>
    l.taxSubcategoryExperimentalTheatre;
String _taxSubcategoryCinema(AppLocalizations l) => l.taxSubcategoryCinema;
String _taxSubcategoryMovieScreening(AppLocalizations l) =>
    l.taxSubcategoryMovieScreening;
String _taxSubcategoryOpenAirCinema(AppLocalizations l) =>
    l.taxSubcategoryOpenAirCinema;
String _taxSubcategoryFilmFestival(AppLocalizations l) =>
    l.taxSubcategoryFilmFestival;
String _taxSubcategoryDocumentary(AppLocalizations l) =>
    l.taxSubcategoryDocumentary;
String _taxSubcategoryShortFilms(AppLocalizations l) =>
    l.taxSubcategoryShortFilms;
String _taxSubcategoryRetroCinema(AppLocalizations l) =>
    l.taxSubcategoryRetroCinema;
String _taxSubcategoryAnimation(AppLocalizations l) =>
    l.taxSubcategoryAnimation;
String _taxSubcategorySportsScreening(AppLocalizations l) =>
    l.taxSubcategorySportsScreening;
String _taxSubcategoryMovieDiscussion(AppLocalizations l) =>
    l.taxSubcategoryMovieDiscussion;
String _taxSubcategoryPremiere(AppLocalizations l) => l.taxSubcategoryPremiere;
String _taxSubcategoryIndependentFilm(AppLocalizations l) =>
    l.taxSubcategoryIndependentFilm;
String _taxSubcategoryCinemaClub(AppLocalizations l) =>
    l.taxSubcategoryCinemaClub;
String _taxSubcategoryExhibition(AppLocalizations l) =>
    l.taxSubcategoryExhibition;
String _taxSubcategoryGallery(AppLocalizations l) => l.taxSubcategoryGallery;
String _taxSubcategoryMuseum(AppLocalizations l) => l.taxSubcategoryMuseum;
String _taxSubcategoryMuseumNight(AppLocalizations l) =>
    l.taxSubcategoryMuseumNight;
String _taxSubcategoryGalleryWalk(AppLocalizations l) =>
    l.taxSubcategoryGalleryWalk;
String _taxSubcategoryArtistTalk(AppLocalizations l) =>
    l.taxSubcategoryArtistTalk;
String _taxSubcategoryArtWalk(AppLocalizations l) => l.taxSubcategoryArtWalk;
String _taxSubcategoryPhotographyExhibition(AppLocalizations l) =>
    l.taxSubcategoryPhotographyExhibition;
String _taxSubcategoryStreetArt(AppLocalizations l) =>
    l.taxSubcategoryStreetArt;
String _taxSubcategoryArchitecture(AppLocalizations l) =>
    l.taxSubcategoryArchitecture;
String _taxSubcategoryCulturalHeritage(AppLocalizations l) =>
    l.taxSubcategoryCulturalHeritage;
String _taxSubcategoryMonument(AppLocalizations l) => l.taxSubcategoryMonument;
String _taxSubcategoryMemorial(AppLocalizations l) => l.taxSubcategoryMemorial;
String _taxSubcategorySculpture(AppLocalizations l) =>
    l.taxSubcategorySculpture;
String _taxSubcategoryHistoricLandmark(AppLocalizations l) =>
    l.taxSubcategoryHistoricLandmark;
String _taxSubcategoryLiteratureEvening(AppLocalizations l) =>
    l.taxSubcategoryLiteratureEvening;
String _taxSubcategoryBookReading(AppLocalizations l) =>
    l.taxSubcategoryBookReading;
String _taxSubcategoryHistoryWalk(AppLocalizations l) =>
    l.taxSubcategoryHistoryWalk;
String _taxSubcategoryDesignEvent(AppLocalizations l) =>
    l.taxSubcategoryDesignEvent;
String _taxSubcategoryCraftExhibition(AppLocalizations l) =>
    l.taxSubcategoryCraftExhibition;
String _taxSubcategoryPublicArt(AppLocalizations l) =>
    l.taxSubcategoryPublicArt;
String _taxSubcategoryCreativeMeetup(AppLocalizations l) =>
    l.taxSubcategoryCreativeMeetup;
String _taxSubcategoryFashionEvent(AppLocalizations l) =>
    l.taxSubcategoryFashionEvent;
String _taxSubcategoryLecture(AppLocalizations l) => l.taxSubcategoryLecture;
String _taxSubcategoryPublicTalk(AppLocalizations l) =>
    l.taxSubcategoryPublicTalk;
String _taxSubcategoryDiscussion(AppLocalizations l) =>
    l.taxSubcategoryDiscussion;
String _taxSubcategoryDebate(AppLocalizations l) => l.taxSubcategoryDebate;
String _taxSubcategoryPanelDiscussion(AppLocalizations l) =>
    l.taxSubcategoryPanelDiscussion;
String _taxSubcategoryScienceTalk(AppLocalizations l) =>
    l.taxSubcategoryScienceTalk;
String _taxSubcategoryHistoryLecture(AppLocalizations l) =>
    l.taxSubcategoryHistoryLecture;
String _taxSubcategoryPsychologyTalk(AppLocalizations l) =>
    l.taxSubcategoryPsychologyTalk;
String _taxSubcategoryFinanceTalk(AppLocalizations l) =>
    l.taxSubcategoryFinanceTalk;
String _taxSubcategoryCareerTalk(AppLocalizations l) =>
    l.taxSubcategoryCareerTalk;
String _taxSubcategoryLegalInfoSession(AppLocalizations l) =>
    l.taxSubcategoryLegalInfoSession;
String _taxSubcategoryBookClub(AppLocalizations l) => l.taxSubcategoryBookClub;
String _taxSubcategoryPracticalSeminar(AppLocalizations l) =>
    l.taxSubcategoryPracticalSeminar;
String _taxSubcategorySelfDevelopment(AppLocalizations l) =>
    l.taxSubcategorySelfDevelopment;
String _taxSubcategoryHealthTalk(AppLocalizations l) =>
    l.taxSubcategoryHealthTalk;
String _taxSubcategoryTechnologyTalk(AppLocalizations l) =>
    l.taxSubcategoryTechnologyTalk;
String _taxSubcategoryStartupTalk(AppLocalizations l) =>
    l.taxSubcategoryStartupTalk;
String _taxSubcategoryParentingTalk(AppLocalizations l) =>
    l.taxSubcategoryParentingTalk;
String _taxSubcategoryCommunityDiscussion(AppLocalizations l) =>
    l.taxSubcategoryCommunityDiscussion;
String _taxSubcategoryNetworking(AppLocalizations l) =>
    l.taxSubcategoryNetworking;
String _taxSubcategoryBusinessBreakfast(AppLocalizations l) =>
    l.taxSubcategoryBusinessBreakfast;
String _taxSubcategoryBusinessLunch(AppLocalizations l) =>
    l.taxSubcategoryBusinessLunch;
String _taxSubcategoryConference(AppLocalizations l) =>
    l.taxSubcategoryConference;
String _taxSubcategoryProductPresentation(AppLocalizations l) =>
    l.taxSubcategoryProductPresentation;
String _taxSubcategoryProductLaunch(AppLocalizations l) =>
    l.taxSubcategoryProductLaunch;
String _taxSubcategoryStartupMeetup(AppLocalizations l) =>
    l.taxSubcategoryStartupMeetup;
String _taxSubcategoryPitchNight(AppLocalizations l) =>
    l.taxSubcategoryPitchNight;
String _taxSubcategoryInvestorMeetup(AppLocalizations l) =>
    l.taxSubcategoryInvestorMeetup;
String _taxSubcategoryJobFair(AppLocalizations l) => l.taxSubcategoryJobFair;
String _taxSubcategoryPortfolioReview(AppLocalizations l) =>
    l.taxSubcategoryPortfolioReview;
String _taxSubcategoryFreelancersMeetup(AppLocalizations l) =>
    l.taxSubcategoryFreelancersMeetup;
String _taxSubcategoryDemoDay(AppLocalizations l) => l.taxSubcategoryDemoDay;
String _taxSubcategoryExpo(AppLocalizations l) => l.taxSubcategoryExpo;
String _taxSubcategoryFounderMeetup(AppLocalizations l) =>
    l.taxSubcategoryFounderMeetup;
String _taxSubcategoryIndustryMeetup(AppLocalizations l) =>
    l.taxSubcategoryIndustryMeetup;
String _taxSubcategoryCareerNetworking(AppLocalizations l) =>
    l.taxSubcategoryCareerNetworking;
String _taxSubcategoryCoworkingEvent(AppLocalizations l) =>
    l.taxSubcategoryCoworkingEvent;
String _taxSubcategoryBusinessWorkshop(AppLocalizations l) =>
    l.taxSubcategoryBusinessWorkshop;
String _taxSubcategoryWorkshop(AppLocalizations l) => l.taxSubcategoryWorkshop;
String _taxSubcategoryMasterclass(AppLocalizations l) =>
    l.taxSubcategoryMasterclass;
String _taxSubcategoryCourse(AppLocalizations l) => l.taxSubcategoryCourse;
String _taxSubcategoryPottery(AppLocalizations l) => l.taxSubcategoryPottery;
String _taxSubcategoryCeramics(AppLocalizations l) => l.taxSubcategoryCeramics;
String _taxSubcategoryDrawing(AppLocalizations l) => l.taxSubcategoryDrawing;
String _taxSubcategoryPainting(AppLocalizations l) => l.taxSubcategoryPainting;
String _taxSubcategoryPhotography(AppLocalizations l) =>
    l.taxSubcategoryPhotography;
String _taxSubcategoryCookingClass(AppLocalizations l) =>
    l.taxSubcategoryCookingClass;
String _taxSubcategorySewing(AppLocalizations l) => l.taxSubcategorySewing;
String _taxSubcategoryFloristics(AppLocalizations l) =>
    l.taxSubcategoryFloristics;
String _taxSubcategoryCandleMaking(AppLocalizations l) =>
    l.taxSubcategoryCandleMaking;
String _taxSubcategoryPublicSpeaking(AppLocalizations l) =>
    l.taxSubcategoryPublicSpeaking;
String _taxSubcategoryCreativeClass(AppLocalizations l) =>
    l.taxSubcategoryCreativeClass;
String _taxSubcategoryCraftWorkshop(AppLocalizations l) =>
    l.taxSubcategoryCraftWorkshop;
String _taxSubcategoryWritingWorkshop(AppLocalizations l) =>
    l.taxSubcategoryWritingWorkshop;
String _taxSubcategoryMusicLesson(AppLocalizations l) =>
    l.taxSubcategoryMusicLesson;
String _taxSubcategoryDanceWorkshop(AppLocalizations l) =>
    l.taxSubcategoryDanceWorkshop;
String _taxSubcategoryBeautyWorkshop(AppLocalizations l) =>
    l.taxSubcategoryBeautyWorkshop;
String _taxSubcategoryWellnessWorkshop(AppLocalizations l) =>
    l.taxSubcategoryWellnessWorkshop;
String _taxSubcategoryLanguageExchange(AppLocalizations l) =>
    l.taxSubcategoryLanguageExchange;
String _taxSubcategoryEnglishClub(AppLocalizations l) =>
    l.taxSubcategoryEnglishClub;
String _taxSubcategoryDutchClub(AppLocalizations l) =>
    l.taxSubcategoryDutchClub;
String _taxSubcategoryLatvianClub(AppLocalizations l) =>
    l.taxSubcategoryLatvianClub;
String _taxSubcategoryConversationClub(AppLocalizations l) =>
    l.taxSubcategoryConversationClub;
String _taxSubcategoryInternationalMeetup(AppLocalizations l) =>
    l.taxSubcategoryInternationalMeetup;
String _taxSubcategoryExpatsMeetup(AppLocalizations l) =>
    l.taxSubcategoryExpatsMeetup;
String _taxSubcategoryTandemMeeting(AppLocalizations l) =>
    l.taxSubcategoryTandemMeeting;
String _taxSubcategoryLanguageCafe(AppLocalizations l) =>
    l.taxSubcategoryLanguageCafe;
String _taxSubcategoryLanguageWalk(AppLocalizations l) =>
    l.taxSubcategoryLanguageWalk;
String _taxSubcategorySpeedFriending(AppLocalizations l) =>
    l.taxSubcategorySpeedFriending;
String _taxSubcategorySpeakingClub(AppLocalizations l) =>
    l.taxSubcategorySpeakingClub;
String _taxSubcategoryCultureExchange(AppLocalizations l) =>
    l.taxSubcategoryCultureExchange;
String _taxSubcategoryNewcomersMeetup(AppLocalizations l) =>
    l.taxSubcategoryNewcomersMeetup;
String _taxSubcategoryStudyGroup(AppLocalizations l) =>
    l.taxSubcategoryStudyGroup;
String _taxSubcategoryCoffee(AppLocalizations l) => l.taxSubcategoryCoffee;
String _taxSubcategoryBreakfast(AppLocalizations l) =>
    l.taxSubcategoryBreakfast;
String _taxSubcategoryBrunch(AppLocalizations l) => l.taxSubcategoryBrunch;
String _taxSubcategoryLunch(AppLocalizations l) => l.taxSubcategoryLunch;
String _taxSubcategoryDinner(AppLocalizations l) => l.taxSubcategoryDinner;
String _taxSubcategoryDessert(AppLocalizations l) => l.taxSubcategoryDessert;
String _taxSubcategoryStreetFood(AppLocalizations l) =>
    l.taxSubcategoryStreetFood;
String _taxSubcategoryFoodTasting(AppLocalizations l) =>
    l.taxSubcategoryFoodTasting;
String _taxSubcategoryDrinkTasting(AppLocalizations l) =>
    l.taxSubcategoryDrinkTasting;
String _taxSubcategoryWineTasting(AppLocalizations l) =>
    l.taxSubcategoryWineTasting;
String _taxSubcategoryBeerTasting(AppLocalizations l) =>
    l.taxSubcategoryBeerTasting;
String _taxSubcategoryCocktailTasting(AppLocalizations l) =>
    l.taxSubcategoryCocktailTasting;
String _taxSubcategoryTeaCeremony(AppLocalizations l) =>
    l.taxSubcategoryTeaCeremony;
String _taxSubcategoryBbq(AppLocalizations l) => l.taxSubcategoryBbq;
String _taxSubcategoryPicnic(AppLocalizations l) => l.taxSubcategoryPicnic;
String _taxSubcategoryFoodTour(AppLocalizations l) => l.taxSubcategoryFoodTour;
String _taxSubcategoryBarCrawl(AppLocalizations l) => l.taxSubcategoryBarCrawl;
String _taxSubcategoryPubCrawl(AppLocalizations l) => l.taxSubcategoryPubCrawl;
String _taxSubcategoryHappyHour(AppLocalizations l) =>
    l.taxSubcategoryHappyHour;
String _taxSubcategoryRestaurantVisit(AppLocalizations l) =>
    l.taxSubcategoryRestaurantVisit;
String _taxSubcategoryCafeVisit(AppLocalizations l) =>
    l.taxSubcategoryCafeVisit;
String _taxSubcategoryBakeryVisit(AppLocalizations l) =>
    l.taxSubcategoryBakeryVisit;
String _taxSubcategoryVeganFood(AppLocalizations l) =>
    l.taxSubcategoryVeganFood;
String _taxSubcategoryLocalFood(AppLocalizations l) =>
    l.taxSubcategoryLocalFood;
String _taxSubcategoryFineDining(AppLocalizations l) =>
    l.taxSubcategoryFineDining;
String _taxSubcategoryFamilyMeal(AppLocalizations l) =>
    l.taxSubcategoryFamilyMeal;
String _taxSubcategoryQuiz(AppLocalizations l) => l.taxSubcategoryQuiz;
String _taxSubcategoryBoardGames(AppLocalizations l) =>
    l.taxSubcategoryBoardGames;
String _taxSubcategoryMafia(AppLocalizations l) => l.taxSubcategoryMafia;
String _taxSubcategoryPokerNoGambling(AppLocalizations l) =>
    l.taxSubcategoryPokerNoGambling;
String _taxSubcategoryChess(AppLocalizations l) => l.taxSubcategoryChess;
String _taxSubcategoryEscapeRoom(AppLocalizations l) =>
    l.taxSubcategoryEscapeRoom;
String _taxSubcategoryQuest(AppLocalizations l) => l.taxSubcategoryQuest;
String _taxSubcategoryCityGame(AppLocalizations l) => l.taxSubcategoryCityGame;
String _taxSubcategoryTreasureHunt(AppLocalizations l) =>
    l.taxSubcategoryTreasureHunt;
String _taxSubcategoryBowling(AppLocalizations l) => l.taxSubcategoryBowling;
String _taxSubcategoryBilliards(AppLocalizations l) =>
    l.taxSubcategoryBilliards;
String _taxSubcategoryDarts(AppLocalizations l) => l.taxSubcategoryDarts;
String _taxSubcategoryMiniGolf(AppLocalizations l) => l.taxSubcategoryMiniGolf;
String _taxSubcategoryArcade(AppLocalizations l) => l.taxSubcategoryArcade;
String _taxSubcategoryVrArcade(AppLocalizations l) => l.taxSubcategoryVrArcade;
String _taxSubcategoryVideoGames(AppLocalizations l) =>
    l.taxSubcategoryVideoGames;
String _taxSubcategoryTableGames(AppLocalizations l) =>
    l.taxSubcategoryTableGames;
String _taxSubcategoryCardGames(AppLocalizations l) =>
    l.taxSubcategoryCardGames;
String _taxSubcategoryRolePlayingGame(AppLocalizations l) =>
    l.taxSubcategoryRolePlayingGame;
String _taxSubcategoryIndoorCompetition(AppLocalizations l) =>
    l.taxSubcategoryIndoorCompetition;
String _taxSubcategoryFootball(AppLocalizations l) => l.taxSubcategoryFootball;
String _taxSubcategoryBasketball(AppLocalizations l) =>
    l.taxSubcategoryBasketball;
String _taxSubcategoryVolleyball(AppLocalizations l) =>
    l.taxSubcategoryVolleyball;
String _taxSubcategoryBeachVolleyball(AppLocalizations l) =>
    l.taxSubcategoryBeachVolleyball;
String _taxSubcategoryTennis(AppLocalizations l) => l.taxSubcategoryTennis;
String _taxSubcategoryTableTennis(AppLocalizations l) =>
    l.taxSubcategoryTableTennis;
String _taxSubcategoryBadminton(AppLocalizations l) =>
    l.taxSubcategoryBadminton;
String _taxSubcategorySquash(AppLocalizations l) => l.taxSubcategorySquash;
String _taxSubcategoryPadel(AppLocalizations l) => l.taxSubcategoryPadel;
String _taxSubcategoryRunning(AppLocalizations l) => l.taxSubcategoryRunning;
String _taxSubcategoryTrailRunning(AppLocalizations l) =>
    l.taxSubcategoryTrailRunning;
String _taxSubcategoryCycling(AppLocalizations l) => l.taxSubcategoryCycling;
String _taxSubcategorySwimming(AppLocalizations l) => l.taxSubcategorySwimming;
String _taxSubcategoryBoxing(AppLocalizations l) => l.taxSubcategoryBoxing;
String _taxSubcategoryMartialArts(AppLocalizations l) =>
    l.taxSubcategoryMartialArts;
String _taxSubcategoryClimbing(AppLocalizations l) => l.taxSubcategoryClimbing;
String _taxSubcategoryBouldering(AppLocalizations l) =>
    l.taxSubcategoryBouldering;
String _taxSubcategoryFitness(AppLocalizations l) => l.taxSubcategoryFitness;
String _taxSubcategoryGym(AppLocalizations l) => l.taxSubcategoryGym;
String _taxSubcategoryCrossfit(AppLocalizations l) => l.taxSubcategoryCrossfit;
String _taxSubcategoryCalisthenics(AppLocalizations l) =>
    l.taxSubcategoryCalisthenics;
String _taxSubcategoryYoga(AppLocalizations l) => l.taxSubcategoryYoga;
String _taxSubcategoryPilates(AppLocalizations l) => l.taxSubcategoryPilates;
String _taxSubcategoryStretching(AppLocalizations l) =>
    l.taxSubcategoryStretching;
String _taxSubcategoryDanceFitness(AppLocalizations l) =>
    l.taxSubcategoryDanceFitness;
String _taxSubcategoryNordicWalking(AppLocalizations l) =>
    l.taxSubcategoryNordicWalking;
String _taxSubcategorySkating(AppLocalizations l) => l.taxSubcategorySkating;
String _taxSubcategorySkateboarding(AppLocalizations l) =>
    l.taxSubcategorySkateboarding;
String _taxSubcategoryRollerblading(AppLocalizations l) =>
    l.taxSubcategoryRollerblading;
String _taxSubcategoryGolf(AppLocalizations l) => l.taxSubcategoryGolf;
String _taxSubcategoryFrisbee(AppLocalizations l) => l.taxSubcategoryFrisbee;
String _taxSubcategoryDiscGolf(AppLocalizations l) => l.taxSubcategoryDiscGolf;
String _taxSubcategoryRunningRace(AppLocalizations l) =>
    l.taxSubcategoryRunningRace;
String _taxSubcategoryCyclingRace(AppLocalizations l) =>
    l.taxSubcategoryCyclingRace;
String _taxSubcategoryFitnessChallenge(AppLocalizations l) =>
    l.taxSubcategoryFitnessChallenge;
String _taxSubcategoryAmateurTournament(AppLocalizations l) =>
    l.taxSubcategoryAmateurTournament;
String _taxSubcategorySalsa(AppLocalizations l) => l.taxSubcategorySalsa;
String _taxSubcategoryBachata(AppLocalizations l) => l.taxSubcategoryBachata;
String _taxSubcategoryKizomba(AppLocalizations l) => l.taxSubcategoryKizomba;
String _taxSubcategoryTango(AppLocalizations l) => l.taxSubcategoryTango;
String _taxSubcategoryHipHop(AppLocalizations l) => l.taxSubcategoryHipHop;
String _taxSubcategoryContemporaryDance(AppLocalizations l) =>
    l.taxSubcategoryContemporaryDance;
String _taxSubcategoryBallroomDance(AppLocalizations l) =>
    l.taxSubcategoryBallroomDance;
String _taxSubcategoryFolkDance(AppLocalizations l) =>
    l.taxSubcategoryFolkDance;
String _taxSubcategoryDanceSocial(AppLocalizations l) =>
    l.taxSubcategoryDanceSocial;
String _taxSubcategoryDanceBattle(AppLocalizations l) =>
    l.taxSubcategoryDanceBattle;
String _taxSubcategoryZumba(AppLocalizations l) => l.taxSubcategoryZumba;
String _taxSubcategoryPartnerDance(AppLocalizations l) =>
    l.taxSubcategoryPartnerDance;
String _taxSubcategoryLatinDance(AppLocalizations l) =>
    l.taxSubcategoryLatinDance;
String _taxSubcategoryHeelsDance(AppLocalizations l) =>
    l.taxSubcategoryHeelsDance;
String _taxSubcategoryStreetDance(AppLocalizations l) =>
    l.taxSubcategoryStreetDance;
String _taxSubcategoryDanceClass(AppLocalizations l) =>
    l.taxSubcategoryDanceClass;
String _taxSubcategoryDancePractice(AppLocalizations l) =>
    l.taxSubcategoryDancePractice;
String _taxSubcategoryDanceShow(AppLocalizations l) =>
    l.taxSubcategoryDanceShow;
String _taxSubcategoryHiking(AppLocalizations l) => l.taxSubcategoryHiking;
String _taxSubcategoryNatureWalk(AppLocalizations l) =>
    l.taxSubcategoryNatureWalk;
String _taxSubcategoryCityWalk(AppLocalizations l) => l.taxSubcategoryCityWalk;
String _taxSubcategoryHistoricalWalk(AppLocalizations l) =>
    l.taxSubcategoryHistoricalWalk;
String _taxSubcategorySunsetWalk(AppLocalizations l) =>
    l.taxSubcategorySunsetWalk;
String _taxSubcategorySunriseWalk(AppLocalizations l) =>
    l.taxSubcategorySunriseWalk;
String _taxSubcategoryForestWalk(AppLocalizations l) =>
    l.taxSubcategoryForestWalk;
String _taxSubcategoryLakeWalk(AppLocalizations l) => l.taxSubcategoryLakeWalk;
String _taxSubcategoryRiverWalk(AppLocalizations l) =>
    l.taxSubcategoryRiverWalk;
String _taxSubcategoryArchitectureWalk(AppLocalizations l) =>
    l.taxSubcategoryArchitectureWalk;
String _taxSubcategoryHiddenGemsWalk(AppLocalizations l) =>
    l.taxSubcategoryHiddenGemsWalk;
String _taxSubcategoryPhotographyWalk(AppLocalizations l) =>
    l.taxSubcategoryPhotographyWalk;
String _taxSubcategoryBirdwatching(AppLocalizations l) =>
    l.taxSubcategoryBirdwatching;
String _taxSubcategoryMushroomPicking(AppLocalizations l) =>
    l.taxSubcategoryMushroomPicking;
String _taxSubcategoryBerryPicking(AppLocalizations l) =>
    l.taxSubcategoryBerryPicking;
String _taxSubcategoryPicnicWalk(AppLocalizations l) =>
    l.taxSubcategoryPicnicWalk;
String _taxSubcategoryParkWalk(AppLocalizations l) => l.taxSubcategoryParkWalk;
String _taxSubcategoryBeachWalk(AppLocalizations l) =>
    l.taxSubcategoryBeachWalk;
String _taxSubcategoryPromenadeWalk(AppLocalizations l) =>
    l.taxSubcategoryPromenadeWalk;
String _taxSubcategoryPark(AppLocalizations l) => l.taxSubcategoryPark;
String _taxSubcategoryBeach(AppLocalizations l) => l.taxSubcategoryBeach;
String _taxSubcategoryPromenade(AppLocalizations l) =>
    l.taxSubcategoryPromenade;
String _taxSubcategoryViewpoint(AppLocalizations l) =>
    l.taxSubcategoryViewpoint;
String _taxSubcategoryForest(AppLocalizations l) => l.taxSubcategoryForest;
String _taxSubcategoryLake(AppLocalizations l) => l.taxSubcategoryLake;
String _taxSubcategoryWaterfall(AppLocalizations l) =>
    l.taxSubcategoryWaterfall;
String _taxSubcategoryCave(AppLocalizations l) => l.taxSubcategoryCave;
String _taxSubcategoryNaturalLandmark(AppLocalizations l) =>
    l.taxSubcategoryNaturalLandmark;
String _taxSubcategoryOutdoorWorkout(AppLocalizations l) =>
    l.taxSubcategoryOutdoorWorkout;
String _taxSubcategoryNatureEscape(AppLocalizations l) =>
    l.taxSubcategoryNatureEscape;
String _taxSubcategorySlowWalk(AppLocalizations l) => l.taxSubcategorySlowWalk;
String _taxSubcategoryStargazing(AppLocalizations l) =>
    l.taxSubcategoryStargazing;
String _taxSubcategoryNorthernLightsWatch(AppLocalizations l) =>
    l.taxSubcategoryNorthernLightsWatch;
String _taxSubcategoryMeteorShowerWatch(AppLocalizations l) =>
    l.taxSubcategoryMeteorShowerWatch;
String _taxSubcategorySup(AppLocalizations l) => l.taxSubcategorySup;
String _taxSubcategoryKayak(AppLocalizations l) => l.taxSubcategoryKayak;
String _taxSubcategoryCanoe(AppLocalizations l) => l.taxSubcategoryCanoe;
String _taxSubcategoryBoatTrip(AppLocalizations l) => l.taxSubcategoryBoatTrip;
String _taxSubcategoryCatamaran(AppLocalizations l) =>
    l.taxSubcategoryCatamaran;
String _taxSubcategoryCanalCruise(AppLocalizations l) =>
    l.taxSubcategoryCanalCruise;
String _taxSubcategoryRowing(AppLocalizations l) => l.taxSubcategoryRowing;
String _taxSubcategorySailing(AppLocalizations l) => l.taxSubcategorySailing;
String _taxSubcategoryFishing(AppLocalizations l) => l.taxSubcategoryFishing;
String _taxSubcategoryWakeboarding(AppLocalizations l) =>
    l.taxSubcategoryWakeboarding;
String _taxSubcategoryWaterBike(AppLocalizations l) =>
    l.taxSubcategoryWaterBike;
String _taxSubcategoryJetSki(AppLocalizations l) => l.taxSubcategoryJetSki;
String _taxSubcategoryBeachActivity(AppLocalizations l) =>
    l.taxSubcategoryBeachActivity;
String _taxSubcategoryWaterTour(AppLocalizations l) =>
    l.taxSubcategoryWaterTour;
String _taxSubcategoryDiving(AppLocalizations l) => l.taxSubcategoryDiving;
String _taxSubcategorySnorkeling(AppLocalizations l) =>
    l.taxSubcategorySnorkeling;
String _taxSubcategorySurfing(AppLocalizations l) => l.taxSubcategorySurfing;
String _taxSubcategoryWindsurfing(AppLocalizations l) =>
    l.taxSubcategoryWindsurfing;
String _taxSubcategoryKitesurfing(AppLocalizations l) =>
    l.taxSubcategoryKitesurfing;
String _taxSubcategoryBeachDay(AppLocalizations l) => l.taxSubcategoryBeachDay;
String _taxSubcategoryWinterWalk(AppLocalizations l) =>
    l.taxSubcategoryWinterWalk;
String _taxSubcategoryIceSkating(AppLocalizations l) =>
    l.taxSubcategoryIceSkating;
String _taxSubcategorySkiing(AppLocalizations l) => l.taxSubcategorySkiing;
String _taxSubcategorySnowboarding(AppLocalizations l) =>
    l.taxSubcategorySnowboarding;
String _taxSubcategorySledding(AppLocalizations l) => l.taxSubcategorySledding;
String _taxSubcategoryWinterHiking(AppLocalizations l) =>
    l.taxSubcategoryWinterHiking;
String _taxSubcategoryChristmasMarketWalk(AppLocalizations l) =>
    l.taxSubcategoryChristmasMarketWalk;
String _taxSubcategoryWinterPhotoRoute(AppLocalizations l) =>
    l.taxSubcategoryWinterPhotoRoute;
String _taxSubcategorySaunaColdPlunge(AppLocalizations l) =>
    l.taxSubcategorySaunaColdPlunge;
String _taxSubcategoryIceFishing(AppLocalizations l) =>
    l.taxSubcategoryIceFishing;
String _taxSubcategoryWinterFestival(AppLocalizations l) =>
    l.taxSubcategoryWinterFestival;
String _taxSubcategoryAutumnLeafWalk(AppLocalizations l) =>
    l.taxSubcategoryAutumnLeafWalk;
String _taxSubcategorySpringBlossomWalk(AppLocalizations l) =>
    l.taxSubcategorySpringBlossomWalk;
String _taxSubcategorySummerOutdoor(AppLocalizations l) =>
    l.taxSubcategorySummerOutdoor;
String _taxSubcategorySeasonalWalk(AppLocalizations l) =>
    l.taxSubcategorySeasonalWalk;
String _taxSubcategorySnowActivity(AppLocalizations l) =>
    l.taxSubcategorySnowActivity;
String _taxSubcategoryColdPlunge(AppLocalizations l) =>
    l.taxSubcategoryColdPlunge;
String _taxSubcategoryHolidayLightsWalk(AppLocalizations l) =>
    l.taxSubcategoryHolidayLightsWalk;
String _taxSubcategoryDayTrip(AppLocalizations l) => l.taxSubcategoryDayTrip;
String _taxSubcategoryWeekendTrip(AppLocalizations l) =>
    l.taxSubcategoryWeekendTrip;
String _taxSubcategoryLocalExperience(AppLocalizations l) =>
    l.taxSubcategoryLocalExperience;
String _taxSubcategoryTouristExcursion(AppLocalizations l) =>
    l.taxSubcategoryTouristExcursion;
String _taxSubcategoryCityTour(AppLocalizations l) => l.taxSubcategoryCityTour;
String _taxSubcategoryFoodTastingTour(AppLocalizations l) =>
    l.taxSubcategoryFoodTastingTour;
String _taxSubcategoryCraftExperience(AppLocalizations l) =>
    l.taxSubcategoryCraftExperience;
String _taxSubcategoryFarmExperience(AppLocalizations l) =>
    l.taxSubcategoryFarmExperience;
String _taxSubcategoryCastleTour(AppLocalizations l) =>
    l.taxSubcategoryCastleTour;
String _taxSubcategoryNatureReserveTour(AppLocalizations l) =>
    l.taxSubcategoryNatureReserveTour;
String _taxSubcategoryCoastalTrip(AppLocalizations l) =>
    l.taxSubcategoryCoastalTrip;
String _taxSubcategoryTrainDayTrip(AppLocalizations l) =>
    l.taxSubcategoryTrainDayTrip;
String _taxSubcategoryLocalGuideExperience(AppLocalizations l) =>
    l.taxSubcategoryLocalGuideExperience;
String _taxSubcategoryBikeTour(AppLocalizations l) => l.taxSubcategoryBikeTour;
String _taxSubcategoryWalkingTour(AppLocalizations l) =>
    l.taxSubcategoryWalkingTour;
String _taxSubcategoryHistoricalTour(AppLocalizations l) =>
    l.taxSubcategoryHistoricalTour;
String _taxSubcategoryArchitectureTour(AppLocalizations l) =>
    l.taxSubcategoryArchitectureTour;
String _taxSubcategoryPhotoTour(AppLocalizations l) =>
    l.taxSubcategoryPhotoTour;
String _taxSubcategoryHiddenGemsTour(AppLocalizations l) =>
    l.taxSubcategoryHiddenGemsTour;
String _taxSubcategoryFamilyActivity(AppLocalizations l) =>
    l.taxSubcategoryFamilyActivity;
String _taxSubcategoryKidsWorkshop(AppLocalizations l) =>
    l.taxSubcategoryKidsWorkshop;
String _taxSubcategoryPlaygroundEvent(AppLocalizations l) =>
    l.taxSubcategoryPlaygroundEvent;
String _taxSubcategoryFamilyPicnic(AppLocalizations l) =>
    l.taxSubcategoryFamilyPicnic;
String _taxSubcategoryKidsTheatre(AppLocalizations l) =>
    l.taxSubcategoryKidsTheatre;
String _taxSubcategoryKidsMuseumEvent(AppLocalizations l) =>
    l.taxSubcategoryKidsMuseumEvent;
String _taxSubcategoryFamilySportsDay(AppLocalizations l) =>
    l.taxSubcategoryFamilySportsDay;
String _taxSubcategoryParentChildClass(AppLocalizations l) =>
    l.taxSubcategoryParentChildClass;
String _taxSubcategoryCreativeKidsClass(AppLocalizations l) =>
    l.taxSubcategoryCreativeKidsClass;
String _taxSubcategoryKidsCookingClass(AppLocalizations l) =>
    l.taxSubcategoryKidsCookingClass;
String _taxSubcategoryKidsOutdoorWalk(AppLocalizations l) =>
    l.taxSubcategoryKidsOutdoorWalk;
String _taxSubcategoryBirthdayActivity(AppLocalizations l) =>
    l.taxSubcategoryBirthdayActivity;
String _taxSubcategoryFamilyFarmVisit(AppLocalizations l) =>
    l.taxSubcategoryFamilyFarmVisit;
String _taxSubcategoryFamilyRoute(AppLocalizations l) =>
    l.taxSubcategoryFamilyRoute;
String _taxSubcategoryKidsParty(AppLocalizations l) =>
    l.taxSubcategoryKidsParty;
String _taxSubcategoryEducationalKidsEvent(AppLocalizations l) =>
    l.taxSubcategoryEducationalKidsEvent;
String _taxSubcategoryBabyFriendlyActivity(AppLocalizations l) =>
    l.taxSubcategoryBabyFriendlyActivity;
String _taxSubcategoryKidsCamp(AppLocalizations l) => l.taxSubcategoryKidsCamp;
String _taxSubcategoryDayCamp(AppLocalizations l) => l.taxSubcategoryDayCamp;
String _taxSubcategoryTeenMeetup(AppLocalizations l) =>
    l.taxSubcategoryTeenMeetup;
String _taxSubcategoryTeenEvent(AppLocalizations l) =>
    l.taxSubcategoryTeenEvent;
String _taxSubcategoryKidsQuest(AppLocalizations l) =>
    l.taxSubcategoryKidsQuest;
String _taxSubcategoryKidsScienceEvent(AppLocalizations l) =>
    l.taxSubcategoryKidsScienceEvent;
String _taxSubcategoryKidsDisco(AppLocalizations l) =>
    l.taxSubcategoryKidsDisco;
String _taxSubcategoryDogWalk(AppLocalizations l) => l.taxSubcategoryDogWalk;
String _taxSubcategoryDogMeetup(AppLocalizations l) =>
    l.taxSubcategoryDogMeetup;
String _taxSubcategoryDogParkMeetup(AppLocalizations l) =>
    l.taxSubcategoryDogParkMeetup;
String _taxSubcategoryPetFriendlyCafe(AppLocalizations l) =>
    l.taxSubcategoryPetFriendlyCafe;
String _taxSubcategoryDogTraining(AppLocalizations l) =>
    l.taxSubcategoryDogTraining;
String _taxSubcategoryPetPhotoSession(AppLocalizations l) =>
    l.taxSubcategoryPetPhotoSession;
String _taxSubcategoryAnimalShelterVisit(AppLocalizations l) =>
    l.taxSubcategoryAnimalShelterVisit;
String _taxSubcategoryFarmAnimalExperience(AppLocalizations l) =>
    l.taxSubcategoryFarmAnimalExperience;
String _taxSubcategoryHorseRiding(AppLocalizations l) =>
    l.taxSubcategoryHorseRiding;
String _taxSubcategoryPonyRiding(AppLocalizations l) =>
    l.taxSubcategoryPonyRiding;
String _taxSubcategoryCatCafe(AppLocalizations l) => l.taxSubcategoryCatCafe;
String _taxSubcategoryPetAdoption(AppLocalizations l) =>
    l.taxSubcategoryPetAdoption;
String _taxSubcategoryPetCharity(AppLocalizations l) =>
    l.taxSubcategoryPetCharity;
String _taxSubcategoryPetFriendlyWalk(AppLocalizations l) =>
    l.taxSubcategoryPetFriendlyWalk;
String _taxSubcategoryDogSport(AppLocalizations l) => l.taxSubcategoryDogSport;
String _taxSubcategoryPetOwnerMeetup(AppLocalizations l) =>
    l.taxSubcategoryPetOwnerMeetup;
String _taxSubcategoryDogShow(AppLocalizations l) => l.taxSubcategoryDogShow;
String _taxSubcategoryPetExhibition(AppLocalizations l) =>
    l.taxSubcategoryPetExhibition;
String _taxSubcategoryPetFair(AppLocalizations l) => l.taxSubcategoryPetFair;
String _taxSubcategoryPetCareTalk(AppLocalizations l) =>
    l.taxSubcategoryPetCareTalk;
String _taxSubcategoryAnimalTherapy(AppLocalizations l) =>
    l.taxSubcategoryAnimalTherapy;
String _taxSubcategoryCharityEvent(AppLocalizations l) =>
    l.taxSubcategoryCharityEvent;
String _taxSubcategoryVolunteerActivity(AppLocalizations l) =>
    l.taxSubcategoryVolunteerActivity;
String _taxSubcategoryCommunityCleanup(AppLocalizations l) =>
    l.taxSubcategoryCommunityCleanup;
String _taxSubcategoryDonationEvent(AppLocalizations l) =>
    l.taxSubcategoryDonationEvent;
String _taxSubcategoryNeighborhoodEvent(AppLocalizations l) =>
    l.taxSubcategoryNeighborhoodEvent;
String _taxSubcategoryFundraisingDinner(AppLocalizations l) =>
    l.taxSubcategoryFundraisingDinner;
String _taxSubcategoryCharityRun(AppLocalizations l) =>
    l.taxSubcategoryCharityRun;
String _taxSubcategoryAnimalShelterVolunteering(AppLocalizations l) =>
    l.taxSubcategoryAnimalShelterVolunteering;
String _taxSubcategoryFoodBankVolunteering(AppLocalizations l) =>
    l.taxSubcategoryFoodBankVolunteering;
String _taxSubcategoryTreePlanting(AppLocalizations l) =>
    l.taxSubcategoryTreePlanting;
String _taxSubcategoryBeachCleanup(AppLocalizations l) =>
    l.taxSubcategoryBeachCleanup;
String _taxSubcategoryParkCleanup(AppLocalizations l) =>
    l.taxSubcategoryParkCleanup;
String _taxSubcategoryCommunityGarden(AppLocalizations l) =>
    l.taxSubcategoryCommunityGarden;
String _taxSubcategoryPublicSquare(AppLocalizations l) =>
    l.taxSubcategoryPublicSquare;
String _taxSubcategoryLocalCommunityMeetup(AppLocalizations l) =>
    l.taxSubcategoryLocalCommunityMeetup;
String _taxSubcategoryMutualAid(AppLocalizations l) =>
    l.taxSubcategoryMutualAid;
String _taxSubcategorySocialImpactEvent(AppLocalizations l) =>
    l.taxSubcategorySocialImpactEvent;
String _taxSubcategoryEnvironmentalAction(AppLocalizations l) =>
    l.taxSubcategoryEnvironmentalAction;
String _taxSubcategoryLocalMarket(AppLocalizations l) =>
    l.taxSubcategoryLocalMarket;
String _taxSubcategoryFleaMarket(AppLocalizations l) =>
    l.taxSubcategoryFleaMarket;
String _taxSubcategorySeasonalMarket(AppLocalizations l) =>
    l.taxSubcategorySeasonalMarket;
String _taxSubcategoryChristmasMarket(AppLocalizations l) =>
    l.taxSubcategoryChristmasMarket;
String _taxSubcategoryFarmersMarket(AppLocalizations l) =>
    l.taxSubcategoryFarmersMarket;
String _taxSubcategoryCraftMarket(AppLocalizations l) =>
    l.taxSubcategoryCraftMarket;
String _taxSubcategoryDesignMarket(AppLocalizations l) =>
    l.taxSubcategoryDesignMarket;
String _taxSubcategoryVintageMarket(AppLocalizations l) =>
    l.taxSubcategoryVintageMarket;
String _taxSubcategoryBookMarket(AppLocalizations l) =>
    l.taxSubcategoryBookMarket;
String _taxSubcategoryFoodMarket(AppLocalizations l) =>
    l.taxSubcategoryFoodMarket;
String _taxSubcategoryFlowerMarket(AppLocalizations l) =>
    l.taxSubcategoryFlowerMarket;
String _taxSubcategoryArtFair(AppLocalizations l) => l.taxSubcategoryArtFair;
String _taxSubcategoryPopUpShop(AppLocalizations l) =>
    l.taxSubcategoryPopUpShop;
String _taxSubcategoryStreetMarket(AppLocalizations l) =>
    l.taxSubcategoryStreetMarket;
String _taxSubcategoryHandmadeFair(AppLocalizations l) =>
    l.taxSubcategoryHandmadeFair;
String _taxSubcategoryCharityMarket(AppLocalizations l) =>
    l.taxSubcategoryCharityMarket;
String _taxSubcategoryKidsMarket(AppLocalizations l) =>
    l.taxSubcategoryKidsMarket;
String _taxSubcategoryNightMarket(AppLocalizations l) =>
    l.taxSubcategoryNightMarket;
String _taxSubcategoryLocalBrandsMarket(AppLocalizations l) =>
    l.taxSubcategoryLocalBrandsMarket;
String _taxSubcategoryClothingSwap(AppLocalizations l) =>
    l.taxSubcategoryClothingSwap;
String _taxSubcategoryChristmas(AppLocalizations l) =>
    l.taxSubcategoryChristmas;
String _taxSubcategoryNewYear(AppLocalizations l) => l.taxSubcategoryNewYear;
String _taxSubcategoryHalloween(AppLocalizations l) =>
    l.taxSubcategoryHalloween;
String _taxSubcategoryEaster(AppLocalizations l) => l.taxSubcategoryEaster;
String _taxSubcategoryValentinesDay(AppLocalizations l) =>
    l.taxSubcategoryValentinesDay;
String _taxSubcategoryJani(AppLocalizations l) => l.taxSubcategoryJani;
String _taxSubcategoryCityFestival(AppLocalizations l) =>
    l.taxSubcategoryCityFestival;
String _taxSubcategorySummerFestival(AppLocalizations l) =>
    l.taxSubcategorySummerFestival;
String _taxSubcategoryAutumnEvent(AppLocalizations l) =>
    l.taxSubcategoryAutumnEvent;
String _taxSubcategorySpringEvent(AppLocalizations l) =>
    l.taxSubcategorySpringEvent;
String _taxSubcategorySchoolHoliday(AppLocalizations l) =>
    l.taxSubcategorySchoolHoliday;
String _taxSubcategoryNationalHoliday(AppLocalizations l) =>
    l.taxSubcategoryNationalHoliday;
String _taxSubcategoryLocalTradition(AppLocalizations l) =>
    l.taxSubcategoryLocalTradition;
String _taxSubcategoryMidsummer(AppLocalizations l) =>
    l.taxSubcategoryMidsummer;
String _taxSubcategoryFireworks(AppLocalizations l) =>
    l.taxSubcategoryFireworks;
String _taxSubcategoryPublicCelebration(AppLocalizations l) =>
    l.taxSubcategoryPublicCelebration;
String _taxSubcategoryRechargeWalk(AppLocalizations l) =>
    l.taxSubcategoryRechargeWalk;
String _taxSubcategoryCalmWalk(AppLocalizations l) => l.taxSubcategoryCalmWalk;
String _taxSubcategoryMindfulWalk(AppLocalizations l) =>
    l.taxSubcategoryMindfulWalk;
String _taxSubcategoryCoffeeWalk(AppLocalizations l) =>
    l.taxSubcategoryCoffeeWalk;
String _taxSubcategoryTeaWalk(AppLocalizations l) => l.taxSubcategoryTeaWalk;
String _taxSubcategorySunsetReset(AppLocalizations l) =>
    l.taxSubcategorySunsetReset;
String _taxSubcategoryNatureReset(AppLocalizations l) =>
    l.taxSubcategoryNatureReset;
String _taxSubcategoryDigitalDetox(AppLocalizations l) =>
    l.taxSubcategoryDigitalDetox;
String _taxSubcategorySlowMorning(AppLocalizations l) =>
    l.taxSubcategorySlowMorning;
String _taxSubcategoryEveningReset(AppLocalizations l) =>
    l.taxSubcategoryEveningReset;
String _taxSubcategorySauna(AppLocalizations l) => l.taxSubcategorySauna;
String _taxSubcategorySpa(AppLocalizations l) => l.taxSubcategorySpa;
String _taxSubcategoryMassage(AppLocalizations l) => l.taxSubcategoryMassage;
String _taxSubcategoryBreathwork(AppLocalizations l) =>
    l.taxSubcategoryBreathwork;
String _taxSubcategoryMeditation(AppLocalizations l) =>
    l.taxSubcategoryMeditation;
String _taxSubcategorySoundHealing(AppLocalizations l) =>
    l.taxSubcategorySoundHealing;
String _taxSubcategoryWellnessClass(AppLocalizations l) =>
    l.taxSubcategoryWellnessClass;
String _taxSubcategoryRelaxationSession(AppLocalizations l) =>
    l.taxSubcategoryRelaxationSession;
String _taxSubcategoryMentalHealthMeetup(AppLocalizations l) =>
    l.taxSubcategoryMentalHealthMeetup;
String _taxSubcategoryQuietSocial(AppLocalizations l) =>
    l.taxSubcategoryQuietSocial;
String _taxSubcategoryCoupleRecharge(AppLocalizations l) =>
    l.taxSubcategoryCoupleRecharge;
String _taxSubcategorySoloRecharge(AppLocalizations l) =>
    l.taxSubcategorySoloRecharge;
String _taxSubcategoryFriendsRecharge(AppLocalizations l) =>
    l.taxSubcategoryFriendsRecharge;
String _taxSubcategoryPirtsRitual(AppLocalizations l) =>
    l.taxSubcategoryPirtsRitual;
String _taxSubcategoryRetreat(AppLocalizations l) => l.taxSubcategoryRetreat;
String _taxSubcategoryLaserTag(AppLocalizations l) => l.taxSubcategoryLaserTag;
String _taxSubcategoryPaintball(AppLocalizations l) =>
    l.taxSubcategoryPaintball;
String _taxSubcategoryAirsoft(AppLocalizations l) => l.taxSubcategoryAirsoft;
String _taxSubcategoryKarting(AppLocalizations l) => l.taxSubcategoryKarting;
String _taxSubcategoryShootingRange(AppLocalizations l) =>
    l.taxSubcategoryShootingRange;
String _taxSubcategoryArchery(AppLocalizations l) => l.taxSubcategoryArchery;
String _taxSubcategoryAxeThrowing(AppLocalizations l) =>
    l.taxSubcategoryAxeThrowing;
String _taxSubcategoryTrampolinePark(AppLocalizations l) =>
    l.taxSubcategoryTrampolinePark;
String _taxSubcategoryRopePark(AppLocalizations l) => l.taxSubcategoryRopePark;
String _taxSubcategoryZipline(AppLocalizations l) => l.taxSubcategoryZipline;
String _taxSubcategoryWindTunnel(AppLocalizations l) =>
    l.taxSubcategoryWindTunnel;
String _taxSubcategoryHotAirBalloon(AppLocalizations l) =>
    l.taxSubcategoryHotAirBalloon;
String _taxSubcategorySkydiving(AppLocalizations l) =>
    l.taxSubcategorySkydiving;
String _taxSubcategoryBungeeJumping(AppLocalizations l) =>
    l.taxSubcategoryBungeeJumping;
String _taxSubcategoryParkour(AppLocalizations l) => l.taxSubcategoryParkour;
String _taxSubcategoryObstacleCourse(AppLocalizations l) =>
    l.taxSubcategoryObstacleCourse;
String _taxSubcategoryZoo(AppLocalizations l) => l.taxSubcategoryZoo;
String _taxSubcategoryPettingZoo(AppLocalizations l) =>
    l.taxSubcategoryPettingZoo;
String _taxSubcategoryAquarium(AppLocalizations l) => l.taxSubcategoryAquarium;
String _taxSubcategoryAmusementPark(AppLocalizations l) =>
    l.taxSubcategoryAmusementPark;
String _taxSubcategoryWaterPark(AppLocalizations l) =>
    l.taxSubcategoryWaterPark;
String _taxSubcategoryAdventurePark(AppLocalizations l) =>
    l.taxSubcategoryAdventurePark;
String _taxSubcategoryBotanicalGarden(AppLocalizations l) =>
    l.taxSubcategoryBotanicalGarden;
String _taxSubcategoryPlanetarium(AppLocalizations l) =>
    l.taxSubcategoryPlanetarium;
String _taxSubcategoryScienceCenter(AppLocalizations l) =>
    l.taxSubcategoryScienceCenter;
String _taxSubcategoryObservationDeck(AppLocalizations l) =>
    l.taxSubcategoryObservationDeck;
String _taxSubcategoryFerrisWheel(AppLocalizations l) =>
    l.taxSubcategoryFerrisWheel;
String _taxSubcategorySeasonalAttraction(AppLocalizations l) =>
    l.taxSubcategorySeasonalAttraction;
String _taxSubcategoryCarMeetup(AppLocalizations l) =>
    l.taxSubcategoryCarMeetup;
String _taxSubcategoryRetroCars(AppLocalizations l) =>
    l.taxSubcategoryRetroCars;
String _taxSubcategoryCarShow(AppLocalizations l) => l.taxSubcategoryCarShow;
String _taxSubcategoryAutoExhibition(AppLocalizations l) =>
    l.taxSubcategoryAutoExhibition;
String _taxSubcategoryTuningMeetup(AppLocalizations l) =>
    l.taxSubcategoryTuningMeetup;
String _taxSubcategoryDriftEvent(AppLocalizations l) =>
    l.taxSubcategoryDriftEvent;
String _taxSubcategoryOffroadTrip(AppLocalizations l) =>
    l.taxSubcategoryOffroadTrip;
String _taxSubcategoryMotorcycleRide(AppLocalizations l) =>
    l.taxSubcategoryMotorcycleRide;
String _taxSubcategoryMotorcycleMeetup(AppLocalizations l) =>
    l.taxSubcategoryMotorcycleMeetup;
String _taxSubcategoryScooterMeetup(AppLocalizations l) =>
    l.taxSubcategoryScooterMeetup;
String _taxSubcategoryCarPhotoMeet(AppLocalizations l) =>
    l.taxSubcategoryCarPhotoMeet;
String _taxSubcategoryDriveInCinema(AppLocalizations l) =>
    l.taxSubcategoryDriveInCinema;
String _taxSubcategoryAnimeMeetup(AppLocalizations l) =>
    l.taxSubcategoryAnimeMeetup;
String _taxSubcategoryCosplayEvent(AppLocalizations l) =>
    l.taxSubcategoryCosplayEvent;
String _taxSubcategoryComicCon(AppLocalizations l) => l.taxSubcategoryComicCon;
String _taxSubcategoryEsportsTournament(AppLocalizations l) =>
    l.taxSubcategoryEsportsTournament;
String _taxSubcategoryLanParty(AppLocalizations l) => l.taxSubcategoryLanParty;
String _taxSubcategoryRetroGaming(AppLocalizations l) =>
    l.taxSubcategoryRetroGaming;
String _taxSubcategoryTabletopWargames(AppLocalizations l) =>
    l.taxSubcategoryTabletopWargames;
String _taxSubcategoryTradingCardGames(AppLocalizations l) =>
    l.taxSubcategoryTradingCardGames;
String _taxSubcategoryHackathon(AppLocalizations l) =>
    l.taxSubcategoryHackathon;
String _taxSubcategoryGameDevMeetup(AppLocalizations l) =>
    l.taxSubcategoryGameDevMeetup;
String _taxSubcategoryTechMeetup(AppLocalizations l) =>
    l.taxSubcategoryTechMeetup;
String _taxSubcategoryRoboticsEvent(AppLocalizations l) =>
    l.taxSubcategoryRoboticsEvent;
String _taxSubcategoryFandomMeetup(AppLocalizations l) =>
    l.taxSubcategoryFandomMeetup;
String _taxSubcategoryCollectorsMeetup(AppLocalizations l) =>
    l.taxSubcategoryCollectorsMeetup;
String _taxSubcategorySpeedDating(AppLocalizations l) =>
    l.taxSubcategorySpeedDating;
String _taxSubcategorySinglesParty(AppLocalizations l) =>
    l.taxSubcategorySinglesParty;
String _taxSubcategorySinglesMixer(AppLocalizations l) =>
    l.taxSubcategorySinglesMixer;
String _taxSubcategorySinglesDinner(AppLocalizations l) =>
    l.taxSubcategorySinglesDinner;
String _taxSubcategoryBlindDateEvent(AppLocalizations l) =>
    l.taxSubcategoryBlindDateEvent;
String _taxSubcategoryDatingGameEvent(AppLocalizations l) =>
    l.taxSubcategoryDatingGameEvent;
String _taxSubcategorySinglesActivity(AppLocalizations l) =>
    l.taxSubcategorySinglesActivity;
String _taxSubcategoryMatchmakingEvent(AppLocalizations l) =>
    l.taxSubcategoryMatchmakingEvent;
String _taxSubcategoryOtherEvent(AppLocalizations l) =>
    l.taxSubcategoryOtherEvent;
