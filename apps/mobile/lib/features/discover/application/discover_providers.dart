import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/service_locator.dart';
import '../../../core/telemetry/analytics_service.dart';
import '../domain/entities/discover_item_entity.dart';
import '../domain/repositories/discover_preferences_repository.dart';
import '../domain/usecases/get_discover_details_usecase.dart';
import '../domain/usecases/get_discover_feed_usecase.dart';
import 'controllers/discover_feed_controller.dart';

final discoverFeedControllerProvider =
    ChangeNotifierProvider<DiscoverFeedController>((ref) {
  return DiscoverFeedController(
    getDiscoverFeedUseCase: sl<GetDiscoverFeedUseCase>(),
    discoverPreferencesRepository: sl<DiscoverPreferencesRepository>(),
    analyticsService: sl<AnalyticsService>(),
  );
});

final discoverDetailsProvider =
    FutureProvider.family<DiscoverItemEntity, String>((ref, itemId) async {
  final GetDiscoverDetailsUseCase useCase = sl<GetDiscoverDetailsUseCase>();
  return useCase(itemId);
});
