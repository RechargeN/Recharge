import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/create_providers.dart';

class CreateSuccessPage extends ConsumerWidget {
  const CreateSuccessPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(createControllerProvider).state.publishedDraft;
    final user = ref.watch(authControllerProvider).state.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Publish status')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.check_circle_outline, size: 52),
              const SizedBox(height: 12),
              Text(
                draft == null
                    ? 'Публикация обработана'
                    : 'Отправлено на модерацию: ${draft.publishStatus.name}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(RouteNames.discover),
                child: const Text('Вернуться в Discover'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: user == null
                    ? null
                    : () {
                        ref.read(createControllerProvider).resetToFreshDraft(
                              organizerId: user.id,
                              organizerEmail: user.email,
                              organizerName: user.email.split('@').first,
                            );
                        context.go(RouteNames.create);
                      },
                child: const Text('Создать еще'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
