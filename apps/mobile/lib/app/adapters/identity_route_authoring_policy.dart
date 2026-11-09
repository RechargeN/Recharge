import '../../features/create/domain/repositories/route_authoring_policy.dart';
import '../../features/create/data/policies/demo_route_authoring_policy.dart';
import '../../features/identity/domain/repositories/identity_workspace_repository.dart';

/// App composition of the existing Route policy with fresh local Identity.
class IdentityRouteAuthoringPolicy implements RouteAuthoringPolicy {
  const IdentityRouteAuthoringPolicy(this.repository);
  final IdentityWorkspaceRepository repository;
  @override
  Future<RouteAuthorizationDecision> authorize(
    RouteAuthorizationRequest request,
  ) async {
    try {
      final access = await repository.loadAccessSnapshot(request.actorId);
      if (!access.belongsTo(request.actorId)) {
        return const RouteAuthorizationDecision.denied('actor_mismatch');
      }
      final admin = {
        RouteAuthoringOperation.moderate,
        RouteAuthoringOperation.reviewMapCandidate,
        RouteAuthoringOperation.moderateSafety,
        RouteAuthoringOperation.restoreRoute,
      }.contains(request.operation);
      if (admin ? !access.canUseAdminTools : !access.isVerifiedCreator) {
        return const RouteAuthorizationDecision.denied(
          'identity_access_denied',
        );
      }
      return const DemoRouteAuthoringPolicy().authorize(
        RouteAuthorizationRequest(
          actorId: request.actorId,
          draftId: request.draftId,
          operation: request.operation,
          publisherId: request.publisherId,
          publisherType: request.publisherType,
          capabilities: access.globalCapabilities,
        ),
      );
    } on Object {
      return const RouteAuthorizationDecision.denied(
        'identity_access_unavailable',
      );
    }
  }
}
