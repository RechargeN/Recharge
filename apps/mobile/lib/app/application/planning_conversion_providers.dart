import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adapters/legacy_quick_plan_conversion_adapter.dart';
import '../di/service_locator.dart';
import '../../core/id/id_generator.dart';
import '../../features/create/application/create_runtime_defaults.dart';
import '../../features/create/application/quick_plan_conversion_coordinator.dart';
import '../../features/create/application/scenario_conversion_handoff_store.dart';
import '../../features/create/data/datasources/quick_plan_conversion_memory_datasource.dart';
import '../../features/create/domain/usecases/expand_quick_plan_to_scenario_usecase.dart';

export 'planning_conversion_facade.dart';

import 'planning_conversion_facade.dart';

final quickPlanConversionSourceProvider =
    Provider<InMemoryQuickPlanConversionSource>((ref) {
      return InMemoryQuickPlanConversionSource();
    });

final legacyQuickPlanConversionAdapterProvider =
    Provider<LegacyQuickPlanConversionAdapter>((ref) {
      return const LegacyQuickPlanConversionAdapter();
    });

final scenarioConversionHandoffStoreProvider =
    Provider<ScenarioConversionHandoffStore>((ref) {
      return ScenarioConversionHandoffStore();
    });

final planningCreateRuntimeDefaultsProvider = Provider<CreateRuntimeDefaults>((
  ref,
) {
  return sl<CreateRuntimeDefaults>();
});

final quickPlanConversionCoordinatorProvider =
    Provider<QuickPlanConversionCoordinator>((ref) {
      final source = ref.watch(quickPlanConversionSourceProvider);
      final idGenerator = sl<IdGenerator>();
      return QuickPlanConversionCoordinator(
        expand: ExpandQuickPlanToScenarioUseCase(
          source: source,
          idGenerator: idGenerator,
        ),
        idGenerator: idGenerator,
        runtimeDefaults: sl<CreateRuntimeDefaults>(),
      );
    });

final planningConversionFacadeProvider = Provider<PlanningConversionFacade>((
  ref,
) {
  return PlanningConversionFacade(
    adapter: ref.watch(legacyQuickPlanConversionAdapterProvider),
    source: ref.watch(quickPlanConversionSourceProvider),
    coordinator: ref.watch(quickPlanConversionCoordinatorProvider),
    handoffStore: ref.watch(scenarioConversionHandoffStoreProvider),
    runtimeDefaults: ref.watch(planningCreateRuntimeDefaultsProvider),
  );
});
