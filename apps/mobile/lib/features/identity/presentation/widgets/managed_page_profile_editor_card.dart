import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/identity_workspace_providers.dart';
import '../../application/state/managed_page_profile_editor_state.dart';
import '../../domain/entities/managed_page_entity.dart';
import '../../domain/entities/managed_page_field_moderation_overlay.dart';
import '../../domain/usecases/submit_managed_page_field_edit_usecase.dart';

/// Owner/team profile editor card for the Professional Page workspace, per
/// `MANAGED_PAGE_PROFILE_EDITOR_LOCAL_SLICE_SPEC.md` (`PP-01A`). Edits only
/// the page's default locale text for the three fields reachable without a
/// media-upload subsystem: short description, long description and custom
/// activity label. Every save is mock-auto-approved in the same call — there
/// is no pending/review state to show.
class ManagedPageProfileEditorCard extends ConsumerStatefulWidget {
  const ManagedPageProfileEditorCard({
    super.key,
    required this.page,
    required this.actingUserId,
    required this.ownCapabilities,
  });

  final ManagedPageEntity page;
  final String actingUserId;
  final Set<String> ownCapabilities;

  @override
  ConsumerState<ManagedPageProfileEditorCard> createState() =>
      _ManagedPageProfileEditorCardState();
}

class _ManagedPageProfileEditorCardState
    extends ConsumerState<ManagedPageProfileEditorCard> {
  String? _loadedForPageId;

  bool get _canEdit => widget.ownCapabilities.contains(
    SubmitManagedPageFieldEditUseCase.pageManageCapability,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleLoad();
  }

  @override
  void didUpdateWidget(covariant ManagedPageProfileEditorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page.id != widget.page.id) {
      _loadedForPageId = null;
      _scheduleLoad();
    }
  }

  void _scheduleLoad() {
    if (_loadedForPageId == widget.page.id) return;
    _loadedForPageId = widget.page.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(managedPageProfileEditorControllerProvider)
          .ensureLoaded(widget.page.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ManagedPageProfileEditorState state = ref
        .watch(managedPageProfileEditorControllerProvider)
        .state;
    final bool loading =
        state.status == ManagedPageProfileEditorStatusFlag.loading ||
        state.status == ManagedPageProfileEditorStatusFlag.initial;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Profile',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...<Widget>[
              _ProfileFieldRow(
                label: 'Short description',
                fieldKey: ManagedPageModeratedFieldKey.shortDescription,
                overlay: state.overlayFor(
                  ManagedPageModeratedFieldKey.shortDescription,
                ),
                page: widget.page,
                canEdit: _canEdit,
                busy: state.isBusy,
                maxLength: SubmitManagedPageFieldEditUseCase.maxShortTextLength,
                multiline: false,
                onSave: (String text) => ref
                    .read(managedPageProfileEditorControllerProvider)
                    .submit(
                      actingUserId: widget.actingUserId,
                      page: widget.page,
                      fieldKey: ManagedPageModeratedFieldKey.shortDescription,
                      value: ManagedPageLocalizedTextValue(<String, String>{
                        widget.page.defaultLocale: text,
                      }),
                    ),
              ),
              const Divider(height: 24),
              _ProfileFieldRow(
                label: 'Description',
                fieldKey: ManagedPageModeratedFieldKey.description,
                overlay: state.overlayFor(
                  ManagedPageModeratedFieldKey.description,
                ),
                page: widget.page,
                canEdit: _canEdit,
                busy: state.isBusy,
                maxLength: SubmitManagedPageFieldEditUseCase.maxLongTextLength,
                multiline: true,
                onSave: (String text) => ref
                    .read(managedPageProfileEditorControllerProvider)
                    .submit(
                      actingUserId: widget.actingUserId,
                      page: widget.page,
                      fieldKey: ManagedPageModeratedFieldKey.description,
                      value: ManagedPageLocalizedTextValue(<String, String>{
                        widget.page.defaultLocale: text,
                      }),
                    ),
              ),
              const Divider(height: 24),
              _ProfileFieldRow(
                label: 'Custom activity label',
                fieldKey: ManagedPageModeratedFieldKey.customActivityLabel,
                overlay: state.overlayFor(
                  ManagedPageModeratedFieldKey.customActivityLabel,
                ),
                page: widget.page,
                canEdit: _canEdit,
                busy: state.isBusy,
                maxLength:
                    SubmitManagedPageFieldEditUseCase.maxActivityLabelLength,
                multiline: false,
                onSave: (String text) => ref
                    .read(managedPageProfileEditorControllerProvider)
                    .submit(
                      actingUserId: widget.actingUserId,
                      page: widget.page,
                      fieldKey:
                          ManagedPageModeratedFieldKey.customActivityLabel,
                      value: ManagedPageActivityLabelValue(text),
                    ),
              ),
            ],
            if (state.message != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                state.message!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileFieldRow extends StatelessWidget {
  const _ProfileFieldRow({
    required this.label,
    required this.fieldKey,
    required this.overlay,
    required this.page,
    required this.canEdit,
    required this.busy,
    required this.maxLength,
    required this.multiline,
    required this.onSave,
  });

  final String label;
  final ManagedPageModeratedFieldKey fieldKey;
  final ManagedPageFieldModerationOverlay? overlay;
  final ManagedPageEntity page;
  final bool canEdit;
  final bool busy;
  final int maxLength;
  final bool multiline;
  final Future<bool> Function(String text) onSave;

  String get _currentText {
    final ManagedPageModeratedFieldValue? value = overlay?.effectiveValue(
      currentVerificationRevision: page.verificationRevision,
    );
    return switch (value) {
      ManagedPageLocalizedTextValue v =>
        v.valuesByLocale[page.defaultLocale] ?? '',
      ManagedPageActivityLabelValue v => v.value,
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final String current = _currentText;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(
                current.isEmpty ? 'Not set.' : current,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        if (canEdit)
          IconButton(
            key: ValueKey<String>('edit-field-${fieldKey.name}'),
            tooltip: 'Edit $label',
            icon: const Icon(Icons.edit_outlined),
            onPressed: busy ? null : () => _openEditDialog(context, current),
          ),
      ],
    );
  }

  Future<void> _openEditDialog(BuildContext context, String current) async {
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _FieldEditDialog(
          label: label,
          fieldKey: fieldKey,
          initialText: current,
          maxLength: maxLength,
          multiline: multiline,
        );
      },
    );
    if (result == null) return;
    await onSave(result.trim());
  }
}

/// Owns its `TextEditingController` for its own widget lifetime, so
/// disposal happens only once the dialog route (and its close animation)
/// is actually torn down — not immediately when `showDialog`'s Future
/// resolves, which races the still-animating route and disposes a
/// controller still in use.
class _FieldEditDialog extends StatefulWidget {
  const _FieldEditDialog({
    required this.label,
    required this.fieldKey,
    required this.initialText,
    required this.maxLength,
    required this.multiline,
  });

  final String label;
  final ManagedPageModeratedFieldKey fieldKey;
  final String initialText;
  final int maxLength;
  final bool multiline;

  @override
  State<_FieldEditDialog> createState() => _FieldEditDialogState();
}

class _FieldEditDialogState extends State<_FieldEditDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.label}'),
      content: TextField(
        key: ValueKey<String>('field-input-${widget.fieldKey.name}'),
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        maxLines: widget.multiline ? 5 : 1,
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: ValueKey<String>('save-field-${widget.fieldKey.name}'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
