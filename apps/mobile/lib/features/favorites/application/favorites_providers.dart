import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/service_locator.dart';
import '../../../core/telemetry/analytics_service.dart';
import '../domain/usecases/add_favorite_usecase.dart';
import '../domain/usecases/get_favorites_usecase.dart';
import '../domain/usecases/remove_favorite_usecase.dart';
import 'controllers/favorites_controller.dart';

final favoritesControllerProvider =
    ChangeNotifierProvider<FavoritesController>((ref) {
  return FavoritesController(
    getFavoritesUseCase: sl<GetFavoritesUseCase>(),
    addFavoriteUseCase: sl<AddFavoriteUseCase>(),
    removeFavoriteUseCase: sl<RemoveFavoriteUseCase>(),
    analyticsService: sl<AnalyticsService>(),
  );
});
