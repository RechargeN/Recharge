import 'dart:convert';

import '../../../../core/geo/geo_bounds.dart';
import '../../../../core/geo/geo_point.dart';
import '../../domain/entities/route_draft_data.dart';
import 'demo_coverage_config.dart';

class DemoRouteGraphFormatException implements Exception {
  const DemoRouteGraphFormatException(this.message);

  final String message;

  @override
  String toString() => 'DemoRouteGraphFormatException: $message';
}

class DemoRouteGraphManifest {
  const DemoRouteGraphManifest({
    required this.graphId,
    required this.graphVersion,
    required this.dataVersion,
    required this.generatedAtUtc,
    required this.sourceId,
    required this.sourceUrl,
    required this.sourceSnapshotSha256,
    required this.attribution,
    required this.licenseId,
    required this.licenseUrl,
    required this.copyrightUrl,
    required this.algorithmVersion,
    required this.weightingVersion,
  });

  final String graphId;
  final String graphVersion;
  final String dataVersion;
  final DateTime generatedAtUtc;
  final String sourceId;
  final String sourceUrl;
  final String sourceSnapshotSha256;
  final String attribution;
  final String licenseId;
  final String licenseUrl;
  final String copyrightUrl;
  final String algorithmVersion;
  final String weightingVersion;

  RouteProviderReference get providerReference => RouteProviderReference(
    code: 'demoGraph',
    attribution: attribution,
    licenseId: licenseId,
    dataVersion: dataVersion,
    allowsPublication: false,
  );

  bool get isValid =>
      graphId.trim().isNotEmpty &&
      graphVersion.trim().isNotEmpty &&
      dataVersion.trim().isNotEmpty &&
      generatedAtUtc.isUtc &&
      sourceId.trim().isNotEmpty &&
      Uri.tryParse(sourceUrl)?.hasScheme == true &&
      RegExp(r'^[0-9a-f]{64}$').hasMatch(sourceSnapshotSha256) &&
      attribution.trim().isNotEmpty &&
      licenseId.trim().isNotEmpty &&
      Uri.tryParse(licenseUrl)?.hasScheme == true &&
      Uri.tryParse(copyrightUrl)?.hasScheme == true &&
      algorithmVersion.trim().isNotEmpty &&
      weightingVersion.trim().isNotEmpty;
}

class DemoRouteGraphNode {
  const DemoRouteGraphNode({required this.id, required this.position});

  final String id;
  final GeoPoint position;
}

class DemoRouteGraphEdge {
  const DemoRouteGraphEdge({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.bidirectional,
    required this.highway,
    required this.surface,
  });

  final String id;
  final String fromNodeId;
  final String toNodeId;
  final bool bidirectional;
  final String highway;
  final String surface;
}

class DemoRouteGraph {
  DemoRouteGraph({
    required this.schemaVersion,
    required this.manifest,
    required this.coverage,
    required Iterable<DemoRouteGraphNode> nodes,
    required Iterable<DemoRouteGraphEdge> edges,
  }) : nodes = Map<String, DemoRouteGraphNode>.unmodifiable(_indexNodes(nodes)),
       edges = List<DemoRouteGraphEdge>.unmodifiable(edges);

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final DemoRouteGraphManifest manifest;
  final DemoCoverageConfig coverage;
  final Map<String, DemoRouteGraphNode> nodes;
  final List<DemoRouteGraphEdge> edges;

  factory DemoRouteGraph.fromJsonString(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) {
        throw const DemoRouteGraphFormatException(
          'Root value must be an object.',
        );
      }
      return DemoRouteGraph.fromJson(Map<String, Object?>.from(decoded));
    } on DemoRouteGraphFormatException {
      rethrow;
    } on Object catch (error) {
      throw DemoRouteGraphFormatException('Invalid graph JSON: $error');
    }
  }

  factory DemoRouteGraph.fromJson(Map<String, Object?> json) {
    try {
      final schemaVersion = _integer(json, 'schemaVersion');
      if (schemaVersion != currentSchemaVersion) {
        throw DemoRouteGraphFormatException(
          'Unsupported schema version $schemaVersion.',
        );
      }

      final manifestJson = _map(json, 'manifest');
      final coverageJson = _map(json, 'coverage');
      final bounds = GeoBounds.fromMap(_map(coverageJson, 'bounds'));
      final manifest = DemoRouteGraphManifest(
        graphId: _string(manifestJson, 'graphId'),
        graphVersion: _string(manifestJson, 'graphVersion'),
        dataVersion: _string(manifestJson, 'dataVersion'),
        generatedAtUtc: DateTime.parse(
          _string(manifestJson, 'generatedAtUtc'),
        ).toUtc(),
        sourceId: _string(manifestJson, 'sourceId'),
        sourceUrl: _string(manifestJson, 'sourceUrl'),
        sourceSnapshotSha256: _string(manifestJson, 'sourceSnapshotSha256'),
        attribution: _string(manifestJson, 'attribution'),
        licenseId: _string(manifestJson, 'licenseId'),
        licenseUrl: _string(manifestJson, 'licenseUrl'),
        copyrightUrl: _string(manifestJson, 'copyrightUrl'),
        algorithmVersion: _string(manifestJson, 'algorithmVersion'),
        weightingVersion: _string(manifestJson, 'weightingVersion'),
      );
      final profiles = _list(coverageJson, 'supportedProfiles')
          .map((Object? value) {
            final profile = Map<String, Object?>.from(value! as Map);
            return RouteProfileRef(
              id: _string(profile, 'id'),
              version: _integer(profile, 'version'),
            );
          })
          .toList(growable: false);
      final coverage = DemoCoverageConfig(
        id: _string(coverageJson, 'id'),
        version: _integer(coverageJson, 'version'),
        graphId: manifest.graphId,
        graphVersion: manifest.graphVersion,
        bounds: bounds,
        maximumSnapDistanceMeters: _number(
          coverageJson,
          'maximumSnapDistanceMeters',
        ),
        supportedProfiles: profiles,
      );
      final nodes = _list(json, 'nodes')
          .map((Object? value) {
            final node = Map<String, Object?>.from(value! as Map);
            return DemoRouteGraphNode(
              id: _string(node, 'id'),
              position: GeoPoint.fromMap(_map(node, 'position')),
            );
          })
          .toList(growable: false);
      final edges = _list(json, 'edges')
          .map((Object? value) {
            final edge = Map<String, Object?>.from(value! as Map);
            return DemoRouteGraphEdge(
              id: _string(edge, 'id'),
              fromNodeId: _string(edge, 'fromNodeId'),
              toNodeId: _string(edge, 'toNodeId'),
              bidirectional: _boolean(edge, 'bidirectional'),
              highway: _string(edge, 'highway'),
              surface: _string(edge, 'surface'),
            );
          })
          .toList(growable: false);

      final graph = DemoRouteGraph(
        schemaVersion: schemaVersion,
        manifest: manifest,
        coverage: coverage,
        nodes: nodes,
        edges: edges,
      );
      graph.validate();
      return graph;
    } on DemoRouteGraphFormatException {
      rethrow;
    } on Object catch (error) {
      throw DemoRouteGraphFormatException('Invalid graph payload: $error');
    }
  }

  void validate() {
    if (!manifest.isValid || !coverage.isValid) {
      throw const DemoRouteGraphFormatException(
        'Manifest or coverage is invalid.',
      );
    }
    if (manifest.graphId != coverage.graphId ||
        manifest.graphVersion != coverage.graphVersion) {
      throw const DemoRouteGraphFormatException(
        'Manifest and coverage graph identity differ.',
      );
    }
    if (nodes.length < 2 || edges.isEmpty) {
      throw const DemoRouteGraphFormatException('Graph is empty.');
    }
    if (nodes.values.any(
      (DemoRouteGraphNode node) =>
          node.id.trim().isEmpty ||
          !node.position.isValid ||
          !coverage.bounds.contains(node.position),
    )) {
      throw const DemoRouteGraphFormatException(
        'Graph contains an invalid or out-of-coverage node.',
      );
    }

    final edgeIds = <String>{};
    for (final edge in edges) {
      if (edge.id.trim().isEmpty ||
          !edgeIds.add(edge.id) ||
          edge.fromNodeId == edge.toNodeId ||
          !nodes.containsKey(edge.fromNodeId) ||
          !nodes.containsKey(edge.toNodeId) ||
          edge.highway.trim().isEmpty ||
          edge.surface.trim().isEmpty) {
        throw DemoRouteGraphFormatException('Invalid edge ${edge.id}.');
      }
    }
  }

  static Map<String, Object?> _map(Map<String, Object?> json, String key) =>
      Map<String, Object?>.from(json[key]! as Map);

  static List<Object?> _list(Map<String, Object?> json, String key) =>
      List<Object?>.from(json[key]! as List);

  static String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw DemoRouteGraphFormatException('$key must be a string.');
    }
    return value;
  }

  static int _integer(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! num || value.toInt() != value) {
      throw DemoRouteGraphFormatException('$key must be an integer.');
    }
    return value.toInt();
  }

  static double _number(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! num || !value.toDouble().isFinite) {
      throw DemoRouteGraphFormatException('$key must be a finite number.');
    }
    return value.toDouble();
  }

  static bool _boolean(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! bool) {
      throw DemoRouteGraphFormatException('$key must be a boolean.');
    }
    return value;
  }

  static Map<String, DemoRouteGraphNode> _indexNodes(
    Iterable<DemoRouteGraphNode> source,
  ) {
    final indexed = <String, DemoRouteGraphNode>{};
    for (final node in source) {
      if (indexed.containsKey(node.id)) {
        throw DemoRouteGraphFormatException('Duplicate node id ${node.id}.');
      }
      indexed[node.id] = node;
    }
    return indexed;
  }
}
