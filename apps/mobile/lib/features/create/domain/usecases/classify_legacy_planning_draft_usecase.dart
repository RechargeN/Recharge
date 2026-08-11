enum LegacyPlanningTarget { quickPlan, scenario, route, unresolved }

class LegacyPlanningClassification {
  const LegacyPlanningClassification({
    required this.target,
    required this.reasonCodes,
    required this.requiresUserConfirmation,
  });

  final LegacyPlanningTarget target;
  final List<String> reasonCodes;
  final bool requiresUserConfirmation;
}

class ClassifyLegacyPlanningDraftUseCase {
  const ClassifyLegacyPlanningDraftUseCase();

  LegacyPlanningClassification call(Map<String, Object?> payload) {
    final String objectType = _normalized(payload['objectType']);
    final Map<String, Object?> sectionData = _map(payload['sectionData']);
    final Map<String, Object?> scenario = <String, Object?>{
      ..._map(sectionData['scenario']),
      ..._map(sectionData['scenario_details']),
    };
    final Map<String, Object?> combined = <String, Object?>{
      ...payload,
      ...sectionData,
      ...scenario,
    };
    final List<String> reasons = <String>[];

    if (objectType == 'private_plan' || objectType == 'privateplan') {
      return const LegacyPlanningClassification(
        target: LegacyPlanningTarget.quickPlan,
        reasonCodes: <String>['private_plan_alias'],
        requiresUserConfirmation: false,
      );
    }

    final bool hasTrackGeometry = _hasAnyKey(combined, <String>{
      'gpx',
      'gpxData',
      'geometry',
      'polyline',
      'segments',
      'anchors',
      'elevationProfile',
      'elevationGainM',
      'poiByDistance',
    });
    if (hasTrackGeometry) {
      reasons.add('continuous_track_evidence');
    }

    final bool explicitScenario =
        objectType == 'scenario' ||
        _normalized(combined['contentType']) == 'scenario';
    final bool hasScenarioSchema =
        _int(combined['scenarioSchemaVersion']) != null ||
        _int(combined['schemaVersion']) != null &&
            (sectionData.containsKey('scenario') ||
                sectionData.containsKey('scenario_details'));
    final bool hasDays = _nonEmptyList(combined['days']);
    final bool hasLogistics =
        _nonEmptyList(combined['legs']) ||
        _hasAnyKey(combined, <String>{
          'stay',
          'stays',
          'plannedTransport',
          'planned_transport',
          'alternatives',
          'defaultTimezoneId',
          'displayCurrencyCode',
        });
    final String format = _normalized(combined['format']);
    final bool hasExtendedFormat = format == 'weekend' || format == 'trip';
    final bool scenarioShaped =
        explicitScenario ||
        hasScenarioSchema ||
        hasDays ||
        hasLogistics ||
        hasExtendedFormat;
    if (explicitScenario) {
      reasons.add('explicit_scenario_type');
    }
    if (hasScenarioSchema) {
      reasons.add('scenario_schema');
    }
    if (hasDays) {
      reasons.add('scenario_days');
    }
    if (hasLogistics) {
      reasons.add('scenario_logistics');
    }
    if (hasExtendedFormat) {
      reasons.add('scenario_extended_format');
    }

    final bool scenarioRouteLabel =
        _containsScenarioRoute(payload) ||
        _normalized(payload['mode']) == 'scenario' ||
        _normalized(combined['mode']) == 'scenario';
    final bool explicitRoute = objectType == 'route';

    if (hasTrackGeometry && !scenarioShaped) {
      return LegacyPlanningClassification(
        target: LegacyPlanningTarget.route,
        reasonCodes: List<String>.unmodifiable(reasons),
        requiresUserConfirmation: false,
      );
    }
    if (scenarioShaped && !hasTrackGeometry) {
      final bool fromLegacyQuickPlan =
          objectType == 'quick_plan' || objectType == 'quickplan';
      if (fromLegacyQuickPlan) {
        reasons.add('legacy_quick_plan_slot');
      }
      return LegacyPlanningClassification(
        target: LegacyPlanningTarget.scenario,
        reasonCodes: List<String>.unmodifiable(reasons),
        requiresUserConfirmation: fromLegacyQuickPlan,
      );
    }
    if (hasTrackGeometry && scenarioShaped) {
      reasons.add('mixed_route_scenario_evidence');
      return LegacyPlanningClassification(
        target: LegacyPlanningTarget.unresolved,
        reasonCodes: List<String>.unmodifiable(reasons),
        requiresUserConfirmation: true,
      );
    }
    if (scenarioRouteLabel ||
        (explicitRoute && _nonEmptyList(combined['stops']))) {
      reasons.add('ambiguous_scenario_route_handoff');
      return LegacyPlanningClassification(
        target: LegacyPlanningTarget.unresolved,
        reasonCodes: List<String>.unmodifiable(reasons),
        requiresUserConfirmation: true,
      );
    }
    if (explicitRoute) {
      return const LegacyPlanningClassification(
        target: LegacyPlanningTarget.route,
        reasonCodes: <String>['explicit_route_type'],
        requiresUserConfirmation: false,
      );
    }
    if (objectType == 'quick_plan' || objectType == 'quickplan') {
      return const LegacyPlanningClassification(
        target: LegacyPlanningTarget.quickPlan,
        reasonCodes: <String>['lightweight_quick_plan_shape'],
        requiresUserConfirmation: false,
      );
    }
    return const LegacyPlanningClassification(
      target: LegacyPlanningTarget.unresolved,
      reasonCodes: <String>['insufficient_identity_evidence'],
      requiresUserConfirmation: true,
    );
  }

  static bool _containsScenarioRoute(Map<String, Object?> payload) {
    for (final String key in <String>['title', 'label', 'source', 'kind']) {
      final String value = _normalized(payload[key]).replaceAll('_', ' ');
      if (value.contains('scenario route') ||
          value.contains('route scenario')) {
        return true;
      }
    }
    return false;
  }

  static bool _hasAnyKey(Map<String, Object?> value, Set<String> keys) {
    return keys.any((String key) {
      final Object? candidate = value[key];
      if (candidate == null) {
        return false;
      }
      if (candidate is String) {
        return candidate.trim().isNotEmpty;
      }
      if (candidate is Iterable) {
        return candidate.isNotEmpty;
      }
      if (candidate is Map) {
        return candidate.isNotEmpty;
      }
      return true;
    });
  }

  static bool _nonEmptyList(Object? value) => value is List && value.isNotEmpty;

  static String _normalized(Object? value) =>
      value?.toString().trim().toLowerCase().replaceAll('-', '_') ?? '';

  static int? _int(Object? value) => switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text),
    _ => null,
  };

  static Map<String, Object?> _map(Object? value) {
    if (value is! Map) {
      return <String, Object?>{};
    }
    return value.map<String, Object?>((dynamic key, dynamic item) {
      return MapEntry<String, Object?>(key.toString(), item as Object?);
    });
  }
}
