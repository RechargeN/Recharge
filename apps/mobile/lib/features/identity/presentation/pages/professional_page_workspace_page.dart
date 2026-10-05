import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../application/identity_workspace_providers.dart';
import '../../domain/entities/managed_page_entity.dart';
import '../../domain/entities/managed_page_membership_entity.dart';
import '../widgets/managed_page_profile_editor_card.dart';
import '../widgets/team_invitations_card.dart';

enum ProfessionalPageSection { overview, content, account }

class ProfessionalPageWorkspacePage extends ConsumerStatefulWidget {
  const ProfessionalPageWorkspacePage({super.key, required this.section});

  final ProfessionalPageSection section;

  @override
  ConsumerState<ProfessionalPageWorkspacePage> createState() =>
      _ProfessionalPageWorkspacePageState();
}

class _ProfessionalPageWorkspacePageState
    extends ConsumerState<ProfessionalPageWorkspacePage> {
  @override
  void initState() {
    super.initState();
    // IDP-05A: opening a page surface (also by deep link) re-validates the
    // stored active workspace, so a revoked page is never rendered from a
    // stale preference.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(identityWorkspaceControllerProvider).revalidateAccess(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ProfessionalPageSection section = widget.section;
    final state = ref.watch(identityWorkspaceControllerProvider).state;
    final String? activePageId = state.activeWorkspace?.isPage ?? false
        ? state.activeWorkspace!.id
        : null;
    // Exact-ID access: the page must be activatable for this user right now
    // (verified Creator, active page, active membership) — not merely present.
    final ManagedPageEntity? page =
        activePageId == null ||
            !(state.accessSnapshot?.canActivatePage(activePageId) ?? false)
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
            _ActiveProfessionalPage(
              page: page,
              section: section,
              actingUserId: state.userId,
              membership: state.accessSnapshot?.membershipFor(page.id),
            ),
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
  const _ActiveProfessionalPage({
    required this.page,
    required this.section,
    required this.actingUserId,
    required this.membership,
  });

  final ManagedPageEntity page;
  final ProfessionalPageSection section;
  final String actingUserId;
  final ManagedPageMembershipEntity? membership;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  page.displayName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
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
                      'Preview only. The page is not public until '
                      'verification is approved.',
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        if (section == ProfessionalPageSection.overview &&
            membership != null &&
            membership!.isActive) ...<Widget>[
          const SizedBox(height: 16),
          ManagedPageProfileEditorCard(
            page: page,
            actingUserId: actingUserId,
            ownCapabilities: membership!.capabilities,
          ),
        ],
        if (section == ProfessionalPageSection.account &&
            membership != null &&
            membership!.isActive) ...<Widget>[
          const SizedBox(height: 16),
          TeamInvitationsCard(
            pageId: page.id,
            actingUserId: actingUserId,
            ownCapabilities: membership!.capabilities,
          ),
        ],
      ],
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
