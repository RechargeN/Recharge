import 'package:flutter/services.dart';

import 'demo_route_graph.dart';

class DemoRouteGraphAssetLoader {
  DemoRouteGraphAssetLoader({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  static const String defaultAssetPath =
      'assets/route_demo/riga_mezaparks_graph_v1.json';

  final AssetBundle _bundle;

  Future<DemoRouteGraph> load({String assetPath = defaultAssetPath}) async {
    final source = await _bundle.loadString(assetPath);
    return DemoRouteGraph.fromJsonString(source);
  }
}
