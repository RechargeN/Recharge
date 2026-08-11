import '../../../../core/geo/geo_bounds.dart';
import '../../../../core/geo/geo_point.dart';
import 'create_draft_entity.dart';
import 'route_draft_data.dart';
import 'route_quality_data.dart';

enum RoutePublisherType { user, page }

enum RoutePublicationMode { reviewed, trustedDirect }

enum RouteModerationState { pending, approved, rejected, cancelled }

enum RouteLifecycleStatus { active, needsReview, suspended, archived }

enum RoutePublishReceiptStatus {
  submitted,
  published,
  idempotent,
  conflict,
  denied,
  invalid,
}

class RoutePublisherRef {
  const RoutePublisherRef({required this.type, required this.id});

  final RoutePublisherType type;
  final String id;

  bool get isValid => id.trim().isNotEmpty;
}

class PublishedRouteSegment {
  const PublishedRouteSegment({
    required this.id,
    required this.order,
    required this.fromAnchorId,
    required this.toAnchorId,
    required this.source,
    required this.encodedPolyline,
    required this.geometryHash,
    required this.distanceMeters,
    required this.providerCode,
  });

  final String id;
  final int order;
  final String fromAnchorId;
  final String toAnchorId;
  final RouteSegmentSource source;
  final String encodedPolyline;
  final String geometryHash;
  final double distanceMeters;
  final String? providerCode;
}

class PublishedRouteWaypoint {
  PublishedRouteWaypoint({
    required this.id,
    required this.position,
    required this.typeId,
    required this.distanceFromStartMeters,
    required this.anchorId,
    required this.segmentId,
    required this.catalogVersion,
    required this.title,
    required this.description,
    required this.note,
    required this.safetyNote,
    required Iterable<String> technicalAttributeIds,
    required Iterable<String> photoIds,
    required this.verifiedAtUtc,
  }) : technicalAttributeIds = List<String>.unmodifiable(
         technicalAttributeIds,
       ),
       photoIds = List<String>.unmodifiable(photoIds);

  final String id;
  final GeoPoint position;
  final String typeId;
  final double distanceFromStartMeters;
  final String? anchorId;
  final String? segmentId;
  final int catalogVersion;
  final String? title;
  final String? description;
  final String? note;
  final String? safetyNote;
  final List<String> technicalAttributeIds;
  final List<String> photoIds;
  final DateTime? verifiedAtUtc;
}

class PublishedRouteGeometry {
  PublishedRouteGeometry({
    required this.routeId,
    required this.versionId,
    required this.geometryHash,
    required this.fullEncodedPolyline,
    required Iterable<PublishedRouteSegment> segments,
    required Iterable<PublishedRouteWaypoint> waypoints,
    required Iterable<RouteProviderReference> providers,
    required this.encodingPolicyId,
    required this.encodingPolicyVersion,
    required this.quality,
  }) : segments = List<PublishedRouteSegment>.unmodifiable(segments),
       waypoints = List<PublishedRouteWaypoint>.unmodifiable(waypoints),
       providers = List<RouteProviderReference>.unmodifiable(providers);

  final String routeId;
  final String versionId;
  final String geometryHash;
  final String fullEncodedPolyline;
  final List<PublishedRouteSegment> segments;
  final List<PublishedRouteWaypoint> waypoints;
  final List<RouteProviderReference> providers;
  final String encodingPolicyId;
  final int encodingPolicyVersion;
  final RouteQualityDraft? quality;
}

class RouteSearchProjection {
  RouteSearchProjection({
    required this.routeId,
    required this.versionId,
    required this.geometryHash,
    required this.marketId,
    required this.startPoint,
    required this.bounds,
    required this.overviewEncodedPolyline,
    required this.distanceMeters,
    required this.effectiveDurationSeconds,
    required this.routingProfileId,
    required this.difficultyId,
    required Iterable<String> categoryIds,
    required Iterable<String> searchTokens,
  }) : categoryIds = List<String>.unmodifiable(categoryIds),
       searchTokens = List<String>.unmodifiable(searchTokens);

  final String routeId;
  final String versionId;
  final String geometryHash;
  final String marketId;
  final GeoPoint startPoint;
  final GeoBounds bounds;
  final String overviewEncodedPolyline;
  final double distanceMeters;
  final int effectiveDurationSeconds;
  final String routingProfileId;
  final String difficultyId;
  final List<String> categoryIds;
  final List<String> searchTokens;
}

class RoutePublicationAuditEvent {
  const RoutePublicationAuditEvent({
    required this.id,
    required this.action,
    required this.actorId,
    required this.publisher,
    required this.routeId,
    required this.versionId,
    required this.attemptId,
    required this.occurredAtUtc,
    this.reasonCode,
  });

  final String id;
  final String action;
  final String actorId;
  final RoutePublisherRef publisher;
  final String routeId;
  final String versionId;
  final String attemptId;
  final DateTime occurredAtUtc;
  final String? reasonCode;
}

class PublishedRouteVersion {
  const PublishedRouteVersion({
    required this.routeId,
    required this.versionId,
    required this.versionNumber,
    required this.previousVersionId,
    required this.publisher,
    required this.authorId,
    required this.contentHash,
    required this.geometryHash,
    required this.mode,
    required this.demoOnly,
    required this.contentSnapshot,
    required this.geometry,
    required this.projection,
    required this.createdAtUtc,
    required this.publishedAtUtc,
    this.rollbackSourceVersionId,
  });

  final String routeId;
  final String versionId;
  final int versionNumber;
  final String? previousVersionId;
  final RoutePublisherRef publisher;
  final String authorId;
  final String contentHash;
  final String geometryHash;
  final RoutePublicationMode mode;
  final bool demoOnly;
  final CreateDraftEntity contentSnapshot;
  final PublishedRouteGeometry geometry;
  final RouteSearchProjection projection;
  final DateTime createdAtUtc;
  final DateTime publishedAtUtc;
  final String? rollbackSourceVersionId;
}

class RoutePublicationBundle {
  const RoutePublicationBundle({
    required this.attemptId,
    required this.version,
    required this.auditEvent,
  });

  final String attemptId;
  final PublishedRouteVersion version;
  final RoutePublicationAuditEvent auditEvent;
}

class RouteModerationRequest {
  const RouteModerationRequest({
    required this.id,
    required this.attemptId,
    required this.bundle,
    required this.state,
    required this.submittedAtUtc,
    this.decidedAtUtc,
    this.decidedBy,
    this.reasonCode,
  });

  final String id;
  final String attemptId;
  final RoutePublicationBundle bundle;
  final RouteModerationState state;
  final DateTime submittedAtUtc;
  final DateTime? decidedAtUtc;
  final String? decidedBy;
  final String? reasonCode;

  RouteModerationRequest copyWith({
    RouteModerationState? state,
    DateTime? decidedAtUtc,
    String? decidedBy,
    String? reasonCode,
  }) => RouteModerationRequest(
    id: id,
    attemptId: attemptId,
    bundle: bundle,
    state: state ?? this.state,
    submittedAtUtc: submittedAtUtc,
    decidedAtUtc: decidedAtUtc ?? this.decidedAtUtc,
    decidedBy: decidedBy ?? this.decidedBy,
    reasonCode: reasonCode ?? this.reasonCode,
  );
}

class RoutePublicationAggregate {
  RoutePublicationAggregate({
    required this.routeId,
    required Iterable<PublishedRouteVersion> versions,
    required this.activeVersionId,
    required this.lifecycleStatus,
    required Iterable<RoutePublicationAuditEvent> auditTrail,
  }) : versions = List<PublishedRouteVersion>.unmodifiable(versions),
       auditTrail = List<RoutePublicationAuditEvent>.unmodifiable(auditTrail);

  final String routeId;
  final List<PublishedRouteVersion> versions;
  final String? activeVersionId;
  final RouteLifecycleStatus lifecycleStatus;
  final List<RoutePublicationAuditEvent> auditTrail;

  PublishedRouteVersion? get activeVersion {
    for (final version in versions) {
      if (version.versionId == activeVersionId) return version;
    }
    return null;
  }
}

class RoutePublishReceipt {
  const RoutePublishReceipt({
    required this.status,
    required this.routeId,
    required this.versionId,
    required this.geometryHash,
    required this.displayDraft,
    this.requestId,
    this.reasonCode,
  });

  final RoutePublishReceiptStatus status;
  final String routeId;
  final String versionId;
  final String geometryHash;
  final CreateDraftEntity displayDraft;
  final String? requestId;
  final String? reasonCode;

  bool get isSuccess =>
      status == RoutePublishReceiptStatus.submitted ||
      status == RoutePublishReceiptStatus.published ||
      status == RoutePublishReceiptStatus.idempotent;

  bool get isPublished =>
      status == RoutePublishReceiptStatus.published ||
      status == RoutePublishReceiptStatus.idempotent;
}

class RouteModerationDecision {
  const RouteModerationDecision({
    required this.requestId,
    required this.approved,
    required this.actorId,
    required this.attemptId,
    required this.decidedAtUtc,
    this.reasonCode,
  });

  final String requestId;
  final bool approved;
  final String actorId;
  final String attemptId;
  final DateTime decidedAtUtc;
  final String? reasonCode;
}
