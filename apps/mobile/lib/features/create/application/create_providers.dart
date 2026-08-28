import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/service_locator.dart';
import '../../../core/telemetry/analytics_service.dart';
import 'collection_create_config.dart';
import 'collection_create_coordinator.dart';
import 'create_runtime_defaults.dart';
import 'event_create_coordinator.dart';
import 'scenario_create_coordinator.dart';
import 'scenario_generation_coordinator.dart';
import 'scenario_transit_schedule_coordinator.dart';
import 'scenario_transit_picker_config.dart';
import 'scenario_transit_telemetry.dart';
import 'place_enrichment_coordinator.dart';
import 'route_create_runtime.dart';
import 'route_publication_coordinator.dart';
import '../domain/entities/rental_direct_publish_policy.dart';
import '../domain/repositories/catalog_object_picker_port.dart';
import '../domain/repositories/create_template_repository.dart';
import '../domain/repositories/rental_publication_index_sink.dart';
import '../domain/usecases/load_create_draft_usecase.dart';
import '../domain/usecases/manage_create_template_usecase.dart';
import '../domain/usecases/promote_rental_to_published_usecase.dart';
import '../domain/usecases/publish_create_draft_usecase.dart';
import '../domain/usecases/save_create_draft_usecase.dart';
import '../domain/usecases/check_place_duplicates_usecase.dart';
import 'controllers/create_controller.dart';
import 'controllers/route_gpx_transfer_controller.dart';
import 'controllers/route_recording_controller.dart';
import 'controllers/route_quality_admin_controller.dart';
import 'controllers/scenario_transit_picker_controller.dart';
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
    loadCreateDraftByIdUseCase: sl(),
    saveCreateDraftUseCase: sl<SaveCreateDraftUseCase>(),
    publishCreateDraftUseCase: sl<PublishCreateDraftUseCase>(),
    analyticsService: sl<AnalyticsService>(),
    runtimeDefaults: sl<CreateRuntimeDefaults>(),
    eventCreateCoordinator: sl<EventCreateCoordinator>(),
    eventAdmissionConfigurationEnabled: true,
    eventMockAvailabilityEnabled: true,
    createTemplateRepository: sl<CreateTemplateRepository>(),
    manageCreateTemplate: sl<ManageCreateTemplateUseCase>(),
    routePublicationCoordinator: sl<RoutePublicationCoordinator>(),
    scenarioCreateCoordinator: sl<ScenarioCreateCoordinator>(),
    scenarioGenerationCoordinator: sl<ScenarioGenerationCoordinator>(),
    placeEnrichmentCoordinator: sl<PlaceEnrichmentCoordinator>(),
    catalogObjectPicker: sl<CatalogObjectPickerPort>(),
    checkPlaceDuplicates: sl<CheckPlaceDuplicatesUseCase>(),
    // RNT-PUB-01 §1.3: local/mock composition explicitly opts into the
    // trusted direct-publish policy — the domain default is `false`.
    rentalDirectPublishPolicy: const RentalDirectPublishPolicy(
      isTrusted: true,
    ),
    promoteRentalToPublished: sl<PromoteRentalToPublishedUseCase>(),
    rentalPublicationIndexSink: sl<RentalPublicationIndexSink>(),
    // CLG-CRT-01: the same `CollectionCreateRuntimeConfig` instance the
    // coordinator factory and the Discover-side providers read — one
    // composition-wide source of truth for the three kill switches.
    collectionCreateConfig: sl<CollectionCreateRuntimeConfig>(),
  );
});

final collectionCreateCoordinatorProvider =
    Provider.autoDispose<CollectionCreateCoordinator>((ref) {
      return sl<CollectionCreateCoordinator>();
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

final scenarioTransitPickerControllerProvider =
    Provider.autoDispose<ScenarioTransitPickerController?>((ref) {
      if (!scenarioTransitPickerConfig.pickerEnabled ||
          !sl.isRegistered<ScenarioTransitScheduleCoordinator>()) {
        return null;
      }
      final controller = ScenarioTransitPickerController(
        coordinator: sl<ScenarioTransitScheduleCoordinator>(),
        telemetry: ScenarioTransitTelemetry(sl<AnalyticsService>()),
      );
      ref.onDispose(controller.dispose);
      return controller;
    });
