import '../entities/route_draft_data.dart';
import '../entities/route_quality_data.dart';

abstract interface class RouteQualityCalculator {
  RouteQualityDraft calculate({
    required RouteDraftData route,
    required DateTime calculatedAtUtc,
  });
}
