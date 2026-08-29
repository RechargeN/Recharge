import '../router/route_names.dart';
import 'planning_navigation_intent.dart';

class PlanningNavigationResolver {
  const PlanningNavigationResolver();

  String resolve(PlanningNavigationIntent intent) =>
      switch (intent.targetKind) {
        PlanningTargetKind.scenario => Uri(
          path: RouteNames.createObjectFor('scenario'),
          queryParameters: <String, String>{'scenarioDraftId': intent.targetId},
        ).toString(),
        PlanningTargetKind.quickPlan => RouteNames.quickPlanFor(
          intent.targetId,
        ),
        PlanningTargetKind.route => Uri(
          path: RouteNames.createObjectFor('route'),
          queryParameters: <String, String>{'routeId': intent.targetId},
        ).toString(),
      };
}
