class ScenarioCreateStepConfig {
  const ScenarioCreateStepConfig({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

const List<ScenarioCreateStepConfig> scenarioCreateSteps =
    <ScenarioCreateStepConfig>[
      ScenarioCreateStepConfig(
        id: 'context',
        title: 'Context',
        description: 'Format, date mode, party, pace and budget',
      ),
      ScenarioCreateStepConfig(
        id: 'composer',
        title: 'Plan',
        description: 'Independent stops, time blocks and their order',
      ),
      ScenarioCreateStepConfig(
        id: 'review',
        title: 'Review',
        description: 'Totals, warnings and personal save readiness',
      ),
    ];

const int scenarioMinimumActiveItems = 2;
const int scenarioDefaultItemDurationMinutes = 60;
