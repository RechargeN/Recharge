import 'package:flutter/material.dart';

import '../../../../core/localization/l10n_context.dart';
import '../../application/event_classification_section.dart';
import '../../domain/entities/event_classification.dart';
import 'create_texts.dart';

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
      label: context.l10n.createFormEventClassification,
      child: Column(
        key: const Key('event-classification-section'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            context.l10n.createFormHowDoesEventWork,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.createFormMechanicsAttendeeRolesAreIndependentFrom,
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
                    Text(
                      '${context.l10n.createEventSuggestedLabel}: '
                      '${context.l10n.createEventArchetype(suggestion.archetype.wireName)}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.createFormOnlySuggestionConfirmChooseAnother,
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
                        child: Text(context.l10n.createFormUseSuggestion),
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
              labelText: context.l10n.createFormEventMechanics,
              errorText: _errorText(context, state, 'eventArchetype'),
            ),
            items: EventArchetype.values
                .map(
                  (EventArchetype archetype) =>
                      DropdownMenuItem<EventArchetype>(
                        value: archetype,
                        child: Text(
                          context.l10n.createEventArchetype(archetype.wireName),
                        ),
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
                labelText: context.l10n.createFormExplainEventMechanics,
                errorText: _errorText(
                  context,
                  state,
                  'eventArchetypeOtherReason',
                ),
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
              labelText: context.l10n.createFormPrimaryAttendeeRole,
              errorText: _errorText(context, state, 'primaryParticipationMode'),
            ),
            items: ParticipationMode.values
                .map(
                  (ParticipationMode mode) =>
                      DropdownMenuItem<ParticipationMode>(
                        value: mode,
                        child: Text(
                          context.l10n.createEventParticipationMode(
                            'mode_${mode.wireName}',
                          ),
                        ),
                      ),
                )
                .toList(growable: false),
            onChanged: (ParticipationMode? next) {
              if (next != null) onPrimaryParticipationChanged(next);
            },
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.createFormAdditionalRolesUp3,
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
                    label: context.l10n.createEventAdditionalRole(
                      context.l10n.createEventParticipationMode(
                        'mode_${mode.wireName}',
                      ),
                    ),
                    selected: selected,
                    child: FilterChip(
                      key: Key('event-additional-${mode.wireName}'),
                      label: Text(
                        context.l10n.createEventParticipationMode(
                          'mode_${mode.wireName}',
                        ),
                      ),
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
          if (_errorText(context, state, 'additionalParticipationModes')
              case final error?)
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
                child: Text(context.l10n.createFormClearClassification),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// L4: a section field error, resolved from its message id.
String? _errorText(
  BuildContext context,
  EventClassificationSectionState section,
  String fieldId,
) => switch (section.errorIdFor(fieldId)) {
  final String id => CreateTexts.fieldError(context.l10n, id),
  null => null,
};
