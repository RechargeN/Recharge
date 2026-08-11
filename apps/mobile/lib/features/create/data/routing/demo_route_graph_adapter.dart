import '../../../../core/config/provider_cost_policy.dart';
import '../../../../core/geo/geo_distance.dart';
import '../../../../core/geo/geo_point.dart';
import '../../../../core/telemetry/provider_cost_ledger.dart';
import '../../domain/entities/route_draft_data.dart';
import '../../domain/repositories/route_routing_repository.dart';
import 'demo_route_graph.dart';

class DemoRouteGraphAdapter implements RouteRoutingRepository {
  DemoRouteGraphAdapter({
    required DemoRouteGraph graph,
    ProviderCostLedger? costLedger,
    ProviderCostPolicy? costPolicy,
  }) : _graph = graph,
       _costLedger = costLedger ?? InMemoryProviderCostLedger(),
       _costPolicy =
           costPolicy ??
           ProviderCostPolicy(
             providerId: graph.manifest.graphId,
             version: 1,
             costClass: CostClass.zeroCost,
             enabled: true,
             dailyRequestLimit: 0,
           ) {
    graph.validate();
  }

  static const Set<String> _supportedPreferenceIds = <String>{
    'avoid_stairs',
    'prefer_unpaved',
  };

  final DemoRouteGraph _graph;
  final ProviderCostLedger _costLedger;
  final ProviderCostPolicy _costPolicy;

  @override
  Future<RouteRoutingResult> route(RouteRoutingRequest request) async {
    _recordCost(request.operationId);
    _throwIfCancelled(request.operationId, request.cancellationSignal);
    _validateRequest(request);

    final fromNode = _nearestNode(request.from.position);
    final toNode = _nearestNode(request.to.position);
    if (fromNode == null || toNode == null) {
      throw RouteRoutingException(
        code: RouteRoutingFailureCode.outsideCoverage,
        operationId: request.operationId,
        message: 'An endpoint cannot be snapped to the demo graph.',
      );
    }
    if (fromNode.id == toNode.id &&
        request.from.position == request.to.position) {
      throw RouteRoutingException(
        code: RouteRoutingFailureCode.noPath,
        operationId: request.operationId,
        message: 'A route requires two distinct endpoints.',
      );
    }

    final path = _shortestPath(
      operationId: request.operationId,
      fromNodeId: fromNode.id,
      toNodeId: toNode.id,
      preferences: request.preferences,
      cancellationSignal: request.cancellationSignal,
    );
    if (path == null) {
      throw RouteRoutingException(
        code: RouteRoutingFailureCode.noPath,
        operationId: request.operationId,
        message: 'No path connects the selected demo graph endpoints.',
      );
    }

    final graphPoints = path
        .map((String nodeId) => _graph.nodes[nodeId]!.position)
        .toList(growable: false);
    final points = _withEndpoints(
      request.from.position,
      graphPoints,
      request.to.position,
    );
    final geometry = RouteGeometryDraft.fromPoints(points);
    final preferenceIds = request.preferences.values.keys.toList()..sort();
    final appliedPreferenceIds = preferenceIds
        .where(_supportedPreferenceIds.contains)
        .toList(growable: false);
    final unsupportedPreferenceIds = preferenceIds
        .where((String id) => !_supportedPreferenceIds.contains(id))
        .toList(growable: false);

    return RouteRoutingResult(
      operationId: request.operationId,
      expectedGeometryRevision: request.expectedGeometryRevision,
      requestFingerprint: request.requestFingerprint,
      fromAnchorId: request.from.anchorId,
      toAnchorId: request.to.anchorId,
      geometry: geometry,
      provenance: RouteProvenanceDraft(
        sourceId: 'demoGraph',
        sourceRevision: 1,
        createdAtUtc: _graph.manifest.generatedAtUtc,
        algorithmVersion:
            '${_graph.manifest.algorithmVersion}+'
            '${_graph.manifest.weightingVersion}',
        provider: _graph.manifest.providerReference,
      ),
      appliedPreferenceIds: appliedPreferenceIds,
      unsupportedPreferenceIds: unsupportedPreferenceIds,
      providerDurationSeconds: (geometry.lengthMeters / 1.4).round(),
    );
  }

  @override
  Future<List<RouteGeneratedCandidate>> generate(
    RouteGenerationRequest request,
  ) async {
    _recordCost(request.operationId);
    _throwIfCancelled(request.operationId, request.cancellationSignal);
    throw RouteRoutingException(
      code: RouteRoutingFailureCode.providerRejected,
      operationId: request.operationId,
      message: 'Demo graph generation is not enabled in RTE-04.',
    );
  }

  void _validateRequest(RouteRoutingRequest request) {
    if (request.operationId.trim().isEmpty ||
        request.requestFingerprint.trim().isEmpty ||
        request.expectedGeometryRevision < 0 ||
        !request.from.position.isValid ||
        !request.to.position.isValid) {
      throw RouteRoutingException(
        code: RouteRoutingFailureCode.providerRejected,
        operationId: request.operationId,
        message: 'The routing request is invalid.',
      );
    }
    if (!_graph.coverage.supports(request.profile)) {
      throw RouteRoutingException(
        code: RouteRoutingFailureCode.unsupportedProfile,
        operationId: request.operationId,
        message: 'The profile is unavailable in demo coverage.',
      );
    }
    if (!_graph.coverage.bounds.contains(request.from.position) ||
        !_graph.coverage.bounds.contains(request.to.position)) {
      throw RouteRoutingException(
        code: RouteRoutingFailureCode.outsideCoverage,
        operationId: request.operationId,
        message: 'An endpoint is outside demo coverage.',
      );
    }
  }

  DemoRouteGraphNode? _nearestNode(GeoPoint point) {
    DemoRouteGraphNode? nearest;
    var nearestDistance = double.infinity;
    final candidates = _graph.nodes.values.toList()
      ..sort(
        (DemoRouteGraphNode left, DemoRouteGraphNode right) =>
            left.id.compareTo(right.id),
      );
    for (final candidate in candidates) {
      final distance = GeoDistance.haversineMeters(point, candidate.position);
      if (distance < nearestDistance) {
        nearest = candidate;
        nearestDistance = distance;
      }
    }
    return nearestDistance <= _graph.coverage.maximumSnapDistanceMeters
        ? nearest
        : null;
  }

  List<String>? _shortestPath({
    required String operationId,
    required String fromNodeId,
    required String toNodeId,
    required RouteRoutingPreferences preferences,
    required RouteCancellationSignal? cancellationSignal,
  }) {
    final adjacency = _adjacency(preferences);
    final distances = <String, double>{fromNodeId: 0};
    final previous = <String, String>{};
    final frontier = <_FrontierEntry>[
      _FrontierEntry(nodeId: fromNodeId, distance: 0),
    ];
    final visited = <String>{};

    while (frontier.isNotEmpty) {
      _throwIfCancelled(operationId, cancellationSignal);
      frontier.sort(_compareFrontier);
      final current = frontier.removeAt(0);
      if (!visited.add(current.nodeId)) {
        continue;
      }
      if (current.nodeId == toNodeId) {
        return _buildPath(previous, fromNodeId, toNodeId);
      }

      for (final arc in adjacency[current.nodeId] ?? const <_GraphArc>[]) {
        if (visited.contains(arc.toNodeId)) {
          continue;
        }
        final candidateDistance = current.distance + arc.weight;
        final knownDistance = distances[arc.toNodeId];
        final knownPrevious = previous[arc.toNodeId];
        final isBetter =
            knownDistance == null ||
            candidateDistance < knownDistance - 0.000001 ||
            ((candidateDistance - knownDistance).abs() <= 0.000001 &&
                current.nodeId.compareTo(knownPrevious ?? '') < 0);
        if (!isBetter) {
          continue;
        }
        distances[arc.toNodeId] = candidateDistance;
        previous[arc.toNodeId] = current.nodeId;
        frontier.add(
          _FrontierEntry(nodeId: arc.toNodeId, distance: candidateDistance),
        );
      }
    }
    return null;
  }

  Map<String, List<_GraphArc>> _adjacency(RouteRoutingPreferences preferences) {
    final avoidStairs = _boolPreference(preferences, 'avoid_stairs');
    final preferUnpaved = _boolPreference(preferences, 'prefer_unpaved');
    final adjacency = <String, List<_GraphArc>>{};

    for (final edge in _graph.edges) {
      if (avoidStairs && edge.highway == 'steps') {
        continue;
      }
      final from = _graph.nodes[edge.fromNodeId]!;
      final to = _graph.nodes[edge.toNodeId]!;
      var weight = GeoDistance.haversineMeters(from.position, to.position);
      if (preferUnpaved) {
        weight *= _isUnpaved(edge.surface) ? 0.85 : 1.15;
      }
      adjacency
          .putIfAbsent(edge.fromNodeId, () => <_GraphArc>[])
          .add(_GraphArc(toNodeId: edge.toNodeId, weight: weight));
      if (edge.bidirectional) {
        adjacency
            .putIfAbsent(edge.toNodeId, () => <_GraphArc>[])
            .add(_GraphArc(toNodeId: edge.fromNodeId, weight: weight));
      }
    }
    for (final arcs in adjacency.values) {
      arcs.sort(
        (_GraphArc left, _GraphArc right) =>
            left.toNodeId.compareTo(right.toNodeId),
      );
    }
    return adjacency;
  }

  static bool _boolPreference(RouteRoutingPreferences preferences, String id) {
    final value = preferences.values[id];
    return value is RouteBoolPreferenceValue && value.value;
  }

  static bool _isUnpaved(String surface) => const <String>{
    'compacted',
    'dirt',
    'earth',
    'fine_gravel',
    'grass',
    'gravel',
    'ground',
    'sand',
    'unpaved',
  }.contains(surface);

  static List<String> _buildPath(
    Map<String, String> previous,
    String fromNodeId,
    String toNodeId,
  ) {
    final reversePath = <String>[toNodeId];
    var current = toNodeId;
    while (current != fromNodeId) {
      final predecessor = previous[current];
      if (predecessor == null) {
        return const <String>[];
      }
      reversePath.add(predecessor);
      current = predecessor;
    }
    return reversePath.reversed.toList(growable: false);
  }

  static List<GeoPoint> _withEndpoints(
    GeoPoint from,
    List<GeoPoint> graphPoints,
    GeoPoint to,
  ) {
    final points = <GeoPoint>[from];
    for (final point in graphPoints) {
      if (points.last != point) {
        points.add(point);
      }
    }
    if (points.last != to) {
      points.add(to);
    }
    return points;
  }

  void _recordCost(String operationId) {
    if (!_costPolicy.permitsRequests ||
        _costPolicy.costClass != CostClass.zeroCost ||
        _costPolicy.providerId != _graph.manifest.graphId) {
      throw RouteRoutingException(
        code: RouteRoutingFailureCode.providerRejected,
        operationId: operationId,
        message: 'Demo graph cost policy does not permit this request.',
      );
    }
    _costLedger.record(
      ProviderCostLedgerEntry(
        providerId: _costPolicy.providerId,
        operationId: operationId,
        costClass: _costPolicy.costClass,
        recordedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  static void _throwIfCancelled(
    String operationId,
    RouteCancellationSignal? signal,
  ) {
    if (signal?.isCancelled ?? false) {
      throw RouteRoutingException(
        code: RouteRoutingFailureCode.cancelled,
        operationId: operationId,
        message: 'The routing operation was cancelled.',
      );
    }
  }

  static int _compareFrontier(_FrontierEntry left, _FrontierEntry right) {
    final byDistance = left.distance.compareTo(right.distance);
    return byDistance != 0 ? byDistance : left.nodeId.compareTo(right.nodeId);
  }
}

class _GraphArc {
  const _GraphArc({required this.toNodeId, required this.weight});

  final String toNodeId;
  final double weight;
}

class _FrontierEntry {
  const _FrontierEntry({required this.nodeId, required this.distance});

  final String nodeId;
  final double distance;
}
