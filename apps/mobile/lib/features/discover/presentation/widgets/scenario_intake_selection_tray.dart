import 'package:flutter/material.dart';

import '../../../../core/localization/l10n_context.dart';
import '../../application/state/scenario_intake_selection_state.dart';
import '../../domain/entities/discover_item_entity.dart';

class ScenarioIntakeSelectionTray extends StatelessWidget {
  const ScenarioIntakeSelectionTray({
    super.key,
    required this.selectedItems,
    required this.message,
    required this.onRemove,
    required this.onCancel,
    required this.onReview,
  });

  final List<DiscoverItemEntity> selectedItems;
  final ScenarioIntakeIssue? message;
  final ValueChanged<String> onRemove;
  final VoidCallback onCancel;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      liveRegion: true,
      label: <String>[
        context.l10n.discoverStopsSelected(selectedItems.length),
        if (message != null) scenarioIntakeIssueText(context.l10n, message!),
      ].join(' '),
      child: Material(
        elevation: 12,
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (selectedItems.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: selectedItems.indexed
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Semantics(
                                selected: true,
                                label:
                                    '${context.l10n.discoverSelectedStopLabel(entry.$1 + 1)} ${entry.$2.title}',
                                child: InputChip(
                                  avatar: CircleAvatar(
                                    child: Text('${entry.$1 + 1}'),
                                  ),
                                  label: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 140,
                                    ),
                                    child: Text(
                                      entry.$2.title,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  deleteButtonTooltipMessage:
                                      '${context.l10n.discoverRemove} '
                                      '${entry.$2.title}',
                                  onDeleted: () => onRemove(entry.$2.id),
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                if (message != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    scenarioIntakeIssueText(context.l10n, message!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.end,
                  children: <Widget>[
                    Text(
                      context.l10n.discoverSelectedCount(selectedItems.length),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextButton(
                      onPressed: onCancel,
                      child: Text(context.l10n.discoverCancel),
                    ),
                    const SizedBox(width: 6),
                    FilledButton.icon(
                      onPressed: onReview,
                      icon: const Icon(Icons.playlist_add_check),
                      label: Text(context.l10n.scenarioIntakeReview),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String scenarioIntakeIssueText(
  AppLocalizations l10n,
  ScenarioIntakeIssue issue,
) => switch (issue) {
  ScenarioIntakeIssue.findPeopleNotSupported =>
    l10n.discoverIntakeFindPeopleNotSupported,
  ScenarioIntakeIssue.missingIdentity => l10n.discoverIntakeMissingIdentity,
  ScenarioIntakeIssue.noLocation => l10n.discoverIntakeNoLocation,
  ScenarioIntakeIssue.limitReached => l10n.discoverIntakeLimitReached(20),
};
