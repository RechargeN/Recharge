import 'package:flutter/material.dart';

import '../../../application/controllers/create_controller.dart';
import '../../../application/state/create_state.dart';
import '../../../domain/entities/scenario_draft_data.dart';
import '../../../domain/entities/scenario_logistics_draft.dart';
import '../create_texts.dart';
import '../../../../../core/localization/l10n_context.dart';
import '../create_form_texts.dart';

class ScenarioContextSection extends StatelessWidget {
  const ScenarioContextSection({
    required this.controller,
    required this.state,
    super.key,
  });

  final CreateController controller;
  final CreateState state;

  @override
  Widget build(BuildContext context) {
    final ScenarioDraftData data = state.draft.scenarioData!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextFormField(
          key: ValueKey<String>('scenario-title-${state.draft.title}'),
          initialValue: state.draft.title,
          decoration: InputDecoration(
            labelText: context.l10n.createScenarioScenarioTitle,
            errorText: switch (state.validationErrors['title']) {
              final String id => CreateTexts.fieldError(context.l10n, id),
              null => null,
            },
            border: const OutlineInputBorder(),
          ),
          maxLength: 80,
          onChanged: controller.updateTitle,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<ScenarioFormat>(
          isExpanded: true,
          initialValue: data.format,
          decoration: InputDecoration(
            labelText: context.l10n.createScenarioFormat,
            border: OutlineInputBorder(),
          ),
          items: ScenarioFormat.values
              .map(
                (ScenarioFormat value) => DropdownMenuItem<ScenarioFormat>(
                  value: value,
                  child: Text(createOptionText(context.l10n, value)),
                ),
              )
              .toList(growable: false),
          onChanged: (ScenarioFormat? value) {
            if (value != null) controller.updateScenarioContext(format: value);
          },
        ),
        const SizedBox(height: 10),
        SegmentedButton<ScenarioDateMode>(
          segments: <ButtonSegment<ScenarioDateMode>>[
            ButtonSegment<ScenarioDateMode>(
              value: ScenarioDateMode.template,
              label: Text(context.l10n.createScenarioFlexibleTemplate),
            ),
            ButtonSegment<ScenarioDateMode>(
              value: ScenarioDateMode.dated,
              label: Text(context.l10n.createScenarioDatedTrip),
            ),
          ],
          selected: <ScenarioDateMode>{data.dateMode},
          onSelectionChanged: (Set<ScenarioDateMode> values) =>
              controller.updateScenarioContext(dateMode: values.first),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: DropdownButtonFormField<ScenarioPartyKind>(
                initialValue: data.party.kind,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.l10n.createScenarioParty,
                  border: OutlineInputBorder(),
                ),
                items: ScenarioPartyKind.values
                    .map(
                      (ScenarioPartyKind value) =>
                          DropdownMenuItem<ScenarioPartyKind>(
                            value: value,
                            child: Text(createOptionText(context.l10n, value)),
                          ),
                    )
                    .toList(growable: false),
                onChanged: (ScenarioPartyKind? value) {
                  if (value != null) {
                    controller.updateScenarioContext(partyKind: value);
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: data.party.peopleCount.clamp(1, 12),
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.l10n.createScenarioPeople,
                  border: OutlineInputBorder(),
                ),
                items: List<DropdownMenuItem<int>>.generate(
                  12,
                  (int index) => DropdownMenuItem<int>(
                    value: index + 1,
                    child: Text('${index + 1}'),
                  ),
                ),
                onChanged: (int? value) {
                  if (value != null) {
                    controller.updateScenarioContext(peopleCount: value);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<ScenarioPace>(
          isExpanded: true,
          initialValue: data.constraints.pace,
          decoration: InputDecoration(
            labelText: context.l10n.createScenarioPace,
            border: OutlineInputBorder(),
          ),
          items: ScenarioPace.values
              .map(
                (ScenarioPace value) => DropdownMenuItem<ScenarioPace>(
                  value: value,
                  child: Text(createOptionText(context.l10n, value)),
                ),
              )
              .toList(growable: false),
          onChanged: (ScenarioPace? value) {
            if (value != null) controller.updateScenarioContext(pace: value);
          },
        ),
        const SizedBox(height: 10),
        _TransportPreferences(controller: controller, data: data),
        const SizedBox(height: 10),
        DropdownButtonFormField<ScenarioBudgetBasis>(
          isExpanded: true,
          initialValue: data.constraints.budgetBasis,
          decoration: InputDecoration(
            labelText: context.l10n.createScenarioBudgetBasis,
            border: OutlineInputBorder(),
          ),
          items: ScenarioBudgetBasis.values
              .map(
                (ScenarioBudgetBasis value) =>
                    DropdownMenuItem<ScenarioBudgetBasis>(
                      value: value,
                      child: Text(createOptionText(context.l10n, value)),
                    ),
              )
              .toList(growable: false),
          onChanged: (ScenarioBudgetBasis? value) {
            if (value != null) {
              controller.updateScenarioContext(budgetBasis: value);
            }
          },
        ),
      ],
    );
  }
}

class _TransportPreferences extends StatelessWidget {
  const _TransportPreferences({required this.controller, required this.data});

  final CreateController controller;
  final ScenarioDraftData data;

  @override
  Widget build(BuildContext context) {
    final ScenarioConstraintsDraft constraints = data.constraints;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              context.l10n.createScenarioHowWillYouTravel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.createScenarioOwnCarFullySupportedPublicTransport,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ScenarioTravelMode>(
              key: const ValueKey<String>('scenario-primary-travel-mode'),
              initialValue: constraints.primaryTravelMode,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.l10n.createScenarioPrimaryTransport,
                border: OutlineInputBorder(),
              ),
              items: ScenarioTravelMode.values
                  .map(
                    (ScenarioTravelMode mode) =>
                        DropdownMenuItem<ScenarioTravelMode>(
                          value: mode,
                          child: Text(_travelModeLabel(context.l10n, mode)),
                        ),
                  )
                  .toList(growable: false),
              onChanged: (ScenarioTravelMode? mode) {
                if (mode == null) return;
                controller.updateScenarioTransport(
                  primaryTravelMode: mode,
                  allowedTravelModes: <ScenarioTravelMode>{
                    ...constraints.allowedTravelModes,
                    mode,
                  },
                );
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ScenarioTravelMode.values
                  .map((ScenarioTravelMode mode) {
                    final bool selected = constraints.allowedTravelModes
                        .contains(mode);
                    final bool isPrimary =
                        constraints.primaryTravelMode == mode;
                    return FilterChip(
                      label: Text(_travelModeLabel(context.l10n, mode)),
                      selected: selected,
                      onSelected: isPrimary
                          ? null
                          : (bool value) {
                              final Set<ScenarioTravelMode> next =
                                  <ScenarioTravelMode>{
                                    ...constraints.allowedTravelModes,
                                  };
                              value ? next.add(mode) : next.remove(mode);
                              controller.updateScenarioTransport(
                                primaryTravelMode:
                                    constraints.primaryTravelMode,
                                allowedTravelModes: next,
                              );
                            },
                    );
                  })
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

String _travelModeLabel(AppLocalizations l10n, ScenarioTravelMode mode) =>
    createOptionText(l10n, mode);
