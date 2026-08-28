import '../../../core/telemetry/analytics_service.dart';
import '../domain/entities/collection_moderation_request.dart';
import '../domain/entities/collection_publication_data.dart';

/// COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §15 "Telemetry и privacy" — a
/// single, strict allowlist for every Collection-authoring lifecycle event.
/// Never a query string, title, description, curator note, any id, a raw
/// price, an area label, coordinates, a media URL, or a free-form error
/// message — only typed enums and booleans reach `_analytics.track`.
///
/// `CreateController` is this telemetry's only caller
/// (COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §6/§15 single-owner rule) —
/// neither `CollectionCreateCoordinator` nor the publication
/// repository/datasource ever call analytics directly.
enum CollectionCreateTelemetryAction {
  publish,
  removalOnly,
  archive,
  moderationDecision,
}

enum CollectionCreateTelemetryResult {
  success,
  pendingReview,
  idempotencyConflict,
  revisionConflict,
  notFound,
  removalOnlyConflict,
  persistenceUnavailable,
}

class CollectionCreateTelemetry {
  const CollectionCreateTelemetry.disabled() : _analytics = null;

  const CollectionCreateTelemetry(AnalyticsService analytics)
    : _analytics = analytics;

  final AnalyticsService? _analytics;

  void _track({
    required CollectionCreateTelemetryAction action,
    required CollectionCreateTelemetryResult result,
    bool? direct,
    bool? accept,
    bool? synced,
    CollectionModerationRejectionReason? rejectionReason,
  }) {
    _analytics?.track(
      'collection_create_action',
      params: <String, Object?>{
        'action': action.name,
        'result': result.name,
        if (direct != null) 'direct': direct,
        if (accept != null) 'accept': accept,
        // Review finding: a persistent Discover-sink failure on
        // publish/moderation-accept/archive must never be indistinguishable
        // from a clean success in telemetry, even though the *author* is
        // still told it succeeded (the local write did).
        if (synced != null) 'synced': synced,
        if (rejectionReason != null) 'rejection_reason': rejectionReason.name,
      },
    );
  }

  /// `direct` records which write path was taken
  /// (`publish.collection.direct` vs `submit.collection`); `outcome`
  /// distinguishes an actually-active publish from one still awaiting
  /// `moderate.collection`; `discoverSynced` is only meaningful when the
  /// outcome activated something (ignored for `pendingReview`).
  void trackPublish({
    required bool direct,
    required CollectionPublishOutcome outcome,
    bool discoverSynced = true,
  }) {
    final bool isPending = outcome == CollectionPublishOutcome.pendingReview;
    _track(
      action: CollectionCreateTelemetryAction.publish,
      result: isPending
          ? CollectionCreateTelemetryResult.pendingReview
          : CollectionCreateTelemetryResult.success,
      direct: direct,
      synced: isPending ? null : discoverSynced,
    );
  }

  void trackRemovalOnly({bool discoverSynced = true}) {
    _track(
      action: CollectionCreateTelemetryAction.removalOnly,
      result: CollectionCreateTelemetryResult.success,
      synced: discoverSynced,
    );
  }

  void trackArchive({bool discoverSynced = true}) {
    _track(
      action: CollectionCreateTelemetryAction.archive,
      result: CollectionCreateTelemetryResult.success,
      synced: discoverSynced,
    );
  }

  void trackModerationDecision({
    required bool accept,
    bool discoverSynced = true,
    CollectionModerationRejectionReason? rejectionReason,
  }) {
    _track(
      action: CollectionCreateTelemetryAction.moderationDecision,
      result: CollectionCreateTelemetryResult.success,
      accept: accept,
      // Nothing to sync on a reject — omit rather than report a
      // meaningless "true".
      synced: accept ? discoverSynced : null,
      rejectionReason: rejectionReason,
    );
  }

  /// One shared failure sink for every `CollectionPublicationException`
  /// (§12's `CollectionPublicationFailure` enum) — [action] is which
  /// command threw it, [failureCode] is `CollectionPublicationFailure.name`,
  /// never the free-form exception message.
  void trackFailure({
    required CollectionCreateTelemetryAction action,
    required String failureCode,
  }) {
    _track(action: action, result: _resultFromFailureCode(failureCode));
  }

  static CollectionCreateTelemetryResult _resultFromFailureCode(String code) {
    for (final CollectionCreateTelemetryResult value
        in CollectionCreateTelemetryResult.values) {
      if (value.name == code) return value;
    }
    return CollectionCreateTelemetryResult.persistenceUnavailable;
  }
}
