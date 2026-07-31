import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/config/provider_cost_policy.dart';
import 'package:recharge/core/geo/geo_bounds.dart';
import 'package:recharge/core/geo/geo_point.dart';
import 'package:recharge/core/telemetry/provider_cost_ledger.dart';
import 'package:recharge/features/create/data/routing/demo_coverage_config.dart';
import 'package:recharge/features/create/data/routing/demo_route_graph.dart';
import 'package:recharge/features/create/data/routing/demo_route_graph_adapter.dart';
import 'package:recharge/features/create/data/routing/demo_route_graph_asset_loader.dart';
import 'package:recharge/features/create/domain/entities/route_draft_data.dart';
import 'package:recharge/features/create/domain/repositories/route_routing_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DemoRouteGraph graph;

  setUpAll(() async {
    graph = await DemoRouteGraphAssetLoader().load();
  });

  group('DemoRouteGraph asset', () {
    test('loads a bounded OSM-derived graph with legal provenance', () {
      expect(graph.nodes, hasLength(44));
      expect(graph.edges, hasLength(53));
      expect(graph.manifest.graphId, 'riga-mezaparks-walking');
      expect(graph.manifest.sourceId, 'openstreetmap');
      expect(graph.manifest.attribution, '© OpenStreetMap contributors');
      expect(graph.manifest.licenseId, 'ODbL-1.0');
      expect(graph.manifest.sourceSnapshotSha256, hasLength(64));
      expect(graph.manifest.providerReference.allowsPublication, isFalse);
      expect(
        graph.manifest.sourceUrl,
        isNot(startsWith('https://tile.openstreetmap.org')),
      );
    });

    test('rejects a future graph schema', () {
      expect(
        () => DemoRouteGraph.fromJson(<String, Object?>{'schemaVersion': 2}),
        throwsA(isA<DemoRouteGraphFormatException>()),
      );
    });

    test('rejects duplicate graph node ids', () {
      expect(
        () => DemoRouteGraph(
          schemaVersion: 1,
          manifest: graph.manifest,
          coverage: graph.coverage,
          nodes: <DemoRouteGraphNode>[
            graph.nodes.values.first,
            graph.nodes.values.first,
          ],
          edges: graph.edges,
        ),
        throwsA(isA<DemoRouteGraphFormatException>()),
      );
    });
  });

  group('DemoRouteGraphAdapter', () {
    test(
      'routes along real graph edges and preserves request identity',
      () async {
        final ledger = InMemoryProviderCostLedger();
        final adapter = DemoRouteGraphAdapter(graph: graph, costLedger: ledger);
        final from = graph.nodes['osm-node-1694684151']!;
        final to = graph.nodes['osm-node-10766543461']!;
        final request = _request(from.position, to.position);

        final result = await adapter.route(request);

        expect(result.operationId, request.operationId);
        expect(
          result.expectedGeometryRevision,
          request.expectedGeometryRevision,
        );
        expect(result.requestFingerprint, request.requestFingerprint);
        expect(result.geometry.points.first, from.position);
        expect(result.geometry.points.last, to.position);
        expect(result.geometry.points.length, greaterThan(2));
        expect(result.geometry.matchesCanonicalRepresentation, isTrue);
        expect(result.provenance.sourceId, 'demoGraph');
        expect(result.provenance.provider?.code, 'demoGraph');
        expect(result.provenance.provider?.allowsPublication, isFalse);
        expect(result.appliedPreferenceIds, <String>['avoid_stairs']);
        expect(result.unsupportedPreferenceIds, <String>['future_option']);
        expect(_allStepsFollowGraph(result.geometry.points, graph), isTrue);
        expect(ledger.entries, hasLength(1));
        expect(ledger.meteredCallCount, 0);
      },
    );

    test(
      'replays identical geometry and provenance deterministically',
      () async {
        final ledger = InMemoryProviderCostLedger();
        final adapter = DemoRouteGraphAdapter(graph: graph, costLedger: ledger);
        final request = _request(
          graph.nodes['osm-node-1694684151']!.position,
          graph.nodes['osm-node-10766543461']!.position,
        );

        final first = await adapter.route(request);
        final second = await adapter.route(request);

        expect(second.geometry.encodedPolyline, first.geometry.encodedPolyline);
        expect(second.geometry.geometryHash, first.geometry.geometryHash);
        expect(second.geometry.points, first.geometry.points);
        expect(second.provenance.createdAtUtc, first.provenance.createdAtUtc);
        expect(
          second.provenance.algorithmVersion,
          first.provenance.algorithmVersion,
        );
        expect(ledger.entries, hasLength(2));
        expect(ledger.meteredCallCount, 0);
      },
    );

    test(
      'returns typed outside-coverage failure without a fake line',
      () async {
        final adapter = DemoRouteGraphAdapter(graph: graph);
        final request = _request(
          const GeoPoint(latitude: 56.9496, longitude: 24.1052),
          graph.nodes['osm-node-10766543461']!.position,
        );

        await expectLater(
          adapter.route(request),
          throwsA(
            isA<RouteRoutingException>().having(
              (RouteRoutingException error) => error.code,
              'code',
              RouteRoutingFailureCode.outsideCoverage,
            ),
          ),
        );
      },
    );

    test('returns typed no-path failure for disconnected components', () async {
      final disconnected = _disconnectedGraph();
      final adapter = DemoRouteGraphAdapter(graph: disconnected);

      await expectLater(
        adapter.route(
          _request(
            disconnected.nodes['a']!.position,
            disconnected.nodes['d']!.position,
          ),
        ),
        throwsA(
          isA<RouteRoutingException>().having(
            (RouteRoutingException error) => error.code,
            'code',
            RouteRoutingFailureCode.noPath,
          ),
        ),
      );
    });

    test('cancels during graph traversal with a typed failure', () async {
      final adapter = DemoRouteGraphAdapter(graph: graph);
      final request = _request(
        graph.nodes['osm-node-1694684151']!.position,
        graph.nodes['osm-node-10766543461']!.position,
        cancellationSignal: _CancelAfterReads(2),
      );

      await expectLater(
        adapter.route(request),
        throwsA(
          isA<RouteRoutingException>().having(
            (RouteRoutingException error) => error.code,
            'code',
            RouteRoutingFailureCode.cancelled,
          ),
        ),
      );
    });

    test('rejects unsupported profiles explicitly', () async {
      final adapter = DemoRouteGraphAdapter(graph: graph);
      final request = _request(
        graph.nodes['osm-node-1694684151']!.position,
        graph.nodes['osm-node-10766543461']!.position,
        profile: const RouteProfileRef(id: 'cycling', version: 1),
      );

      await expectLater(
        adapter.route(request),
        throwsA(
          isA<RouteRoutingException>().having(
            (RouteRoutingException error) => error.code,
            'code',
            RouteRoutingFailureCode.unsupportedProfile,
          ),
        ),
      );
    });

    test('does not pretend that route generation exists in RTE-04', () async {
      final ledger = InMemoryProviderCostLedger();
      final adapter = DemoRouteGraphAdapter(graph: graph, costLedger: ledger);

      await expectLater(
        adapter.generate(
          RouteGenerationRequest(
            operationId: 'generate-1',
            expectedGeometryRevision: 1,
            requestFingerprint: 'generate-fingerprint',
            origin: graph.nodes.values.first.position,
            profile: const RouteProfileRef(id: 'walking', version: 1),
            preferences: RouteRoutingPreferences(),
            targetDistanceMeters: 1000,
            shape: RouteShape.loop,
          ),
        ),
        throwsA(
          isA<RouteRoutingException>().having(
            (RouteRoutingException error) => error.code,
            'code',
            RouteRoutingFailureCode.providerRejected,
          ),
        ),
      );
      expect(ledger.meteredCallCount, 0);
    });

    test('refuses a metered policy even when it is enabled', () async {
      final ledger = InMemoryProviderCostLedger();
      final adapter = DemoRouteGraphAdapter(
        graph: graph,
        costLedger: ledger,
        costPolicy: ProviderCostPolicy(
          providerId: graph.manifest.graphId,
          version: 1,
          costClass: CostClass.metered,
          enabled: true,
          dailyRequestLimit: 10,
        ),
      );

      await expectLater(
        adapter.route(
          _request(
            graph.nodes['osm-node-1694684151']!.position,
            graph.nodes['osm-node-10766543461']!.position,
          ),
        ),
        throwsA(
          isA<RouteRoutingException>().having(
            (RouteRoutingException error) => error.code,
            'code',
            RouteRoutingFailureCode.providerRejected,
          ),
        ),
      );
      expect(ledger.entries, isEmpty);
    });
  });
}

RouteRoutingRequest _request(
  GeoPoint from,
  GeoPoint to, {
  RouteProfileRef profile = const RouteProfileRef(id: 'walking', version: 1),
  RouteCancellationSignal? cancellationSignal,
}) => RouteRoutingRequest(
  operationId: 'route-operation-1',
  expectedGeometryRevision: 8,
  requestFingerprint: 'route-fingerprint-1',
  from: RouteRoutingEndpoint(anchorId: 'anchor-a', position: from),
  to: RouteRoutingEndpoint(anchorId: 'anchor-b', position: to),
  profile: profile,
  preferences: RouteRoutingPreferences(
    values: const <String, RoutePreferenceValue>{
      'avoid_stairs': RouteBoolPreferenceValue(true),
      'future_option': RouteBoolPreferenceValue(true),
    },
  ),
  cancellationSignal: cancellationSignal,
);

bool _allStepsFollowGraph(List<GeoPoint> points, DemoRouteGraph graph) {
  final nodeByPoint = <GeoPoint, String>{
    for (final node in graph.nodes.values) node.position: node.id,
  };
  final edges = <String>{
    for (final edge in graph.edges) ...<String>{
      '${edge.fromNodeId}>${edge.toNodeId}',
      if (edge.bidirectional) '${edge.toNodeId}>${edge.fromNodeId}',
    },
  };
  for (var index = 0; index < points.length - 1; index += 1) {
    final fromNodeId = nodeByPoint[points[index]];
    final toNodeId = nodeByPoint[points[index + 1]];
    if (fromNodeId == null ||
        toNodeId == null ||
        !edges.contains('$fromNodeId>$toNodeId')) {
      return false;
    }
  }
  return true;
}

DemoRouteGraph _disconnectedGraph() {
  const bounds = GeoBounds(
    southwest: GeoPoint(latitude: 56.9995, longitude: 24.1440),
    northeast: GeoPoint(latitude: 57.0035, longitude: 24.1490),
  );
  final manifest = DemoRouteGraphManifest(
    graphId: 'disconnected',
    graphVersion: 'v1',
    dataVersion: 'fixture-v1',
    generatedAtUtc: DateTime.utc(2026, 7, 24),
    sourceId: 'test',
    sourceUrl: 'https://example.test/source',
    sourceSnapshotSha256:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    attribution: 'Test fixture',
    licenseId: 'test-only',
    licenseUrl: 'https://example.test/license',
    copyrightUrl: 'https://example.test/copyright',
    algorithmVersion: 'dijkstra-v1',
    weightingVersion: 'distance-v1',
  );
  return DemoRouteGraph(
    schemaVersion: 1,
    manifest: manifest,
    coverage: DemoCoverageConfig(
      id: 'disconnected-coverage',
      version: 1,
      graphId: manifest.graphId,
      graphVersion: manifest.graphVersion,
      bounds: bounds,
      maximumSnapDistanceMeters: 20,
      supportedProfiles: const <RouteProfileRef>[
        RouteProfileRef(id: 'walking', version: 1),
      ],
    ),
    nodes: const <DemoRouteGraphNode>[
      DemoRouteGraphNode(
        id: 'a',
        position: GeoPoint(latitude: 57.0000, longitude: 24.1450),
      ),
      DemoRouteGraphNode(
        id: 'b',
        position: GeoPoint(latitude: 57.0001, longitude: 24.1451),
      ),
      DemoRouteGraphNode(
        id: 'c',
        position: GeoPoint(latitude: 57.0020, longitude: 24.1470),
      ),
      DemoRouteGraphNode(
        id: 'd',
        position: GeoPoint(latitude: 57.0021, longitude: 24.1471),
      ),
    ],
    edges: const <DemoRouteGraphEdge>[
      DemoRouteGraphEdge(
        id: 'ab',
        fromNodeId: 'a',
        toNodeId: 'b',
        bidirectional: true,
        highway: 'path',
        surface: 'ground',
      ),
      DemoRouteGraphEdge(
        id: 'cd',
        fromNodeId: 'c',
        toNodeId: 'd',
        bidirectional: true,
        highway: 'path',
        surface: 'ground',
      ),
    ],
  );
}

class _CancelAfterReads implements RouteCancellationSignal {
  _CancelAfterReads(this.maximumReads);

  final int maximumReads;
  int _reads = 0;

  @override
  bool get isCancelled {
    _reads += 1;
    return _reads >= maximumReads;
  }
}
