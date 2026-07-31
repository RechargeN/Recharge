import '../../domain/repositories/route_authoring_policy.dart';

class DemoRouteAuthoringPolicy implements RouteAuthoringPolicy {
  const DemoRouteAuthoringPolicy();

  @override
  Future<RouteAuthorizationDecision> authorize(
    RouteAuthorizationRequest request,
  ) async {
    if (request.actorId.trim().isEmpty || request.draftId.trim().isEmpty) {
      return const RouteAuthorizationDecision.denied('invalid_actor_or_draft');
    }
    if (request.publisherType != 'user') {
      return const RouteAuthorizationDecision.denied(
        'page_publisher_not_enabled',
      );
    }
    if (request.publisherId != null && request.publisherId != request.actorId) {
      return const RouteAuthorizationDecision.denied('publisher_not_owned');
    }
    final capability = switch (request.operation) {
      RouteAuthoringOperation.editGeometry ||
      RouteAuthoringOperation.useRouting ||
      RouteAuthoringOperation.generateRoute ||
      RouteAuthoringOperation.importGpx ||
      RouteAuthoringOperation.recordGps ||
      RouteAuthoringOperation.resolveElevation => 'create.route',
      RouteAuthoringOperation.submitForReview => 'submit.route',
      RouteAuthoringOperation.publishDirect => 'publish.route.direct',
      RouteAuthoringOperation.moderate => 'moderate.route',
      RouteAuthoringOperation.createRevision ||
      RouteAuthoringOperation.verifyQuality ||
      RouteAuthoringOperation.reviewMapCandidate ||
      RouteAuthoringOperation.rollbackRoute => 'manage.route',
      RouteAuthoringOperation.moderateSafety ||
      RouteAuthoringOperation.restoreRoute => 'moderate.route',
      RouteAuthoringOperation.archive => 'archive.route',
    };
    if (!request.capabilities.contains(capability)) {
      return RouteAuthorizationDecision.denied(
        'missing_capability:$capability',
      );
    }
    return const RouteAuthorizationDecision.allowed();
  }
}
