import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../application/controllers/create_controller.dart';
import '../../domain/entities/create_template_entity.dart';

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
                  'Event templates',
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
                label: const Text('Choose or manage'),
              ),
              FilledButton.tonalIcon(
                key: const Key('save-event-template'),
                onPressed: () => _saveCurrent(context),
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Save current'),
              ),
            ],
          ),
          if (controller.lastEventTemplate case final template?) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Next “Create another Event” will use: ${template.name}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveCurrent(BuildContext context) async {
    final String? name = await _requestName(
      context,
      title: 'Save Event template',
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
                'Your Event templates',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            if (templates.isEmpty)
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No templates yet. Save the current Event to reuse it.',
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
                              ? 'Untitled Event'
                              : template.snapshot.title,
                        ),
                        leading: index == 0
                            ? const Tooltip(
                                message: 'Last template',
                                child: Icon(Icons.history),
                              )
                            : const Icon(Icons.bookmark_outline),
                        onTap: () => _use(context, template),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Template actions',
                          onSelected: (String action) =>
                              _handleAction(context, template, action),
                          itemBuilder: (_) => const <PopupMenuEntry<String>>[
                            PopupMenuItem(
                              value: 'rename',
                              child: Text('Rename'),
                            ),
                            PopupMenuItem(
                              value: 'replace',
                              child: Text('Replace with current'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
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
          title: 'Rename template',
          initialValue: template.name,
        );
        if (name != null) {
          await controller.renameEventTemplate(template.id, name);
        }
        break;
      case 'replace':
        final bool confirmed = await _confirm(
          context,
          title: 'Replace template?',
          body: 'The reusable content will be replaced with the current Event.',
        );
        if (confirmed) await controller.replaceEventTemplate(template.id);
        break;
      case 'delete':
        final bool confirmed = await _confirm(
          context,
          title: 'Delete template?',
          body: 'Active drafts and published Events will not be affected.',
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
        decoration: const InputDecoration(labelText: 'Template name'),
        onChanged: (String value) => input = value,
        onFieldSubmitted: (String value) =>
            Navigator.of(dialogContext).pop(value),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(input),
          child: const Text('Save'),
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
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;
}

void _showMessage(BuildContext context, String? message) {
  if (message == null) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
