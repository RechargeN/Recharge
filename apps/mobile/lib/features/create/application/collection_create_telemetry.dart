import '../../../core/telemetry/analytics_service.dart';
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
  }) {
    _analytics?.track(
      'collection_create_action',
      params: <String, Object?>{
        'action': action.name,
        'result': result.name,
        if (direct != null) 'direct': direct,
        if (accept != null) 'accept': accept,
      },
    );
  }

  /// `direct` records which write path was taken
  /// (`publish.collection.direct` vs `submit.collection`); `outcome`
  /// distinguishes an actually-active publish from one still awaiting
  /// `moderate.collection`.
  void trackPublish({
    required bool direct,
    required CollectionPublishOutcome outcome,
  }) {
    _track(
      action: CollectionCreateTelemetryAction.publish,
      result: outcome == CollectionPublishOutcome.pendingReview
          ? CollectionCreateTelemetryResult.pendingReview
          : CollectionCreateTelemetryResult.success,
      direct: direct,
    );
  }

  void trackRemovalOnly() {
    _track(
      action: CollectionCreateTelemetryAction.removalOnly,
      result: CollectionCreateTelemetryResult.success,
    );
  }

  void trackArchive() {
    _track(
      action: CollectionCreateTelemetryAction.archive,
      result: CollectionCreateTelemetryResult.success,
    );
  }

  void trackModerationDecision({required bool accept}) {
    _track(
      action: CollectionCreateTelemetryAction.moderationDecision,
      result: CollectionCreateTelemetryResult.success,
      accept: accept,
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
