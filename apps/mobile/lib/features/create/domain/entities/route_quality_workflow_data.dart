import 'create_draft_entity.dart';
import 'route_draft_data.dart';

enum RouteCandidateDecision { pending, accepted, rejected, deferred }

enum RouteSafetySeverity { information, warning, high, critical }

enum RouteSafetyReportState { open, resolved, dismissed }

class RouteGeometryDiff {
  const RouteGeometryDiff({
    required this.baseGeometryHash,
    required this.candidateGeometryHash,
    required this.basePointCount,
    required this.candidatePointCount,
    required this.distanceDeltaMeters,
    required this.anchorCountDelta,
    required this.waypointCountDelta,
  });

  final String baseGeometryHash;
  final String candidateGeometryHash;
  final int basePointCount;
  final int candidatePointCount;
  final double distanceDeltaMeters;
  final int anchorCountDelta;
  final int waypointCountDelta;

  bool get geometryChanged => baseGeometryHash != candidateGeometryHash;

  bool get isValid =>
      baseGeometryHash.trim().isNotEmpty &&
      candidateGeometryHash.trim().isNotEmpty &&
      basePointCount >= 2 &&
      candidatePointCount >= 2 &&
      distanceDeltaMeters.isFinite;
}

class RouteMapSnapshotCandidate {
  const RouteMapSnapshotCandidate({
    required this.id,
    required this.routeId,
    required this.baseVersionId,
    required this.sourceSnapshotId,
    required this.sourceAttribution,
    required this.candidateDraft,
    required this.diff,
    required this.decision,
    required this.createdAtUtc,
    this.decidedAtUtc,
    this.decidedBy,
    this.reasonCode,
  });

  final String id;
  final String routeId;
  final String baseVersionId;
  final String sourceSnapshotId;
  final String sourceAttribution;
  final RouteDraftData candidateDraft;
  final RouteGeometryDiff diff;
  final RouteCandidateDecision decision;
  final DateTime createdAtUtc;
  final DateTime? decidedAtUtc;
  final String? decidedBy;
  final String? reasonCode;

  bool get isValid =>
      id.trim().isNotEmpty &&
      routeId.trim().isNotEmpty &&
      baseVersionId.trim().isNotEmpty &&
      sourceSnapshotId.trim().isNotEmpty &&
      sourceAttribution.trim().isNotEmpty &&
      diff.isValid &&
      createdAtUtc.isUtc &&
      (decidedAtUtc == null || decidedAtUtc!.isUtc);

  RouteMapSnapshotCandidate copyWith({
    RouteCandidateDecision? decision,
    DateTime? decidedAtUtc,
    String? decidedBy,
    String? reasonCode,
  }) => RouteMapSnapshotCandidate(
    id: id,
    routeId: routeId,
    baseVersionId: baseVersionId,
    sourceSnapshotId: sourceSnapshotId,
    sourceAttribution: sourceAttribution,
    candidateDraft: candidateDraft,
    diff: diff,
    decision: decision ?? this.decision,
    createdAtUtc: createdAtUtc,
    decidedAtUtc: decidedAtUtc ?? this.decidedAtUtc,
    decidedBy: decidedBy ?? this.decidedBy,
    reasonCode: reasonCode ?? this.reasonCode,
  );
}

class RouteSafetyReport {
  const RouteSafetyReport({
    required this.id,
    required this.routeId,
    required this.versionId,
    required this.reporterId,
    required this.reasonCode,
    required this.severity,
    required this.state,
    required this.createdAtUtc,
    this.safeNote,
    this.decidedAtUtc,
    this.decidedBy,
    this.decisionReasonCode,
  });

  final String id;
  final String routeId;
  final String versionId;
  final String reporterId;
  final String reasonCode;
  final RouteSafetySeverity severity;
  final RouteSafetyReportState state;
  final DateTime createdAtUtc;
  final String? safeNote;
  final DateTime? decidedAtUtc;
  final String? decidedBy;
  final String? decisionReasonCode;

  bool get isValid =>
      id.trim().isNotEmpty &&
      routeId.trim().isNotEmpty &&
      versionId.trim().isNotEmpty &&
      reporterId.trim().isNotEmpty &&
      reasonCode.trim().isNotEmpty &&
      createdAtUtc.isUtc &&
      (safeNote?.length ?? 0) <= 1000 &&
      (decidedAtUtc == null || decidedAtUtc!.isUtc);

  RouteSafetyReport copyWith({
    RouteSafetyReportState? state,
    DateTime? decidedAtUtc,
    String? decidedBy,
    String? decisionReasonCode,
  }) => RouteSafetyReport(
    id: id,
    routeId: routeId,
    versionId: versionId,
    reporterId: reporterId,
    reasonCode: reasonCode,
    severity: severity,
    state: state ?? this.state,
    createdAtUtc: createdAtUtc,
    safeNote: safeNote,
    decidedAtUtc: decidedAtUtc ?? this.decidedAtUtc,
    decidedBy: decidedBy ?? this.decidedBy,
    decisionReasonCode: decisionReasonCode ?? this.decisionReasonCode,
  );
}

class RouteCandidateDecisionResult {
  const RouteCandidateDecisionResult({
    required this.candidate,
    this.revisionDraft,
  });

  final RouteMapSnapshotCandidate candidate;
  final CreateDraftEntity? revisionDraft;
}
