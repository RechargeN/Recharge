import '../../../features/create/domain/entities/scenario_item_draft.dart';
import '../../../features/create/domain/entities/scenario_object_intake.dart';
import '../../../features/create/domain/repositories/create_draft_collection_repository.dart';
import '../../../features/create/domain/repositories/scenario_copy_source_repository.dart';

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
    required this.copySources,
    required this.days,
    required this.anchors,
    required this.orderedRefs,
    required this.role,
    required this.confirmUnavailable,
    required this.confirmScheduleAdjustment,
    this.selectedTargetId,
    this.selectedCopySourceId,
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
        copySources: const <ScenarioCopySourceSummary>[],
        days: const <ScenarioIntakeDayOption>[],
        anchors: const <ScenarioIntakeAnchorOption>[],
        orderedRefs: const <ScenarioObjectRef>[],
        role: ScenarioItemRole.mandatory,
        confirmUnavailable: false,
        confirmScheduleAdjustment: false,
      );

  final ScenarioObjectIntakeStage stage;
  final String intentId;
  final List<CreateDraftSummary> targets;
  final List<ScenarioCopySourceSummary> copySources;
  final String? selectedTargetId;
  final String? selectedCopySourceId;
  final String? selectedTargetTitle;
  final List<ScenarioIntakeDayOption> days;
  final List<ScenarioIntakeAnchorOption> anchors;
  final String? selectedDayId;
  final String? afterItemId;
  final List<ScenarioObjectRef> orderedRefs;
  final ScenarioItemRole role;
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
    List<ScenarioCopySourceSummary>? copySources,
    String? selectedTargetId,
    bool clearSelectedTargetId = false,
    String? selectedCopySourceId,
    bool clearSelectedCopySourceId = false,
    String? selectedTargetTitle,
    bool clearSelectedTargetTitle = false,
    List<ScenarioIntakeDayOption>? days,
    List<ScenarioIntakeAnchorOption>? anchors,
    String? selectedDayId,
    bool clearSelectedDayId = false,
    String? afterItemId,
    bool clearAfterItemId = false,
    List<ScenarioObjectRef>? orderedRefs,
    ScenarioItemRole? role,
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
    copySources: copySources ?? this.copySources,
    selectedTargetId: clearSelectedTargetId
        ? null
        : (selectedTargetId ?? this.selectedTargetId),
    selectedCopySourceId: clearSelectedCopySourceId
        ? null
        : (selectedCopySourceId ?? this.selectedCopySourceId),
    selectedTargetTitle: clearSelectedTargetTitle
        ? null
        : (selectedTargetTitle ?? this.selectedTargetTitle),
    days: days ?? this.days,
    anchors: anchors ?? this.anchors,
    selectedDayId: clearSelectedDayId
        ? null
        : (selectedDayId ?? this.selectedDayId),
    afterItemId: clearAfterItemId ? null : (afterItemId ?? this.afterItemId),
    orderedRefs: orderedRefs ?? this.orderedRefs,
    role: role ?? this.role,
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
