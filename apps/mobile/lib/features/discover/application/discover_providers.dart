import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/service_locator.dart';
import '../../../core/telemetry/analytics_service.dart';
import '../domain/entities/discover_item_entity.dart';
import '../domain/entities/discover_query.dart';
import '../domain/repositories/discover_preferences_repository.dart';
import '../domain/usecases/get_discover_details_usecase.dart';
import '../domain/usecases/get_discover_feed_usecase.dart';
import 'controllers/discover_feed_controller.dart';
import 'discover_runtime_defaults.dart';
import '../domain/usecases/build_time_window_usecase.dart';
import '../domain/usecases/submit_route_safety_report_usecase.dart';

final discoverFeedControllerProvider =
    ChangeNotifierProvider<DiscoverFeedController>((ref) {
      return DiscoverFeedController(
        getDiscoverFeedUseCase: sl<GetDiscoverFeedUseCase>(),
        discoverPreferencesRepository: sl<DiscoverPreferencesRepository>(),
        analyticsService: sl<AnalyticsService>(),
        initialQuery: sl<DiscoverQuery>(),
        buildTimeWindow: sl<BuildTimeWindowUseCase>(),
        runtimeDefaults: sl<DiscoverRuntimeDefaults>(),
      );
    });

final discoverDetailsProvider =
    FutureProvider.family<DiscoverItemEntity, String>((ref, itemId) async {
      final GetDiscoverDetailsUseCase useCase = sl<GetDiscoverDetailsUseCase>();
      return useCase(itemId);
    });

final submitRouteSafetyReportProvider =
    Provider<SubmitRouteSafetyReportUseCase>((ref) {
      return sl<SubmitRouteSafetyReportUseCase>();
    });
