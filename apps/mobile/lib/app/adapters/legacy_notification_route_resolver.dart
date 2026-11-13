import '../application/planning_navigation_intent.dart';
import '../application/planning_navigation_resolver.dart';
import '../router/route_names.dart';
import 'legacy_planning_link_classifier.dart';

class LegacyNotificationRouteResolver {
  const LegacyNotificationRouteResolver();

  String? resolve(String rawRoute) {
    final uri = Uri.tryParse(rawRoute.trim());
    if (uri == null || !uri.hasAbsolutePath) return null;
    final classification = const LegacyPlanningLinkClassifier().classify(
      rawRoute,
    );
    final id = classification.targetId;
    if (id != null) {
      final intent = switch (classification.kind) {
        LegacyPlanningPayloadKind.scenario =>
          PlanningNavigationIntent.openScenario(id),
        LegacyPlanningPayloadKind.quickPlan =>
          PlanningNavigationIntent.openQuickPlan(id),
        LegacyPlanningPayloadKind.route => PlanningNavigationIntent.openRoute(
          id,
        ),
        _ => null,
      };
      if (intent != null) {
        return const PlanningNavigationResolver().resolve(intent);
      }
    }
    // Observation-period compatibility for already persisted notifications.
    if (uri.path == RouteNames.legacyScenarioBuilder) return rawRoute;
    return rawRoute;
  }
}
