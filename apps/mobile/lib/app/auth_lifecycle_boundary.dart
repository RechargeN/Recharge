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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(authControllerProvider);
    if (!controller.supportsGoogleSignIn) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(controller.restoreSession());
    } else {
      controller.suspendServerAuthority();
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
