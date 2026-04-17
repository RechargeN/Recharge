import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/telemetry/analytics_service.dart';
import 'di/service_locator.dart';
import 'observers/app_lifecycle_observer.dart';
import 'router/app_router.dart';

class RechargeApp extends ConsumerStatefulWidget {
  const RechargeApp({super.key});

  @override
  ConsumerState<RechargeApp> createState() => _RechargeAppState();
}

class _RechargeAppState extends ConsumerState<RechargeApp> {
  late final AppLifecycleObserver _lifecycleObserver;

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = AppLifecycleObserver(
      analyticsService: sl<AnalyticsService>(),
    );
    _lifecycleObserver.attach();
  }

  @override
  void dispose() {
    _lifecycleObserver.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Recharge',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1C9C74)),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
