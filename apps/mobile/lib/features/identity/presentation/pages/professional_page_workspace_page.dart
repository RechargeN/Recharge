import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../application/identity_workspace_providers.dart';
import '../../domain/entities/managed_page_entity.dart';

enum ProfessionalPageSection { overview, content, account }

class ProfessionalPageWorkspacePage extends ConsumerWidget {
  const ProfessionalPageWorkspacePage({super.key, required this.section});

  final ProfessionalPageSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(identityWorkspaceControllerProvider).state;
    final String? activePageId = state.activeWorkspace?.isPage ?? false
        ? state.activeWorkspace!.id
        : null;
    final ManagedPageEntity? page = activePageId == null
        ? null
        : state.accessSnapshot?.pageById(activePageId);

    return Scaffold(
      appBar: AppBar(title: Text(_title(section))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          if (page == null)
            _EmptyProfessionalExperience(section: section)
          else
            _ActiveProfessionalPage(page: page, section: section),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.push(RouteNames.settings),
            icon: const Icon(Icons.switch_account_outlined),
            label: Text(
              page == null
                  ? 'Create or select Professional Page'
                  : 'Switch Professional Page',
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyProfessionalExperience extends StatelessWidget {
  const _EmptyProfessionalExperience({required this.section});

  final ProfessionalPageSection section;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.add_business_outlined, size: 36),
            const SizedBox(height: 12),
            Text(
              'Professional Page preview',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              section == ProfessionalPageSection.content
                  ? 'Content appears only after the user creates or joins a '
                        'real Professional Page.'
                  : 'No page is invented for this preview. Create a page to '
                        'activate its workspace and publisher context.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveProfessionalPage extends StatelessWidget {
  const _ActiveProfessionalPage({required this.page, required this.section});

  final ManagedPageEntity page;
  final ProfessionalPageSection section;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              page.displayName,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '${page.verificationStatus.name} · ${page.countryCode} · '
              '${page.defaultCurrency} · ${page.timezone}',
            ),
            const SizedBox(height: 18),
            Text(_sectionDescription(section)),
            if (section == ProfessionalPageSection.overview) ...<Widget>[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                key: const ValueKey<String>('preview-public-page'),
                onPressed: () => context.push(
                  RouteNames.professionalPagePreviewFor(page.id),
                ),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Preview public page'),
              ),
              if (!page.isPubliclyVisible) ...<Widget>[
                const SizedBox(height: 8),
                const Text(
                  'Preview only. The page is not public until verification '
                  'is approved.',
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

String _title(ProfessionalPageSection section) {
  return switch (section) {
    ProfessionalPageSection.overview => 'Page',
    ProfessionalPageSection.content => 'Content',
    ProfessionalPageSection.account => 'Account',
  };
}

String _sectionDescription(ProfessionalPageSection section) {
  return switch (section) {
    ProfessionalPageSection.overview =>
      'Professional Page overview and moderation status.',
    ProfessionalPageSection.content =>
      'Content is scoped to this exact Professional Page.',
    ProfessionalPageSection.account =>
      'Page account, memberships and international settings.',
  };
}
