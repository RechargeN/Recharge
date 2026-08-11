import 'dart:async';

import 'package:flutter/material.dart';

import '../../../application/controllers/create_controller.dart';
import '../../../application/scenario_generation_coordinator.dart';
import '../../../application/state/create_state.dart';
import '../../../domain/entities/scenario_generation_proposal.dart';

class ScenarioGenerationPanel extends StatefulWidget {
  const ScenarioGenerationPanel({
    required this.controller,
    required this.state,
    super.key,
  });

  final CreateController controller;
  final CreateState state;

  @override
  State<ScenarioGenerationPanel> createState() =>
      _ScenarioGenerationPanelState();
}

class _ScenarioGenerationPanelState extends State<ScenarioGenerationPanel> {
  static const String _examplePrompt =
      'A calm cultural afternoon in Riga with a walk and dinner';

  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(
      text: widget.state.scenarioGenerationPrompt,
    );
  }

  @override
  void didUpdateWidget(covariant ScenarioGenerationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String prompt = widget.state.scenarioGenerationPrompt;
    if (_promptController.text != prompt) {
      _promptController.value = TextEditingValue(
        text: prompt,
        selection: TextSelection.collapsed(offset: prompt.length),
      );
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final ScenarioGenerationPreview? preview =
        widget.state.scenarioGenerationPreview;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.auto_awesome_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Build with AI',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Chip(
                  key: ValueKey<String>('scenario-generation-mode'),
                  avatar: Icon(Icons.science_outlined, size: 16),
                  label: Text('Local demo'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Describe the mood and priorities. This demo uses only the '
              'local Recharge catalog; it does not call an external AI.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('scenario-generation-prompt'),
              controller: _promptController,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'What would you like to do?',
                hintText: 'A relaxed afternoon in Riga with culture and dinner',
                border: OutlineInputBorder(),
              ),
              onChanged: widget.controller.updateScenarioGenerationPrompt,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                key: const ValueKey<String>('scenario-generation-example'),
                avatar: const Icon(Icons.lightbulb_outline, size: 16),
                label: const Text('Use an example'),
                onPressed: widget.state.scenarioGenerationLoading
                    ? null
                    : () {
                        _promptController.value = const TextEditingValue(
                          text: _examplePrompt,
                          selection: TextSelection.collapsed(
                            offset: _examplePrompt.length,
                          ),
                        );
                        widget.controller.updateScenarioGenerationPrompt(
                          _examplePrompt,
                        );
                      },
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const ValueKey<String>('generate-scenario-preview'),
              onPressed: widget.state.scenarioGenerationLoading
                  ? null
                  : () =>
                        unawaited(widget.controller.generateScenarioPreview()),
              icon: widget.state.scenarioGenerationLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                widget.state.scenarioGenerationLoading
                    ? 'Building preview…'
                    : 'Generate preview',
              ),
            ),
            if (widget.state.scenarioGenerationError
                case final String error) ...[
              const SizedBox(height: 10),
              Text(
                error,
                key: const ValueKey<String>('scenario-generation-error'),
                style: TextStyle(color: colors.error),
              ),
            ],
            if (preview != null) ...<Widget>[
              const SizedBox(height: 16),
              _ScenarioProposalPreview(
                preview: preview,
                onApply: widget.controller.applyScenarioGenerationPreview,
                onEdit: widget.controller.discardScenarioGenerationPreview,
                onDiscard: widget.controller.discardScenarioGenerationPreview,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScenarioProposalPreview extends StatelessWidget {
  const _ScenarioProposalPreview({
    required this.preview,
    required this.onApply,
    required this.onEdit,
    required this.onDiscard,
  });

  final ScenarioGenerationPreview preview;
  final VoidCallback onApply;
  final VoidCallback onEdit;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final ScenarioGenerationProposal proposal = preview.proposal;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey<String>('scenario-generation-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Proposed stops',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final String label in proposal.context.displayLabels)
              Chip(label: Text(label)),
          ],
        ),
        const SizedBox(height: 8),
        for (final ScenarioGeneratedCatalogItem item in proposal.items)
          Card(
            key: ValueKey<String>('scenario-generation-item-${item.objectId}'),
            elevation: 0,
            color: colors.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('Catalog snapshot'),
                      ),
                    ],
                  ),
                  if (item.subtitle.isNotEmpty) Text(item.subtitle),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatMinutes(item.durationMinutes)} · ${item.reason}',
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          'Activity time: ${_formatMinutes(proposal.activityMinutes)}',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          preview.readiness.canSaveToMyScenarios
              ? 'Preview readiness: ready to review'
              : 'Preview readiness: needs your review',
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Still unverified',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                for (final ScenarioGenerationIssue issue in proposal.issues)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text('• ${issue.message}'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey<String>('apply-scenario-generation'),
          onPressed: proposal.canApply ? onApply : null,
          child: const Text('Apply to Scenario'),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                key: const ValueKey<String>('edit-scenario-generation'),
                onPressed: onEdit,
                child: const Text('Edit prompt'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextButton(
                key: const ValueKey<String>('discard-scenario-generation'),
                onPressed: onDiscard,
                child: const Text('Discard'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    final int hours = minutes ~/ 60;
    final int remainder = minutes % 60;
    return remainder == 0 ? '$hours h' : '$hours h $remainder min';
  }
}
