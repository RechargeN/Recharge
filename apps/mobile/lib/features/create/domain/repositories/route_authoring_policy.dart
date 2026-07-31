enum RouteAuthoringOperation {
  editGeometry,
  useRouting,
  generateRoute,
  importGpx,
  recordGps,
  resolveElevation,
  submitForReview,
  publishDirect,
  moderate,
  createRevision,
  verifyQuality,
  reviewMapCandidate,
  moderateSafety,
  restoreRoute,
  rollbackRoute,
  archive,
}

class RouteAuthorizationRequest {
  const RouteAuthorizationRequest({
    required this.actorId,
    required this.draftId,
    required this.operation,
    required this.capabilities,
    this.publisherId,
    this.publisherType = 'user',
  });

  final String actorId;
  final String draftId;
  final String? publisherId;
  final String publisherType;
  final RouteAuthoringOperation operation;
  final Set<String> capabilities;
}

class RouteAuthorizationDecision {
  const RouteAuthorizationDecision._({required this.allowed, this.reasonCode});

  const RouteAuthorizationDecision.allowed() : this._(allowed: true);

  const RouteAuthorizationDecision.denied(String reasonCode)
    : this._(allowed: false, reasonCode: reasonCode);

  final bool allowed;
  final String? reasonCode;
}

abstract interface class RouteAuthoringPolicy {
  Future<RouteAuthorizationDecision> authorize(
    RouteAuthorizationRequest request,
  );
}
