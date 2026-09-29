import 'package:flutter/material.dart';

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
            Text('Templates', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (templates.isEmpty)
              const Text('No saved templates yet.')
            else
              ...templates.map(
                (template) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(template.name),
                  trailing: TextButton(
                    onPressed: () =>
                        widget.controller.applyRentalTemplate(template.id),
                    child: const Text('Use'),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _nameField,
                    decoration: const InputDecoration(
                      labelText: 'Save current as template',
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
                  child: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: widget.controller.duplicateRentalListing,
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Duplicate this listing'),
            ),
          ],
        ),
      ),
    );
  }
}
