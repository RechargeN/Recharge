import 'package:flutter/material.dart';

IconData discoverCategoryIcon(String categoryId) {
  return switch (categoryId) {
    'music_nightlife' => Icons.music_note_outlined,
    'comedy_theatre_performance' => Icons.theater_comedy_outlined,
    'cinema_screenings' => Icons.movie_outlined,
    'art_culture_museums' => Icons.palette_outlined,
    'education_talks' => Icons.school_outlined,
    'business_networking' => Icons.handshake_outlined,
    'workshops_masterclasses' => Icons.design_services_outlined,
    'language_social_learning' => Icons.translate_outlined,
    'food_drinks' => Icons.local_cafe_outlined,
    'games_indoor' => Icons.sports_esports_outlined,
    'sport' => Icons.sports_tennis_outlined,
    'dance' => Icons.directions_run_outlined,
    'outdoor_nature_walking' => Icons.park_outlined,
    'water_activities' => Icons.water_outlined,
    'winter_seasonal' => Icons.ac_unit_outlined,
    'travel_tours' => Icons.explore_outlined,
    'family_kids' => Icons.family_restroom_outlined,
    'pets_animals' => Icons.pets_outlined,
    'community_charity' => Icons.volunteer_activism_outlined,
    'markets_fairs' => Icons.storefront_outlined,
    'holidays_seasonal' => Icons.celebration_outlined,
    'wellness_recharge' => Icons.self_improvement_outlined,
    'adrenaline_entertainment' => Icons.bolt_outlined,
    'attractions' => Icons.attractions_outlined,
    'auto_moto' => Icons.directions_car_outlined,
    'geek_tech' => Icons.memory_outlined,
    'dating_singles' => Icons.favorite_border_outlined,
    _ => Icons.category_outlined,
  };
}
