import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/identity_workspace_providers.dart';
import '../../application/state/identity_workspace_state.dart';
import '../../domain/entities/admin_experience_preview.dart';
import '../../domain/entities/identity_access_snapshot.dart';
import '../../domain/entities/managed_page_entity.dart';
import '../../domain/entities/managed_page_membership_entity.dart';
import '../../domain/entities/workspace_ref.dart';

class WorkspaceSwitcherPage extends ConsumerStatefulWidget {
  const WorkspaceSwitcherPage({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<WorkspaceSwitcherPage> createState() =>
      _WorkspaceSwitcherPageState();
}

class _WorkspaceSwitcherPageState extends ConsumerState<WorkspaceSwitcherPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(identityWorkspaceControllerProvider).ensureLoaded(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(identityWorkspaceControllerProvider);
    final IdentityWorkspaceState state = controller.state;

    return Scaffold(
      appBar: AppBar(title: const Text('Switch workspace')),
      body: switch (state.status) {
        IdentityWorkspaceStatus.initial || IdentityWorkspaceStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        IdentityWorkspaceStatus.error => _WorkspaceError(
          message: state.message ?? 'Unable to load workspaces',
          onRetry: () => controller.ensureLoaded(widget.userId),
        ),
        IdentityWorkspaceStatus.ready ||
        IdentityWorkspaceStatus.switching ||
        IdentityWorkspaceStatus.creatingPage ||
        IdentityWorkspaceStatus.requestingLimit => _WorkspaceList(
          state: state,
          onSelect: (WorkspaceRef workspace) async {
            final bool selected = await controller.selectWorkspace(workspace);
            if (!context.mounted) return;
            final String message = controller.state.message ?? '';
            if (message.isNotEmpty) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(message)));
            }
            if (selected) {
              FocusManager.instance.primaryFocus?.unfocus();
            }
          },
          onCreatePage: () => _createPage(context),
          onRequestAdditionalPage: () => _requestAdditionalPage(context),
          onPreview: (AdminExperiencePreview preview) {
            controller.selectAdminPreview(preview);
          },
          onAdminTools: () => _showAdminAccess(context),
        ),
      },
    );
  }

  Future<void> _createPage(BuildContext context) async {
    final _CreatePageDraft? draft = await showDialog<_CreatePageDraft>(
      context: context,
      builder: (BuildContext context) => const _CreatePageDialog(),
    );
    if (draft == null || !context.mounted) return;
    final controller = ref.read(identityWorkspaceControllerProvider);
    await controller.createProfessionalPage(
      displayName: draft.displayName,
      kind: draft.kind,
    );
    if (!context.mounted) return;
    final String message = controller.state.message ?? '';
    if (message.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _requestAdditionalPage(BuildContext context) async {
    final controller = ref.read(identityWorkspaceControllerProvider);
    await controller.requestAdditionalPage();
    if (!context.mounted) return;
    final String message = controller.state.message ?? '';
    if (message.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showAdminAccess(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Admin access active'),
        content: const Text(
          'This mock account has explicit Admin capabilities. '
          'Operational Admin tools are connected in IDP-05A.',
        ),
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

class _WorkspaceList extends StatelessWidget {
  const _WorkspaceList({
    required this.state,
    required this.onSelect,
    required this.onCreatePage,
    required this.onRequestAdditionalPage,
    required this.onPreview,
    required this.onAdminTools,
  });

  final IdentityWorkspaceState state;
  final ValueChanged<WorkspaceRef> onSelect;
  final VoidCallback onCreatePage;
  final VoidCallback onRequestAdditionalPage;
  final ValueChanged<AdminExperiencePreview> onPreview;
  final VoidCallback onAdminTools;

  @override
  Widget build(BuildContext context) {
    final IdentityAccessSnapshot snapshot = state.accessSnapshot!;
    final WorkspaceRef active =
        state.activeWorkspace ?? WorkspaceRef.personal(state.userId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: <Widget>[
        const _SectionLabel('PERSONAL'),
        const SizedBox(height: 8),
        _WorkspaceTile(
          key: const ValueKey<String>('workspace-personal'),
          icon: Icons.person_outline,
          title: 'Personal profile',
          subtitle: snapshot.isVerifiedCreator
              ? 'Viewer · Creator tools available'
              : 'Viewer',
          selected: active == WorkspaceRef.personal(state.userId),
          enabled: !state.isSwitching,
          onTap: () => onSelect(WorkspaceRef.personal(state.userId)),
        ),
        const SizedBox(height: 22),
        const _SectionLabel('PROFESSIONAL PAGES'),
        const SizedBox(height: 8),
        if (snapshot.availablePages.isEmpty)
          _EmptyPages(enabled: !state.isBusy, onCreatePage: onCreatePage)
        else
          for (final ManagedPageEntity page in snapshot.availablePages) ...[
            _WorkspaceTile(
              key: ValueKey<String>('workspace-page-${page.id}'),
              icon: _pageIcon(page.kind),
              title: page.displayName,
              subtitle: _pageSubtitle(snapshot, page),
              selected: active == WorkspaceRef.page(page.id),
              enabled: !state.isBusy,
              onTap: () => onSelect(WorkspaceRef.page(page.id)),
            ),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 8),
        Text(
          '${snapshot.ownedPages.length} of 3 self-service pages used',
          key: const ValueKey<String>('owned-page-quota'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (snapshot.ownedPages.isNotEmpty && snapshot.ownedPages.length < 3)
          OutlinedButton.icon(
            key: const ValueKey<String>('create-professional-page'),
            onPressed: state.isBusy ? null : onCreatePage,
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Create Professional Page'),
          )
        else if (state.pendingLimitRequest != null)
          const Card(
            child: ListTile(
              key: ValueKey<String>('page-limit-request-pending'),
              leading: Icon(Icons.schedule_outlined),
              title: Text('Additional page request pending'),
              subtitle: Text('Moderators will review your request.'),
            ),
          )
        else
          OutlinedButton.icon(
            key: const ValueKey<String>('request-additional-page'),
            onPressed: state.isBusy ? null : onRequestAdditionalPage,
            icon: const Icon(Icons.forward_to_inbox_outlined),
            label: const Text('Request additional page'),
          ),
        if (snapshot.hasGlobalCapability('admin.tools.view')) ...<Widget>[
          const SizedBox(height: 18),
          const _SectionLabel('ADMINISTRATION'),
          const SizedBox(height: 8),
          if (snapshot.hasGlobalCapability('admin.experience.preview')) ...[
            _AdminPreviewCard(
              selected: state.adminPreview,
              enabled: !state.isBusy,
              onSelect: onPreview,
            ),
            const SizedBox(height: 8),
          ],
          _WorkspaceTile(
            key: const ValueKey<String>('admin-tools-entry'),
            icon: Icons.admin_panel_settings_outlined,
            title: 'Admin tools',
            subtitle: 'Admin access active · separate from publishing',
            selected: false,
            enabled: !state.isBusy,
            onTap: onAdminTools,
          ),
        ],
        if (state.isBusy) ...<Widget>[
          const SizedBox(height: 18),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }

  static String _pageSubtitle(
    IdentityAccessSnapshot snapshot,
    ManagedPageEntity page,
  ) {
    final ManagedPageMembershipEntity? membership = snapshot.membershipFor(
      page.id,
    );
    final List<String> parts = <String>[
      _kindLabel(page.kind),
      _verificationLabel(page.verificationStatus),
    ];
    if (membership?.hasCapability('page.manage') ?? false) {
      parts.add('Manage page');
    } else if (membership?.hasCapability('page.content.create') ?? false) {
      parts.add('Create content');
    }
    return parts.join(' · ');
  }
}

class _WorkspaceTile extends StatelessWidget {
  const _WorkspaceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: selected
                    ? colors.primary
                    : colors.surfaceContainerHighest,
                foregroundColor: selected
                    ? colors.onPrimary
                    : colors.onSurfaceVariant,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.chevron_right,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _EmptyPages extends StatelessWidget {
  const _EmptyPages({required this.enabled, required this.onCreatePage});

  final bool enabled;
  final VoidCallback onCreatePage;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('You have not created a Professional Page yet.'),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              key: const ValueKey<String>('empty-create-professional-page'),
              onPressed: enabled ? onCreatePage : null,
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('Create Professional Page'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminPreviewCard extends StatelessWidget {
  const _AdminPreviewCard({
    required this.selected,
    required this.enabled,
    required this.onSelect,
  });

  final AdminExperiencePreview? selected;
  final bool enabled;
  final ValueChanged<AdminExperiencePreview> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'View as',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Presentation preview only. Roles and permissions do not change.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AdminExperiencePreview.values
                  .map(
                    (AdminExperiencePreview preview) => ChoiceChip(
                      key: ValueKey<String>('admin-preview-${preview.name}'),
                      label: Text(_previewLabel(preview)),
                      selected: selected == preview,
                      onSelected: enabled
                          ? (bool value) {
                              if (value) onSelect(preview);
                            }
                          : null,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatePageDraft {
  const _CreatePageDraft({required this.displayName, required this.kind});

  final String displayName;
  final ManagedPageKind kind;
}

class _CreatePageDialog extends StatefulWidget {
  const _CreatePageDialog();

  @override
  State<_CreatePageDialog> createState() => _CreatePageDialogState();
}

class _CreatePageDialogState extends State<_CreatePageDialog> {
  final TextEditingController _nameController = TextEditingController();
  ManagedPageKind _kind = ManagedPageKind.company;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Professional Page'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            key: const ValueKey<String>('professional-page-name'),
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Page name',
              errorText: _errorText,
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ManagedPageKind>(
            key: const ValueKey<String>('professional-page-kind'),
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Page type'),
            items: ManagedPageKind.values
                .map(
                  (ManagedPageKind kind) => DropdownMenuItem<ManagedPageKind>(
                    value: kind,
                    child: Text(_kindLabel(kind)),
                  ),
                )
                .toList(growable: false),
            onChanged: (ManagedPageKind? value) {
              if (value != null) setState(() => _kind = value);
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'The page starts in Pending review. Market, locale, timezone and '
            'currency come from the active market configuration.',
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('submit-professional-page'),
          onPressed: () {
            final String name = _nameController.text.trim();
            if (name.length < 2) {
              setState(() => _errorText = 'Enter at least 2 characters');
              return;
            }
            Navigator.of(
              context,
            ).pop(_CreatePageDraft(displayName: name, kind: _kind));
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _WorkspaceError extends StatelessWidget {
  const _WorkspaceError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

IconData _pageIcon(ManagedPageKind kind) {
  return switch (kind) {
    ManagedPageKind.company => Icons.business_outlined,
    ManagedPageKind.organization => Icons.groups_outlined,
    ManagedPageKind.representativeOffice => Icons.apartment_outlined,
    ManagedPageKind.venueOperator => Icons.storefront_outlined,
    ManagedPageKind.privateProfessional => Icons.badge_outlined,
  };
}

String _kindLabel(ManagedPageKind kind) {
  return switch (kind) {
    ManagedPageKind.company => 'Company',
    ManagedPageKind.organization => 'Organization',
    ManagedPageKind.representativeOffice => 'Representative office',
    ManagedPageKind.venueOperator => 'Venue operator',
    ManagedPageKind.privateProfessional => 'Private professional',
  };
}

String _verificationLabel(ManagedPageVerificationStatus status) {
  return switch (status) {
    ManagedPageVerificationStatus.unverified => 'Unverified',
    ManagedPageVerificationStatus.pending => 'Verification pending',
    ManagedPageVerificationStatus.verified => 'Verified',
    ManagedPageVerificationStatus.rejected => 'Verification rejected',
    ManagedPageVerificationStatus.revoked => 'Verification revoked',
  };
}

String _previewLabel(AdminExperiencePreview preview) {
  return switch (preview) {
    AdminExperiencePreview.viewer => 'Viewer',
    AdminExperiencePreview.creator => 'Creator',
    AdminExperiencePreview.professionalPage => 'Professional Page',
  };
}
