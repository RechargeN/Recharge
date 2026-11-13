import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controllers/scenario_builder_controller.dart';
import '../domain/repositories/quick_plan_repository.dart';

// Explicit injection only; production activation remains gated.
final quickPlanRepositoryProvider = Provider<QuickPlanRepository?>(
  (ref) => null,
);

final scenarioBuilderControllerProvider =
    ChangeNotifierProvider<ScenarioBuilderController>((ref) {
      return ScenarioBuilderController(
        repository: ref.watch(quickPlanRepositoryProvider),
      );
    });
