import '../../domain/entities/create_draft_entity.dart';
import '../../domain/entities/route_draft_data.dart';
import '../../domain/entities/route_draft_save_result.dart';
import '../../domain/entities/route_validation_issue.dart';
import '../route_edit_command.dart';

enum RouteCreateStatus { ready, routing, importing, saving, saved, failed }

class RouteEditHistoryEntry {
  const RouteEditHistoryEntry({
    required this.command,
    required this.before,
    required this.after,
  });

  final RouteEditCommand command;
  final RouteDraftData before;
  final RouteDraftData after;

  RouteEditHistoryEntry copyWith({RouteDraftData? after}) =>
      RouteEditHistoryEntry(
        command: command,
        before: before,
        after: after ?? this.after,
      );
}

class RouteCreateState {
  RouteCreateState({
    required this.status,
    required this.createDraft,
    required this.persistedRevision,
    Iterable<RouteEditHistoryEntry> undoStack = const <RouteEditHistoryEntry>[],
    Iterable<RouteEditHistoryEntry> redoStack = const <RouteEditHistoryEntry>[],
    Iterable<RouteValidationIssue> issues = const <RouteValidationIssue>[],
    this.lastSaveStatus,
    this.lastFailureCode,
    this.ignoredStaleResponses = 0,
  }) : undoStack = List<RouteEditHistoryEntry>.unmodifiable(undoStack),
       redoStack = List<RouteEditHistoryEntry>.unmodifiable(redoStack),
       issues = List<RouteValidationIssue>.unmodifiable(issues);

  final RouteCreateStatus status;
  final CreateDraftEntity createDraft;
  final int persistedRevision;
  final List<RouteEditHistoryEntry> undoStack;
  final List<RouteEditHistoryEntry> redoStack;
  final List<RouteValidationIssue> issues;
  final RouteDraftSaveStatus? lastSaveStatus;
  final String? lastFailureCode;
  final int ignoredStaleResponses;

  RouteDraftData get route => createDraft.routeData!;

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;
  bool get hasPendingOperations => route.operations.any(
    (RouteAsyncOperationDraft operation) =>
        operation.status == RouteAsyncOperationStatus.pending,
  );

  RouteCreateState copyWith({
    RouteCreateStatus? status,
    CreateDraftEntity? createDraft,
    int? persistedRevision,
    Iterable<RouteEditHistoryEntry>? undoStack,
    Iterable<RouteEditHistoryEntry>? redoStack,
    Iterable<RouteValidationIssue>? issues,
    RouteDraftSaveStatus? lastSaveStatus,
    bool clearLastSaveStatus = false,
    String? lastFailureCode,
    bool clearLastFailureCode = false,
    int? ignoredStaleResponses,
  }) => RouteCreateState(
    status: status ?? this.status,
    createDraft: createDraft ?? this.createDraft,
    persistedRevision: persistedRevision ?? this.persistedRevision,
    undoStack: undoStack ?? this.undoStack,
    redoStack: redoStack ?? this.redoStack,
    issues: issues ?? this.issues,
    lastSaveStatus: clearLastSaveStatus
        ? null
        : (lastSaveStatus ?? this.lastSaveStatus),
    lastFailureCode: clearLastFailureCode
        ? null
        : (lastFailureCode ?? this.lastFailureCode),
    ignoredStaleResponses: ignoredStaleResponses ?? this.ignoredStaleResponses,
  );
}
