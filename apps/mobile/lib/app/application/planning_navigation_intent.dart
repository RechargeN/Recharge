enum PlanningTargetKind { quickPlan, scenario, route }

/// Typed navigation contract for the three independent planning aggregates.
class PlanningNavigationIntent {
  const PlanningNavigationIntent._({
    required this.targetKind,
    required this.targetId,
  });

  factory PlanningNavigationIntent.openQuickPlan(String quickPlanId) =>
      PlanningNavigationIntent._(
        targetKind: PlanningTargetKind.quickPlan,
        targetId: _requiredPermanentId(quickPlanId, 'quickPlanId'),
      );

  factory PlanningNavigationIntent.openScenario(String scenarioDraftId) =>
      PlanningNavigationIntent._(
        targetKind: PlanningTargetKind.scenario,
        targetId: _requiredPermanentId(scenarioDraftId, 'scenarioDraftId'),
      );

  factory PlanningNavigationIntent.openRoute(String routeId) =>
      PlanningNavigationIntent._(
        targetKind: PlanningTargetKind.route,
        targetId: _requiredPermanentId(routeId, 'routeId'),
      );

  final PlanningTargetKind targetKind;
  final String targetId;

  static String _requiredPermanentId(String value, String field) {
    final id = value.trim();
    if (id.isEmpty || id != value || id.startsWith('loc_')) {
      throw FormatException('$field must be a stable ID.');
    }
    return id;
  }
}
