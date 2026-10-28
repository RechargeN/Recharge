import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../application/controllers/create_controller.dart';
import '../../domain/entities/create_template_entity.dart';
import '../../../../core/localization/l10n_context.dart';
import 'create_texts.dart';

class EventTemplatePanel extends StatelessWidget {
  const EventTemplatePanel({super.key, required this.controller});

  final CreateController controller;

  @override
  Widget build(BuildContext context) {
    final List<CreateTemplateEntity> templates = controller.eventTemplates;
    return CreateFlowSection(
      key: const Key('event-template-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.auto_awesome_motion_outlined,
                color: RechargeTheme.emerald900,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.createFormEventTemplates,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text('${templates.length} saved'),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                key: const Key('open-event-templates'),
                onPressed: () => _openManager(context),
                icon: const Icon(Icons.view_list_outlined),
                label: Text(context.l10n.createFormChooseManage),
              ),
              FilledButton.tonalIcon(
                key: const Key('save-event-template'),
                onPressed: () => _saveCurrent(context),
                icon: const Icon(Icons.bookmark_add_outlined),
                label: Text(context.l10n.createFormSaveCurrent),
              ),
            ],
          ),
          if (controller.lastEventTemplate case final template?) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              context.l10n.createFormNextCreateAnotherEventWillUse,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            // The template name is the owner's own content, shown verbatim.
            Text(template.name, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Future<void> _saveCurrent(BuildContext context) async {
    final String? name = await _requestName(
      context,
      title: context.l10n.createFormSaveEventTemplate,
      initialValue: controller.state.draft.title,
    );
    if (name == null || !context.mounted) return;
    await controller.saveCurrentEventAsTemplate(name);
    if (context.mounted) {
      _showMessage(context, controller.state.message);
    }
  }

  Future<void> _openManager(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) =>
          _EventTemplateManager(controller: controller),
    );
  }
}

class _EventTemplateManager extends StatelessWidget {
  const _EventTemplateManager({required this.controller});

  final CreateController controller;

  @override
  Widget build(BuildContext context) {
    final List<CreateTemplateEntity> templates = controller.eventTemplates;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                context.l10n.createFormYourEventTemplates,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            if (templates.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      context.l10n.createFormNoTemplatesYetSaveCurrentEvent,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  key: const Key('event-template-list'),
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: templates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final CreateTemplateEntity template = templates[index];
                    return Card(
                      child: ListTile(
                        key: Key('event-template-${template.id}'),
                        title: Text(template.name),
                        subtitle: Text(
                          template.snapshot.title.trim().isEmpty
                              ? context.l10n.createFormUntitledEvent2
                              : template.snapshot.title,
                        ),
                        leading: index == 0
                            ? Tooltip(
                                message: context.l10n.createFormLastTemplate,
                                child: Icon(Icons.history),
                              )
                            : const Icon(Icons.bookmark_outline),
                        onTap: () => _use(context, template),
                        trailing: PopupMenuButton<String>(
                          tooltip: context.l10n.createFormTemplateActions,
                          onSelected: (String action) =>
                              _handleAction(context, template, action),
                          itemBuilder: (_) => <PopupMenuEntry<String>>[
                            PopupMenuItem(
                              value: 'rename',
                              child: Text(context.l10n.createFormRename),
                            ),
                            PopupMenuItem(
                              value: 'replace',
                              child: Text(
                                context.l10n.createFormReplaceWithCurrent,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(context.l10n.createFormDelete),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _use(BuildContext context, CreateTemplateEntity template) async {
    final bool applied = await controller.applyEventTemplate(template.id);
    if (applied && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _handleAction(
    BuildContext context,
    CreateTemplateEntity template,
    String action,
  ) async {
    switch (action) {
      case 'rename':
        final String? name = await _requestName(
          context,
          title: context.l10n.createFormRenameTemplate,
          initialValue: template.name,
        );
        if (name != null) {
          await controller.renameEventTemplate(template.id, name);
        }
        break;
      case 'replace':
        final bool confirmed = await _confirm(
          context,
          title: context.l10n.createFormReplaceTemplate,
          body: context.l10n.createFormReusableContentWillReplacedWithCurrent,
        );
        if (confirmed) await controller.replaceEventTemplate(template.id);
        break;
      case 'delete':
        final bool confirmed = await _confirm(
          context,
          title: context.l10n.createFormDeleteTemplate,
          body: context.l10n.createFormActiveDraftsPublishedEventsWillNot,
        );
        if (confirmed) await controller.deleteEventTemplate(template.id);
        break;
    }
    if (context.mounted) Navigator.of(context).pop();
  }
}

Future<String?> _requestName(
  BuildContext context, {
  required String title,
  required String initialValue,
}) async {
  String input = initialValue.trim();
  final String? result = await showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(title),
      content: TextFormField(
        key: const Key('event-template-name'),
        initialValue: input,
        autofocus: true,
        maxLength: 80,
        decoration: InputDecoration(
          labelText: context.l10n.createFormTemplateName,
        ),
        onChanged: (String value) => input = value,
        onFieldSubmitted: (String value) =>
            Navigator.of(dialogContext).pop(value),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(context.l10n.createFormCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(input),
          child: Text(context.l10n.createFormSave),
        ),
      ],
    ),
  );
  return result;
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.createFormCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.l10n.createFormConfirm),
            ),
          ],
        ),
      ) ??
      false;
}

void _showMessage(BuildContext context, String? code) {
  if (code == null) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(CreateTexts.notice(context.l10n, code))),
  );
}
