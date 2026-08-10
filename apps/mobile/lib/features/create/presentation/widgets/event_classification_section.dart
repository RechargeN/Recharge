import 'package:flutter/material.dart';

import '../../application/event_classification_section.dart';
import '../../domain/entities/event_classification.dart';

class EventClassificationSection extends StatelessWidget {
  const EventClassificationSection({
    super.key,
    required this.state,
    required this.onArchetypeChanged,
    required this.onPrimaryParticipationChanged,
    required this.onAdditionalParticipationChanged,
    required this.onOtherReasonChanged,
    required this.onConfirmSuggestion,
    required this.onClear,
  });

  final EventClassificationSectionState state;
  final ValueChanged<EventArchetype> onArchetypeChanged;
  final ValueChanged<ParticipationMode> onPrimaryParticipationChanged;
  final void Function(ParticipationMode mode, bool selected)
  onAdditionalParticipationChanged;
  final ValueChanged<String> onOtherReasonChanged;
  final VoidCallback onConfirmSuggestion;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (!state.enabled) return const SizedBox.shrink();
    final EventClassificationDraft? value = state.classification;
    return Semantics(
      container: true,
      label: 'Event classification',
      child: Column(
        key: const Key('event-classification-section'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'How does this event work?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Mechanics and attendee roles are independent from the category, '
            'format, access and price.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (state.suggestion case final suggestion?) ...<Widget>[
            const SizedBox(height: 12),
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text('Suggested: ${_label(suggestion.archetype.wireName)}'),
                    const SizedBox(height: 4),
                    Text(
                      'This is only a suggestion. Confirm it or choose another.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonal(
                        key: const Key(
                          'event-classification-confirm-suggestion',
                        ),
                        onPressed: onConfirmSuggestion,
                        child: const Text('Use suggestion'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<EventArchetype>(
            key: const Key('event-archetype'),
            initialValue: value?.archetype,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Event mechanics *',
              errorText: state.errorFor('eventArchetype'),
            ),
            items: EventArchetype.values
                .map(
                  (EventArchetype archetype) =>
                      DropdownMenuItem<EventArchetype>(
                        value: archetype,
                        child: Text(_label(archetype.wireName)),
                      ),
                )
                .toList(growable: false),
            onChanged: (EventArchetype? next) {
              if (next != null) onArchetypeChanged(next);
            },
          ),
          if (value?.archetype == EventArchetype.other) ...<Widget>[
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey<String>(
                'event-archetype-other-${value?.otherReason ?? ''}',
              ),
              initialValue: value?.otherReason ?? '',
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Explain the event mechanics *',
                errorText: state.errorFor('eventArchetypeOtherReason'),
              ),
              onChanged: onOtherReasonChanged,
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<ParticipationMode>(
            key: const Key('event-primary-participation'),
            initialValue: value?.primaryParticipationMode,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Primary attendee role *',
              errorText: state.errorFor('primaryParticipationMode'),
            ),
            items: ParticipationMode.values
                .map(
                  (ParticipationMode mode) =>
                      DropdownMenuItem<ParticipationMode>(
                        value: mode,
                        child: Text(_label(mode.wireName)),
                      ),
                )
                .toList(growable: false),
            onChanged: (ParticipationMode? next) {
              if (next != null) onPrimaryParticipationChanged(next);
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Additional roles (up to 3)',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ParticipationMode.values
                .map((ParticipationMode mode) {
                  final bool selected =
                      value?.additionalParticipationModes.contains(mode) ??
                      false;
                  final bool isPrimary =
                      value?.primaryParticipationMode == mode;
                  final bool canSelect =
                      selected || (!isPrimary && state.canAddParticipationMode);
                  return Semantics(
                    label: '${_label(mode.wireName)} additional attendee role',
                    selected: selected,
                    child: FilterChip(
                      key: Key('event-additional-${mode.wireName}'),
                      label: Text(_label(mode.wireName)),
                      selected: selected,
                      onSelected: canSelect
                          ? (bool next) =>
                                onAdditionalParticipationChanged(mode, next)
                          : null,
                    ),
                  );
                })
                .toList(growable: false),
          ),
          if (state.errorFor('additionalParticipationModes') case final error?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (value != null) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('event-classification-clear'),
                onPressed: onClear,
                child: const Text('Clear classification'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _label(String wireName) {
  return wireName
      .split('_')
      .map(
        (String word) => word.isEmpty
            ? word
            : '${word.substring(0, 1).toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}
