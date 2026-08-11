import '../entities/route_draft_data.dart';
import '../entities/route_quality_workflow_data.dart';
import '../entities/route_publication_data.dart';

abstract interface class RouteGeometryDiffBuilder {
  RouteGeometryDiff build({
    required PublishedRouteVersion baseVersion,
    required RouteDraftData candidate,
  });
}
