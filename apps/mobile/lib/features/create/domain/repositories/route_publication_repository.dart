import '../entities/route_publication_data.dart';

abstract interface class RoutePublicationRepository {
  Future<RoutePublishReceipt> submitForReview({
    required String requestId,
    required RoutePublicationBundle bundle,
  });

  Future<RoutePublishReceipt> publishDirect(RoutePublicationBundle bundle);

  Future<RoutePublishReceipt> decide(RouteModerationDecision decision);

  Future<List<RouteModerationRequest>> pendingRequests();

  Future<RouteModerationRequest?> requestById(String requestId);

  Future<RoutePublicationAggregate?> routeById(String routeId);

  Future<RoutePublicationAggregate?> routeByVersionId(String versionId);

  Future<RoutePublicationAggregate?> archive({
    required String routeId,
    required String actorId,
    required String attemptId,
    required DateTime archivedAtUtc,
  });

  Future<RoutePublicationAggregate?> setLifecycle({
    required String routeId,
    required RouteLifecycleStatus status,
    required String actorId,
    required String attemptId,
    required String reasonCode,
    required DateTime changedAtUtc,
  });
}
