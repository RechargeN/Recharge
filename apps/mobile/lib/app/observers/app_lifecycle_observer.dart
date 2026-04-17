import 'package:flutter/widgets.dart';

import '../../core/telemetry/analytics_service.dart';

class AppLifecycleObserver with WidgetsBindingObserver {
  AppLifecycleObserver({
    required AnalyticsService analyticsService,
  }) : _analyticsService = analyticsService;

  final AnalyticsService _analyticsService;
  bool _isAttached = false;

  void attach() {
    if (_isAttached) return;
    WidgetsBinding.instance.addObserver(this);
    _isAttached = true;
  }

  void detach() {
    if (!_isAttached) return;
    WidgetsBinding.instance.removeObserver(this);
    _isAttached = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _analyticsService.track(
      'app_lifecycle_changed',
      params: <String, Object?>{
        'state': state.name,
      },
    );
  }
}

