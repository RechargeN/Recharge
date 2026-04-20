import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../application/auth_providers.dart';
import '../../application/controllers/auth_controller.dart';
import '../widgets/auth_gate_sheet.dart';
import '../../../discover/presentation/widgets/discover_feed_section.dart';

class DiscoverHubPage extends ConsumerStatefulWidget {
  const DiscoverHubPage({
    super.key,
    required this.favoriteApplied,
  });

  final bool favoriteApplied;

  @override
  ConsumerState<DiscoverHubPage> createState() => _DiscoverHubPageState();
}

class _DiscoverHubPageState extends ConsumerState<DiscoverHubPage> {
  bool _snackShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.favoriteApplied && !_snackShown) {
      _snackShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сохранено в избранное')),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = ref.watch(authControllerProvider);
    final authState = authController.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Hub'),
        actions: <Widget>[
          if (authState.isAuthenticated)
            TextButton(
              onPressed: () async {
                await authController.signOut();
                if (context.mounted) {
                  context.go(RouteNames.discover);
                }
              },
              child: const Text('Выйти'),
            )
          else
            TextButton(
              onPressed: () => context.push(
                '${RouteNames.signIn}?sourceScreen=discover&sourceAction=manual_sign_in',
              ),
              child: const Text('Войти'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            authState.isAuthenticated
                ? 'Привет, ${authState.user?.email}'
                : 'Вы в режиме гостя',
          ),
          const SizedBox(height: 8),
          const Text(
            'Discover Feed',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push(RouteNames.discoverMap),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Открыть карту'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              if (authState.isAuthenticated) {
                context.push(RouteNames.favorites);
                return;
              }
              authController.trackAuthGateViewed(
                sourceScreen: 'discover',
                sourceAction: 'open_favorites',
              );
              await showAuthGateSheet(
                context,
                action: ProtectedAction.favorites,
                sourceScreen: 'discover',
                sourceAction: 'open_favorites',
                originRoute: RouteNames.favorites,
                onContinueAsGuest: () {
                  authController.trackGuestContinueClicked(
                    sourceScreen: 'discover',
                    sourceAction: 'open_favorites',
                  );
                },
              );
            },
            icon: const Icon(Icons.favorite_outline),
            label: const Text('Открыть избранное'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              if (authState.isAuthenticated) {
                context.push(RouteNames.notifications);
                return;
              }
              authController.trackAuthGateViewed(
                sourceScreen: 'discover',
                sourceAction: 'open_notifications',
              );
              await showAuthGateSheet(
                context,
                action: ProtectedAction.notifications,
                sourceScreen: 'discover',
                sourceAction: 'open_notifications',
                originRoute: RouteNames.notifications,
                onContinueAsGuest: () {
                  authController.trackGuestContinueClicked(
                    sourceScreen: 'discover',
                    sourceAction: 'open_notifications',
                  );
                },
              );
            },
            icon: const Icon(Icons.notifications_outlined),
            label: const Text('Открыть уведомления'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              if (authState.isAuthenticated) {
                context.push(RouteNames.profile);
                return;
              }
              authController.trackAuthGateViewed(
                sourceScreen: 'discover',
                sourceAction: 'open_profile',
              );
              await showAuthGateSheet(
                context,
                action: ProtectedAction.profile,
                sourceScreen: 'discover',
                sourceAction: 'open_profile',
                originRoute: RouteNames.profile,
                onContinueAsGuest: () {
                  authController.trackGuestContinueClicked(
                    sourceScreen: 'discover',
                    sourceAction: 'open_profile',
                  );
                },
              );
            },
            child: const Text('Открыть профиль'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              if (authState.isAuthenticated) {
                context.push(RouteNames.create);
                return;
              }
              authController.trackAuthGateViewed(
                sourceScreen: 'discover',
                sourceAction: 'open_create',
              );
              await showAuthGateSheet(
                context,
                action: ProtectedAction.create,
                sourceScreen: 'discover',
                sourceAction: 'open_create',
                originRoute: RouteNames.create,
                onContinueAsGuest: () {
                  authController.trackGuestContinueClicked(
                    sourceScreen: 'discover',
                    sourceAction: 'open_create',
                  );
                },
              );
            },
            child: const Text('Перейти в create'),
          ),
          const SizedBox(height: 20),
          DiscoverFeedSection(
            onOpenDetails: (String itemId) {
              context.push('${RouteNames.discoverDetails}/$itemId');
            },
          ),
          if (authState.message != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              authState.message!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}
