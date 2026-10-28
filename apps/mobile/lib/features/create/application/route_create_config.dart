import '../domain/entities/route_draft_data.dart';
import '../domain/usecases/validate_route_draft_usecase.dart';

class RouteCreateStepConfig {
  const RouteCreateStepConfig({
    required this.id,
    required this.titleId,
    required this.descriptionId,
  });

  final String id;

  /// ARB message ids; the UI resolves them with `createFormText` (L4).
  final String titleId;
  final String descriptionId;
}

const List<RouteCreateStepConfig> routeCreateSteps = <RouteCreateStepConfig>[
  RouteCreateStepConfig(
    id: 'method',
    titleId: 'createStepRouteMethodTitle',
    descriptionId: 'createStepRouteMethodDescription',
  ),
  RouteCreateStepConfig(
    id: 'profile',
    titleId: 'createStepRouteProfileTitle',
    descriptionId: 'createStepRouteProfileDescription',
  ),
  RouteCreateStepConfig(
    id: 'editor',
    titleId: 'createStepRouteEditorTitle',
    descriptionId: 'createStepRouteEditorDescription',
  ),
  RouteCreateStepConfig(
    id: 'details',
    titleId: 'createStepRouteDetailsTitle',
    descriptionId: 'createStepRouteDetailsDescription',
  ),
  RouteCreateStepConfig(
    id: 'review',
    titleId: 'createStepRouteReviewTitle',
    descriptionId: 'createStepRouteReviewDescription',
  ),
];

class RouteCreateConfig {
  const RouteCreateConfig({
    required this.version,
    required this.validationPolicy,
    this.autosaveDebounce = const Duration(milliseconds: 700),
    this.minimumHistoryEntries = 10,
    this.maximumHistoryEntries = 50,
    this.maximumHistoryGeometryPoints = 100000,
  });

  final int version;
  final RouteValidationPolicy validationPolicy;
  final Duration autosaveDebounce;
  final int minimumHistoryEntries;
  final int maximumHistoryEntries;
  final int maximumHistoryGeometryPoints;

  bool get isValid =>
      version > 0 &&
      validationPolicy.isValid &&
      !autosaveDebounce.isNegative &&
      minimumHistoryEntries > 0 &&
      maximumHistoryEntries >= minimumHistoryEntries &&
      maximumHistoryGeometryPoints > 0;
}

RouteCreateConfig demoRouteCreateConfig() => RouteCreateConfig(
  version: 1,
  validationPolicy: RouteValidationPolicy(
    profileRules: <RouteProfileValidationRule>[
      RouteProfileValidationRule(
        profile: const RouteProfileRef(id: 'walking', version: 1),
        minimumDistanceMeters: 1,
        maximumDistanceMeters: 500000,
        maximumDurationSeconds: 604800,
        allowedShapes: RouteShape.values,
        supportedPreferenceIds: const <String>[
          'avoid_stairs',
          'prefer_unpaved',
        ],
      ),
    ],
    encodingPolicyId: RouteGeometryEncodingPolicyDraft.standard.id,
    encodingPolicyVersion: RouteGeometryEncodingPolicyDraft.standard.version,
    minimumAnchors: 2,
    maximumAnchors: 100,
    maximumSegments: 120,
    maximumWaypoints: 250,
    maximumGeometryPoints: 10000,
    endpointToleranceMeters: 2,
    distanceToleranceMeters: 0.1,
    waypointTrackToleranceMeters: 25,
    maximumDirectShare: 0.2,
    manualDurationReasonDeviationRatio: 0.25,
    requirePermanentIds: false,
  ),
);

RouteDraftData createEmptyRouteDraft() => RouteDraftData(
  geometryRevision: 0,
  creationMethod: RouteCreationMethod.points,
  shape: RouteShape.oneWay,
  profile: const RouteProfileRef(id: 'walking', version: 1),
  preferences: RouteRoutingPreferences(
    values: const <String, RoutePreferenceValue>{
      'avoid_stairs': RouteBoolPreferenceValue(true),
    },
  ),
  anchors: const <RouteAnchorDraft>[],
  segments: const <RouteSegmentDraft>[],
  waypoints: const <RouteWaypointDraft>[],
  conditions: RouteConditionsDraft(),
  sourceIssues: const <RouteSourceIssueDraft>[],
  metrics: RouteMetricsDraft(
    geometryRevision: 0,
    calculationModelId: 'walking-duration',
    calculationModelVersion: 1,
    distanceMeters: 0,
    autoDurationSeconds: 0,
    effectiveDurationSeconds: 0,
    directDistanceMeters: 0,
    fallbackDistanceMeters: 0,
  ),
  encodingPolicy: RouteGeometryEncodingPolicyDraft.standard,
);
