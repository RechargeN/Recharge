import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../application/auth_providers.dart';
import '../../application/controllers/auth_controller.dart';

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
      ref.read(authControllerProvider).trackAuthScreenViewed(
            sourceScreen: widget.sourceScreen,
            sourceAction: widget.sourceAction,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final authController = ref.watch(authControllerProvider);
    final state = authController.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Войти'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Войдите, чтобы сохранить и управлять',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Без входа вы можете смотреть события и места. Вход нужен для избранного, профиля и создания активностей.',
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Введите email',
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'Введите пароль',
                ),
                validator: _validatePassword,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isSubmitting ? null : _onSubmit,
                child: Text(
                  _isSubmitting ? 'Входим в аккаунт...' : 'Войти',
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () => context.go(RouteNames.discover),
                child: const Text('Продолжить как гость'),
              ),
              if (_inlineError != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  _inlineError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              if (!_isSubmitting && _inlineError == null && state.message != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  state.message!,
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
    if (text.isEmpty) return 'Введите email';
    final reg = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!reg.hasMatch(text)) return 'Введите корректный email';
    return null;
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Введите пароль';
    if (text.length < 8) return 'Пароль слишком короткий';
    return null;
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _inlineError = null);
      return;
    }

    final action = _actionFromString(widget.originAction);
    ref.read(authControllerProvider).setPendingTarget(
          action: action,
          originRoute: widget.originRoute,
        );

    setState(() {
      _isSubmitting = true;
      _inlineError = null;
    });

    final success = await ref.read(authControllerProvider).signIn(
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
      default:
        return ProtectedAction.none;
    }
  }

  String _routeWithFavoriteApplied(String route) {
    final Uri uri = Uri.parse(route);
    final Map<String, String> query = Map<String, String>.from(uri.queryParameters)
      ..['favoriteApplied'] = '1';
    return uri.replace(queryParameters: query).toString();
  }

  String? _normalizeOriginRoute(String? route) {
    if (route == null || route.isEmpty) return null;
    final decoded = Uri.decodeComponent(route);
    if (!decoded.startsWith('/')) return null;
    return decoded;
  }
}
