enum AdmissionMode {
  openEntry,
  rsvp,
  booking,
  application,
  ticket,
  teamRegistration,
}

enum EventRegistrationMode { none, external, internal }

enum ConfirmationMode {
  none,
  instant,
  manualApproval,
  lottery,
  providerManaged,
}

enum EligibilityRuleKind {
  invitation,
  accessCode,
  membership,
  allowlist,
  qualification,
  accreditation,
  ageRequirement,
  waiver,
}

enum GuestPolicyMode { none, plusOne, plusN, namedGuestsOnly }

enum EventAccessWindowKind { absolute, occurrenceRelative }

enum WaitlistPromotionMode { organizerManaged, fifoAutomatic }

enum EventAdmissionPreset {
  noRegistration,
  freeRsvp,
  organizerApplication,
  externalRegistration,
  externalTickets,
  rechargeTickets,
  teamRegistration,
}

class EligibilityRule {
  const EligibilityRule({
    required this.id,
    required this.kind,
    this.publicExplanation,
    this.policyRef,
  });

  final String id;
  final EligibilityRuleKind kind;
  final String? publicExplanation;
  final String? policyRef;

  EligibilityRule copyWith({
    String? id,
    EligibilityRuleKind? kind,
    String? publicExplanation,
    bool clearPublicExplanation = false,
    String? policyRef,
    bool clearPolicyRef = false,
  }) => EligibilityRule(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    publicExplanation: clearPublicExplanation
        ? null
        : (publicExplanation ?? this.publicExplanation),
    policyRef: clearPolicyRef ? null : (policyRef ?? this.policyRef),
  );
}

class GuestPolicy {
  const GuestPolicy({
    required this.mode,
    this.maxGuests,
    this.countsAgainstCapacity = true,
  });

  final GuestPolicyMode mode;
  final int? maxGuests;
  final bool countsAgainstCapacity;

  GuestPolicy copyWith({
    GuestPolicyMode? mode,
    int? maxGuests,
    bool clearMaxGuests = false,
    bool? countsAgainstCapacity,
  }) => GuestPolicy(
    mode: mode ?? this.mode,
    maxGuests: clearMaxGuests ? null : (maxGuests ?? this.maxGuests),
    countsAgainstCapacity: countsAgainstCapacity ?? this.countsAgainstCapacity,
  );
}

class OnsiteAdmissionPolicy {
  const OnsiteAdmissionPolicy({
    required this.allowed,
    required this.salesAtDoor,
    required this.registrationAtDoor,
    required this.subjectToAvailability,
  });

  final bool allowed;
  final bool salesAtDoor;
  final bool registrationAtDoor;
  final bool subjectToAvailability;

  OnsiteAdmissionPolicy copyWith({
    bool? allowed,
    bool? salesAtDoor,
    bool? registrationAtDoor,
    bool? subjectToAvailability,
  }) => OnsiteAdmissionPolicy(
    allowed: allowed ?? this.allowed,
    salesAtDoor: salesAtDoor ?? this.salesAtDoor,
    registrationAtDoor: registrationAtDoor ?? this.registrationAtDoor,
    subjectToAvailability: subjectToAvailability ?? this.subjectToAvailability,
  );
}

class InterestPolicy {
  const InterestPolicy({
    required this.optionalRsvpEnabled,
    this.reminderConsentRequired = true,
    this.createsBooking = false,
    this.reservesInventory = false,
    this.registrationAtDoorRequired = false,
  });

  final bool optionalRsvpEnabled;
  final bool reminderConsentRequired;
  final bool createsBooking;
  final bool reservesInventory;
  final bool registrationAtDoorRequired;

  InterestPolicy copyWith({
    bool? optionalRsvpEnabled,
    bool? reminderConsentRequired,
    bool? createsBooking,
    bool? reservesInventory,
    bool? registrationAtDoorRequired,
  }) => InterestPolicy(
    optionalRsvpEnabled: optionalRsvpEnabled ?? this.optionalRsvpEnabled,
    reminderConsentRequired:
        reminderConsentRequired ?? this.reminderConsentRequired,
    createsBooking: createsBooking ?? this.createsBooking,
    reservesInventory: reservesInventory ?? this.reservesInventory,
    registrationAtDoorRequired:
        registrationAtDoorRequired ?? this.registrationAtDoorRequired,
  );
}

class EventAccessWindow {
  const EventAccessWindow({
    required this.kind,
    this.opensAtUtc,
    this.closesAtUtc,
    this.opensBeforeOccurrenceMinutes,
    this.closesBeforeOccurrenceMinutes,
  });

  final EventAccessWindowKind kind;
  final DateTime? opensAtUtc;
  final DateTime? closesAtUtc;
  final int? opensBeforeOccurrenceMinutes;
  final int? closesBeforeOccurrenceMinutes;

  EventAccessWindow copyWith({
    EventAccessWindowKind? kind,
    DateTime? opensAtUtc,
    bool clearOpensAtUtc = false,
    DateTime? closesAtUtc,
    bool clearClosesAtUtc = false,
    int? opensBeforeOccurrenceMinutes,
    bool clearOpensBeforeOccurrenceMinutes = false,
    int? closesBeforeOccurrenceMinutes,
    bool clearClosesBeforeOccurrenceMinutes = false,
  }) => EventAccessWindow(
    kind: kind ?? this.kind,
    opensAtUtc: clearOpensAtUtc ? null : (opensAtUtc ?? this.opensAtUtc),
    closesAtUtc: clearClosesAtUtc ? null : (closesAtUtc ?? this.closesAtUtc),
    opensBeforeOccurrenceMinutes: clearOpensBeforeOccurrenceMinutes
        ? null
        : (opensBeforeOccurrenceMinutes ?? this.opensBeforeOccurrenceMinutes),
    closesBeforeOccurrenceMinutes: clearClosesBeforeOccurrenceMinutes
        ? null
        : (closesBeforeOccurrenceMinutes ?? this.closesBeforeOccurrenceMinutes),
  );
}

class WaitlistConfiguration {
  const WaitlistConfiguration({
    required this.enabled,
    required this.promotionMode,
    this.offerTtlMinutes,
    this.paymentDeadlineMinutes,
  });

  final bool enabled;
  final WaitlistPromotionMode promotionMode;
  final int? offerTtlMinutes;
  final int? paymentDeadlineMinutes;

  WaitlistConfiguration copyWith({
    bool? enabled,
    WaitlistPromotionMode? promotionMode,
    int? offerTtlMinutes,
    bool clearOfferTtlMinutes = false,
    int? paymentDeadlineMinutes,
    bool clearPaymentDeadlineMinutes = false,
  }) => WaitlistConfiguration(
    enabled: enabled ?? this.enabled,
    promotionMode: promotionMode ?? this.promotionMode,
    offerTtlMinutes: clearOfferTtlMinutes
        ? null
        : (offerTtlMinutes ?? this.offerTtlMinutes),
    paymentDeadlineMinutes: clearPaymentDeadlineMinutes
        ? null
        : (paymentDeadlineMinutes ?? this.paymentDeadlineMinutes),
  );
}

class EventAdmissionDraft {
  const EventAdmissionDraft({
    required this.admissionMode,
    required this.registrationMode,
    required this.confirmationMode,
    this.eligibilityRules = const <EligibilityRule>[],
    this.guestPolicy,
    this.onsiteAdmissionPolicy,
    this.interestPolicy,
    this.registrationWindow,
    this.applicationWindow,
    this.waitlistPolicy,
  });

  final AdmissionMode? admissionMode;
  final EventRegistrationMode? registrationMode;
  final ConfirmationMode? confirmationMode;
  final List<EligibilityRule> eligibilityRules;
  final GuestPolicy? guestPolicy;
  final OnsiteAdmissionPolicy? onsiteAdmissionPolicy;
  final InterestPolicy? interestPolicy;
  final EventAccessWindow? registrationWindow;
  final EventAccessWindow? applicationWindow;
  final WaitlistConfiguration? waitlistPolicy;

  bool get isComplete =>
      admissionMode != null &&
      registrationMode != null &&
      confirmationMode != null;

  EventAdmissionDraft replaceLocalIds(String Function() nextId) => copyWith(
    eligibilityRules: eligibilityRules
        .map(
          (rule) =>
              rule.id.startsWith('loc_') ? rule.copyWith(id: nextId()) : rule,
        )
        .toList(growable: false),
  );

  EventAdmissionDraft copyWith({
    AdmissionMode? admissionMode,
    bool clearAdmissionMode = false,
    EventRegistrationMode? registrationMode,
    bool clearRegistrationMode = false,
    ConfirmationMode? confirmationMode,
    bool clearConfirmationMode = false,
    List<EligibilityRule>? eligibilityRules,
    GuestPolicy? guestPolicy,
    bool clearGuestPolicy = false,
    OnsiteAdmissionPolicy? onsiteAdmissionPolicy,
    bool clearOnsiteAdmissionPolicy = false,
    InterestPolicy? interestPolicy,
    bool clearInterestPolicy = false,
    EventAccessWindow? registrationWindow,
    bool clearRegistrationWindow = false,
    EventAccessWindow? applicationWindow,
    bool clearApplicationWindow = false,
    WaitlistConfiguration? waitlistPolicy,
    bool clearWaitlistPolicy = false,
  }) => EventAdmissionDraft(
    admissionMode: clearAdmissionMode
        ? null
        : (admissionMode ?? this.admissionMode),
    registrationMode: clearRegistrationMode
        ? null
        : (registrationMode ?? this.registrationMode),
    confirmationMode: clearConfirmationMode
        ? null
        : (confirmationMode ?? this.confirmationMode),
    eligibilityRules: eligibilityRules ?? this.eligibilityRules,
    guestPolicy: clearGuestPolicy ? null : (guestPolicy ?? this.guestPolicy),
    onsiteAdmissionPolicy: clearOnsiteAdmissionPolicy
        ? null
        : (onsiteAdmissionPolicy ?? this.onsiteAdmissionPolicy),
    interestPolicy: clearInterestPolicy
        ? null
        : (interestPolicy ?? this.interestPolicy),
    registrationWindow: clearRegistrationWindow
        ? null
        : (registrationWindow ?? this.registrationWindow),
    applicationWindow: clearApplicationWindow
        ? null
        : (applicationWindow ?? this.applicationWindow),
    waitlistPolicy: clearWaitlistPolicy
        ? null
        : (waitlistPolicy ?? this.waitlistPolicy),
  );
}
