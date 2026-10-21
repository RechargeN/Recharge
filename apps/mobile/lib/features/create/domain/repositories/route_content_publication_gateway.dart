import '../entities/create_draft_entity.dart';
import '../entities/route_content_publication.dart';

/// J2 / RTE-PUB-01 Route owner command `distribute`. Every decision is the
/// server's: owner authority, the trimmed-geometry allowlist and the recorded
/// GPS trim rule. Failures are `EventPublicationRejected` /
/// `EventPublicationUnavailable`.
abstract interface class RouteDistributionGateway {
  Future<RouteDistributionRef> distribute({
    required String routeId,
    required int expectedRevision,
    required String idempotencyKey,
  });
}

/// The Route the user is editing in Create, exactly as Create stored it.
abstract interface class RouteDraftSource {
  Future<CreateDraftEntity?> current();
}

/// Local journal of this install's own Route publications.
abstract interface class RouteContentPublicationJournal {
  Future<RouteContentPublicationRecord?> forDraft({
    required String accountId,
    required String localDraftId,
  });
  Future<void> save(RouteContentPublicationRecord record);
}
