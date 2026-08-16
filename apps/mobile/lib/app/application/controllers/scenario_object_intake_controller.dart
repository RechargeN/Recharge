import 'package:flutter/foundation.dart';

import '../../../features/create/domain/entities/create_draft_entity.dart';
import '../../../features/create/domain/entities/scenario_draft_data.dart';
import '../../../features/create/domain/entities/scenario_item_draft.dart';
import '../../../features/create/domain/entities/scenario_object_intake.dart';
import '../../application/scenario_object_intake_facade.dart';
import '../../application/scenario_object_intake_telemetry.dart';
import '../state/scenario_object_intake_state.dart';

class ScenarioObjectIntakeController extends ChangeNotifier {
  ScenarioObjectIntakeController({
    required ScenarioObjectIntakeIntent intent,
    required ScenarioObjectIntakeFacade facade,
    required String organizerEmail,
    required String organizerName,
    ScenarioObjectIntakeTelemetry telemetry =
        const ScenarioObjectIntakeTelemetry.disabled(),
  }) : _intent = intent,
       _facade = facade,
       _organizerEmail = organizerEmail,
       _organizerName = organizerName,
       _telemetry = telemetry,
       _state = ScenarioObjectIntakeState.loading(intentId: intent.intentId);

  final ScenarioObjectIntakeIntent _intent;
  final ScenarioObjectIntakeFacade _facade;
  final String _organizerEmail;
  final String _organizerName;
  final ScenarioObjectIntakeTelemetry _telemetry;
  CreateDraftEntity? _targetDraft;

  ScenarioObjectIntakeState _state;
  ScenarioObjectIntakeState get state => _state;
  List<ScenarioIntakeCandidate> get candidates => _intent.candidates;
  bool get canCreateNewTarget => _facade.config.createNewTargetEnabled;

  bool get duplicateConfirmationRequired {
    final target = _targetDraft?.scenarioData;
    if (target == null) return false;
    return _state.orderedRefs.any(
      (ref) => target.items.any((item) {
        final source = item.source;
        return source is ScenarioCatalogObjectSourceDraft &&
            source.objectId == ref.objectId &&
            source.objectType == ref.objectType;
      }),
    );
  }

  bool get unavailableConfirmationRequired => _intent.candidates.any(
    (candidate) => candidate.sourceStatus == ScenarioSourceStatus.unavailable,
  );

  bool get scheduleAdjustmentConfirmationRequired {
    final target = _targetDraft?.scenarioData;
    if (target == null) return false;
    return _intent.candidates.any((candidate) {
      final planned = candidate.schedule?.planned;
      if (planned == null) return false;
      return switch (target.dateMode) {
        ScenarioDateMode.template =>
          planned is! ScenarioTemplatePlannedTimeDraft,
        ScenarioDateMode.dated => planned is! ScenarioDatedPlannedTimeDraft,
      };
    });
  }

  Future<void> initialize() async {
    try {
      final targets = await _facade.begin(_intent);
      _state = _state.copyWith(
        stage: ScenarioObjectIntakeStage.target,
        targets: targets,
        orderedRefs: _intent.candidates
            .map((candidate) => candidate.ref)
            .toList(growable: false),
        clearMessage: true,
      );
    } on Object {
      _state = _state.copyWith(
        stage: ScenarioObjectIntakeStage.error,
        message: 'Scenario targets are unavailable. Retry from Details.',
      );
    }
    notifyListeners();
  }

  void selectTarget(String targetId) {
    final summary = _state.targets.where((value) => value.id == targetId);
    if (summary.length != 1) return;
    _targetDraft = null;
    _state = _state.copyWith(
      selectedTargetId: targetId,
      selectedTargetTitle: summary.single.title,
      newTargetSelected: false,
      clearMessage: true,
    );
    notifyListeners();
  }

  void selectNewTarget() {
    if (!canCreateNewTarget) return;
    _targetDraft = null;
    final suggested = '${_intent.candidates.first.snapshot.title} plan';
    _state = _state.copyWith(
      clearSelectedTargetId: true,
      clearSelectedTargetTitle: true,
      newTargetSelected: true,
      newTargetTitle: _state.newTargetTitle.trim().isEmpty
          ? suggested
          : _state.newTargetTitle,
      clearMessage: true,
    );
    notifyListeners();
  }

  void updateNewTargetTitle(String value) {
    _state = _state.copyWith(newTargetTitle: value, clearMessage: true);
    notifyListeners();
  }

  Future<void> continueFromTarget() async {
    if (!_state.newTargetSelected && _state.selectedTargetId == null) {
      _message('Choose a Scenario or create a new one.');
      return;
    }
    _state = _state.copyWith(
      stage: ScenarioObjectIntakeStage.loading,
      clearMessage: true,
    );
    notifyListeners();
    try {
      if (_state.newTargetSelected) {
        _targetDraft = _facade.materializeNewTarget(
          intent: _intent,
          organizerEmail: _organizerEmail,
          organizerName: _organizerName,
          title: _state.newTargetTitle,
        );
      } else {
        _targetDraft = await _facade.loadTarget(
          ownerId: _intent.requesterId,
          targetDraftId: _state.selectedTargetId!,
        );
      }
      final target = _targetDraft;
      if (target == null ||
          target.objectType != CreateObjectType.scenario ||
          target.organizerId != _intent.requesterId ||
          target.scenarioData == null) {
        _targetDraft = null;
        _state = _state.copyWith(
          stage: ScenarioObjectIntakeStage.target,
          message: 'This Scenario is no longer editable.',
        );
      } else {
        _preparePlacement(target);
      }
    } on FormatException {
      _state = _state.copyWith(
        stage: ScenarioObjectIntakeStage.target,
        message: 'Enter a Scenario title.',
      );
    } on Object {
      _state = _state.copyWith(
        stage: ScenarioObjectIntakeStage.target,
        message: 'Could not open this Scenario.',
      );
    }
    notifyListeners();
  }

  void setDay(String? dayId) {
    final target = _targetDraft?.scenarioData;
    if (target == null ||
        (dayId != null && !target.days.any((day) => day.id == dayId))) {
      return;
    }
    _state = _state.copyWith(
      selectedDayId: dayId,
      clearSelectedDayId: dayId == null,
      clearAfterItemId: true,
      anchors: _anchors(target, dayId),
      clearMessage: true,
    );
    notifyListeners();
  }

  void setAfterItem(String? itemId) {
    if (itemId != null && !_state.anchors.any((value) => value.id == itemId)) {
      return;
    }
    _state = _state.copyWith(
      afterItemId: itemId,
      clearAfterItemId: itemId == null,
      clearMessage: true,
    );
    notifyListeners();
  }

  void setRole(ScenarioItemRole role) {
    if (role == ScenarioItemRole.alternative) return;
    _state = _state.copyWith(role: role, clearMessage: true);
    notifyListeners();
  }

  void moveCandidate(int index, int delta) {
    final targetIndex = index + delta;
    if (index < 0 ||
        index >= _state.orderedRefs.length ||
        targetIndex < 0 ||
        targetIndex >= _state.orderedRefs.length) {
      return;
    }
    final refs = <ScenarioObjectRef>[..._state.orderedRefs];
    refs.insert(targetIndex, refs.removeAt(index));
    _state = _state.copyWith(orderedRefs: refs);
    notifyListeners();
  }

  void continueToReview() {
    if (_targetDraft == null) return;
    _state = _state.copyWith(
      stage: ScenarioObjectIntakeStage.review,
      clearMessage: true,
      selectedTargetTitle: _targetDraft!.title,
    );
    _telemetry.track(
      intent: _intent,
      action: ScenarioObjectIntakeTelemetryAction.preview,
      result: ScenarioObjectIntakeTelemetryResult.success,
      targetKind: _targetKind,
      placement: _placementKind,
    );
    notifyListeners();
  }

  void confirmDuplicate(bool value) {
    _state = _state.copyWith(confirmDuplicate: value, clearMessage: true);
    notifyListeners();
  }

  void confirmUnavailable(bool value) {
    _state = _state.copyWith(confirmUnavailable: value, clearMessage: true);
    notifyListeners();
  }

  void confirmScheduleAdjustment(bool value) {
    _state = _state.copyWith(
      confirmScheduleAdjustment: value,
      clearMessage: true,
    );
    notifyListeners();
  }

  Future<void> apply({required bool authenticated}) async {
    final target = _targetDraft;
    if (target == null) return;
    if (!authenticated) {
      _trackApply(ScenarioObjectIntakeTelemetryResult.authRequired);
      _message('Sign in again before adding items to Scenario.');
      return;
    }
    if (duplicateConfirmationRequired && !_state.confirmDuplicate) {
      _message('Confirm adding another occurrence.');
      return;
    }
    if (unavailableConfirmationRequired && !_state.confirmUnavailable) {
      _message('Confirm use of the unavailable saved snapshot.');
      return;
    }
    if (scheduleAdjustmentConfirmationRequired &&
        !_state.confirmScheduleAdjustment) {
      _message('Confirm conversion to a flexible template stop.');
      return;
    }
    _state = _state.copyWith(
      stage: ScenarioObjectIntakeStage.applying,
      clearMessage: true,
    );
    notifyListeners();
    final outcome = await _facade.apply(
      ownerId: _intent.requesterId,
      intentId: _intent.intentId,
      targetDraft: target,
      dayId: _state.selectedDayId,
      afterItemId: _state.afterItemId,
      orderedRefs: _state.orderedRefs,
      roles: <ScenarioObjectRef, ScenarioItemRole>{
        for (final ref in _state.orderedRefs) ref: _state.role,
      },
      confirmedDuplicates: _state.confirmDuplicate
          ? _state.orderedRefs.toSet()
          : const <ScenarioObjectRef>{},
      confirmedUnavailable: _state.confirmUnavailable
          ? _state.orderedRefs.toSet()
          : const <ScenarioObjectRef>{},
      confirmedScheduleAdjustments: _state.confirmScheduleAdjustment
          ? _state.orderedRefs.toSet()
          : const <ScenarioObjectRef>{},
    );
    if (outcome.succeeded) {
      _trackApply(ScenarioObjectIntakeTelemetryResult.success);
      _state = _state.copyWith(
        stage: ScenarioObjectIntakeStage.success,
        successTargetId: outcome.targetDraftId,
        successTargetRevision: outcome.targetRevision,
        successItemCount: outcome.createdItemCount == 0
            ? _state.orderedRefs.length
            : outcome.createdItemCount,
        replayed: outcome.replayed,
        clearMessage: true,
      );
    } else {
      _trackApply(
        outcome.status == ScenarioObjectIntakeApplyStatus.persistenceFailed
            ? ScenarioObjectIntakeTelemetryResult.persistenceFailed
            : ScenarioObjectIntakeTelemetryResult.rejected,
      );
      _state = _state.copyWith(
        stage: ScenarioObjectIntakeStage.review,
        message: _failureMessage(outcome.failure),
      );
    }
    notifyListeners();
  }

  void back() {
    if (_state.stage == ScenarioObjectIntakeStage.review) {
      _state = _state.copyWith(
        stage: ScenarioObjectIntakeStage.placement,
        clearMessage: true,
      );
      notifyListeners();
      return;
    }
    if (_state.stage == ScenarioObjectIntakeStage.placement) {
      _targetDraft = null;
      _state = _state.copyWith(
        stage: ScenarioObjectIntakeStage.target,
        days: const <ScenarioIntakeDayOption>[],
        anchors: const <ScenarioIntakeAnchorOption>[],
        clearSelectedDayId: true,
        clearAfterItemId: true,
        clearMessage: true,
      );
      notifyListeners();
    }
  }

  Future<void> discard() =>
      _facade.discard(ownerId: _intent.requesterId, intentId: _intent.intentId);

  Future<void> retry() {
    _telemetry.track(
      intent: _intent,
      action: ScenarioObjectIntakeTelemetryAction.retry,
      result: ScenarioObjectIntakeTelemetryResult.started,
    );
    return initialize();
  }

  void trackOpenTarget() {
    _telemetry.track(
      intent: _intent,
      action: ScenarioObjectIntakeTelemetryAction.openTarget,
      result: ScenarioObjectIntakeTelemetryResult.success,
      targetKind: _targetKind,
      placement: _placementKind,
    );
  }

  void _trackApply(ScenarioObjectIntakeTelemetryResult result) {
    _telemetry.track(
      intent: _intent,
      action: ScenarioObjectIntakeTelemetryAction.apply,
      result: result,
      targetKind: _targetKind,
      placement: _placementKind,
    );
  }

  ScenarioObjectIntakeTargetKind get _targetKind => _state.newTargetSelected
      ? ScenarioObjectIntakeTargetKind.newTarget
      : ScenarioObjectIntakeTargetKind.existing;

  ScenarioObjectIntakePlacementKind get _placementKind =>
      _state.selectedDayId == null
      ? ScenarioObjectIntakePlacementKind.unscheduled
      : ScenarioObjectIntakePlacementKind.day;

  void _preparePlacement(CreateDraftEntity target) {
    final scenario = target.scenarioData!;
    final days = scenario.days
        .map(
          (day) => ScenarioIntakeDayOption(
            id: day.id,
            title: day.title,
            itemCount: day.itemIds.length,
            dateLabel: day.localDate?.iso8601,
          ),
        )
        .toList(growable: false);
    final selectedDayId = days.isEmpty ? null : days.first.id;
    _state = _state.copyWith(
      stage: ScenarioObjectIntakeStage.placement,
      selectedTargetId: target.id,
      selectedTargetTitle: target.title,
      days: days,
      anchors: _anchors(scenario, selectedDayId),
      selectedDayId: selectedDayId,
      clearSelectedDayId: selectedDayId == null,
      clearAfterItemId: true,
      confirmDuplicate: false,
      confirmUnavailable: false,
      confirmScheduleAdjustment: false,
      clearMessage: true,
    );
  }

  List<ScenarioIntakeAnchorOption> _anchors(
    ScenarioDraftData scenario,
    String? dayId,
  ) {
    if (dayId == null) return const <ScenarioIntakeAnchorOption>[];
    final day = scenario.days.where((value) => value.id == dayId);
    if (day.length != 1) return const <ScenarioIntakeAnchorOption>[];
    final byId = <String, ScenarioItemDraft>{
      for (final item in scenario.items) item.id: item,
    };
    return day.single.itemIds
        .where(byId.containsKey)
        .map(
          (id) =>
              ScenarioIntakeAnchorOption(id: id, title: _itemTitle(byId[id]!)),
        )
        .toList(growable: false);
  }

  String _itemTitle(ScenarioItemDraft item) {
    final source = item.source;
    if (source is ScenarioCatalogObjectSourceDraft) {
      return source.snapshot.title;
    }
    if (source is ScenarioTimeBlockSourceDraft) return source.title;
    return item.kind.name;
  }

  void _message(String value) {
    _state = _state.copyWith(message: value);
    notifyListeners();
  }

  String _failureMessage(ScenarioIntakeFailure? failure) => switch (failure) {
    ScenarioIntakeFailure.revisionConflict =>
      'Scenario changed. Go back, reopen it and review again.',
    ScenarioIntakeFailure.intentExpired =>
      'This selection expired. Return to Details and try again.',
    ScenarioIntakeFailure.targetUnavailable ||
    ScenarioIntakeFailure.targetNotFound =>
      'This Scenario is no longer available. Choose another one.',
    ScenarioIntakeFailure.duplicateConfirmationRequired =>
      'Confirm adding another occurrence.',
    ScenarioIntakeFailure.scheduleConfirmationRequired =>
      'Confirm conversion to a flexible template stop.',
    ScenarioIntakeFailure.lockedLegBoundary =>
      'A locked logistics leg protects this insertion point.',
    ScenarioIntakeFailure.persistenceUnavailable =>
      'Could not save. Your selection is retained; retry Apply.',
    _ => 'Could not add this object. Review the selection and retry.',
  };
}
