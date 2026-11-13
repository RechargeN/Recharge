enum LegacyPlanningPayloadKind {
  quickPlan,
  scenario,
  route,
  ambiguous,
  unsupported,
}

class LegacyPlanningLinkClassification {
  const LegacyPlanningLinkClassification({
    required this.kind,
    this.targetId,
    required this.reason,
  });

  final LegacyPlanningPayloadKind kind;
  final String? targetId;
  final String reason;
}

/// Read-only compatibility classifier. It never rewrites ambiguous records.
class LegacyPlanningLinkClassifier {
  const LegacyPlanningLinkClassifier();

  LegacyPlanningLinkClassification classify(String rawLocation) {
    final uri = Uri.tryParse(rawLocation.trim());
    if (uri == null || !uri.hasAbsolutePath) {
      return const LegacyPlanningLinkClassification(
        kind: LegacyPlanningPayloadKind.unsupported,
        reason: 'invalid_uri',
      );
    }
    final query = uri.queryParameters;
    final scenarioId = _id(query['scenarioDraftId']);
    if (scenarioId != null) {
      return LegacyPlanningLinkClassification(
        kind: LegacyPlanningPayloadKind.scenario,
        targetId: scenarioId,
        reason: 'typed_scenario_id',
      );
    }
    final quickPlanId = _id(query['quickPlanId']);
    if (quickPlanId != null) {
      return LegacyPlanningLinkClassification(
        kind: LegacyPlanningPayloadKind.quickPlan,
        targetId: quickPlanId,
        reason: 'typed_quick_plan_id',
      );
    }
    final routeId = _id(query['routeId']);
    if (routeId != null) {
      return LegacyPlanningLinkClassification(
        kind: LegacyPlanningPayloadKind.route,
        targetId: routeId,
        reason: 'typed_route_id',
      );
    }
    if (uri.path == '/scenario-builder') {
      return const LegacyPlanningLinkClassification(
        kind: LegacyPlanningPayloadKind.ambiguous,
        reason: 'legacy_builder_without_stable_id',
      );
    }
    if (query['category'] == 'scenario' || query['mode'] == 'scenario') {
      return const LegacyPlanningLinkClassification(
        kind: LegacyPlanningPayloadKind.ambiguous,
        reason: 'legacy_scenario_category',
      );
    }
    return const LegacyPlanningLinkClassification(
      kind: LegacyPlanningPayloadKind.unsupported,
      reason: 'not_a_planning_link',
    );
  }

  static String? _id(String? value) {
    final id = value?.trim();
    return id == null || id.isEmpty || id.startsWith('loc_') ? null : id;
  }
}
