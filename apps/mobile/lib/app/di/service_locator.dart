import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config/market_config.dart';
import '../config/travel_policy_config.dart';
import '../adapters/collection_publication_discovery_adapter.dart';
import '../adapters/rental_publication_discovery_adapter.dart';
import '../adapters/route_publication_discovery_adapter.dart';
import '../adapters/route_safety_reporting_adapter.dart';
import '../adapters/route_gpx_file_selector_adapter.dart';
import '../adapters/route_geolocator_adapter.dart';
import '../../core/telemetry/analytics_service.dart';
import '../../core/id/id_generator.dart';
import '../../core/notifications/app_notification_sink.dart';
import '../../features/ai_assist/application/ai_assist_coordinator.dart';
import '../../features/ai_assist/application/ai_assist_runtime_config.dart';
import '../../features/ai_assist/data/datasources/local_ai_assist_gateway.dart';
import '../../features/ai_assist/data/datasources/local_ai_prompt_registry.dart';
import '../../features/ai_assist/domain/repositories/ai_assist_gateway.dart';
import '../../features/ai_assist/domain/repositories/ai_prompt_registry.dart';
import '../../features/ai_assist/domain/usecases/execute_ai_assist_usecase.dart';
import '../../features/ai_assist/domain/usecases/sanitize_ai_input_usecase.dart';
import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/get_current_user_usecase.dart';
import '../../features/auth/domain/usecases/restore_session_usecase.dart';
import '../../features/auth/domain/usecases/sign_in_usecase.dart';
import '../../features/auth/domain/usecases/sign_out_usecase.dart';
import '../../features/create/data/datasources/create_local_datasource.dart';
import '../../features/create/data/datasources/create_template_local_datasource.dart';
import '../../features/create/data/datasources/event_mock_inventory_datasource.dart';
import '../../features/create/data/datasources/scenario_object_intake_local_datasource.dart';
import '../../features/create/data/datasources/place_duplicate_mock_datasource.dart';
import '../../features/create/data/datasources/place_enrichment_mock_datasource.dart';
import '../../features/create/data/datasources/catalog_object_picker_mock_datasource.dart';
import '../../features/create/data/datasources/scenario_proposal_mock_datasource.dart';
import '../../features/create/data/datasources/gtfs_cache_datasource.dart';
import '../../features/create/data/datasources/latvia_gtfs_datasource.dart';
import '../../features/create/application/create_runtime_defaults.dart';
import '../../features/create/application/event_create_coordinator.dart';
import '../../features/create/application/scenario_create_coordinator.dart';
import '../../features/create/application/scenario_generation_coordinator.dart';
import '../../features/create/application/place_enrichment_coordinator.dart';
import '../../features/create/application/scenario_transit_schedule_coordinator.dart';
import '../../features/create/application/route_create_config.dart';
import '../../features/create/application/route_create_coordinator.dart';
import '../../features/create/application/route_create_runtime.dart';
import '../../features/create/application/route_draft_autosave_coordinator.dart';
import '../../features/create/application/route_publication_coordinator.dart';
import '../../features/create/application/route_quality_workflow_coordinator.dart';
import '../../features/create/data/datasources/route_publication_memory_datasource.dart';
import '../../features/create/data/datasources/route_quality_workflow_memory_datasource.dart';
import '../../features/create/data/datasources/route_gpx_memory_source_store.dart';
import '../../features/create/data/datasources/route_recording_secure_store.dart';
import '../../features/create/data/gpx/route_gpx_inspector.dart';
import '../../features/create/data/gpx/route_gpx_importer.dart';
import '../../features/create/data/gpx/route_gpx_exporter.dart';
import '../../features/create/data/policies/demo_route_authoring_policy.dart';
import '../../features/create/data/repositories/event_timezone_repository_impl.dart';
import '../../features/create/data/repositories/event_inventory_snapshot_repository_impl.dart';
import '../../features/create/data/repositories/create_repository_impl.dart';
import '../../features/create/data/repositories/create_template_repository_impl.dart';
import '../../features/create/data/repositories/scenario_object_intake_repository_impl.dart';
import '../../features/create/data/repositories/route_publication_repository_impl.dart';
import '../../features/create/data/repositories/route_quality_workflow_repository_impl.dart';
import '../../features/create/application/collection_create_config.dart';
import '../../features/create/application/collection_create_coordinator.dart';
import '../../features/create/data/datasources/collection_catalog_search_mock_datasource.dart';
import '../../features/create/data/datasources/collection_publication_local_datasource.dart';
import '../../features/create/data/datasources/google_places_search_datasource.dart';
import '../../features/create/data/repositories/collection_catalog_search_repository_impl.dart';
import '../../features/create/data/repositories/collection_publication_repository_impl.dart';
import '../../features/create/data/repositories/location_search_repository_impl.dart';
import '../../features/create/data/repositories/route_gpx_repository_impl.dart';
import '../../features/create/data/repositories/route_recording_journal_repository_impl.dart';
import '../../features/create/data/repositories/scenario_transit_schedule_repository_impl.dart';
import '../../features/create/data/routing/demo_route_graph_adapter.dart';
import '../../features/create/data/routing/demo_route_graph_asset_loader.dart';
import '../../features/create/domain/repositories/collection_catalog_search_repository.dart';
import '../../features/create/domain/repositories/collection_publication_index_sink.dart';
import '../../features/create/domain/repositories/collection_publication_repository.dart';
import '../../features/create/domain/repositories/create_repository.dart';
import '../../features/create/domain/repositories/create_draft_collection_repository.dart';
import '../../features/create/domain/repositories/location_search_repository.dart';
import '../../features/create/domain/repositories/rental_promotion_repository.dart';
import '../../features/create/domain/repositories/create_template_repository.dart';
import '../../features/create/domain/repositories/scenario_object_intake_intent_repository.dart';
import '../../features/create/domain/repositories/route_draft_persistence_repository.dart';
import '../../features/create/domain/repositories/rental_publication_index_sink.dart';
import '../../features/create/domain/repositories/route_authoring_policy.dart';
import '../../features/create/domain/repositories/route_publication_index_sink.dart';
import '../../features/create/domain/repositories/route_publication_repository.dart';
import '../../features/create/domain/repositories/route_quality_workflow_repository.dart';
import '../../features/create/domain/repositories/route_gpx_repository.dart';
import '../../features/create/domain/repositories/route_gpx_source_store.dart';
import '../../features/create/domain/repositories/route_gpx_file_picker_port.dart';
import '../../features/create/domain/repositories/route_location_recording_port.dart';
import '../../features/create/domain/repositories/route_recording_journal_repository.dart';
import '../../features/create/domain/repositories/scenario_transit_schedule_repository.dart';
import '../../features/create/application/controllers/route_recording_controller.dart';
import '../../core/map/map_scene.dart';
import '../../features/create/domain/repositories/event_timezone_repository.dart';
import '../../features/create/domain/repositories/event_inventory_snapshot_repository.dart';
import '../../features/create/domain/repositories/catalog_object_picker_port.dart';
import '../../features/create/domain/repositories/scenario_proposal_generator_port.dart';
import '../../features/create/domain/repositories/place_enrichment_port.dart';
import '../../features/create/domain/usecases/generate_scenario_proposal_usecase.dart';
import '../../features/create/domain/usecases/generate_place_enrichment_proposal_usecase.dart';
import '../../features/create/domain/usecases/load_create_draft_usecase.dart';
import '../../features/create/domain/usecases/load_create_draft_by_id_usecase.dart';
import '../../features/create/domain/usecases/materialize_event_schedule_usecase.dart';
import '../../features/create/domain/usecases/manage_create_template_usecase.dart';
import '../../features/create/domain/usecases/promote_rental_to_published_usecase.dart';
import '../../features/create/domain/usecases/publish_create_draft_usecase.dart';
import '../../features/create/domain/usecases/save_create_draft_usecase.dart';
import '../../features/create/domain/usecases/check_place_duplicates_usecase.dart';
import '../../features/create/domain/usecases/build_route_publication_bundle_usecase.dart';
import '../../features/create/domain/usecases/inspect_route_gpx_usecase.dart';
import '../../features/create/domain/usecases/export_route_gpx_usecase.dart';
import '../../features/discover/data/datasources/discover_remote_datasource.dart';
import '../../features/discover/data/datasources/published_collection_discovery_local_datasource.dart';
import '../../features/discover/data/datasources/published_rental_discovery_local_datasource.dart';
import '../../features/discover/data/datasources/published_route_discovery_local_datasource.dart';
import '../../features/discover/data/datasources/discover_preferences_local_datasource.dart';
import '../../features/discover/data/repositories/collection_item_resolution_repository_impl.dart';
import '../../features/discover/data/repositories/discover_preferences_repository_impl.dart';
import '../../features/discover/data/repositories/discover_repository_impl.dart';
import '../../features/discover/data/repositories/timezone_repository_impl.dart';
import '../../features/discover/data/repositories/travel_time_repository_impl.dart';
import '../../features/discover/data/repositories/time_fit_evaluation_store_impl.dart';
import '../../features/discover/domain/entities/discover_query.dart';
import '../../features/discover/domain/repositories/collection_item_resolution_repository.dart';
import '../../features/discover/domain/repositories/discover_preferences_repository.dart';
import '../../features/discover/domain/repositories/discover_repository.dart';
import '../../features/discover/domain/repositories/published_collection_discovery_port.dart';
import '../../features/discover/domain/repositories/published_rental_discovery_port.dart';
import '../../features/discover/domain/repositories/published_route_discovery_port.dart';
import '../../features/discover/domain/repositories/route_safety_reporting_port.dart';
import '../../features/discover/domain/repositories/timezone_repository.dart';
import '../../features/discover/domain/repositories/travel_time_repository.dart';
import '../../features/discover/domain/repositories/time_fit_evaluation_store.dart';
import '../../features/discover/domain/usecases/apply_time_window_usecase.dart';
import '../../features/discover/domain/usecases/build_time_window_usecase.dart';
import '../../features/discover/domain/usecases/calculate_time_fit_score_usecase.dart';
import '../../features/discover/domain/usecases/calculate_travel_times_usecase.dart';
import '../../features/discover/domain/usecases/get_discover_details_usecase.dart';
import '../../features/discover/domain/usecases/get_discover_feed_usecase.dart';
import '../../features/discover/domain/usecases/submit_route_safety_report_usecase.dart';
import '../../features/discover/application/discover_runtime_defaults.dart';
import '../../features/explore/data/datasources/explore_local_datasource.dart';
import '../../features/explore/data/repositories/explore_repository_impl.dart';
import '../../features/explore/domain/repositories/explore_repository.dart';
import '../../features/explore/domain/usecases/load_profile_editable_usecase.dart';
import '../../features/explore/domain/usecases/load_settings_usecase.dart';
import '../../features/explore/domain/usecases/save_profile_editable_usecase.dart';
import '../../features/explore/domain/usecases/save_settings_usecase.dart';
import '../../features/identity/data/datasources/identity_workspace_local_datasource.dart';
import '../../features/identity/data/datasources/mock_identity_fixture.dart';
import '../../features/identity/data/datasources/public_professional_page_local_datasource.dart';
import '../../features/identity/data/repositories/identity_workspace_repository_impl.dart';
import '../../features/identity/data/repositories/public_professional_page_repository_impl.dart';
import '../../features/identity/domain/repositories/identity_workspace_repository.dart';
import '../../features/identity/domain/repositories/public_professional_page_repository.dart';
import '../../features/identity/domain/usecases/create_professional_page_usecase.dart';
import '../../features/identity/domain/usecases/load_identity_workspace_usecase.dart';
import '../../features/identity/domain/usecases/request_page_limit_increase_usecase.dart';
import '../../features/identity/domain/usecases/select_workspace_usecase.dart';
import '../../features/identity/domain/usecases/resolve_public_professional_page_usecase.dart';
import '../../features/favorites/data/datasources/favorites_local_datasource.dart';
import '../../features/favorites/data/repositories/favorites_repository_impl.dart';
import '../../features/favorites/domain/repositories/favorites_repository.dart';
import '../../features/favorites/domain/usecases/add_favorite_usecase.dart';
import '../../features/favorites/domain/usecases/get_favorites_usecase.dart';
import '../../features/favorites/domain/usecases/remove_favorite_usecase.dart';
import '../../features/notifications/data/datasources/notifications_local_datasource.dart';
import '../../features/notifications/data/repositories/notifications_repository_impl.dart';
import '../../features/notifications/domain/repositories/notifications_repository.dart';
import '../../features/notifications/domain/usecases/get_notifications_usecase.dart';
import '../../features/notifications/domain/usecases/mark_notification_read_usecase.dart';
import '../../features/visited/data/datasources/visited_places_local_datasource.dart';
import '../../features/visited/data/repositories/visited_places_repository_impl.dart';
import '../../features/visited/domain/repositories/visited_places_repository.dart';
import '../../features/visited/domain/usecases/get_visited_places_usecase.dart';
import '../../features/visited/domain/usecases/record_place_visit_usecase.dart';
import '../../features/visited/domain/usecases/remove_visit_usecase.dart';

final GetIt sl = GetIt.instance;

Future<void> setupDependencies() async {
  if (sl.isRegistered<AnalyticsService>()) {
    return;
  }

  sl
    ..registerLazySingleton<MarketRegistry>(MarketRegistry.new)
    ..registerLazySingleton<MarketConfig>(() => sl<MarketRegistry>().active)
    ..registerLazySingleton<TravelPolicyConfig>(TravelPolicyConfig.new)
    ..registerLazySingleton<IdGenerator>(UuidV4IdGenerator.new)
    ..registerLazySingleton<AiAssistRuntimeConfig>(AiAssistRuntimeConfig.new)
    ..registerLazySingleton<AiPromptRegistry>(LocalAiPromptRegistry.new)
    ..registerLazySingleton<AiAssistQuotaStore>(InMemoryAiAssistQuotaStore.new)
    ..registerLazySingleton<AiAssistGateway>(LocalAiAssistGateway.new)
    ..registerFactory<SanitizeAiInputUseCase>(SanitizeAiInputUseCase.new)
    ..registerFactory<ExecuteAiAssistUseCase>(
      () => ExecuteAiAssistUseCase(
        promptRegistry: sl(),
        gateway: sl(),
        quotaStore: sl(),
        sanitizer: sl(),
      ),
    )
    ..registerFactory<AiAssistCoordinator>(
      () => AiAssistCoordinator(
        executeAiAssist: sl(),
        promptRegistry: sl(),
        idGenerator: sl(),
        config: sl(),
      ),
    )
    ..registerLazySingleton<DiscoverQuery>(
      () => DiscoverQuery.defaults(
        marketCityId: sl<MarketConfig>().marketCityId,
        centerLat: sl<MarketConfig>().centerLat,
        centerLng: sl<MarketConfig>().centerLng,
      ),
    )
    ..registerLazySingleton<CreateRuntimeDefaults>(
      () => CreateRuntimeDefaults(
        marketCityId: sl<MarketConfig>().marketCityId,
        timezone: sl<MarketConfig>().timezoneId,
        country: sl<MarketConfig>().countryCode,
        city: sl<MarketConfig>().cityName,
        currency: sl<MarketConfig>().currencyCode,
        marketCenterLat: sl<MarketConfig>().centerLat,
        marketCenterLng: sl<MarketConfig>().centerLng,
      ),
    )
    ..registerLazySingleton<DiscoverRuntimeDefaults>(
      () => DiscoverRuntimeDefaults(
        timezoneId: sl<MarketConfig>().timezoneId,
        originLat: sl<MarketConfig>().centerLat,
        originLng: sl<MarketConfig>().centerLng,
      ),
    )
    ..registerLazySingleton<AnalyticsService>(ConsoleAnalyticsService.new)
    ..registerLazySingleton<FlutterSecureStorage>(FlutterSecureStorage.new)
    ..registerLazySingleton<http.Client>(http.Client.new)
    ..registerLazySingleton<RouteRecordingSecureStore>(
      () => EncryptedFileRouteRecordingStore(
        secureStorage: sl(),
        supportDirectory: getApplicationSupportDirectory,
      ),
    )
    ..registerLazySingleton<RouteRecordingJournalRepository>(
      () => RouteRecordingJournalRepositoryImpl(store: sl()),
    )
    ..registerLazySingleton<RouteLocationRecordingPort>(
      RouteGeolocatorAdapter.new,
    )
    ..registerFactory<RouteRecordingController>(
      () => RouteRecordingController(
        idGenerator: sl(),
        location: sl(),
        journalRepository: sl(),
      ),
    )
    ..registerLazySingleton<AuthRemoteDataSource>(MockAuthRemoteDataSource.new)
    ..registerLazySingleton<AuthLocalDataSource>(
      () => AuthLocalDataSource(sl()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(remoteDataSource: sl(), localDataSource: sl()),
    )
    ..registerLazySingleton<MockIdentityFixture>(MockIdentityFixture.new)
    ..registerLazySingleton<IdentityWorkspaceLocalDataSource>(
      () => IdentityWorkspaceLocalDataSource(sl()),
    )
    ..registerLazySingleton<PublicProfessionalPageLocalDataSource>(
      () => PublicProfessionalPageLocalDataSource(sl()),
    )
    ..registerLazySingleton<IdentityWorkspaceRepository>(
      () => IdentityWorkspaceRepositoryImpl(
        localDataSource: sl(),
        mockFixture: sl(),
        publicPageLocalDataSource: sl(),
      ),
    )
    ..registerLazySingleton<PublicProfessionalPageRepository>(
      () => PublicProfessionalPageRepositoryImpl(sl()),
    )
    ..registerLazySingleton<PublicPageContentProjectionRepository>(
      EmptyPublicPageContentProjectionRepository.new,
    )
    ..registerLazySingleton<DiscoverRemoteDataSource>(
      MockDiscoverRemoteDataSource.new,
    )
    ..registerLazySingleton<CreateLocalDataSource>(
      () => CreateLocalDataSource(
        sl(),
        activeMarketCityId: sl<CreateRuntimeDefaults>().marketCityId,
        activeTimezone: sl<CreateRuntimeDefaults>().timezone,
        activeCountry: sl<CreateRuntimeDefaults>().country,
        activeCity: sl<CreateRuntimeDefaults>().city,
      ),
    )
    ..registerLazySingleton<CreateTemplateLocalDataSource>(
      () => CreateTemplateLocalDataSource(
        sl(),
        activeMarketCityId: sl<CreateRuntimeDefaults>().marketCityId,
        activeTimezone: sl<CreateRuntimeDefaults>().timezone,
        activeCountry: sl<CreateRuntimeDefaults>().country,
        activeCity: sl<CreateRuntimeDefaults>().city,
      ),
    )
    ..registerLazySingleton<ScenarioObjectIntakeLocalDataSource>(
      () => ScenarioObjectIntakeLocalDataSource(sl()),
    )
    ..registerLazySingleton<CreateRepository>(
      () => CreateRepositoryImpl(localDataSource: sl(), idGenerator: sl()),
    )
    ..registerLazySingleton<CreateDraftCollectionRepository>(() {
      final repository = sl<CreateRepository>();
      if (repository is! CreateDraftCollectionRepository) {
        throw StateError(
          'Create repository must support draft collection persistence.',
        );
      }
      return repository as CreateDraftCollectionRepository;
    })
    // RNT-PUB-01 §1.2: same repository instance, cast to the narrower
    // RentalPromotionRepository interface — mirrors the
    // CreateDraftCollectionRepository cast above.
    ..registerLazySingleton<RentalPromotionRepository>(() {
      final repository = sl<CreateRepository>();
      if (repository is! RentalPromotionRepository) {
        throw StateError(
          'Create repository must support Rental direct-publish promotion.',
        );
      }
      return repository as RentalPromotionRepository;
    })
    ..registerLazySingleton<PromoteRentalToPublishedUseCase>(
      () => PromoteRentalToPublishedUseCase(sl()),
    )
    ..registerLazySingleton<CreateTemplateRepository>(
      () => CreateTemplateRepositoryImpl(sl()),
    )
    ..registerLazySingleton<ScenarioObjectIntakeIntentRepository>(
      () => ScenarioObjectIntakeRepositoryImpl(sl()),
    )
    ..registerFactory<ManageCreateTemplateUseCase>(
      () => ManageCreateTemplateUseCase(sl()),
    )
    ..registerLazySingleton<PublishedRouteDiscoveryLocalDataSource>(
      () => PublishedRouteDiscoveryLocalDataSource(sl()),
    )
    ..registerLazySingleton<RoutePublicationDiscoveryAdapter>(
      () => RoutePublicationDiscoveryAdapter(sl()),
    )
    ..registerLazySingleton<RoutePublicationIndexSink>(
      () => sl<RoutePublicationDiscoveryAdapter>(),
    )
    ..registerLazySingleton<PublishedRouteDiscoveryPort>(
      () => sl<RoutePublicationDiscoveryAdapter>(),
    )
    // Rental — both sides active (DTL-OBJ-01 §3.6): unlike Collection
    // below, Rental's Create-authoring half (RentalDirectPublishPolicy
    // etc.) is already wired, so RentalPublicationIndexSink is registered
    // too, mirroring Route above.
    ..registerLazySingleton<PublishedRentalDiscoveryLocalDataSource>(
      () => PublishedRentalDiscoveryLocalDataSource(sl()),
    )
    ..registerLazySingleton<RentalPublicationDiscoveryAdapter>(
      () => RentalPublicationDiscoveryAdapter(sl()),
    )
    ..registerLazySingleton<RentalPublicationIndexSink>(
      () => sl<RentalPublicationDiscoveryAdapter>(),
    )
    ..registerLazySingleton<PublishedRentalDiscoveryPort>(
      () => sl<RentalPublicationDiscoveryAdapter>(),
    )
    // Collection — both sides active (CLG-CRT-01): mirrors Rental above.
    // `CollectionPublicationDiscoveryAdapter` is the one file that imports
    // both `CollectionPublicationIndexSink` (Create) and
    // `PublishedCollectionDiscoveryPort` (Discover); `sink`/`port` here are
    // the same instance, same pattern as Route/Rental.
    ..registerLazySingleton<PublishedCollectionDiscoveryLocalDataSource>(
      () => PublishedCollectionDiscoveryLocalDataSource(sl()),
    )
    ..registerLazySingleton<CollectionPublicationDiscoveryAdapter>(
      () => CollectionPublicationDiscoveryAdapter(sl()),
    )
    ..registerLazySingleton<CollectionPublicationIndexSink>(
      () => sl<CollectionPublicationDiscoveryAdapter>(),
    )
    ..registerLazySingleton<PublishedCollectionDiscoveryPort>(
      () => sl<CollectionPublicationDiscoveryAdapter>(),
    )
    ..registerLazySingleton<CollectionItemResolutionRepository>(
      CollectionItemResolutionRepositoryImpl.new,
    )
    // CLG-CRT-01 §15 "Миграция и rollback": one config instance for the
    // whole composition — `collectionCreateEnabled: true` is safe to ship,
    // `collectionPublishingEnabled`/`collectionDiscoverEnabled` stay `false`
    // (the class defaults) until this slice's own gates are green end to
    // end; flip both here, in one place, once that is true.
    ..registerLazySingleton<CollectionCreateRuntimeConfig>(
      () => const CollectionCreateRuntimeConfig(),
    )
    ..registerLazySingleton<CollectionPublicationLocalDatasource>(
      () => CollectionPublicationLocalDatasource(idGenerator: sl()),
    )
    ..registerLazySingleton<CollectionPublicationRepository>(
      () => CollectionPublicationRepositoryImpl(
        datasource: sl(),
        sink: sl<CollectionPublicationIndexSink>(),
      ),
    )
    ..registerLazySingleton<CollectionCatalogSearchMockDatasource>(
      CollectionCatalogSearchMockDatasource.new,
    )
    ..registerLazySingleton<CollectionCatalogSearchRepository>(
      () => CollectionCatalogSearchRepositoryImpl(datasource: sl()),
    )
    // LOC-SRCH prerequisite: key comes from the gitignored
    // google_maps.properties via --dart-define-from-file (documented in
    // the tracked google_maps.properties.example), same mechanism the
    // native Google Maps SDK config already uses. `GooglePlacesSearchDatasource`
    // still fails closed (empty results) if the value is empty — a missing
    // properties file degrades safely, it does not crash the build.
    ..registerLazySingleton<GooglePlacesSearchDatasource>(
      () => GooglePlacesSearchDatasource(
        client: sl(),
        apiKey: const String.fromEnvironment('GOOGLE_PLACES_API_KEY'),
      ),
    )
    ..registerLazySingleton<LocationSearchRepository>(
      () => LocationSearchRepositoryImpl(sl()),
    )
    ..registerFactory<CollectionCreateCoordinator>(
      () => CollectionCreateCoordinator(
        idGenerator: sl(),
        catalogSearchRepository: sl(),
        publicationRepository: sl(),
        locationSearchRepository: sl(),
        config: sl<CollectionCreateRuntimeConfig>(),
      ),
    )
    ..registerLazySingleton<RoutePublicationMemoryDataSource>(
      RoutePublicationMemoryDataSource.new,
    )
    ..registerLazySingleton<RoutePublicationRepository>(
      () => RoutePublicationRepositoryImpl(sl(), indexSink: sl()),
    )
    ..registerLazySingleton<RouteQualityWorkflowMemoryDataSource>(
      RouteQualityWorkflowMemoryDataSource.new,
    )
    ..registerLazySingleton<RouteGpxImportConfig>(
      () => const RouteGpxImportConfig(),
    )
    ..registerLazySingleton<RouteGpxSourceStore>(
      () => RouteGpxMemorySourceStore(idGenerator: sl(), config: sl()),
    )
    ..registerLazySingleton<RouteGpxFilePickerPort>(
      () => RouteGpxFileSelectorAdapter(sl()),
    )
    ..registerLazySingleton<RouteGpxInspector>(
      () => RouteGpxInspector(config: sl()),
    )
    ..registerLazySingleton<RouteGpxImporter>(
      () => RouteGpxImporter(inspector: sl()),
    )
    ..registerLazySingleton<RouteGpxExporter>(RouteGpxExporter.new)
    ..registerLazySingleton<RouteGpxRepository>(
      () => RouteGpxRepositoryImpl(
        sourceStore: sl(),
        inspector: sl(),
        importer: sl(),
        exporter: sl(),
      ),
    )
    ..registerFactory<InspectRouteGpxUseCase>(
      () => InspectRouteGpxUseCase(sl()),
    )
    ..registerFactory<ExportRouteGpxUseCase>(() => ExportRouteGpxUseCase(sl()))
    ..registerLazySingleton<RouteQualityWorkflowRepository>(
      () => RouteQualityWorkflowRepositoryImpl(sl()),
    )
    ..registerLazySingleton<RouteAuthoringPolicy>(DemoRouteAuthoringPolicy.new)
    ..registerFactory<RouteQualityWorkflowCoordinator>(
      () => RouteQualityWorkflowCoordinator(
        idGenerator: sl(),
        workflowRepository: sl(),
        publicationRepository: sl(),
        authoringPolicy: sl(),
      ),
    )
    ..registerLazySingleton<RouteSafetyReportingPort>(
      () => RouteSafetyReportingAdapter(sl<RouteQualityWorkflowCoordinator>()),
    )
    ..registerFactory<SubmitRouteSafetyReportUseCase>(
      () => SubmitRouteSafetyReportUseCase(sl()),
    )
    ..registerFactory<RoutePublicationCoordinator>(
      () => RoutePublicationCoordinator(
        idGenerator: sl(),
        repository: sl(),
        authoringPolicy: sl(),
        buildBundle: const BuildRoutePublicationBundleUseCase(),
        buildPolicy: RoutePublicationBuildPolicy(
          validationPolicy: demoRouteCreateConfig().validationPolicy,
          locallyAllowedProviderCodes: const <String>{'demoGraph'},
        ),
      ),
    )
    ..registerLazySingleton<DemoRouteGraphAssetLoader>(
      DemoRouteGraphAssetLoader.new,
    )
    ..registerLazySingleton<RouteCreateRuntimeFactory>(
      () => () async {
        final graph = await sl<DemoRouteGraphAssetLoader>().load();
        final repository = sl<CreateRepository>();
        if (repository is! RouteDraftPersistenceRepository) {
          throw StateError(
            'Create repository must support Route draft persistence.',
          );
        }
        final routeRepository = repository as RouteDraftPersistenceRepository;
        final graphEdges = graph.edges
            .map(
              (edge) => MapPolylineData(
                id: edge.id,
                layerId: 'trail_graph',
                points: [
                  graph.nodes[edge.fromNodeId]!.position,
                  graph.nodes[edge.toNodeId]!.position,
                ],
              ),
            )
            .toList(growable: false);
        return RouteCreateRuntime(
          coordinator: RouteCreateCoordinator(
            idGenerator: sl(),
            routingRepository: DemoRouteGraphAdapter(graph: graph),
            autosaveCoordinator: RouteDraftAutosaveCoordinator(routeRepository),
            config: demoRouteCreateConfig(),
            gpxRepository: sl(),
          ),
          coverageBounds: graph.coverage.bounds,
          graphEdges: graphEdges,
          supportedProfiles: graph.coverage.supportedProfiles,
          attribution: graph.manifest.attribution,
        );
      },
    )
    ..registerLazySingleton<EventTimezoneRepository>(
      EventTimezoneRepositoryImpl.new,
    )
    ..registerLazySingleton<EventMockInventoryDataSource>(
      EventMockInventoryDataSource.new,
    )
    ..registerLazySingleton<EventInventorySnapshotRepository>(
      () => EventInventorySnapshotRepositoryImpl(sl()),
    )
    ..registerFactory<MaterializeEventScheduleUseCase>(
      () => MaterializeEventScheduleUseCase(sl()),
    )
    ..registerFactory<EventCreateCoordinator>(
      () => EventCreateCoordinator(
        materializeSchedule: sl(),
        inventorySnapshotRepository: sl(),
      ),
    )
    ..registerLazySingleton<CatalogObjectPickerPort>(
      MockCatalogObjectPickerDataSource.new,
    )
    ..registerFactory<ScenarioCreateCoordinator>(
      () => ScenarioCreateCoordinator(idGenerator: sl()),
    )
    ..registerLazySingleton<ScenarioProposalGeneratorPort>(
      () => MockScenarioProposalDataSource(catalog: sl()),
    )
    ..registerFactory<GenerateScenarioProposalUseCase>(
      () => GenerateScenarioProposalUseCase(sl()),
    )
    ..registerFactory<ScenarioGenerationCoordinator>(
      () => ScenarioGenerationCoordinator(
        generateProposal: sl(),
        scenarioCreateCoordinator: sl(),
      ),
    )
    ..registerLazySingleton<PlaceEnrichmentPort>(
      MockPlaceEnrichmentDataSource.new,
    )
    ..registerFactory<GeneratePlaceEnrichmentProposalUseCase>(
      () => GeneratePlaceEnrichmentProposalUseCase(sl()),
    )
    ..registerFactory<PlaceEnrichmentCoordinator>(
      () => PlaceEnrichmentCoordinator(generateProposal: sl()),
    )
    ..registerLazySingleton<LatviaGtfsProviderRegistry>(
      LatviaGtfsProviderRegistry.new,
    )
    ..registerLazySingleton<LatviaGtfsRemoteDataSource>(
      () => LatviaGtfsRemoteDataSource(client: sl()),
    )
    ..registerLazySingleton<GtfsCacheDataSource>(
      () =>
          GtfsCacheDataSource(supportDirectory: getApplicationSupportDirectory),
    )
    ..registerLazySingleton<ScenarioTransitScheduleRepository>(
      () => ScenarioTransitScheduleRepositoryImpl(
        registry: sl(),
        remoteDataSource: sl(),
        cacheDataSource: sl(),
      ),
    )
    ..registerFactory<ScenarioTransitScheduleCoordinator>(
      () => ScenarioTransitScheduleCoordinator(repository: sl()),
    )
    ..registerLazySingleton<DiscoverPreferencesLocalDataSource>(
      () => DiscoverPreferencesLocalDataSource(
        sl(),
        defaultMarketCityId: sl<MarketConfig>().marketCityId,
        defaultCenterLat: sl<MarketConfig>().centerLat,
        defaultCenterLng: sl<MarketConfig>().centerLng,
      ),
    )
    ..registerLazySingleton<DiscoverRepository>(
      () =>
          DiscoverRepositoryImpl(remoteDataSource: sl(), publishedRoutes: sl()),
    )
    ..registerLazySingleton<TimezoneRepository>(TimezoneRepositoryImpl.new)
    ..registerLazySingleton<TravelTimeRepository>(
      () => TravelTimeRepositoryImpl(
        walkingSpeedKmh: sl<TravelPolicyConfig>().walkingSpeedKmh,
        walkingRouteFactor: sl<TravelPolicyConfig>().walkingRouteFactor,
        drivingSpeedKmh: sl<TravelPolicyConfig>().drivingSpeedKmh,
        drivingRouteFactor: sl<TravelPolicyConfig>().drivingRouteFactor,
        transitSpeedKmh: sl<TravelPolicyConfig>().transitSpeedKmh,
        transitRouteFactor: sl<TravelPolicyConfig>().transitRouteFactor,
      ),
    )
    ..registerLazySingleton<TimeFitEvaluationStore>(
      InMemoryTimeFitEvaluationStore.new,
    )
    ..registerLazySingleton<DiscoverPreferencesRepository>(
      () => DiscoverPreferencesRepositoryImpl(localDataSource: sl()),
    )
    ..registerLazySingleton<ExploreLocalDataSource>(
      () => ExploreLocalDataSource(sl()),
    )
    ..registerLazySingleton<ExploreRepository>(
      () => ExploreRepositoryImpl(localDataSource: sl()),
    )
    ..registerLazySingleton<FavoritesLocalDataSource>(
      () => FavoritesLocalDataSource(sl()),
    )
    ..registerLazySingleton<FavoritesRepository>(
      () => FavoritesRepositoryImpl(localDataSource: sl()),
    )
    ..registerLazySingleton<NotificationsLocalDataSource>(
      () => NotificationsLocalDataSource(sl()),
    )
    ..registerLazySingleton<NotificationsRepository>(
      () => NotificationsRepositoryImpl(localDataSource: sl()),
    )
    ..registerLazySingleton<AppNotificationSink>(
      () => sl<NotificationsRepository>() as AppNotificationSink,
    )
    ..registerLazySingleton<VisitedPlacesLocalDataSource>(
      () => VisitedPlacesLocalDataSource(sl()),
    )
    ..registerLazySingleton<VisitedPlacesRepository>(
      () => VisitedPlacesRepositoryImpl(localDataSource: sl()),
    )
    ..registerFactory<SignInUseCase>(() => SignInUseCase(sl()))
    ..registerFactory<RestoreSessionUseCase>(() => RestoreSessionUseCase(sl()))
    ..registerFactory<SignOutUseCase>(() => SignOutUseCase(sl()))
    ..registerFactory<GetCurrentUserUseCase>(() => GetCurrentUserUseCase(sl()))
    ..registerFactory<LoadIdentityWorkspaceUseCase>(
      () => LoadIdentityWorkspaceUseCase(sl()),
    )
    ..registerFactory<CreateProfessionalPageUseCase>(
      () => CreateProfessionalPageUseCase(repository: sl(), idGenerator: sl()),
    )
    ..registerFactory<RequestPageLimitIncreaseUseCase>(
      () =>
          RequestPageLimitIncreaseUseCase(repository: sl(), idGenerator: sl()),
    )
    ..registerFactory<SelectWorkspaceUseCase>(
      () => SelectWorkspaceUseCase(sl()),
    )
    ..registerFactory<ResolvePublicProfessionalPageUseCase>(
      () => ResolvePublicProfessionalPageUseCase(
        repository: sl(),
        contentRepository: sl(),
      ),
    )
    ..registerFactory<LoadCreateDraftUseCase>(
      () => LoadCreateDraftUseCase(sl()),
    )
    ..registerFactory<LoadCreateDraftByIdUseCase>(
      () => LoadCreateDraftByIdUseCase(sl()),
    )
    ..registerFactory<SaveCreateDraftUseCase>(
      () => SaveCreateDraftUseCase(sl()),
    )
    ..registerFactory<PublishCreateDraftUseCase>(
      () => PublishCreateDraftUseCase(sl()),
    )
    ..registerFactory<CheckPlaceDuplicatesUseCase>(
      () => const CheckPlaceDuplicatesUseCase(
        candidates: mockPlaceDuplicateCandidates,
      ),
    )
    ..registerFactory<CalculateTravelTimesUseCase>(
      () => CalculateTravelTimesUseCase(sl()),
    )
    ..registerFactory<BuildTimeWindowUseCase>(
      () => BuildTimeWindowUseCase(sl()),
    )
    ..registerFactory<CalculateTimeFitScoreUseCase>(
      () => CalculateTimeFitScoreUseCase(
        timeFitWeight: sl<TravelPolicyConfig>().effectiveTimeFitWeight,
      ),
    )
    ..registerFactory<ApplyTimeWindowUseCase>(
      () => ApplyTimeWindowUseCase(
        calculateTravelTimes: sl(),
        timezoneRepository: sl(),
        calculateTimeFitScore: sl(),
        placeReturnSafetyRatio: sl<TravelPolicyConfig>().placeReturnSafetyRatio,
        placeReturnSafetyMinMinutes:
            sl<TravelPolicyConfig>().placeReturnSafetyMinMinutes,
        placeReturnSafetyMaxMinutes:
            sl<TravelPolicyConfig>().placeReturnSafetyMaxMinutes,
        onInvalidOpeningRule: (String objectId) {
          sl<AnalyticsService>().track(
            'time_fit_invalid_opening_rule',
            params: <String, Object?>{'object_id': objectId},
          );
        },
      ),
    )
    ..registerFactory<GetDiscoverFeedUseCase>(
      () => GetDiscoverFeedUseCase(
        sl(),
        applyTimeWindow: sl(),
        evaluationStore: sl(),
      ),
    )
    ..registerFactory<GetDiscoverDetailsUseCase>(
      () => GetDiscoverDetailsUseCase(sl(), evaluationStore: sl()),
    )
    ..registerFactory<LoadProfileEditableUseCase>(
      () => LoadProfileEditableUseCase(sl()),
    )
    ..registerFactory<SaveProfileEditableUseCase>(
      () => SaveProfileEditableUseCase(sl()),
    )
    ..registerFactory<LoadSettingsUseCase>(() => LoadSettingsUseCase(sl()))
    ..registerFactory<SaveSettingsUseCase>(() => SaveSettingsUseCase(sl()))
    ..registerFactory<GetFavoritesUseCase>(() => GetFavoritesUseCase(sl()))
    ..registerFactory<AddFavoriteUseCase>(() => AddFavoriteUseCase(sl()))
    ..registerFactory<RemoveFavoriteUseCase>(() => RemoveFavoriteUseCase(sl()))
    ..registerFactory<GetNotificationsUseCase>(
      () => GetNotificationsUseCase(sl()),
    )
    ..registerFactory<MarkNotificationReadUseCase>(
      () => MarkNotificationReadUseCase(sl()),
    )
    ..registerFactory<GetVisitedPlacesUseCase>(
      () => GetVisitedPlacesUseCase(sl()),
    )
    ..registerFactory<RecordPlaceVisitUseCase>(
      () => RecordPlaceVisitUseCase(repository: sl(), idGenerator: sl()),
    )
    ..registerFactory<RemoveVisitUseCase>(() => RemoveVisitUseCase(sl()));
}
