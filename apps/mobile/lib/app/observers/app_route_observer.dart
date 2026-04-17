import 'package:flutter/widgets.dart';

import '../../core/telemetry/analytics_service.dart';

class AppRouteObserver extends NavigatorObserver {
  AppRouteObserver({
    required AnalyticsService analyticsService,
  }) : _analyticsService = analyticsService;

  final AnalyticsService _analyticsService;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _trackRouteEvent('app_route_pushed', route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute == null) return;
    _trackRouteEvent('app_route_replaced', newRoute, oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) return;
    _trackRouteEvent('app_route_returned', previousRoute, route);
  }

  void _trackRouteEvent(
    String eventName,
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    _analyticsService.track(
      eventName,
      params: <String, Object?>{
        'route': _routeName(route),
        'from_route': previousRoute == null ? null : _routeName(previousRoute),
      },
    );
  }

  String _routeName(Route<dynamic> route) {
    final String? name = route.settings.name;
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return route.runtimeType.toString();
  }
}
