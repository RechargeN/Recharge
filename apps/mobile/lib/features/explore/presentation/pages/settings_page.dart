import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/controllers/explore_controller.dart';
import '../../application/explore_providers.dart';
import '../../application/state/explore_state.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authController = ref.watch(authControllerProvider);
    final user = authController.state.user;
    final ExploreController exploreController = ref.watch(exploreControllerProvider);
    final ExploreState state = exploreController.state;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Требуется авторизация')),
      );
    }

    if (!state.isLoaded || state.userId != user.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(exploreControllerProvider).ensureLoaded(
              userId: user.id,
              email: user.email,
              role: user.role,
              favoritesCount: state.favoritesCount,
            );
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: switch (state.status) {
        ExploreStatus.initial || ExploreStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
        ExploreStatus.error => const Center(
            child: Text('Не удалось загрузить настройки'),
          ),
        ExploreStatus.ready || ExploreStatus.saving => ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              DropdownButtonFormField<String>(
                value: state.settings.language,
                decoration: const InputDecoration(
                  labelText: 'Language',
                  border: OutlineInputBorder(),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'ru', child: Text('Русский')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'lv', child: Text('Latviešu')),
                ],
                onChanged: (String? value) {
                  if (value != null) {
                    exploreController.updateLanguage(value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: state.settings.currency,
                decoration: const InputDecoration(
                  labelText: 'Currency',
                  border: OutlineInputBorder(),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                ],
                onChanged: (String? value) {
                  if (value != null) {
                    exploreController.updateCurrency(value);
                  }
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Notifications'),
                value: state.settings.notificationsEnabled,
                onChanged: exploreController.updateNotifications,
              ),
              const Divider(height: 28),
              ListTile(
                title: const Text('Support / Help'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _showLinkDialog(
                  context,
                  title: 'Support / Help',
                  url: 'https://example.com/support',
                ),
              ),
              ListTile(
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _showLinkDialog(
                  context,
                  title: 'Privacy Policy',
                  url: 'https://example.com/privacy',
                ),
              ),
              ListTile(
                title: const Text('Terms of Service'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _showLinkDialog(
                  context,
                  title: 'Terms of Service',
                  url: 'https://example.com/terms',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () async {
                  await authController.signOut();
                  if (context.mounted) {
                    context.go(RouteNames.discover);
                  }
                },
                child: const Text('Выйти'),
              ),
            ],
          ),
      },
    );
  }

  void _showLinkDialog(
    BuildContext context, {
    required String title,
    required String url,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(url),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
