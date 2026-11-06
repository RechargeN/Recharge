import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/application/auth_providers.dart';

class AuthLifecycleBoundary extends ConsumerStatefulWidget {
  const AuthLifecycleBoundary({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<AuthLifecycleBoundary> createState() =>
      _AuthLifecycleBoundaryState();
}

class _AuthLifecycleBoundaryState extends ConsumerState<AuthLifecycleBoundary>
    with WidgetsBindingObserver {
  bool _backgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(authControllerProvider);
    if (!controller.supportsGoogleSignIn) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _backgrounded = true;
        controller.suspendForBackground();
      case AppLifecycleState.resumed:
        if (!_backgrounded) return;
        _backgrounded = false;
        unawaited(controller.restoreAfterBackground());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // Transient: system overlays such as the Google account picker
        // (Credential Manager) or the notification shade. A sign-in in progress
        // must not be invalidated by them (A34, 2026-11-06).
        return;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
