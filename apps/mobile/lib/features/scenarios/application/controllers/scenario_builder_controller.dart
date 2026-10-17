import 'package:flutter/foundation.dart';

import '../../../../core/id/id_generator.dart';
import '../../domain/entities/scenario_draft_entity.dart';
import '../../domain/repositories/quick_plan_repository.dart';
import '../state/scenario_builder_state.dart';

class ScenarioBuilderController extends ChangeNotifier {
  ScenarioBuilderController({
    IdGenerator? idGenerator,
    QuickPlanRepository? repository,
  }) : _repository = repository {
    _idGenerator = idGenerator ?? UuidV4IdGenerator();
    _state = ScenarioBuilderState.initial(
      draftId: _idGenerator.generate(),
      generateId: _idGenerator.generate,
    );
  }

  late final IdGenerator _idGenerator;
  final QuickPlanRepository? _repository;
  int _serverRevision = 0;
  bool _dirty = false;
  String? _pendingSaveId;
  int? _pendingSaveRevision;
  bool _syncBusy = false;
  Object? syncError;
  bool get syncBusy => _syncBusy;
  bool get persistenceEnabled => _repository != null;
  List<Map<String, Object?>> get syncConflicts =>
      _repository?.conflicts ?? const [];

  void clearOwner() {
    _repository?.clearVisible();
    reset();
  }

  Future<void> openStoredPlan(String id) async {
    final repository = _repository;
    if (repository == null || _syncBusy) return;
    try {
      await repository.restore();
      final local = repository.cached(id);
      _state = _state.copyWith(draft: local ?? _state.draft.copyWith(id: id));
      _serverRevision = repository.serverRevision(id) ?? 0;
      _dirty = repository.hasPending(id);
      notifyListeners();
      await sync();
    } on Object catch (error) {
      syncError = error;
      notifyListeners();
    }
  }

  /// Explicit save/refresh: a refresh also replays durable pending commands.
  Future<void> sync({bool save = false}) async {
    final repository = _repository;
    if (repository == null || _syncBusy) return;
    _syncBusy = true;
    syncError = null;
    notifyListeners();
    final draft = _state.draft;
    try {
      if (save) {
        _pendingSaveId = draft.id;
        _pendingSaveRevision = draft.revision;
        await repository.save(draft, expectedRevision: _serverRevision);
      }
      await repository.refresh(draft.id);
      final current = repository.cached(draft.id);
      // Keep unsaved edits made while the request was in flight.
      if (current != null &&
          (save ||
              !_dirty ||
              (_pendingSaveId == draft.id &&
                  _pendingSaveRevision == draft.revision)) &&
          _state.draft.id == draft.id &&
          _state.draft.revision == draft.revision) {
        _serverRevision = repository.serverRevision(draft.id) ?? 0;
        _state = _state.copyWith(draft: current);
        _dirty = false;
        _pendingSaveId = null;
        _pendingSaveRevision = null;
      }
    } on Object catch (error) {
      syncError = error;
      if (!repository.hasPending(draft.id)) {
        _pendingSaveId = null;
        _pendingSaveRevision = null;
      }
    } finally {
      _syncBusy = false;
      notifyListeners();
    }
  }

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
    _serverRevision = 0;
    _dirty = false;
    _pendingSaveId = null;
    _pendingSaveRevision = null;
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
    _setDraftSteps(<ScenarioStepEntity>[
      ..._state.draft.steps,
      step.copyWith(id: _idGenerator.generate()),
    ]);
  }

  void optimizeRoute() {
    _setDraftSteps(optimizedScenarioStepsFor(_state.draft));
  }

  void _updateDraft(ScenarioDraftEntity next, {bool regenerateSteps = true}) {
    _dirty = true;
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
    _dirty = true;
    _state = _state.copyWith(
      draft: _state.draft.copyWith(
        revision: _state.draft.revision + 1,
        steps: steps,
      ),
    );
    notifyListeners();
  }
}
