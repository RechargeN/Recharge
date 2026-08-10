import '../../../features/create/domain/entities/scenario_item_draft.dart';
import '../../../features/create/domain/entities/scenario_object_intake.dart';
import '../../../features/create/domain/repositories/create_draft_collection_repository.dart';

enum ScenarioObjectIntakeStage {
  loading,
  target,
  placement,
  review,
  applying,
  success,
  error,
}

class ScenarioIntakeDayOption {
  const ScenarioIntakeDayOption({
    required this.id,
    required this.title,
    required this.itemCount,
    this.dateLabel,
  });

  final String id;
  final String title;
  final int itemCount;
  final String? dateLabel;
}

class ScenarioIntakeAnchorOption {
  const ScenarioIntakeAnchorOption({required this.id, required this.title});

  final String id;
  final String title;
}

class ScenarioObjectIntakeState {
  const ScenarioObjectIntakeState({
    required this.stage,
    required this.intentId,
    required this.targets,
    required this.days,
    required this.anchors,
    required this.orderedRefs,
    required this.role,
    required this.newTargetSelected,
    required this.newTargetTitle,
    required this.confirmDuplicate,
    required this.confirmUnavailable,
    required this.confirmScheduleAdjustment,
    this.selectedTargetId,
    this.selectedTargetTitle,
    this.selectedDayId,
    this.afterItemId,
    this.message,
    this.successTargetId,
    this.successTargetRevision,
    this.successItemCount = 0,
    this.replayed = false,
  });

  factory ScenarioObjectIntakeState.loading({required String intentId}) =>
      ScenarioObjectIntakeState(
        stage: ScenarioObjectIntakeStage.loading,
        intentId: intentId,
        targets: const <CreateDraftSummary>[],
        days: const <ScenarioIntakeDayOption>[],
        anchors: const <ScenarioIntakeAnchorOption>[],
        orderedRefs: const <ScenarioObjectRef>[],
        role: ScenarioItemRole.mandatory,
        newTargetSelected: false,
        newTargetTitle: '',
        confirmDuplicate: false,
        confirmUnavailable: false,
        confirmScheduleAdjustment: false,
      );

  final ScenarioObjectIntakeStage stage;
  final String intentId;
  final List<CreateDraftSummary> targets;
  final String? selectedTargetId;
  final String? selectedTargetTitle;
  final bool newTargetSelected;
  final String newTargetTitle;
  final List<ScenarioIntakeDayOption> days;
  final List<ScenarioIntakeAnchorOption> anchors;
  final String? selectedDayId;
  final String? afterItemId;
  final List<ScenarioObjectRef> orderedRefs;
  final ScenarioItemRole role;
  final bool confirmDuplicate;
  final bool confirmUnavailable;
  final bool confirmScheduleAdjustment;
  final String? message;
  final String? successTargetId;
  final int? successTargetRevision;
  final int successItemCount;
  final bool replayed;

  ScenarioObjectIntakeState copyWith({
    ScenarioObjectIntakeStage? stage,
    List<CreateDraftSummary>? targets,
    String? selectedTargetId,
    bool clearSelectedTargetId = false,
    String? selectedTargetTitle,
    bool clearSelectedTargetTitle = false,
    bool? newTargetSelected,
    String? newTargetTitle,
    List<ScenarioIntakeDayOption>? days,
    List<ScenarioIntakeAnchorOption>? anchors,
    String? selectedDayId,
    bool clearSelectedDayId = false,
    String? afterItemId,
    bool clearAfterItemId = false,
    List<ScenarioObjectRef>? orderedRefs,
    ScenarioItemRole? role,
    bool? confirmDuplicate,
    bool? confirmUnavailable,
    bool? confirmScheduleAdjustment,
    String? message,
    bool clearMessage = false,
    String? successTargetId,
    int? successTargetRevision,
    int? successItemCount,
    bool? replayed,
  }) => ScenarioObjectIntakeState(
    stage: stage ?? this.stage,
    intentId: intentId,
    targets: targets ?? this.targets,
    selectedTargetId: clearSelectedTargetId
        ? null
        : (selectedTargetId ?? this.selectedTargetId),
    selectedTargetTitle: clearSelectedTargetTitle
        ? null
        : (selectedTargetTitle ?? this.selectedTargetTitle),
    newTargetSelected: newTargetSelected ?? this.newTargetSelected,
    newTargetTitle: newTargetTitle ?? this.newTargetTitle,
    days: days ?? this.days,
    anchors: anchors ?? this.anchors,
    selectedDayId: clearSelectedDayId
        ? null
        : (selectedDayId ?? this.selectedDayId),
    afterItemId: clearAfterItemId ? null : (afterItemId ?? this.afterItemId),
    orderedRefs: orderedRefs ?? this.orderedRefs,
    role: role ?? this.role,
    confirmDuplicate: confirmDuplicate ?? this.confirmDuplicate,
    confirmUnavailable: confirmUnavailable ?? this.confirmUnavailable,
    confirmScheduleAdjustment:
        confirmScheduleAdjustment ?? this.confirmScheduleAdjustment,
    message: clearMessage ? null : (message ?? this.message),
    successTargetId: successTargetId ?? this.successTargetId,
    successTargetRevision: successTargetRevision ?? this.successTargetRevision,
    successItemCount: successItemCount ?? this.successItemCount,
    replayed: replayed ?? this.replayed,
  );
}
