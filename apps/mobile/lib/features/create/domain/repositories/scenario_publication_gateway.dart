import '../entities/create_draft_entity.dart';
import '../entities/scenario_publication.dart';

/// Planning owner commands of SCN-PUB-01. Every decision is the server's:
/// owner authority, the allowlist, privacy and stop checks. Failures are
/// `EventPublicationRejected` / `EventPublicationUnavailable`.
abstract interface class ScenarioPlanningGateway {
  /// The current server revision of the owner's plan (I2 persistence).
  Future<int> serverRevision(String scenarioId);

  Future<ScenarioDistributionRef> distribute({
    required String scenarioId,
    required int expectedRevision,
    required String idempotencyKey,
  });

  Future<ScenarioShareLink> share({
    required String scenarioId,
    required int expectedRevision,
    required String idempotencyKey,
    int? ttlDays,
  });

  /// True when an active link was revoked.
  Future<bool> unshare({
    required String scenarioId,
    required int expectedRevision,
    required String idempotencyKey,
  });

  /// The share snapshot behind an unlisted token (any signed-in reader).
  Future<Map<String, Object?>> resolveShare(String token);
}

/// The Scenario the user is editing in Create, exactly as Create stored it.
abstract interface class ScenarioDraftSource {
  Future<CreateDraftEntity?> current();
}

/// Local journal of this install's own Scenario publications.
abstract interface class ScenarioPublicationJournal {
  Future<ScenarioPublicationRecord?> forScenario({
    required String accountId,
    required String scenarioId,
  });
  Future<void> save(ScenarioPublicationRecord record);
}
