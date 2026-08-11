import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/event_admission.dart';
import 'package:recharge/features/create/domain/entities/event_draft_data.dart';
import 'package:recharge/features/create/domain/usecases/normalize_event_admission_preset_usecase.dart';
import 'package:recharge/features/create/domain/usecases/validate_event_access_configuration_usecase.dart';

void main() {
  const NormalizeEventAdmissionPresetUseCase normalize =
      NormalizeEventAdmissionPresetUseCase();
  const ValidateEventAccessConfigurationUseCase validate =
      ValidateEventAccessConfigurationUseCase();

  test('canonical admission dictionaries are complete', () {
    expect(AdmissionMode.values, hasLength(6));
    expect(EventRegistrationMode.values, hasLength(3));
    expect(ConfirmationMode.values, hasLength(5));
    expect(EligibilityRuleKind.values, hasLength(8));
  });

  test('preset normalizes to independent axes and ambiguous preset blocks', () {
    final free = normalize(EventAdmissionPreset.freeRsvp);
    expect(free.canApply, isTrue);
    expect(free.admission!.admissionMode, AdmissionMode.rsvp);
    expect(free.admission!.registrationMode, EventRegistrationMode.internal);
    expect(free.admission!.confirmationMode, ConfirmationMode.instant);

    final ambiguous = normalize(EventAdmissionPreset.externalRegistration);
    expect(ambiguous.canApply, isFalse);
    expect(ambiguous.admission, isNull);
    expect(ambiguous.issues, hasLength(2));
  });

  test(
    'legacy migration suggestions preserve ambiguity until confirmation',
    () {
      const SuggestLegacyEventAdmissionUseCase suggest =
          SuggestLegacyEventAdmissionUseCase();
      final EventAdmissionLegacySuggestion none = suggest(
        schemaVersion: 2,
        registrationMode: EventRegistrationMode.none,
      )!;
      expect(none.canConfirm, isTrue);
      expect(none.admission.admissionMode, AdmissionMode.openEntry);

      final EventAdmissionLegacySuggestion external = suggest(
        schemaVersion: 2,
        registrationMode: EventRegistrationMode.external,
      )!;
      expect(external.canConfirm, isFalse);
      expect(
        external.admission.registrationMode,
        EventRegistrationMode.external,
      );
      expect(external.admission.admissionMode, isNull);
      expect(
        suggest(schemaVersion: 3, registrationMode: EventRegistrationMode.none),
        isNull,
      );
    },
  );

  test('open entry and optional interest never create booking semantics', () {
    final issues = validate(
      admission: const EventAdmissionDraft(
        admissionMode: AdmissionMode.openEntry,
        registrationMode: EventRegistrationMode.none,
        confirmationMode: ConfirmationMode.none,
        interestPolicy: InterestPolicy(optionalRsvpEnabled: true),
      ),
      inventory: null,
      capacityMode: EventCapacityMode.unlimited,
      capacity: null,
      format: EventFormat.offline,
      scheduleMode: EventScheduleMode.oneTime,
      occurrences: _occurrences(),
      externalRegistrationUrl: null,
    );

    expect(issues, isEmpty);
  });

  test('unsafe interest, guests and secret-like policy refs fail closed', () {
    final issues = validate(
      admission: const EventAdmissionDraft(
        admissionMode: AdmissionMode.openEntry,
        registrationMode: EventRegistrationMode.none,
        confirmationMode: ConfirmationMode.none,
        interestPolicy: InterestPolicy(
          optionalRsvpEnabled: true,
          createsBooking: true,
        ),
        guestPolicy: GuestPolicy(
          mode: GuestPolicyMode.plusN,
          countsAgainstCapacity: false,
        ),
        eligibilityRules: <EligibilityRule>[
          EligibilityRule(
            id: 'loc_rule',
            kind: EligibilityRuleKind.accessCode,
            policyRef: 'secret@example.com',
          ),
        ],
      ),
      inventory: null,
      capacityMode: EventCapacityMode.unlimited,
      capacity: null,
      format: EventFormat.offline,
      scheduleMode: EventScheduleMode.oneTime,
      occurrences: _occurrences(),
      externalRegistrationUrl: null,
    );

    expect(
      issues.map((issue) => issue.code),
      containsAll(<String>[
        'interest_policy_not_non_reserving',
        'guest_capacity_bypass_unsupported',
        'guest_limit_required',
        'eligibility_policy_ref_invalid',
      ]),
    );
  });

  test('relative windows are required for recurring Event', () {
    final issues = validate(
      admission: EventAdmissionDraft(
        admissionMode: AdmissionMode.application,
        registrationMode: EventRegistrationMode.external,
        confirmationMode: ConfirmationMode.manualApproval,
        applicationWindow: EventAccessWindow(
          kind: EventAccessWindowKind.absolute,
          opensAtUtc: DateTime.utc(2030, 1, 1),
          closesAtUtc: DateTime.utc(2030, 1, 2),
        ),
      ),
      inventory: null,
      capacityMode: EventCapacityMode.unknown,
      capacity: null,
      format: EventFormat.online,
      scheduleMode: EventScheduleMode.recurring,
      occurrences: _occurrences(),
      externalRegistrationUrl: 'https://provider.example/register',
    );

    expect(
      issues.map((issue) => issue.code),
      contains('access_window_must_be_relative'),
    );
  });

  test('internal, provider-managed and lottery capabilities stay gated', () {
    final providerIssues = validate(
      admission: const EventAdmissionDraft(
        admissionMode: AdmissionMode.ticket,
        registrationMode: EventRegistrationMode.external,
        confirmationMode: ConfirmationMode.providerManaged,
      ),
      inventory: null,
      capacityMode: EventCapacityMode.unknown,
      capacity: null,
      format: EventFormat.online,
      scheduleMode: EventScheduleMode.oneTime,
      occurrences: _occurrences(),
      externalRegistrationUrl: 'https://provider.example/register',
    );
    expect(
      providerIssues.map((issue) => issue.code),
      contains('provider_confirmation_not_ready'),
    );

    final lotteryIssues = validate(
      admission: const EventAdmissionDraft(
        admissionMode: AdmissionMode.application,
        registrationMode: EventRegistrationMode.internal,
        confirmationMode: ConfirmationMode.lottery,
      ),
      inventory: null,
      capacityMode: EventCapacityMode.unknown,
      capacity: null,
      format: EventFormat.offline,
      scheduleMode: EventScheduleMode.oneTime,
      occurrences: _occurrences(),
      externalRegistrationUrl: null,
    );
    expect(
      lotteryIssues.map((issue) => issue.code),
      containsAll(<String>[
        'internal_registration_not_ready',
        'lottery_not_ready',
      ]),
    );
  });
}

List<EventOccurrenceDraft> _occurrences() => <EventOccurrenceDraft>[
  EventOccurrenceDraft(
    id: 'loc_occurrence',
    localDate: '2030-01-10',
    startAtUtc: DateTime.utc(2030, 1, 10, 18),
    endAtUtc: DateTime.utc(2030, 1, 10, 20),
  ),
];
