import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n_context.dart';
import '../../application/identity_workspace_providers.dart';
import '../../application/state/identity_workspace_state.dart';
import '../../domain/entities/admin_experience_preview.dart';
import '../../domain/entities/identity_access_snapshot.dart';
import '../../domain/entities/managed_page_entity.dart';
import '../../domain/entities/managed_page_membership_entity.dart';
import '../../domain/entities/workspace_ref.dart';
import '../../domain/usecases/create_professional_page_usecase.dart';

/// Self-contained "switch workspace" section: personal profile, Professional
/// Pages, page creation/limit request and admin preview. Designed to be
/// embedded inline (e.g. in Settings) instead of pushed as a separate route.
class WorkspaceSection extends ConsumerStatefulWidget {
  const WorkspaceSection({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<WorkspaceSection> createState() => _WorkspaceSectionState();
}

class _WorkspaceSectionState extends ConsumerState<WorkspaceSection> {
  String? _loadKey;

  @override
  void initState() {
    super.initState();
    _scheduleLoad();
  }

  @override
  void didUpdateWidget(covariant WorkspaceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _scheduleLoad();
  }

  void _scheduleLoad({bool force = false}) {
    if (!force && _loadKey == widget.userId) return;
    _loadKey = widget.userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(identityWorkspaceControllerProvider).ensureLoaded(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(identityWorkspaceControllerProvider);
    final IdentityWorkspaceState state = controller.state;

    return switch (state.status) {
      IdentityWorkspaceStatus.initial ||
      IdentityWorkspaceStatus.loading => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      IdentityWorkspaceStatus.error => _WorkspaceError(
        message: identityWorkspaceText(context.l10n, state.message),
        onRetry: () => _scheduleLoad(force: true),
      ),
      IdentityWorkspaceStatus.ready ||
      IdentityWorkspaceStatus.switching ||
      IdentityWorkspaceStatus.creatingPage ||
      IdentityWorkspaceStatus.requestingLimit => _WorkspaceList(
        state: state,
        onSelect: (WorkspaceRef workspace) async {
          final bool selected = await controller.selectWorkspace(workspace);
          if (!context.mounted) return;
          final String message = controller.state.message == null
              ? ''
              : identityWorkspaceText(context.l10n, controller.state.message);
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
    };
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
    final String message = controller.state.message == null
        ? ''
        : identityWorkspaceText(context.l10n, controller.state.message);
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
    final String message = controller.state.message == null
        ? ''
        : identityWorkspaceText(context.l10n, controller.state.message);
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
        title: Text(context.l10n.identityAdminAccessActive),
        content: Text(context.l10n.identityAdminMockNotice),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.identityOk),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionLabel(context.l10n.identitySectionPersonal),
        const SizedBox(height: 8),
        _WorkspaceTile(
          key: const ValueKey<String>('workspace-personal'),
          icon: Icons.person_outline,
          title: context.l10n.identityCreator,
          subtitle: _personalSubtitle(
            context,
            snapshot.creatorVerificationStatus,
          ),
          selected: active == WorkspaceRef.personal(state.userId),
          enabled: !state.isSwitching,
          onTap: () => onSelect(WorkspaceRef.personal(state.userId)),
        ),
        const SizedBox(height: 22),
        _SectionLabel(context.l10n.identitySectionProfessionalPages),
        const SizedBox(height: 8),
        if (snapshot.availablePages.isEmpty)
          _EmptyPages(enabled: !state.isBusy, onCreatePage: onCreatePage)
        else
          for (final ManagedPageEntity page in snapshot.availablePages) ...[
            _WorkspaceTile(
              key: ValueKey<String>('workspace-page-${page.id}'),
              icon: _pageIcon(page.kind),
              title: page.displayName,
              subtitle: _pageSubtitle(context, snapshot, page),
              selected: active == WorkspaceRef.page(page.id),
              enabled: !state.isBusy,
              onTap: () => onSelect(WorkspaceRef.page(page.id)),
            ),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 8),
        Text(
          context.l10n.identityPagesUsed(
            snapshot.ownedPages.length,
            CreateProfessionalPageUseCase.selfServiceOwnedPageLimit,
          ),
          key: const ValueKey<String>('owned-page-quota'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (snapshot.ownedPages.isNotEmpty && snapshot.ownedPages.length < 3)
          OutlinedButton.icon(
            key: const ValueKey<String>('create-professional-page'),
            onPressed: state.isBusy ? null : onCreatePage,
            icon: const Icon(Icons.add_business_outlined),
            label: Text(context.l10n.identityCreatePage),
          )
        else if (state.pendingLimitRequest != null)
          Card(
            child: ListTile(
              key: ValueKey<String>('page-limit-request-pending'),
              leading: Icon(Icons.schedule_outlined),
              title: Text(context.l10n.identityLimitRequestPending),
              subtitle: Text(context.l10n.identityModeratorsWillReview),
            ),
          )
        else
          OutlinedButton.icon(
            key: const ValueKey<String>('request-additional-page'),
            onPressed: state.isBusy ? null : onRequestAdditionalPage,
            icon: const Icon(Icons.forward_to_inbox_outlined),
            label: Text(context.l10n.identityRequestAdditionalPage),
          ),
        if (snapshot.hasGlobalCapability('admin.tools.view')) ...<Widget>[
          const SizedBox(height: 18),
          _SectionLabel(context.l10n.identitySectionAdministration),
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
            title: context.l10n.identityAdminTools,
            subtitle: context.l10n.identityAdminSeparate,
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

  static String _personalSubtitle(
    BuildContext context,
    CreatorVerificationStatus status,
  ) => switch (status) {
    CreatorVerificationStatus.notStarted =>
      context.l10n.identityPersonalNotStarted,
    CreatorVerificationStatus.pending => context.l10n.identityPersonalPending,
    CreatorVerificationStatus.verified => context.l10n.identityVerifiedTools,
    CreatorVerificationStatus.rejected => context.l10n.identityPersonalRejected,
    CreatorVerificationStatus.expired => context.l10n.identityPersonalExpired,
    CreatorVerificationStatus.revoked => context.l10n.identityPersonalRevoked,
  };

  static String _pageSubtitle(
    BuildContext context,
    IdentityAccessSnapshot snapshot,
    ManagedPageEntity page,
  ) {
    final ManagedPageMembershipEntity? membership = snapshot.membershipFor(
      page.id,
    );
    final List<String> parts = <String>[
      _kindLabel(context.l10n, page.kind),
      _verificationLabel(context.l10n, page.verificationStatus),
    ];
    if (membership?.hasCapability('page.manage') ?? false) {
      parts.add(context.l10n.identityManagePage);
    } else if (membership?.hasCapability('page.content.create') ?? false) {
      parts.add(context.l10n.identityCreateContent);
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
            Text(context.l10n.identityNoPageYet),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              key: const ValueKey<String>('empty-create-professional-page'),
              onPressed: enabled ? onCreatePage : null,
              icon: const Icon(Icons.add_business_outlined),
              label: Text(context.l10n.identityCreatePage),
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
              context.l10n.identityViewAs,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(context.l10n.identityPreviewOnlyRoles),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AdminExperiencePreview.values
                  .map(
                    (AdminExperiencePreview preview) => ChoiceChip(
                      key: ValueKey<String>('admin-preview-${preview.name}'),
                      label: Text(_previewLabel(context.l10n, preview)),
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
      scrollable: true,
      title: Text(context.l10n.identityCreatePage),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            key: const ValueKey<String>('professional-page-name'),
            controller: _nameController,
            decoration: InputDecoration(
              labelText: context.l10n.identityPageName,
              errorText: _errorText,
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ManagedPageKind>(
            key: const ValueKey<String>('professional-page-kind'),
            isExpanded: true,
            initialValue: _kind,
            decoration: InputDecoration(
              labelText: context.l10n.identityPageType,
            ),
            items: ManagedPageKind.values
                .map(
                  (ManagedPageKind kind) => DropdownMenuItem<ManagedPageKind>(
                    value: kind,
                    child: Text(
                      _kindLabel(context.l10n, kind),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (ManagedPageKind? value) {
              if (value != null) setState(() => _kind = value);
            },
          ),
          const SizedBox(height: 12),
          Text(context.l10n.identityPageStartsPending),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.identityCancel),
        ),
        FilledButton(
          key: const ValueKey<String>('submit-professional-page'),
          onPressed: () {
            final String name = _nameController.text.trim();
            if (name.length < 2) {
              setState(() => _errorText = context.l10n.identityMinTwoChars);
              return;
            }
            Navigator.of(
              context,
            ).pop(_CreatePageDraft(displayName: name, kind: _kind));
          },
          child: Text(context.l10n.identityCreate),
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
            FilledButton.tonal(
              onPressed: onRetry,
              child: Text(context.l10n.identityRetry),
            ),
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

String _kindLabel(AppLocalizations l10n, ManagedPageKind kind) {
  return switch (kind) {
    ManagedPageKind.company => l10n.identityKindCompany,
    ManagedPageKind.organization => l10n.identityKindOrganization,
    ManagedPageKind.representativeOffice =>
      l10n.identityKindRepresentativeOffice,
    ManagedPageKind.venueOperator => l10n.identityKindVenueOperator,
    ManagedPageKind.privateProfessional => l10n.identityKindPrivateProfessional,
  };
}

String _verificationLabel(
  AppLocalizations l10n,
  ManagedPageVerificationStatus status,
) {
  return switch (status) {
    ManagedPageVerificationStatus.unverified => l10n.identityUnverified,
    ManagedPageVerificationStatus.pending => l10n.identityVerificationPending,
    ManagedPageVerificationStatus.verified => l10n.identityVerified,
    ManagedPageVerificationStatus.rejected => l10n.identityVerificationRejected,
    ManagedPageVerificationStatus.revoked => l10n.identityVerificationRevoked,
  };
}

String _previewLabel(AppLocalizations l10n, AdminExperiencePreview preview) {
  return switch (preview) {
    AdminExperiencePreview.creator => l10n.identityCreator,
    AdminExperiencePreview.professionalPage => l10n.identityProfessionalPage,
  };
}

/// L4.6: the workspace controller's message code in the reader's language.
String identityWorkspaceText(AppLocalizations l10n, String? code) =>
    l10n.identityWorkspaceNotice(code ?? 'workspace_load_failed');
