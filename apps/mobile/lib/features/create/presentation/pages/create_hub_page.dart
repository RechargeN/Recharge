import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../application/create_taxonomy.dart';
import '../../domain/entities/create_draft_entity.dart';

class CreateHubPage extends StatelessWidget {
  const CreateHubPage({
    super.key,
    required this.isAuthenticated,
    required this.capabilities,
  });

  final bool isAuthenticated;
  final List<String> capabilities;

  @override
  Widget build(BuildContext context) {
    if (!isAuthenticated) {
      return const Scaffold(body: Center(child: Text('Требуется авторизация')));
    }

    final bool canCreatePlace = capabilities.contains('create.place');
    final bool canCreateRoute = capabilities.contains('create.route');
    final List<CreateBlockConfig> availableBlocks = rechargeCreateBlockConfigs
        .where(
          (CreateBlockConfig config) =>
              (config.objectType != CreateObjectType.place || canCreatePlace) &&
              (config.objectType != CreateObjectType.route || canCreateRoute),
        )
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Hub')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            'What do you want to create?',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose a type to open its creation page.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.15,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            children: availableBlocks
                .map(
                  (CreateBlockConfig config) => _CreateHubCard(
                    config: config,
                    onTap: () => context.pushNamed(
                      'create_object',
                      pathParameters: <String, String>{
                        'objectTypeId': config.objectType.taxonomyId,
                      },
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _CreateHubCard extends StatelessWidget {
  const _CreateHubCard({required this.config, required this.onTap});

  final CreateBlockConfig config;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      key: ValueKey<String>('create-hub-${config.objectType.taxonomyId}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  _iconForCreateBlock(config.objectType),
                  color: colorScheme.primary,
                ),
                const Spacer(),
                Icon(Icons.arrow_forward, size: 20, color: colorScheme.primary),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              config.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                config.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconForCreateBlock(CreateObjectType objectType) {
  return switch (objectType) {
    CreateObjectType.event => Icons.event,
    CreateObjectType.activity => Icons.self_improvement,
    CreateObjectType.route => Icons.route,
    CreateObjectType.place => Icons.place,
    CreateObjectType.session => Icons.calendar_month,
    CreateObjectType.scenario => Icons.account_tree,
    CreateObjectType.quickPlan => Icons.flash_on,
    CreateObjectType.findPeople => Icons.group_add,
    CreateObjectType.classWorkshop => Icons.school,
    CreateObjectType.rental => Icons.handyman,
    CreateObjectType.collection => Icons.collections_bookmark,
  };
}
