import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controllers/scenario_builder_controller.dart';

final scenarioBuilderControllerProvider =
    ChangeNotifierProvider<ScenarioBuilderController>((ref) {
      return ScenarioBuilderController();
    });
