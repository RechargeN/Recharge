import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/localization/l10n_context.dart';
import '../../application/auth_providers.dart';
import '../../application/controllers/auth_controller.dart';
import '../../application/state/auth_state.dart';
import '../auth_messages.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({
    super.key,
    required this.originRoute,
    required this.originAction,
    required this.sourceScreen,
    required this.sourceAction,
  });

  final String? originRoute;
  final String? originAction;
  final String sourceScreen;
  final String sourceAction;

  /// Stable keys for tests; never derived from the localized labels.
  static const Key emailFieldKey = ValueKey<String>('sign-in-email');
  static const Key passwordFieldKey = ValueKey<String>('sign-in-password');
  static const Key submitButtonKey = ValueKey<String>('sign-in-submit');

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isSubmitting = false;
  String? _inlineError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(authControllerProvider)
          .trackAuthScreenViewed(
            sourceScreen: widget.sourceScreen,
            sourceAction: widget.sourceAction,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final authController = ref.watch(authControllerProvider);
    final state = authController.state;
    final AppLocalizations l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.commonSignIn)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.authSignInHeadline,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(l10n.authSignInBody),
              const SizedBox(height: 24),
              if (authController.supportsGoogleSignIn) ...<Widget>[
                FilledButton(
                  key: SignInPage.submitButtonKey,
                  onPressed: _isSubmitting || state.status == AuthStatus.loading
                      ? null
                      : _onGoogleSubmit,
                  child: Text(
                    _isSubmitting
                        ? l10n.authSigningIn
                        : 'Google', // l10n-ignore: provider brand
                  ),
                ),
              ] else ...<Widget>[
                TextFormField(
                  key: SignInPage.emailFieldKey,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.authEmailLabel,
                    hintText: l10n.authEmailHint,
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: SignInPage.passwordFieldKey,
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.authPasswordLabel,
                    hintText: l10n.authPasswordHint,
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: SignInPage.submitButtonKey,
                  onPressed: _isSubmitting ? null : _onSubmit,
                  child: Text(
                    _isSubmitting ? l10n.authSigningIn : l10n.commonSignIn,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () => context.go(RouteNames.discover),
                child: Text(l10n.commonContinueAsGuest),
              ),
              if (_inlineError != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  authMessage(l10n, _inlineError!),
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              if (!_isSubmitting &&
                  _inlineError == null &&
                  state.message != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  authMessage(l10n, state.message!),
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return context.l10n.authEmailRequired;
    final reg = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!reg.hasMatch(text)) return context.l10n.authEmailInvalid;
    return null;
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return context.l10n.authPasswordRequired;
    if (text.length < 8) return context.l10n.authPasswordTooShort;
    return null;
  }

  Future<void> _onGoogleSubmit() async {
    final controller = ref.read(authControllerProvider);
    controller.setPendingTarget(
      action: _actionFromString(widget.originAction),
      originRoute: widget.originRoute,
    );
    setState(() {
      _isSubmitting = true;
      _inlineError = null;
    });
    final success = await controller.signInWithGoogle();
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _inlineError = success ? null : controller.state.message;
    });
    if (success) {
      _navigateAfterSignIn();
    }
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _inlineError = null);
      return;
    }

    final action = _actionFromString(widget.originAction);
    ref
        .read(authControllerProvider)
        .setPendingTarget(action: action, originRoute: widget.originRoute);

    setState(() {
      _isSubmitting = true;
      _inlineError = null;
    });

    final success = await ref
        .read(authControllerProvider)
        .signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          sourceScreen: widget.sourceScreen,
          sourceAction: widget.sourceAction,
        );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (!success) {
      final message = ref.read(authControllerProvider).state.message;
      setState(() => _inlineError = message);
      return;
    }

    _navigateAfterSignIn();
  }

  void _navigateAfterSignIn() {
    final normalizedOrigin = _normalizeOriginRoute(widget.originRoute);
    final authController = ref.read(authControllerProvider);
    switch (authController.pendingAction) {
      case ProtectedAction.favorite:
        authController.clearPendingTarget();
        context.go(
          _routeWithFavoriteApplied(normalizedOrigin ?? RouteNames.discover),
        );
        break;
      case ProtectedAction.favorites:
        authController.clearPendingTarget();
        context.go(normalizedOrigin ?? RouteNames.favorites);
        break;
      case ProtectedAction.notifications:
        authController.clearPendingTarget();
        context.go(normalizedOrigin ?? RouteNames.notifications);
        break;
      case ProtectedAction.create:
      case ProtectedAction.profile:
      case ProtectedAction.report:
      case ProtectedAction.visit:
        authController.clearPendingTarget();
        context.go(normalizedOrigin ?? RouteNames.discover);
        break;
      case ProtectedAction.none:
        authController.clearPendingTarget();
        context.go(normalizedOrigin ?? RouteNames.discover);
        break;
    }
  }

  ProtectedAction _actionFromString(String? value) {
    switch (value) {
      case 'favorite':
        return ProtectedAction.favorite;
      case 'favorites':
        return ProtectedAction.favorites;
      case 'notifications':
        return ProtectedAction.notifications;
      case 'create':
        return ProtectedAction.create;
      case 'profile':
        return ProtectedAction.profile;
      case 'report':
        return ProtectedAction.report;
      case 'visit':
        return ProtectedAction.visit;
      default:
        return ProtectedAction.none;
    }
  }

  String _routeWithFavoriteApplied(String route) {
    final Uri uri = Uri.parse(route);
    final Map<String, String> query = Map<String, String>.from(
      uri.queryParameters,
    )..['favoriteApplied'] = '1';
    return uri.replace(queryParameters: query).toString();
  }

  String? _normalizeOriginRoute(String? route) {
    if (route == null || route.isEmpty) return null;
    final decoded = Uri.decodeComponent(route);
    if (!decoded.startsWith('/')) return null;
    return decoded;
  }
}
