import '../entities/event_admission.dart';
import '../entities/event_validation_issue.dart';

class AdmissionPresetNormalizationResult {
  const AdmissionPresetNormalizationResult({
    required this.admission,
    this.issues = const <EventValidationIssue>[],
  });

  final EventAdmissionDraft? admission;
  final List<EventValidationIssue> issues;

  bool get canApply =>
      admission != null && issues.every((issue) => !issue.isBlocking);
}

class EventAdmissionLegacySuggestion {
  const EventAdmissionLegacySuggestion({
    required this.admission,
    required this.reasonCode,
  });

  final EventAdmissionDraft admission;
  final String reasonCode;

  bool get canConfirm => admission.isComplete;
}

class SuggestLegacyEventAdmissionUseCase {
  const SuggestLegacyEventAdmissionUseCase();

  EventAdmissionLegacySuggestion? call({
    required int schemaVersion,
    required EventRegistrationMode registrationMode,
  }) {
    if (schemaVersion >= 3) return null;
    return switch (registrationMode) {
      EventRegistrationMode.none => const EventAdmissionLegacySuggestion(
        admission: EventAdmissionDraft(
          admissionMode: AdmissionMode.openEntry,
          registrationMode: EventRegistrationMode.none,
          confirmationMode: ConfirmationMode.none,
        ),
        reasonCode: 'legacy_registration_none',
      ),
      EventRegistrationMode.external => const EventAdmissionLegacySuggestion(
        admission: EventAdmissionDraft(
          admissionMode: null,
          registrationMode: EventRegistrationMode.external,
          confirmationMode: null,
        ),
        reasonCode: 'legacy_registration_external_unconfirmed',
      ),
      EventRegistrationMode.internal => const EventAdmissionLegacySuggestion(
        admission: EventAdmissionDraft(
          admissionMode: null,
          registrationMode: EventRegistrationMode.internal,
          confirmationMode: null,
        ),
        reasonCode: 'legacy_registration_internal_unconfirmed',
      ),
    };
  }
}

class NormalizeEventAdmissionPresetUseCase {
  const NormalizeEventAdmissionPresetUseCase();

  AdmissionPresetNormalizationResult call(
    EventAdmissionPreset preset, {
    AdmissionMode? admissionMode,
    EventRegistrationMode? registrationMode,
    ConfirmationMode? confirmationMode,
  }) {
    EventAdmissionDraft result(
      AdmissionMode admission,
      EventRegistrationMode registration,
      ConfirmationMode confirmation,
    ) => EventAdmissionDraft(
      admissionMode: admission,
      registrationMode: registration,
      confirmationMode: confirmation,
    );

    EventValidationIssue required(String fieldId, String message) =>
        EventValidationIssue(
          code: 'admission_preset_choice_required',
          fieldId: fieldId,
          step: 3,
          message: message,
        );

    switch (preset) {
      case EventAdmissionPreset.noRegistration:
        return AdmissionPresetNormalizationResult(
          admission: result(
            AdmissionMode.openEntry,
            EventRegistrationMode.none,
            ConfirmationMode.none,
          ),
        );
      case EventAdmissionPreset.freeRsvp:
        return AdmissionPresetNormalizationResult(
          admission: result(
            AdmissionMode.rsvp,
            EventRegistrationMode.internal,
            ConfirmationMode.instant,
          ),
        );
      case EventAdmissionPreset.organizerApplication:
        return AdmissionPresetNormalizationResult(
          admission: result(
            AdmissionMode.application,
            EventRegistrationMode.internal,
            ConfirmationMode.manualApproval,
          ),
        );
      case EventAdmissionPreset.externalRegistration:
        final bool validAdmission =
            admissionMode == AdmissionMode.rsvp ||
            admissionMode == AdmissionMode.booking;
        final List<EventValidationIssue> issues = <EventValidationIssue>[
          if (!validAdmission)
            required(
              'admissionMode',
              'Choose RSVP or booking before applying this preset.',
            ),
          if (confirmationMode == null)
            required(
              'confirmationMode',
              'Choose how external registration is confirmed.',
            ),
        ];
        return AdmissionPresetNormalizationResult(
          admission: issues.isEmpty
              ? result(
                  admissionMode!,
                  EventRegistrationMode.external,
                  confirmationMode!,
                )
              : null,
          issues: List<EventValidationIssue>.unmodifiable(issues),
        );
      case EventAdmissionPreset.externalTickets:
        return AdmissionPresetNormalizationResult(
          admission: result(
            AdmissionMode.ticket,
            EventRegistrationMode.external,
            ConfirmationMode.providerManaged,
          ),
        );
      case EventAdmissionPreset.rechargeTickets:
        final bool validConfirmation =
            confirmationMode == ConfirmationMode.instant ||
            confirmationMode == ConfirmationMode.manualApproval;
        if (!validConfirmation) {
          return AdmissionPresetNormalizationResult(
            admission: null,
            issues: <EventValidationIssue>[
              required(
                'confirmationMode',
                'Choose instant or manual approval before applying this preset.',
              ),
            ],
          );
        }
        return AdmissionPresetNormalizationResult(
          admission: result(
            AdmissionMode.ticket,
            EventRegistrationMode.internal,
            confirmationMode!,
          ),
        );
      case EventAdmissionPreset.teamRegistration:
        final bool validRegistration =
            registrationMode == EventRegistrationMode.internal ||
            registrationMode == EventRegistrationMode.external;
        final List<EventValidationIssue> issues = <EventValidationIssue>[
          if (!validRegistration)
            required(
              'registrationMode',
              'Choose internal or external team registration.',
            ),
          if (confirmationMode == null)
            required(
              'confirmationMode',
              'Choose how team registration is confirmed.',
            ),
        ];
        return AdmissionPresetNormalizationResult(
          admission: issues.isEmpty
              ? result(
                  AdmissionMode.teamRegistration,
                  registrationMode!,
                  confirmationMode!,
                )
              : null,
          issues: List<EventValidationIssue>.unmodifiable(issues),
        );
    }
  }
}
