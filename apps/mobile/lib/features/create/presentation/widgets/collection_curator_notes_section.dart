import 'package:flutter/material.dart';

import '../../domain/entities/collection_draft_data.dart';
import '../../domain/entities/collection_item_draft.dart';

/// COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §7 Шаг 3 — curator note + highlight
/// toggle per item. Presentation-only: [data] and the two callbacks are the
/// entire input surface, no business logic (note-length enforcement etc.)
/// lives here — that stays in the domain/coordinator layer.
class CollectionCuratorNotesSection extends StatelessWidget {
  const CollectionCuratorNotesSection({
    super.key,
    required this.data,
    required this.onToggleHighlight,
    required this.onSetCuratorNote,
  });

  final CollectionDraftData data;
  final ValueChanged<String> onToggleHighlight;
  final void Function(String itemId, String note) onSetCuratorNote;

  @override
  Widget build(BuildContext context) {
    if (data.items.isEmpty) {
      return const Text('Add items in the previous step first.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final CollectionItemDraft item in data.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.snapshot.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        FilterChip(
                          label: const Text('Featured'),
                          selected: item.highlight,
                          onSelected: (_) => onToggleHighlight(item.id),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: ValueKey<String>('note_${item.id}'),
                      initialValue: item.curatorNote,
                      maxLength: 300,
                      decoration: const InputDecoration(
                        labelText: 'Why is it here?',
                      ),
                      maxLines: 2,
                      onChanged: (String value) =>
                          onSetCuratorNote(item.id, value),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
