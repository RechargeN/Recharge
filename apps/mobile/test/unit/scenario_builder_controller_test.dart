import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/scenarios/application/controllers/scenario_builder_controller.dart';
import 'package:recharge/features/scenarios/domain/entities/scenario_draft_entity.dart';

void main() {
  test('legacy Quick Plan runtime has stable identity and revision', () {
    final ScenarioBuilderController controller = ScenarioBuilderController();
    final String initialId = controller.state.draft.id;
    final List<String> initialStepIds = controller.state.draft.steps
        .map((step) => step.id)
        .toList(growable: false);

    expect(initialId, isNotEmpty);
    expect(initialStepIds, everyElement(isNotEmpty));
    expect(initialStepIds.toSet(), hasLength(initialStepIds.length));
    expect(controller.state.draft.revision, 0);

    controller.setFreeOnly(true);
    expect(controller.state.draft.id, initialId);
    expect(controller.state.draft.revision, 1);
    controller.reset();
    expect(controller.state.draft.id, isNot(initialId));
    expect(controller.state.draft.revision, 0);
  });

  test('initial scenario has calculated calm route totals', () {
    final ScenarioBuilderController controller = ScenarioBuilderController();

    expect(controller.state.draft.mood, ScenarioMood.calm);
    expect(controller.state.draft.steps, isNotEmpty);
    expect(controller.state.draft.totalDurationMinutes, greaterThan(0));
    expect(controller.state.draft.totalDistanceKm, greaterThan(0));
  });

  test('scenario stops include map coordinates', () {
    final ScenarioBuilderController controller = ScenarioBuilderController();

    expect(
      controller.state.draft.steps.every(
        (ScenarioStepEntity step) => step.latitude > 56 && step.longitude > 27,
      ),
      isTrue,
    );
  });

  test('freeOnly filters paid scenario steps', () {
    final ScenarioBuilderController controller = ScenarioBuilderController();

    controller.setFreeOnly(true);

    expect(controller.state.draft.freeOnly, isTrue);
    expect(
      controller.state.draft.steps.every(
        (ScenarioStepEntity step) => step.isFree,
      ),
      isTrue,
    );
    expect(controller.state.draft.totalPrice.isZero, isTrue);
  });

  test('mood change rebuilds scenario steps', () {
    final ScenarioBuilderController controller = ScenarioBuilderController();

    controller.setMood(ScenarioMood.active);

    expect(controller.state.draft.mood, ScenarioMood.active);
    expect(controller.state.draft.steps.first.category, 'sport.tennis');
  });

  test('applySeed updates route conditions and source prompt', () {
    final ScenarioBuilderController controller = ScenarioBuilderController();

    controller.applySeed(
      mood: ScenarioMood.social,
      maxDurationMinutes: 90,
      freeOnly: true,
      walkingOnly: true,
      sourcePrompt: ' free board games ',
    );

    expect(controller.state.draft.mood, ScenarioMood.social);
    expect(controller.state.draft.maxDurationMinutes, 90);
    expect(controller.state.draft.freeOnly, isTrue);
    expect(controller.state.draft.sourcePrompt, 'free board games');
    expect(
      controller.state.draft.steps.every(
        (ScenarioStepEntity step) => step.isFree,
      ),
      isTrue,
    );
  });

  test('applySeed restores explicit step categories', () {
    final ScenarioBuilderController controller = ScenarioBuilderController();

    controller.applySeed(
      mood: ScenarioMood.calm,
      stepCategories: const <String>['wellness_recharge.calm_walk'],
    );

    expect(controller.state.draft.steps, hasLength(1));
    expect(controller.state.draft.steps.single.title, 'Calm city walk');
  });

  test('removeStepAt updates route totals', () {
    final ScenarioBuilderController controller = ScenarioBuilderController();
    final int initialCount = controller.state.draft.steps.length;
    final int initialDuration = controller.state.draft.totalDurationMinutes;

    controller.removeStepAt(0);

    expect(controller.state.draft.steps, hasLength(initialCount - 1));
    expect(
      controller.state.draft.totalDurationMinutes,
      lessThan(initialDuration),
    );
  });

  test('moveStepDown reorders stops', () {
    final ScenarioBuilderController controller = ScenarioBuilderController();
    final String firstTitle = controller.state.draft.steps.first.title;

    controller.moveStepDown(0);

    expect(controller.state.draft.steps[1].title, firstTitle);
  });

  test('addSuggestedStep appends an available stop', () {
    final ScenarioBuilderController controller = ScenarioBuilderController();
    controller.removeStepAt(0);
    final ScenarioStepEntity suggestion = controller.suggestedSteps.first;

    controller.addSuggestedStep(suggestion);

    expect(
      controller.state.draft.steps.map((ScenarioStepEntity step) => step.title),
      contains(suggestion.title),
    );
  });

  test('route fit reports overloaded seeded route', () {
    final ScenarioBuilderController controller = ScenarioBuilderController();

    controller.applySeed(
      mood: ScenarioMood.social,
      maxDurationMinutes: 90,
      freeOnly: true,
      walkingOnly: true,
      stepCategories: const <String>[
        'games_indoor.board_games',
        'music_nightlife.afterwork_drinks',
      ],
    );

    expect(controller.state.routeFit.score, lessThan(85));
    expect(controller.state.routeFit.label, isNot('Ready'));
    expect(controller.state.routeFit.insights, contains('Trim about 35 min'));
    expect(
      controller.state.routeFit.insights,
      contains('Remove paid stops for free-only mode'),
    );
  });

  test('optimizeRoute trims route to current conditions', () {
    final ScenarioBuilderController controller = ScenarioBuilderController();

    controller.applySeed(
      mood: ScenarioMood.social,
      maxDurationMinutes: 90,
      freeOnly: true,
      walkingOnly: true,
      stepCategories: const <String>[
        'games_indoor.board_games',
        'music_nightlife.afterwork_drinks',
      ],
    );

    controller.optimizeRoute();

    expect(controller.state.draft.totalDurationMinutes, lessThanOrEqualTo(90));
    expect(
      controller.state.draft.steps.every(
        (ScenarioStepEntity step) => step.isFree,
      ),
      isTrue,
    );
    expect(controller.state.routeFit.score, greaterThanOrEqualTo(85));
    expect(controller.state.routeFit.label, 'Ready');
  });
}
