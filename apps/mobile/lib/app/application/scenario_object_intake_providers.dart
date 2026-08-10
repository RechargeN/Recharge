import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/create/application/create_runtime_defaults.dart';
import '../../features/create/application/scenario_create_coordinator.dart';
import '../../features/create/domain/repositories/create_draft_collection_repository.dart';
import '../../features/create/domain/repositories/scenario_object_intake_intent_repository.dart';
import '../adapters/discover_scenario_intake_adapter.dart';
import '../di/service_locator.dart';
import '../../core/telemetry/analytics_service.dart';
import 'scenario_object_intake_config.dart';
import 'scenario_object_intake_facade.dart';
import 'scenario_object_intake_telemetry.dart';

final scenarioObjectIntakeConfigProvider = Provider<ScenarioObjectIntakeConfig>(
  (ref) => const ScenarioObjectIntakeConfig().validated(),
);

final scenarioObjectIntakeTelemetryProvider =
    Provider<ScenarioObjectIntakeTelemetry>((ref) {
      if (!sl.isRegistered<AnalyticsService>()) {
        return const ScenarioObjectIntakeTelemetry.disabled();
      }
      return ScenarioObjectIntakeTelemetry(sl<AnalyticsService>());
    });

final discoverScenarioIntakeAdapterProvider =
    Provider<DiscoverScenarioIntakeAdapter>(
      (ref) => const DiscoverScenarioIntakeAdapter(),
    );

final scenarioObjectIntakeFacadeProvider = Provider<ScenarioObjectIntakeFacade>(
  (ref) {
    final config = ref.watch(scenarioObjectIntakeConfigProvider);
    return ScenarioObjectIntakeFacade(
      intentRepository: sl<ScenarioObjectIntakeIntentRepository>(),
      collectionRepository: sl<CreateDraftCollectionRepository>(),
      scenarioCoordinator: sl<ScenarioCreateCoordinator>(),
      runtimeDefaults: sl<CreateRuntimeDefaults>(),
      idGenerator: sl(),
      config: config,
    );
  },
);
