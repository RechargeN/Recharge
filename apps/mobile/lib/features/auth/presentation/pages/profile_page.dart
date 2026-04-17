import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../application/auth_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authController = ref.watch(authControllerProvider);
    final email = authController.state.user?.email ?? '-';

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Email: $email'),
            const SizedBox(height: 16),
            FilledButton(
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
      ),
    );
  }
}
