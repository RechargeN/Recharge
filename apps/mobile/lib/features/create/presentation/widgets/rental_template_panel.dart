import 'package:flutter/material.dart';

import '../../../../core/localization/l10n_context.dart';
import '../../application/controllers/create_controller.dart';

/// Mirrors `EventTemplatePanel` for Rental: save current draft as a
/// template, or apply/duplicate a previously saved one.
class RentalTemplatePanel extends StatefulWidget {
  const RentalTemplatePanel({required this.controller, super.key});

  final CreateController controller;

  @override
  State<RentalTemplatePanel> createState() => _RentalTemplatePanelState();
}

class _RentalTemplatePanelState extends State<RentalTemplatePanel> {
  final TextEditingController _nameField = TextEditingController();

  @override
  void dispose() {
    _nameField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templates = widget.controller.rentalTemplates;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              context.l10n.createFormTemplates,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (templates.isEmpty)
              Text(context.l10n.createFormNoSavedTemplatesYet)
            else
              ...templates.map(
                (template) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(template.name),
                  trailing: TextButton(
                    onPressed: () =>
                        widget.controller.applyRentalTemplate(template.id),
                    child: Text(context.l10n.createFormUse),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _nameField,
                    decoration: InputDecoration(
                      labelText: context.l10n.createFormSaveCurrentAsTemplate,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final String name = _nameField.text.trim();
                    if (name.isEmpty) return;
                    widget.controller.saveCurrentRentalAsTemplate(name);
                    _nameField.clear();
                  },
                  child: Text(context.l10n.createFormSave),
                ),
              ],
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: widget.controller.duplicateRentalListing,
              icon: const Icon(Icons.copy_all_outlined),
              label: Text(context.l10n.createFormDuplicateListing),
            ),
          ],
        ),
      ),
    );
  }
}
