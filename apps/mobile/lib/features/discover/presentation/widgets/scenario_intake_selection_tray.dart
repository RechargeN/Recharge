import 'package:flutter/material.dart';

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
  final String? message;
  final ValueChanged<String> onRemove;
  final VoidCallback onCancel;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      liveRegion: true,
      label:
          '${selectedItems.length} stops selected for Scenario.'
          '${message == null ? '' : ' $message'}',
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
                                    'Selected stop ${entry.$1 + 1}: '
                                    '${entry.$2.title}',
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
                                      'Remove ${entry.$2.title}',
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
                    message!,
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
                      '${selectedItems.length} selected',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextButton(
                      onPressed: onCancel,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 6),
                    FilledButton.icon(
                      onPressed: onReview,
                      icon: const Icon(Icons.playlist_add_check),
                      label: const Text('Review'),
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
