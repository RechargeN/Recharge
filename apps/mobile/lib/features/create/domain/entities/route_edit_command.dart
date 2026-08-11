import '../../../../shared/primitives/geo/geo_point.dart';
import 'route_draft_data.dart';
import 'route_recording_data.dart';
import '../repositories/route_gpx_repository.dart';

sealed class RouteEditCommand {
  const RouteEditCommand();

  String get code;
}

class SelectRouteCreationMethod extends RouteEditCommand {
  const SelectRouteCreationMethod({
    required this.method,
    this.confirmGeometryReplacement = false,
  });

  final RouteCreationMethod method;
  final bool confirmGeometryReplacement;

  @override
  String get code => 'select_creation_method';
}

class AddRouteAnchor extends RouteEditCommand {
  const AddRouteAnchor({required this.position, this.authorIntentId});

  final GeoPoint position;
  final String? authorIntentId;

  @override
  String get code => 'add_anchor';
}

class ApplyRouteFreehandGeometry extends RouteEditCommand {
  ApplyRouteFreehandGeometry({
    required Iterable<GeoPoint> points,
    this.confirmGeometryReplacement = false,
  }) : points = List<GeoPoint>.unmodifiable(points);

  final List<GeoPoint> points;
  final bool confirmGeometryReplacement;

  @override
  String get code => 'apply_freehand_geometry';
}

class ApplyRouteGpxImport extends RouteEditCommand {
  const ApplyRouteGpxImport({
    required this.result,
    this.confirmGeometryReplacement = false,
  });

  final RouteGpxImportResult result;
  final bool confirmGeometryReplacement;

  @override
  String get code => 'apply_gpx_import';
}

class ApplyRouteGpsRecording extends RouteEditCommand {
  const ApplyRouteGpsRecording({
    required this.result,
    this.confirmGeometryReplacement = false,
  });

  final RouteRecordingApplyResult result;
  final bool confirmGeometryReplacement;

  @override
  String get code => 'apply_gps_recording';
}

class MoveRouteAnchor extends RouteEditCommand {
  const MoveRouteAnchor({required this.anchorId, required this.position});

  final String anchorId;
  final GeoPoint position;

  @override
  String get code => 'move_anchor';
}

class RemoveRouteAnchor extends RouteEditCommand {
  const RemoveRouteAnchor({required this.anchorId});

  final String anchorId;

  @override
  String get code => 'remove_anchor';
}

class SplitRouteSegment extends RouteEditCommand {
  const SplitRouteSegment({required this.segmentId, required this.position});

  final String segmentId;
  final GeoPoint position;

  @override
  String get code => 'split_segment';
}

class MergeRouteSegments extends RouteEditCommand {
  const MergeRouteSegments({
    required this.firstSegmentId,
    required this.secondSegmentId,
  });

  final String firstSegmentId;
  final String secondSegmentId;

  @override
  String get code => 'merge_segments';
}

class ChangeRouteProfile extends RouteEditCommand {
  const ChangeRouteProfile({required this.profile, this.preferences});

  final RouteProfileRef profile;
  final RouteRoutingPreferences? preferences;

  @override
  String get code => 'change_profile';
}

class ChangeRouteShape extends RouteEditCommand {
  const ChangeRouteShape(this.shape);

  final RouteShape shape;

  @override
  String get code => 'change_shape';
}

class ChangeRouteSegmentProfile extends RouteEditCommand {
  const ChangeRouteSegmentProfile({
    required this.segmentId,
    this.profile,
    this.clearOverride = false,
  });

  final String segmentId;
  final RouteProfileRef? profile;
  final bool clearOverride;

  @override
  String get code => 'change_segment_profile';
}

class SetRouteSegmentDirect extends RouteEditCommand {
  const SetRouteSegmentDirect({required this.segmentId, this.fallbackReason});

  final String segmentId;
  final RouteRoutingFailureCode? fallbackReason;

  @override
  String get code => 'set_segment_direct';
}

class RerouteRouteSegment extends RouteEditCommand {
  const RerouteRouteSegment(this.segmentId);

  final String segmentId;

  @override
  String get code => 'reroute_segment';
}

class RetryRouteSegment extends RouteEditCommand {
  const RetryRouteSegment(this.segmentId);

  final String segmentId;

  @override
  String get code => 'retry_segment';
}

class AddRouteWaypoint extends RouteEditCommand {
  const AddRouteWaypoint({
    required this.anchorId,
    required this.typeId,
    this.note,
  });

  final String anchorId;
  final String typeId;
  final String? note;

  @override
  String get code => 'add_waypoint';
}

class MoveRouteWaypoint extends RouteEditCommand {
  const MoveRouteWaypoint({required this.waypointId, required this.anchorId});

  final String waypointId;
  final String anchorId;

  @override
  String get code => 'move_waypoint';
}

class RemoveRouteWaypoint extends RouteEditCommand {
  const RemoveRouteWaypoint(this.waypointId);

  final String waypointId;

  @override
  String get code => 'remove_waypoint';
}

class ChangeRouteConditions extends RouteEditCommand {
  const ChangeRouteConditions(this.conditions);

  final RouteConditionsDraft conditions;

  @override
  String get code => 'change_conditions';
}

class RestorePersistedRoute extends RouteEditCommand {
  const RestorePersistedRoute();

  @override
  String get code => 'restore_persisted_revision';
}
