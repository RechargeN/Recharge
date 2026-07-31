import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/service_locator.dart';
import '../../../core/telemetry/analytics_service.dart';
import '../domain/usecases/get_visited_places_usecase.dart';
import '../domain/usecases/record_place_visit_usecase.dart';
import '../domain/usecases/remove_visit_usecase.dart';
import 'controllers/visited_places_controller.dart';

final visitedPlacesControllerProvider =
    ChangeNotifierProvider<VisitedPlacesController>((ref) {
      return VisitedPlacesController(
        getVisitedPlacesUseCase: sl<GetVisitedPlacesUseCase>(),
        recordPlaceVisitUseCase: sl<RecordPlaceVisitUseCase>(),
        removeVisitUseCase: sl<RemoveVisitUseCase>(),
        analyticsService: sl<AnalyticsService>(),
      );
    });
