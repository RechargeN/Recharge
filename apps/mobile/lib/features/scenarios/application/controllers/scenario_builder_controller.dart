import 'package:flutter/foundation.dart';

import '../../../../core/id/id_generator.dart';
import '../../domain/entities/scenario_draft_entity.dart';
import '../state/scenario_builder_state.dart';

class ScenarioBuilderController extends ChangeNotifier {
  ScenarioBuilderController({IdGenerator? idGenerator}) {
    _idGenerator = idGenerator ?? UuidV4IdGenerator();
    _state = ScenarioBuilderState.initial(
      draftId: _idGenerator.generate(),
      generateId: _idGenerator.generate,
    );
  }

  late final IdGenerator _idGenerator;
  late ScenarioBuilderState _state;
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
    final List<ScenarioStepEntity>? restoredSteps = stepCategories == null
        ? null
        : scenarioStepsByCategories(stepCategories);
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
    _state = ScenarioBuilderState.initial(
      draftId: _idGenerator.generate(),
      generateId: _idGenerator.generate,
    );
    notifyListeners();
  }

  void removeStepAt(int index) {
    if (index < 0 || index >= _state.draft.steps.length) return;
    final List<ScenarioStepEntity> steps = List<ScenarioStepEntity>.from(
      _state.draft.steps,
    )..removeAt(index);
    _setDraftSteps(steps);
  }

  void moveStepUp(int index) {
    if (index <= 0 || index >= _state.draft.steps.length) return;
    final List<ScenarioStepEntity> steps = List<ScenarioStepEntity>.from(
      _state.draft.steps,
    );
    final ScenarioStepEntity current = steps[index];
    steps[index] = steps[index - 1];
    steps[index - 1] = current;
    _setDraftSteps(steps);
  }

  void moveStepDown(int index) {
    if (index < 0 || index >= _state.draft.steps.length - 1) return;
    final List<ScenarioStepEntity> steps = List<ScenarioStepEntity>.from(
      _state.draft.steps,
    );
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
    _setDraftSteps(<ScenarioStepEntity>[
      ..._state.draft.steps,
      step.copyWith(id: _idGenerator.generate()),
    ]);
  }

  void optimizeRoute() {
    _setDraftSteps(optimizedScenarioStepsFor(_state.draft));
  }

  void _updateDraft(ScenarioDraftEntity next, {bool regenerateSteps = true}) {
    final List<ScenarioStepEntity> steps = regenerateSteps
        ? scenarioStepsFor(
            mood: next.mood,
            maxDurationMinutes: next.maxDurationMinutes,
            freeOnly: next.freeOnly,
            walkingOnly: next.walkingOnly,
          )
        : next.steps;
    _state = _state.copyWith(
      draft: next.copyWith(
        revision: _state.draft.revision + 1,
        steps: steps
            .map(
              (ScenarioStepEntity step) => step.id.isEmpty
                  ? step.copyWith(id: _idGenerator.generate())
                  : step,
            )
            .toList(growable: false),
      ),
    );
    notifyListeners();
  }

  void _setDraftSteps(List<ScenarioStepEntity> steps) {
    _state = _state.copyWith(
      draft: _state.draft.copyWith(
        revision: _state.draft.revision + 1,
        steps: steps,
      ),
    );
    notifyListeners();
  }
}
