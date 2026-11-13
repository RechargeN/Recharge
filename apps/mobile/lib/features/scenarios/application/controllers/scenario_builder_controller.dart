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
  List<QuickPlanInvitation> invitations = const [];
  QuickPlanInvitation? selectedInvitation;
  ScenarioDraftEntity? _invitedPlan;
  String? _invitedActor;
  int _accessEpoch = 0;
  bool get invitedMode => selectedInvitation != null;
  ScenarioDraftEntity? get invitedPlan =>
      _invitedActor == _repository?.actorId ? _invitedPlan : null;
  bool ownsInvitation(QuickPlanInvitation g) =>
      g.ownerId == _repository?.actorId;

  Future<void> loadInvitations() async {
    try {
      syncError = null;
      invitations = await _repository!.invitations();
    } on Object catch (e) {
      invitations = const [];
      syncError = e;
    }
    notifyListeners();
  }

  Future<void> inviteUser(
    String userId, {
    QuickPlanInvitation? previous,
  }) async {
    try {
      if (invitedMode) return;
      await _repository!.invite(
        previous?.planId ?? _state.draft.id,
        userId,
        previous: previous,
      );
    } on Object catch (e) {
      syncError = e;
      notifyListeners();
      return;
    }
    await loadInvitations();
  }

  Future<void> actOnInvitation(String action, QuickPlanInvitation g) async {
    hideInvitedContent();
    try {
      await _repository!.invitationAction(action, g);
    } on Object catch (e) {
      syncError = e;
      notifyListeners();
      return;
    }
    if (action == 'leave') selectedInvitation = null;
    await loadInvitations();
  }

  void hideInvitedContent() {
    _accessEpoch++;
    _invitedPlan = null;
    _invitedActor = null;
    notifyListeners();
  }

  Future<void> openInvited(QuickPlanInvitation g) async {
    selectedInvitation = g;
    hideInvitedContent();
    final epoch = _accessEpoch;
    final actor = _repository?.actorId;
    try {
      final plan = await _repository!.readInvited(g);
      if (selectedInvitation != g ||
          actor != _repository.actorId ||
          epoch != _accessEpoch) {
        return;
      }
      _invitedPlan = plan;
      _invitedActor = actor;
      syncError = null;
    } on Object catch (e) {
      syncError = e;
    }
    notifyListeners();
  }

  /// Widget disposal must invalidate late responses without notifying a dying tree.
  void clearInvitedOnExit() {
    _accessEpoch++;
    selectedInvitation = null;
    _invitedPlan = null;
    _invitedActor = null;
  }

  void closeInvited() {
    selectedInvitation = null;
    hideInvitedContent();
  }

  Future<void> importPlan(String source) async {
    if (invitedMode) return;
    try {
      await _repository!.importJson(source);
      syncError = null;
    } on Object catch (e) {
      syncError = e;
    }
    notifyListeners();
  }

  Future<void> deletePlan() async {
    if (invitedMode) return;
    try {
      await _repository!.delete(
        _state.draft.id,
        expectedRevision: _serverRevision,
      );
      syncError = null;
      reset();
    } on Object catch (e) {
      syncError = e;
      notifyListeners();
    }
  }

  List<Map<String, Object?>> get syncConflicts =>
      _repository?.conflicts ?? const [];

  void clearOwner() {
    closeInvited();
    invitations = const [];
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
    if (invitedMode) {
      if (!save) await openInvited(selectedInvitation!);
      return;
    }
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
    if (invitedMode) return;
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
    if (invitedMode) return;
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
