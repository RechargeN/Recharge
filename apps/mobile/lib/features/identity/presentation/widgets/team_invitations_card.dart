import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n_context.dart';
import '../../application/identity_workspace_providers.dart';
import '../../application/state/team_invitation_state.dart';
import '../../domain/entities/managed_page_membership_entity.dart';
import '../../domain/entities/team_invitation_entity.dart';
import '../../domain/usecases/send_team_invitation_usecase.dart';

/// Sending member's Team card for the Professional Page workspace's Account
/// section, per `TEAM_INVITATION_LOCAL_SLICE_SPEC.md` (`PP-03A`). Shows only
/// what is locally knowable: this page's own sent invitations and their
/// pending/revoked/expired status. There is no view of the invited person's
/// side — acceptance requires their own authenticated session and is out of
/// scope for this bounded local/mock slice.
class TeamInvitationsCard extends ConsumerStatefulWidget {
  const TeamInvitationsCard({
    super.key,
    required this.pageId,
    required this.actingUserId,
    required this.ownCapabilities,
  });

  final String pageId;
  final String actingUserId;
  final Set<String> ownCapabilities;

  @override
  ConsumerState<TeamInvitationsCard> createState() =>
      _TeamInvitationsCardState();
}

class _TeamInvitationsCardState extends ConsumerState<TeamInvitationsCard> {
  String? _loadedForPageId;

  bool get _canManageTeam => widget.ownCapabilities.contains(
    SendTeamInvitationUseCase.teamManageCapability,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleLoad();
  }

  @override
  void didUpdateWidget(covariant TeamInvitationsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageId != widget.pageId) {
      _loadedForPageId = null;
      _scheduleLoad();
    }
  }

  void _scheduleLoad() {
    if (_loadedForPageId == widget.pageId) return;
    _loadedForPageId = widget.pageId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(teamInvitationControllerProvider).ensureLoaded(widget.pageId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final TeamInvitationState state = ref
        .watch(teamInvitationControllerProvider)
        .state;
    final bool loading =
        state.status == TeamInvitationStatusFlag.loading ||
        state.status == TeamInvitationStatusFlag.initial;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  context.l10n.identityTeam,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (_canManageTeam)
                  IconButton(
                    key: const ValueKey<String>('send-team-invitation'),
                    tooltip: context.l10n.identityInviteMember,
                    icon: const Icon(Icons.person_add_alt_outlined),
                    onPressed: state.isBusy ? null : _openSendSheet,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (!_canManageTeam)
              Text(context.l10n.identityNoTeamPermission)
            else if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.invitations.isEmpty)
              Text(context.l10n.identityNoInvitations)
            else
              Column(
                children: state.invitations
                    .map(
                      (TeamInvitationEntity invitation) => _InvitationRow(
                        invitation: invitation,
                        canManage: _canManageTeam,
                        busy: state.isBusy,
                        onRevoke: () => ref
                            .read(teamInvitationControllerProvider)
                            .revoke(
                              actingUserId: widget.actingUserId,
                              pageId: widget.pageId,
                              invitationId: invitation.id,
                            ),
                      ),
                    )
                    .toList(growable: false),
              ),
            if (state.message != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                context.l10n.identityTeamNotice(state.message!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openSendSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return _SendInvitationSheet(
          pageId: widget.pageId,
          actingUserId: widget.actingUserId,
          delegableCapabilities: widget.ownCapabilities,
        );
      },
    );
  }
}

class _InvitationRow extends StatelessWidget {
  const _InvitationRow({
    required this.invitation,
    required this.canManage,
    required this.busy,
    required this.onRevoke,
  });

  final TeamInvitationEntity invitation;
  final bool canManage;
  final bool busy;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final TeamInvitationStatus effective = invitation.effectiveStatusAt(
      DateTime.now().toUtc(),
    );
    final bool isPending = effective == TeamInvitationStatus.pending;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(_statusIcon(effective), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(invitation.target.value),
                Text(
                  '${context.l10n.identityRelationship(invitation.proposedRelationship.name)} · '
                  '${_statusLabel(context, effective)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (canManage && isPending)
            TextButton(
              onPressed: busy ? null : onRevoke,
              child: Text(context.l10n.identityRevoke),
            ),
        ],
      ),
    );
  }

  static IconData _statusIcon(TeamInvitationStatus status) {
    return switch (status) {
      TeamInvitationStatus.pending => Icons.hourglass_top_outlined,
      TeamInvitationStatus.revoked => Icons.block_outlined,
      TeamInvitationStatus.expired => Icons.event_busy_outlined,
    };
  }

  static String _statusLabel(
    BuildContext context,
    TeamInvitationStatus status,
  ) {
    return switch (status) {
      TeamInvitationStatus.pending => context.l10n.identityInvitationPending,
      TeamInvitationStatus.revoked => context.l10n.identityInvitationRevoked,
      TeamInvitationStatus.expired => context.l10n.identityInvitationExpired,
    };
  }
}

class _SendInvitationSheet extends ConsumerStatefulWidget {
  const _SendInvitationSheet({
    required this.pageId,
    required this.actingUserId,
    required this.delegableCapabilities,
  });

  final String pageId;
  final String actingUserId;
  final Set<String> delegableCapabilities;

  @override
  ConsumerState<_SendInvitationSheet> createState() =>
      _SendInvitationSheetState();
}

class _SendInvitationSheetState extends ConsumerState<_SendInvitationSheet> {
  final TextEditingController _valueController = TextEditingController();
  TeamInvitationTargetType _targetType = TeamInvitationTargetType.email;
  ManagedPageRelationship _relationship = ManagedPageRelationship.editor;
  final Set<String> _selectedCapabilities = <String>{};
  bool _submitting = false;
  String? _localError;

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.identityInviteMember,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<TeamInvitationTargetType>(
            initialValue: _targetType,
            decoration: InputDecoration(
              labelText: context.l10n.identityInviteBy,
            ),
            items: TeamInvitationTargetType.values
                .map(
                  (TeamInvitationTargetType type) =>
                      DropdownMenuItem<TeamInvitationTargetType>(
                        value: type,
                        child: Text(_targetTypeLabel(context.l10n, type)),
                      ),
                )
                .toList(growable: false),
            onChanged: (TeamInvitationTargetType? value) {
              if (value == null) return;
              setState(() => _targetType = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('team-invitation-target-value'),
            controller: _valueController,
            decoration: InputDecoration(
              labelText: _targetTypeLabel(context.l10n, _targetType),
              errorText: _localError,
            ),
            keyboardType: switch (_targetType) {
              TeamInvitationTargetType.email => TextInputType.emailAddress,
              TeamInvitationTargetType.phone => TextInputType.phone,
              TeamInvitationTargetType.userId => TextInputType.text,
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ManagedPageRelationship>(
            initialValue: _relationship,
            decoration: InputDecoration(labelText: context.l10n.identityRole),
            items:
                const <ManagedPageRelationship>[
                      ManagedPageRelationship.manager,
                      ManagedPageRelationship.editor,
                    ]
                    .map(
                      (ManagedPageRelationship relationship) =>
                          DropdownMenuItem<ManagedPageRelationship>(
                            value: relationship,
                            child: Text(
                              context.l10n.identityRelationship(
                                relationship.name,
                              ),
                            ),
                          ),
                    )
                    .toList(growable: false),
            onChanged: (ManagedPageRelationship? value) {
              if (value == null) return;
              setState(() => _relationship = value);
            },
          ),
          const SizedBox(height: 12),
          if (widget.delegableCapabilities.isNotEmpty) ...<Widget>[
            Text(
              context.l10n.identityCapabilities,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            ...widget.delegableCapabilities.map(
              (String capability) => CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(capability),
                value: _selectedCapabilities.contains(capability),
                onChanged: (bool? checked) {
                  setState(() {
                    if (checked ?? false) {
                      _selectedCapabilities.add(capability);
                    } else {
                      _selectedCapabilities.remove(capability);
                    }
                  });
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey<String>('submit-team-invitation'),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.identitySendInvitation),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final String value = _valueController.text.trim();
    if (value.isEmpty) {
      setState(() => _localError = context.l10n.identityRequired);
      return;
    }
    setState(() {
      _localError = null;
      _submitting = true;
    });
    final bool success = await ref
        .read(teamInvitationControllerProvider)
        .send(
          actingUserId: widget.actingUserId,
          pageId: widget.pageId,
          target: TeamInvitationTarget(type: _targetType, value: value),
          proposedRelationship: _relationship,
          proposedCapabilities: _selectedCapabilities,
        );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _submitting = false);
  }

  static String _targetTypeLabel(
    AppLocalizations l10n,
    TeamInvitationTargetType type,
  ) {
    return switch (type) {
      TeamInvitationTargetType.userId => l10n.identityUserId,
      TeamInvitationTargetType.email => l10n.identityEmail,
      TeamInvitationTargetType.phone => l10n.identityPhone,
    };
  }
}
