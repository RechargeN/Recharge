import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../application/collection_create_config.dart';
import '../../application/collection_create_coordinator.dart';
import '../../application/controllers/create_controller.dart';
import '../../application/create_providers.dart';
import '../../application/state/collection_create_state.dart';
import '../../application/state/create_state.dart';
import '../../domain/entities/collection_draft_data.dart';
import '../../domain/entities/collection_item_draft.dart';
import '../../domain/entities/collection_validation_issue.dart';
import '../../domain/entities/create_draft_entity.dart';
import '../../domain/entities/location_search_suggestion.dart';
import 'collection_curator_notes_section.dart';
import 'items_picker_section.dart';
import 'location_search_suggestion_list.dart';

/// Collection / Guide 5-step create flow
/// (COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §7). Functionally complete
/// against the coordinator built in this slice; visual polish matching the
/// long-lived Place/Route/FindPeople blocks is later, incremental work —
/// this covers the same ground those blocks did in their first cut.
class CollectionCreateBlock extends ConsumerStatefulWidget {
  const CollectionCreateBlock({
    super.key,
    required this.controller,
    required this.state,
    required this.onPublished,
  });

  final CreateController controller;
  final CreateState state;
  final VoidCallback onPublished;

  @override
  ConsumerState<CollectionCreateBlock> createState() =>
      _CollectionCreateBlockState();
}

class _CollectionCreateBlockState extends ConsumerState<CollectionCreateBlock> {
  CollectionCreateCoordinator? _attachedCoordinator;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _shortDescriptionController =
      TextEditingController();
  final TextEditingController _areaController = TextEditingController();

  // Matches LocationSearchRuntimeConfig.debounceMilliseconds' default.
  static const Duration _locationSearchDebounce = Duration(milliseconds: 350);
  Timer? _locationSearchDebounceTimer;

  @override
  void dispose() {
    final CollectionCreateCoordinator? coordinator = _attachedCoordinator;
    if (coordinator != null) {
      widget.controller.detachCollectionCoordinator(coordinator);
    }
    _titleController.dispose();
    _shortDescriptionController.dispose();
    _areaController.dispose();
    _locationSearchDebounceTimer?.cancel();
    super.dispose();
  }

  void _onAreaLabelChanged(String value) {
    widget.controller.setCollectionAreaLabel(value);
    _locationSearchDebounceTimer?.cancel();
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      widget.controller.clearCollectionAreaLocationSuggestions();
      return;
    }
    _locationSearchDebounceTimer = Timer(_locationSearchDebounce, () {
      if (!mounted) return;
      widget.controller.searchCollectionAreaLocation(trimmed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final CollectionCreateCoordinator coordinator = ref.watch(
      collectionCreateCoordinatorProvider,
    );
    if (!identical(_attachedCoordinator, coordinator)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final CollectionCreateCoordinator? previous = _attachedCoordinator;
        if (previous != null) {
          widget.controller.detachCollectionCoordinator(previous);
        }
        _attachedCoordinator = coordinator;
        widget.controller.attachCollectionCoordinator(coordinator);
        setState(() {});
      });
      return const _Panel(child: Text('Preparing Collection draft…'));
    }

    final CollectionCreateState? collectionState =
        widget.controller.collectionCreateState;
    if (collectionState == null) {
      return const _Panel(child: Text('Collection draft is being prepared…'));
    }
    final CreateDraftEntity draft = collectionState.createDraft;
    final CollectionDraftData? data = draft.collectionData;
    if (data == null) {
      return const _Panel(
        child: Text('Collection draft data is being prepared…'),
      );
    }

    final int step = widget.state.collectionStep.clamp(
      0,
      collectionCreateSteps.length - 1,
    );
    final CollectionCreateStepConfig config = collectionCreateSteps[step];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _StepHeader(
          step: step,
          config: config,
          onStepSelected: widget.controller.goToCollectionStep,
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey<int>(step),
            child: switch (step) {
              0 => _basicsStep(collectionState, draft, data),
              1 => _itemsStep(collectionState, data),
              2 => _curatorNotesStep(data),
              3 => _budgetStep(draft, data),
              _ => _publishStep(collectionState, draft, data),
            },
          ),
        ),
        const SizedBox(height: 12),
        _navigation(step, data),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Шаг 1 — Основное + медиа
  // ---------------------------------------------------------------------

  Widget _basicsStep(
    CollectionCreateState collectionState,
    CreateDraftEntity draft,
    CollectionDraftData data,
  ) {
    _syncText(_titleController, draft.title);
    _syncText(_shortDescriptionController, draft.shortDescription);
    _syncText(_areaController, data.areaLabel);
    return _StepCard(
      title: 'Basics & media',
      children: <Widget>[
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(labelText: 'Title'),
          onChanged: widget.controller.updateTitle,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _shortDescriptionController,
          decoration: const InputDecoration(labelText: 'Short pitch'),
          maxLines: 2,
          onChanged: widget.controller.updateShortDescription,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _areaController,
          decoration: const InputDecoration(
            labelText: 'Area or city',
            helperText: 'Type to search, or tap the map below (§7 Шаг 1)',
          ),
          onChanged: _onAreaLabelChanged,
        ),
        if (collectionState.areaLocationSearchLoading)
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 4),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (collectionState.areaLocationSuggestions.isNotEmpty)
          LocationSearchSuggestionList(
            suggestions: collectionState.areaLocationSuggestions,
            onSelected: (LocationSearchSuggestion suggestion) {
              widget.controller.selectCollectionAreaLocationSuggestion(
                suggestion.id,
              );
            },
          ),
        const SizedBox(height: 12),
        Text(
          'Area anchor',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'One reference point for the whole guide — not an item location.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  data.anchorLatitude ?? widget.controller.marketCenterLat,
                  data.anchorLongitude ?? widget.controller.marketCenterLng,
                ),
                zoom: 12,
              ),
              markers: data.anchorLatitude == null || data.anchorLongitude == null
                  ? const <Marker>{}
                  : <Marker>{
                      Marker(
                        markerId: const MarkerId('collection-area-anchor'),
                        position: LatLng(
                          data.anchorLatitude!,
                          data.anchorLongitude!,
                        ),
                      ),
                    },
              onTap: (LatLng point) {
                widget.controller.setCollectionAreaAnchor(
                  latitude: point.latitude,
                  longitude: point.longitude,
                );
              },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Шаг 2 — Состав (ItemsPickerSection)
  // ---------------------------------------------------------------------

  Widget _itemsStep(CollectionCreateState state, CollectionDraftData data) {
    return _StepCard(
      title: 'Items',
      children: <Widget>[
        ItemsPickerSection(
          state: state,
          data: data,
          onSearch: widget.controller.searchCollectionCatalog,
          onAddItem: widget.controller.addCollectionItem,
          onRemoveItem: widget.controller.removeCollectionItem,
          onAddSection: widget.controller.addCollectionSection,
          onRemoveSection: widget.controller.removeCollectionSection,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Шаг 3 — Заметки куратора
  // ---------------------------------------------------------------------

  Widget _curatorNotesStep(CollectionDraftData data) {
    return _StepCard(
      title: 'Curator notes',
      children: <Widget>[
        CollectionCuratorNotesSection(
          data: data,
          onToggleHighlight: widget.controller.toggleCollectionHighlight,
          onSetCuratorNote: widget.controller.setCollectionCuratorNote,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Шаг 4 — Бюджет и публикатор
  // ---------------------------------------------------------------------

  Widget _budgetStep(CreateDraftEntity draft, CollectionDraftData data) {
    return _StepCard(
      title: 'Budget & publisher',
      children: <Widget>[
        const Text('Budget indicator'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: <Widget>[
            _budgetChip(null, 'Not set', data.budgetTier),
            _budgetChip(CollectionBudgetTier.free, 'Free', data.budgetTier),
            _budgetChip(CollectionBudgetTier.low, r'$', data.budgetTier),
            _budgetChip(CollectionBudgetTier.medium, r'$$', data.budgetTier),
            _budgetChip(CollectionBudgetTier.high, r'$$$', data.budgetTier),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Suggest from item prices'),
            onPressed: () {
              final CollectionBudgetTier? suggestion =
                  widget.controller.suggestCollectionBudgetTier();
              if (suggestion == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Not enough priced items yet to suggest a budget.',
                    ),
                  ),
                );
                return;
              }
              widget.controller.setCollectionBudgetIndicator(suggestion);
            },
          ),
        ),
        const SizedBox(height: 16),
        Text('Publisher: ${data.publisherRef.id}'),
        Text('Market: ${draft.marketCityId}'),
        Text('Visibility: ${draft.visibility.name}'),
      ],
    );
  }

  Widget _budgetChip(
    CollectionBudgetTier? value,
    String label,
    CollectionBudgetTier? current,
  ) {
    return ChoiceChip(
      label: Text(label),
      selected: value == current,
      onSelected: (_) => widget.controller.setCollectionBudgetIndicator(value),
    );
  }

  // ---------------------------------------------------------------------
  // Шаг 5 — Превью и публикация
  // ---------------------------------------------------------------------

  Widget _publishStep(
    CollectionCreateState state,
    CreateDraftEntity draft,
    CollectionDraftData data,
  ) {
    final bool hasUnavailable = data.items.any(
      (CollectionItemDraft item) =>
          item.sourceStatus == CollectionSourceStatus.unavailable,
    );
    final bool reviewed =
        data.compositionReview?.draftRevision == state.revision;
    return _StepCard(
      title: 'Preview & publish',
      children: <Widget>[
        Text(draft.title.isEmpty ? '(no title yet)' : draft.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(data.areaLabel),
        const SizedBox(height: 8),
        Text('${data.items.length} items'),
        if (hasUnavailable)
          const Text(
            'Some items are no longer available — review before publishing.',
            style: TextStyle(color: Colors.orange),
          ),
        for (final CollectionValidationIssue issue in state.issues)
          Text(
            '• ${issue.message}',
            style: TextStyle(
              color: issue.severity == CollectionValidationSeverity.error
                  ? Colors.red
                  : Colors.orange,
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Refresh live preview'),
          onPressed: () => widget.controller.buildCollectionPreview(),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.fact_check_outlined),
          label: Text(reviewed ? 'Composition reviewed' : 'Acknowledge composition'),
          onPressed: reviewed
              ? null
              : () => widget.controller.acknowledgeCollectionCompositionReview(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () async {
            final bool published = await widget.controller.publishCollection();
            if (published) widget.onPublished();
          },
          child: const Text('Publish'),
        ),
        if (state.status == CollectionCreateStatus.published) ...<Widget>[
          const Divider(height: 32),
          const Text(
            'Published — remove without review',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const Text(
            'Removing an item here applies instantly, no moderation '
            'round trip (§3.11). Adding or editing text still needs a new '
            'reviewed version — use Publish above for that.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          for (final CollectionItemDraft item in data.items)
            ListTile(
              dense: true,
              title: Text(item.snapshot.title),
              trailing: IconButton(
                tooltip: 'Remove without review',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () async {
                  try {
                    await widget.controller
                        .removeCollectionItemsFromActiveVersion(
                          <String>{item.ref.stableKey},
                        );
                  } catch (error) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not remove: $error')),
                      );
                    }
                  }
                },
              ),
            ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------

  Widget _navigation(int step, CollectionDraftData data) {
    return Row(
      children: <Widget>[
        if (step > 0)
          TextButton(
            onPressed: () => widget.controller.goToCollectionStep(step - 1),
            child: const Text('Back'),
          ),
        const Spacer(),
        if (step < collectionCreateSteps.length - 1)
          FilledButton(
            onPressed: () => widget.controller.goToCollectionStep(step + 1),
            child: const Text('Next'),
          ),
      ],
    );
  }

  void _syncText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.config,
    required this.onStepSelected,
  });

  final int step;
  final CollectionCreateStepConfig config;
  final ValueChanged<int> onStepSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(config.title, style: Theme.of(context).textTheme.titleLarge),
        Text(config.description, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            for (int i = 0; i < collectionCreateSteps.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () => onStepSelected(i),
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: i == step
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        color: i == step
                            ? Theme.of(context).colorScheme.onPrimary
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(24), child: Center(child: child));
  }
}
