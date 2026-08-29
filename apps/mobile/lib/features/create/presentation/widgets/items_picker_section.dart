import 'package:flutter/material.dart';

import '../../application/state/collection_create_state.dart';
import '../../domain/entities/collection_draft_data.dart';
import '../../domain/entities/collection_item_draft.dart';
import '../../domain/repositories/collection_catalog_search_repository.dart';

/// COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §7 Шаг 2 — search, add/remove
/// items, sections. Presentation-only: every callback here is a plain
/// pass-through to whatever `CreateController` command the caller wires up;
/// this widget owns no domain state and calls no coordinator/controller
/// method directly.
class ItemsPickerSection extends StatefulWidget {
  const ItemsPickerSection({
    super.key,
    required this.state,
    required this.data,
    required this.onSearch,
    required this.onAddItem,
    required this.onRemoveItem,
    required this.onAddSection,
    required this.onRemoveSection,
  });

  final CollectionCreateState state;
  final CollectionDraftData data;
  final ValueChanged<String> onSearch;
  final ValueChanged<CollectionCatalogSearchResult> onAddItem;
  final ValueChanged<String> onRemoveItem;
  final ValueChanged<String> onAddSection;
  final ValueChanged<String> onRemoveSection;

  @override
  State<ItemsPickerSection> createState() => _ItemsPickerSectionState();
}

class _ItemsPickerSectionState extends State<ItemsPickerSection> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _sectionTitleController =
      TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _sectionTitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CollectionCreateState state = widget.state;
    final CollectionDraftData data = widget.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search Place, Route, Bookable Session, '
                      'Class/Workshop, Rental',
                ),
                onSubmitted: widget.onSearch,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Search',
              icon: const Icon(Icons.search),
              onPressed: () => widget.onSearch(_searchController.text),
            ),
          ],
        ),
        if (state.status == CollectionCreateStatus.searchingCatalog)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
        if (state.searchResults.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          const Text('Results', style: TextStyle(fontWeight: FontWeight.w600)),
          ...state.searchResults.map(
            (CollectionCatalogSearchResult result) => ListTile(
              dense: true,
              leading: const Icon(Icons.add_circle_outline),
              title: Text(result.snapshot.title),
              subtitle: Text(result.ref.objectType.name),
              onTap: () => widget.onAddItem(result),
            ),
          ),
        ],
        const Divider(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'In this Collection (${data.items.length})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextButton.icon(
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('New section'),
              onPressed: () => _promptNewSection(context),
            ),
          ],
        ),
        _composition(data),
      ],
    );
  }

  Widget _composition(CollectionDraftData data) {
    final Map<String?, List<CollectionItemDraft>> bySection =
        <String?, List<CollectionItemDraft>>{};
    for (final CollectionItemDraft item in data.items) {
      bySection
          .putIfAbsent(item.sectionId, () => <CollectionItemDraft>[])
          .add(item);
    }
    final List<Widget> groups = <Widget>[];
    for (final CollectionSectionDraft section
        in data.sections.toList()..sort((a, b) => a.order.compareTo(b.order))) {
      groups.add(
        _sectionGroup(
          title: section.title,
          items:
              (bySection[section.id] ?? const <CollectionItemDraft>[]).toList()
                ..sort((a, b) => a.order.compareTo(b.order)),
          onRemoveSection: () => widget.onRemoveSection(section.id),
        ),
      );
    }
    final List<CollectionItemDraft> unsectioned =
        (bySection[null] ?? const <CollectionItemDraft>[]).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    if (unsectioned.isNotEmpty || groups.isEmpty) {
      groups.add(_sectionGroup(title: null, items: unsectioned));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: groups,
    );
  }

  Widget _sectionGroup({
    required String? title,
    required List<CollectionItemDraft> items,
    VoidCallback? onRemoveSection,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (title != null)
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (onRemoveSection != null)
                  IconButton(
                    tooltip: 'Remove section',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onRemoveSection,
                  ),
              ],
            ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'No items yet.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          for (final CollectionItemDraft item in items)
            ListTile(
              dense: true,
              leading: item.highlight
                  ? const Icon(Icons.star, color: Colors.amber)
                  : const Icon(Icons.circle_outlined, size: 16),
              title: Text(item.snapshot.title),
              subtitle: item.sourceStatus == CollectionSourceStatus.unavailable
                  ? const Text(
                      'No longer available',
                      style: TextStyle(color: Colors.red),
                    )
                  : Text(item.ref.objectType.name),
              trailing: IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => widget.onRemoveItem(item.id),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _promptNewSection(BuildContext context) async {
    _sectionTitleController.clear();
    final String? title = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('New section'),
        content: TextField(
          controller: _sectionTitleController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Section title'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _sectionTitleController.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (title != null && title.trim().isNotEmpty) {
      widget.onAddSection(title.trim());
    }
  }
}
