import 'package:flutter/material.dart';

import '../../../application/controllers/create_controller.dart';
import '../../../application/controllers/scenario_transit_picker_controller.dart';
import '../../../application/scenario_create_config.dart';
import '../../../application/state/create_state.dart';
import 'scenario_composer_section.dart';
import 'scenario_context_section.dart';
import 'scenario_generation_panel.dart';
import 'scenario_review_section.dart';

class ScenarioCreateBlock extends StatelessWidget {
  const ScenarioCreateBlock({
    required this.controller,
    required this.state,
    this.transitPickerController,
    super.key,
  });

  final CreateController controller;
  final CreateState state;
  final ScenarioTransitPickerController? transitPickerController;

  @override
  Widget build(BuildContext context) {
    final int step = state.scenarioStep;
    return Card(
      key: const ValueKey<String>('scenario-create-block'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Scenario plan',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Build a city, day, weekend or trip plan from independent stops. '
              'A Scenario is not a Route and does not change a Quick Plan.',
            ),
            if (state.draft.sectionData['quick_plan_conversion'] != null) ...[
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.call_split_outlined),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Expanded from a Quick Plan as an independent copy. '
                          'Legacy stops are private custom locations until you review them.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (controller.canGenerateScenario) ...<Widget>[
              ScenarioGenerationPanel(controller: controller, state: state),
              const SizedBox(height: 16),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List<Widget>.generate(
                scenarioCreateSteps.length,
                (int index) => ChoiceChip(
                  label: Text(
                    '${index + 1}. ${scenarioCreateSteps[index].title}',
                  ),
                  selected: step == index,
                  onSelected: (_) => controller.goToScenarioStep(index),
                ),
              ),
            ),
            const SizedBox(height: 16),
            switch (step) {
              0 => ScenarioContextSection(controller: controller, state: state),
              1 => ScenarioComposerSection(
                controller: controller,
                state: state,
                transitPickerController: transitPickerController,
              ),
              _ => ScenarioReviewSection(controller: controller, state: state),
            },
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                if (step > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => controller.goToScenarioStep(step - 1),
                      child: const Text('Back'),
                    ),
                  ),
                if (step > 0) const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: step < scenarioCreateSteps.length - 1
                        ? () => controller.goToScenarioStep(step + 1)
                        : controller.saveScenarioToMyScenarios,
                    child: Text(
                      step < scenarioCreateSteps.length - 1
                          ? 'Continue'
                          : 'Save to My Scenarios',
                    ),
                  ),
                ),
              ],
            ),
            if (state.message != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(state.message!),
            ],
          ],
        ),
      ),
    );
  }
}
