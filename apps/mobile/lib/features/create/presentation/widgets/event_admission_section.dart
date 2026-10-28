import 'package:flutter/material.dart';

import '../../application/controllers/create_controller.dart';
import '../../application/event_admission_section.dart';
import '../../domain/entities/event_admission.dart';

import '../../../../core/localization/l10n_context.dart';
import 'create_texts.dart';
import 'create_form_texts.dart';

class EventAdmissionSection extends StatelessWidget {
  const EventAdmissionSection({
    super.key,
    required this.state,
    required this.controller,
    required this.externalRegistrationUrl,
  });

  final EventAdmissionSectionState state;
  final CreateController controller;
  final String? externalRegistrationUrl;

  @override
  Widget build(BuildContext context) {
    if (!state.enabled) return const SizedBox.shrink();
    final EventAdmissionDraft? value = state.admission;
    return Semantics(
      container: true,
      label: context.l10n.createFormEventAdmissionConfiguration,
      child: Column(
        key: const Key('event-admission-section'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            context.l10n.createFormAdmission,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            context
                .l10n
                .createFormAdmissionRegistrationConfirmationAreIndependentLocal,
          ),
          if (state.legacySuggestion case final suggestion?) ...<Widget>[
            const SizedBox(height: 12),
            Card.outlined(
              key: const Key('event-admission-legacy-suggestion'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      context.l10n.createFormLegacyDraftSuggestionNotApplied,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      suggestion.canConfirm
                          ? context
                                .l10n
                                .createFormOpenEntryWithNoRegistrationConfirmation
                          : context
                                .l10n
                                .createFormLegacyRegistrationPreservedButAdmissionConfirmation,
                    ),
                    if (suggestion.canConfirm)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonal(
                          key: const Key(
                            'event-admission-confirm-legacy-suggestion',
                          ),
                          onPressed:
                              controller.confirmEventAdmissionLegacySuggestion,
                          child: Text(context.l10n.createFormConfirmSuggestion),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<EventAdmissionPreset>(
            key: const Key('event-admission-preset'),
            initialValue: state.selectedPreset,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.l10n.createFormConfigurationPreset,
            ),
            items: EventAdmissionPreset.values
                .map(
                  (preset) => DropdownMenuItem<EventAdmissionPreset>(
                    value: preset,
                    child: Text(createOptionText(context.l10n, preset)),
                  ),
                )
                .toList(growable: false),
            onChanged: (preset) {
              if (preset == null) return;
              controller.previewEventAdmissionPreset(
                preset,
                admissionMode: value?.admissionMode,
                registrationMode: value?.registrationMode,
                confirmationMode: value?.confirmationMode,
              );
            },
          ),
          if (state.presetPreview != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Preview: ${createOptionText(context.l10n, state.presetPreview!.admissionMode!)} · '
              '${createOptionText(context.l10n, state.presetPreview!.registrationMode!)} · '
              '${createOptionText(context.l10n, state.presetPreview!.confirmationMode!)}',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                key: const Key('event-admission-apply-preset'),
                onPressed: controller.applyEventAdmissionPreset,
                child: Text(context.l10n.createFormApplyNormalizedFields),
              ),
            ),
          ],
          for (final issue in state.issues.where(
            (issue) => issue.code == 'admission_preset_choice_required',
          ))
            _IssueText(CreateTexts.event(context.l10n, issue)),
          const SizedBox(height: 12),
          _EnumField<AdmissionMode>(
            key: const Key('event-admission-mode'),
            label: context.l10n.createFormAdmissionMode,
            value: value?.admissionMode,
            values: AdmissionMode.values,
            error: _errorText(context, state, 'admissionMode'),
            onChanged: (next) =>
                controller.updateEventAdmissionAxes(admissionMode: next),
          ),
          _EnumField<EventRegistrationMode>(
            key: const Key('event-registration-axis'),
            label: context.l10n.createFormRegistrationMode,
            value: value?.registrationMode,
            values: EventRegistrationMode.values,
            error: _errorText(context, state, 'registrationMode'),
            onChanged: (next) =>
                controller.updateEventAdmissionAxes(registrationMode: next),
          ),
          _EnumField<ConfirmationMode>(
            key: const Key('event-confirmation-mode'),
            label: context.l10n.createFormConfirmationMode,
            value: value?.confirmationMode,
            values: ConfirmationMode.values,
            error: _errorText(context, state, 'confirmationMode'),
            onChanged: (next) =>
                controller.updateEventAdmissionAxes(confirmationMode: next),
          ),
          if (value?.registrationMode == EventRegistrationMode.external)
            TextFormField(
              key: ValueKey<String>(
                'event-external-registration-${externalRegistrationUrl ?? ''}',
              ),
              initialValue: externalRegistrationUrl ?? '',
              decoration: InputDecoration(
                labelText: context.l10n.createFormExternalHttpsRegistrationUrl2,
                errorText: _errorText(context, state, 'externalBookingUrl'),
              ),
              onChanged: controller.updateEventExternalRegistrationUrl,
            ),
          const SizedBox(height: 8),
          _GuestEditor(value: value, controller: controller, state: state),
          const SizedBox(height: 8),
          _InterestAndOnsiteEditor(value: value, controller: controller),
          const SizedBox(height: 12),
          _EligibilityEditor(
            value: value,
            controller: controller,
            state: state,
          ),
          const SizedBox(height: 12),
          _AccessWindowEditor(
            title: context.l10n.createFormRegistrationWindow,
            value: value?.registrationWindow,
            error: _errorText(context, state, 'registrationWindow'),
            onChanged: (window) => controller.updateEventAccessWindows(
              registrationWindow: window,
              clearRegistrationWindow: window == null,
            ),
          ),
          if (value?.registrationMode == EventRegistrationMode.internal)
            TextFormField(
              key: ValueKey<String>(
                'event-cancellation-deadline-'
                '${value?.cancellationClosesBeforeOccurrenceMinutes ?? ''}',
              ),
              initialValue:
                  value?.cancellationClosesBeforeOccurrenceMinutes
                      ?.toString() ??
                  '',
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context
                    .l10n
                    .createFormCancellationClosesNMinutesBeforeStart,
                errorText: _errorText(context, state, 'cancellationDeadline'),
              ),
              onChanged: (raw) => controller.updateEventCancellationDeadline(
                int.tryParse(raw.trim()),
              ),
            ),
          _AccessWindowEditor(
            title: context.l10n.createFormApplicationWindow,
            value: value?.applicationWindow,
            error: _errorText(context, state, 'applicationWindow'),
            onChanged: (window) => controller.updateEventAccessWindows(
              applicationWindow: window,
              clearApplicationWindow: window == null,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('event-waitlist-enabled'),
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.createFormConfigureWaitlist),
            subtitle: Text(
              context.l10n.createFormPreviewOnlyNoQueuePromotionRuns,
            ),
            value: value?.waitlistPolicy?.enabled ?? false,
            onChanged: (enabled) => controller.updateEventWaitlistConfiguration(
              enabled
                  ? const WaitlistConfiguration(
                      enabled: true,
                      promotionMode: WaitlistPromotionMode.organizerManaged,
                    )
                  : null,
            ),
          ),
          if (value?.waitlistPolicy?.enabled == true)
            _EnumField<WaitlistPromotionMode>(
              label: context.l10n.createFormFuturePromotionPolicy,
              value: value!.waitlistPolicy!.promotionMode,
              values: WaitlistPromotionMode.values,
              error: _errorText(context, state, 'waitlistPolicy'),
              onChanged: (mode) => controller.updateEventWaitlistConfiguration(
                value.waitlistPolicy!.copyWith(promotionMode: mode),
              ),
            ),
          for (final disclosure in state.disclosures)
            _Disclosure(
              message: context.l10n.eventAccessDisclosure(
                disclosure.topic.name,
              ),
              blocking: disclosure.blocking,
            ),
        ],
      ),
    );
  }
}

class _GuestEditor extends StatelessWidget {
  const _GuestEditor({
    required this.value,
    required this.controller,
    required this.state,
  });

  final EventAdmissionDraft? value;
  final CreateController controller;
  final EventAdmissionSectionState state;

  @override
  Widget build(BuildContext context) {
    final GuestPolicy? guest = value?.guestPolicy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _EnumField<GuestPolicyMode>(
          key: const Key('event-guest-mode'),
          label: context.l10n.createFormGuestPolicy,
          // No silent default: an unchosen policy shows no value (E2.0).
          value: guest?.mode,
          values: GuestPolicyMode.values,
          error: _errorText(context, state, 'guestPolicy'),
          onChanged: (mode) => controller.updateEventGuestPolicy(
            GuestPolicy(
              mode: mode,
              maxGuests:
                  mode == GuestPolicyMode.plusN ||
                      mode == GuestPolicyMode.namedGuestsOnly
                  ? guest?.maxGuests
                  : null,
            ),
          ),
        ),
        if (guest?.mode == GuestPolicyMode.plusN ||
            guest?.mode == GuestPolicyMode.namedGuestsOnly)
          TextFormField(
            key: ValueKey<String>('event-guest-max-${guest?.maxGuests ?? ''}'),
            initialValue: guest?.maxGuests?.toString() ?? '',
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.l10n.createFormMaximumGuestsPerRegistration,
              errorText: _errorText(context, state, 'guestMaxGuests'),
            ),
            onChanged: (raw) => controller.updateEventGuestPolicy(
              guest!.copyWith(maxGuests: int.tryParse(raw)),
            ),
          ),
      ],
    );
  }
}

class _InterestAndOnsiteEditor extends StatelessWidget {
  const _InterestAndOnsiteEditor({
    required this.value,
    required this.controller,
  });

  final EventAdmissionDraft? value;
  final CreateController controller;

  @override
  Widget build(BuildContext context) {
    final OnsiteAdmissionPolicy? onsite = value?.onsiteAdmissionPolicy;
    return Column(
      children: <Widget>[
        SwitchListTile(
          key: const Key('event-interest-enabled'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Optional “Interested” response'),
          subtitle: Text(context.l10n.createFormDoesNotBookReserveInventory),
          value: value?.interestPolicy?.optionalRsvpEnabled ?? false,
          onChanged: (enabled) => controller.updateEventInterestPolicy(
            enabled ? const InterestPolicy(optionalRsvpEnabled: true) : null,
          ),
        ),
        SwitchListTile(
          key: const Key('event-onsite-enabled'),
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.createFormOnsiteAdmissionAllowed),
          value: onsite?.allowed ?? false,
          onChanged: (enabled) => controller.updateEventOnsiteAdmissionPolicy(
            enabled
                ? const OnsiteAdmissionPolicy(
                    allowed: true,
                    salesAtDoor: false,
                    registrationAtDoor: false,
                    subjectToAvailability: true,
                  )
                : null,
          ),
        ),
        if (onsite?.allowed == true) ...<Widget>[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.createFormRegistrationAtDoor),
            value: onsite!.registrationAtDoor,
            onChanged: (next) => controller.updateEventOnsiteAdmissionPolicy(
              onsite.copyWith(registrationAtDoor: next ?? false),
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.createFormSalesAtDoor),
            value: onsite.salesAtDoor,
            onChanged: (next) => controller.updateEventOnsiteAdmissionPolicy(
              onsite.copyWith(salesAtDoor: next ?? false),
            ),
          ),
        ],
      ],
    );
  }
}

class _EligibilityEditor extends StatefulWidget {
  const _EligibilityEditor({
    required this.value,
    required this.controller,
    required this.state,
  });

  final EventAdmissionDraft? value;
  final CreateController controller;
  final EventAdmissionSectionState state;

  @override
  State<_EligibilityEditor> createState() => _EligibilityEditorState();
}

class _EligibilityEditorState extends State<_EligibilityEditor> {
  EligibilityRuleKind _kind = EligibilityRuleKind.invitation;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text(
        context.l10n.createFormEligibility,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      Text(context.l10n.createFormNeverEnterAccessCodesIdentitiesPrivate),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: _EnumField<EligibilityRuleKind>(
              label: context.l10n.createFormRuleKind,
              value: _kind,
              values: EligibilityRuleKind.values,
              onChanged: (next) => setState(() => _kind = next),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            key: const Key('event-eligibility-add'),
            tooltip: context.l10n.createFormAddEligibilityRule,
            onPressed: () => widget.controller.addEventEligibilityRule(_kind),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      for (final EligibilityRule rule
          in widget.value?.eligibilityRules ?? const <EligibilityRule>[]) ...[
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(createOptionText(context.l10n, rule.kind)),
          subtitle: TextFormField(
            key: ValueKey<String>('eligibility-${rule.id}'),
            initialValue: rule.publicExplanation ?? '',
            decoration: InputDecoration(
              labelText: context.l10n.createFormPublicExplanationNoSecrets,
            ),
            onChanged: (text) => widget.controller.updateEventEligibilityRule(
              rule.copyWith(
                publicExplanation: text.trim(),
                clearPublicExplanation: text.trim().isEmpty,
              ),
            ),
          ),
          trailing: IconButton(
            tooltip: context.l10n.createFormRemoveEligibilityRule,
            onPressed: () =>
                widget.controller.removeEventEligibilityRule(rule.id),
            icon: const Icon(Icons.delete_outline),
          ),
        ),
      ],
      if (_errorText(context, widget.state, 'eligibilityRules')
          case final error?)
        _IssueText(error),
    ],
  );
}

class _AccessWindowEditor extends StatelessWidget {
  const _AccessWindowEditor({
    required this.title,
    required this.value,
    required this.onChanged,
    this.error,
  });

  final String title;
  final EventAccessWindow? value;
  final ValueChanged<EventAccessWindow?> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: Text(
      value == null
          ? context.l10n.createFormNotConfigured
          : createOptionText(context.l10n, value!.kind),
    ),
    children: <Widget>[
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(context.l10n.createFormEnableWindow),
        value: value != null,
        onChanged: (enabled) => onChanged(
          enabled
              ? const EventAccessWindow(
                  kind: EventAccessWindowKind.occurrenceRelative,
                  opensBeforeOccurrenceMinutes: 10080,
                  closesBeforeOccurrenceMinutes: 60,
                )
              : null,
        ),
      ),
      if (value != null) ...<Widget>[
        _EnumField<EventAccessWindowKind>(
          label: context.l10n.createFormWindowType,
          value: value!.kind,
          values: EventAccessWindowKind.values,
          onChanged: (kind) => onChanged(
            kind == EventAccessWindowKind.absolute
                ? const EventAccessWindow(kind: EventAccessWindowKind.absolute)
                : const EventAccessWindow(
                    kind: EventAccessWindowKind.occurrenceRelative,
                    opensBeforeOccurrenceMinutes: 10080,
                    closesBeforeOccurrenceMinutes: 60,
                  ),
          ),
        ),
        if (value!.kind == EventAccessWindowKind.occurrenceRelative) ...[
          TextFormField(
            key: ValueKey<String>(
              '$title-open-${value!.opensBeforeOccurrenceMinutes ?? ''}',
            ),
            initialValue: value!.opensBeforeOccurrenceMinutes?.toString() ?? '',
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.l10n.createFormOpenMinutesBeforeOccurrence,
            ),
            onChanged: (raw) => onChanged(
              value!.copyWith(opensBeforeOccurrenceMinutes: int.tryParse(raw)),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey<String>(
              '$title-close-${value!.closesBeforeOccurrenceMinutes ?? ''}',
            ),
            initialValue:
                value!.closesBeforeOccurrenceMinutes?.toString() ?? '',
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.l10n.createFormCloseMinutesBeforeOccurrence,
            ),
            onChanged: (raw) => onChanged(
              value!.copyWith(closesBeforeOccurrenceMinutes: int.tryParse(raw)),
            ),
          ),
        ] else ...[
          TextFormField(
            key: ValueKey<String>(
              '$title-open-utc-${value!.opensAtUtc?.toIso8601String() ?? ''}',
            ),
            initialValue: value!.opensAtUtc?.toIso8601String() ?? '',
            decoration: InputDecoration(
              labelText: context.l10n.createFormOpensAtUtcIso8601,
            ),
            onChanged: (raw) => onChanged(
              value!.copyWith(opensAtUtc: DateTime.tryParse(raw)?.toUtc()),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey<String>(
              '$title-close-utc-${value!.closesAtUtc?.toIso8601String() ?? ''}',
            ),
            initialValue: value!.closesAtUtc?.toIso8601String() ?? '',
            decoration: InputDecoration(
              labelText: context.l10n.createFormClosesAtUtcIso8601,
            ),
            onChanged: (raw) => onChanged(
              value!.copyWith(closesAtUtc: DateTime.tryParse(raw)?.toUtc()),
            ),
          ),
        ],
        if (error != null) _IssueText(error!),
      ],
    ],
  );
}

class _EnumField<T extends Enum> extends StatelessWidget {
  const _EnumField({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
    this.error,
  });

  final String label;
  final T? value;
  final List<T> values;
  final ValueChanged<T> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: DropdownButtonFormField<T>(
      initialValue: values.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, errorText: error),
      items: values
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(createOptionText(context.l10n, item)),
            ),
          )
          .toList(growable: false),
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    ),
  );
}

class _Disclosure extends StatelessWidget {
  const _Disclosure({required this.message, required this.blocking});

  final String message;
  final bool blocking;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          blocking ? Icons.lock_outline : Icons.info_outline,
          size: 18,
          color: blocking ? Theme.of(context).colorScheme.error : null,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

class _IssueText extends StatelessWidget {
  const _IssueText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}

/// L4: a section field error, resolved from its message id.
String? _errorText(
  BuildContext context,
  EventAdmissionSectionState section,
  String fieldId,
) => switch (section.errorIdFor(fieldId)) {
  final String id => CreateTexts.fieldError(context.l10n, id),
  null => null,
};
