class ScenarioCreateStepConfig {
  const ScenarioCreateStepConfig({
    required this.id,
    required this.titleId,
    required this.descriptionId,
  });

  final String id;

  /// ARB message ids; the UI resolves them with `createFormText` (L4).
  final String titleId;
  final String descriptionId;
}

const List<ScenarioCreateStepConfig> scenarioCreateSteps =
    <ScenarioCreateStepConfig>[
      ScenarioCreateStepConfig(
        id: 'context',
        titleId: 'createStepScenarioContextTitle',
        descriptionId: 'createStepScenarioContextDescription',
      ),
      ScenarioCreateStepConfig(
        id: 'composer',
        titleId: 'createStepScenarioComposerTitle',
        descriptionId: 'createStepScenarioComposerDescription',
      ),
      ScenarioCreateStepConfig(
        id: 'review',
        titleId: 'createStepScenarioReviewTitle',
        descriptionId: 'createStepScenarioReviewDescription',
      ),
    ];

const int scenarioMinimumActiveItems = 2;
const int scenarioDefaultItemDurationMinutes = 60;
