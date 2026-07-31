import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/service_locator.dart';
import '../../../core/telemetry/analytics_service.dart';
import 'create_runtime_defaults.dart';
import 'event_create_coordinator.dart';
import 'scenario_create_coordinator.dart';
import 'scenario_generation_coordinator.dart';
import 'place_enrichment_coordinator.dart';
import 'route_create_runtime.dart';
import 'route_publication_coordinator.dart';
import '../domain/repositories/catalog_object_picker_port.dart';
import '../domain/repositories/create_template_repository.dart';
import '../domain/usecases/load_create_draft_usecase.dart';
import '../domain/usecases/manage_create_template_usecase.dart';
import '../domain/usecases/publish_create_draft_usecase.dart';
import '../domain/usecases/save_create_draft_usecase.dart';
import '../domain/usecases/check_place_duplicates_usecase.dart';
import 'controllers/create_controller.dart';
import 'controllers/route_gpx_transfer_controller.dart';
import 'controllers/route_recording_controller.dart';
import 'controllers/route_quality_admin_controller.dart';
import '../domain/repositories/route_gpx_file_picker_port.dart';
import '../domain/repositories/route_gpx_repository.dart';
import '../domain/usecases/export_route_gpx_usecase.dart';
import '../domain/usecases/inspect_route_gpx_usecase.dart';
import 'route_quality_workflow_coordinator.dart';

final createControllerProvider = ChangeNotifierProvider<CreateController>((
  ref,
) {
  return CreateController(
    loadCreateDraftUseCase: sl<LoadCreateDraftUseCase>(),
    saveCreateDraftUseCase: sl<SaveCreateDraftUseCase>(),
    publishCreateDraftUseCase: sl<PublishCreateDraftUseCase>(),
    analyticsService: sl<AnalyticsService>(),
    runtimeDefaults: sl<CreateRuntimeDefaults>(),
    eventCreateCoordinator: sl<EventCreateCoordinator>(),
    createTemplateRepository: sl<CreateTemplateRepository>(),
    manageCreateTemplate: sl<ManageCreateTemplateUseCase>(),
    routePublicationCoordinator: sl<RoutePublicationCoordinator>(),
    scenarioCreateCoordinator: sl<ScenarioCreateCoordinator>(),
    scenarioGenerationCoordinator: sl<ScenarioGenerationCoordinator>(),
    placeEnrichmentCoordinator: sl<PlaceEnrichmentCoordinator>(),
    catalogObjectPicker: sl<CatalogObjectPickerPort>(),
    checkPlaceDuplicates: sl<CheckPlaceDuplicatesUseCase>(),
  );
});

final routeCreateRuntimeProvider =
    FutureProvider.autoDispose<RouteCreateRuntime>((ref) async {
      final runtime = await sl<RouteCreateRuntimeFactory>()();
      ref.onDispose(() {
        unawaited(runtime.coordinator.dispose());
      });
      return runtime;
    });

final routeGpxTransferControllerProvider =
    ChangeNotifierProvider.autoDispose<RouteGpxTransferController>((ref) {
      return RouteGpxTransferController(
        filePicker: sl<RouteGpxFilePickerPort>(),
        repository: sl<RouteGpxRepository>(),
        inspectGpx: sl<InspectRouteGpxUseCase>(),
        exportGpx: sl<ExportRouteGpxUseCase>(),
      );
    });

final routeRecordingControllerProvider =
    ChangeNotifierProvider.autoDispose<RouteRecordingController>((ref) {
      return sl<RouteRecordingController>();
    });

final routeQualityAdminControllerProvider =
    ChangeNotifierProvider.autoDispose<RouteQualityAdminController>((ref) {
      return RouteQualityAdminController(sl<RouteQualityWorkflowCoordinator>());
    });
