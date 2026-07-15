import 'package:flutter/foundation.dart';

import '../../domain/entities/scenario_draft_entity.dart';
import '../state/scenario_builder_state.dart';

class ScenarioBuilderController extends ChangeNotifier {
  ScenarioBuilderState _state = ScenarioBuilderState.initial();
  ScenarioBuilderState get state => _state;
  List<ScenarioStepEntity> get suggestedSteps {
    return scenarioSuggestionsFor(_state.draft);
  }

  void setMood(ScenarioMood mood) {
    _updateDraft(_state.draft.copyWith(mood: mood));
  }

  void setMaxDurationMinutes(int minutes) {
    _updateDraft(_state.draft.copyWith(maxDurationMinutes: minutes));
  }

  void setFreeOnly(bool value) {
    _updateDraft(_state.draft.copyWith(freeOnly: value));
  }

  void setWalkingOnly(bool value) {
    _updateDraft(_state.draft.copyWith(walkingOnly: value));
  }

  void applySeed({
    ScenarioMood? mood,
    int? maxDurationMinutes,
    bool? freeOnly,
    bool? walkingOnly,
    String? sourcePrompt,
    List<String>? stepCategories,
  }) {
    final List<ScenarioStepEntity>? restoredSteps =
        stepCategories == null ? null : scenarioStepsByCategories(stepCategories);
    _updateDraft(
      _state.draft.copyWith(
        mood: mood,
        maxDurationMinutes: maxDurationMinutes,
        freeOnly: freeOnly,
        walkingOnly: walkingOnly,
        sourcePrompt: sourcePrompt?.trim(),
        steps: restoredSteps == null || restoredSteps.isEmpty
            ? null
            : restoredSteps,
      ),
      regenerateSteps: restoredSteps == null || restoredSteps.isEmpty,
    );
  }

  void reset() {
    _state = ScenarioBuilderState.initial();
    notifyListeners();
  }

  void removeStepAt(int index) {
    if (index < 0 || index >= _state.draft.steps.length) return;
    final List<ScenarioStepEntity> steps =
        List<ScenarioStepEntity>.from(_state.draft.steps)..removeAt(index);
    _setDraftSteps(steps);
  }

  void moveStepUp(int index) {
    if (index <= 0 || index >= _state.draft.steps.length) return;
    final List<ScenarioStepEntity> steps =
        List<ScenarioStepEntity>.from(_state.draft.steps);
    final ScenarioStepEntity current = steps[index];
    steps[index] = steps[index - 1];
    steps[index - 1] = current;
    _setDraftSteps(steps);
  }

  void moveStepDown(int index) {
    if (index < 0 || index >= _state.draft.steps.length - 1) return;
    final List<ScenarioStepEntity> steps =
        List<ScenarioStepEntity>.from(_state.draft.steps);
    final ScenarioStepEntity current = steps[index];
    steps[index] = steps[index + 1];
    steps[index + 1] = current;
    _setDraftSteps(steps);
  }

  void addSuggestedStep(ScenarioStepEntity step) {
    final bool alreadyAdded = _state.draft.steps.any(
      (ScenarioStepEntity current) => current.category == step.category,
    );
    if (alreadyAdded) return;
    _setDraftSteps(<ScenarioStepEntity>[..._state.draft.steps, step]);
  }

  void optimizeRoute() {
    _setDraftSteps(optimizedScenarioStepsFor(_state.draft));
  }

  void _updateDraft(
    ScenarioDraftEntity next, {
    bool regenerateSteps = true,
  }) {
    final List<ScenarioStepEntity> steps = regenerateSteps
        ? scenarioStepsFor(
            mood: next.mood,
            maxDurationMinutes: next.maxDurationMinutes,
            freeOnly: next.freeOnly,
            walkingOnly: next.walkingOnly,
          )
        : next.steps;
    _state = _state.copyWith(draft: next.copyWith(steps: steps));
    notifyListeners();
  }

  void _setDraftSteps(List<ScenarioStepEntity> steps) {
    _state = _state.copyWith(
      draft: _state.draft.copyWith(steps: steps),
    );
    notifyListeners();
  }
}
