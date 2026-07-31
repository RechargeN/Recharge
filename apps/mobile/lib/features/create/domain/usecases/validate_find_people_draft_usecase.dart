import '../entities/create_draft_entity.dart';
import '../entities/find_people_draft_data.dart';
import '../entities/find_people_validation_issue.dart';

class ValidateFindPeopleDraftUseCase {
  const ValidateFindPeopleDraftUseCase();

  List<FindPeopleValidationIssue> call(CreateDraftEntity draft) {
    if (draft.objectType != CreateObjectType.findPeople) {
      return const <FindPeopleValidationIssue>[];
    }
    final List<FindPeopleValidationIssue> issues =
        <FindPeopleValidationIssue>[];
    void error(String code, String section, String field, String message) {
      issues.add(
        FindPeopleValidationIssue(
          code: code,
          sectionId: section,
          fieldId: field,
          message: message,
        ),
      );
    }

    final FindPeopleDraftData? data = draft.findPeopleData;
    if (data == null) {
      error(
        'details_missing',
        'activity',
        'findPeopleData',
        'Find People details are missing',
      );
      return issues;
    }

    _length(
      draft.title,
      min: 5,
      max: 80,
      section: 'activity',
      field: 'title',
      label: 'Title',
      error: error,
    );
    _length(
      draft.shortDescription,
      min: 20,
      max: 180,
      section: 'activity',
      field: 'shortDescription',
      label: 'Short description',
      error: error,
    );
    _length(
      draft.fullDescription,
      min: 50,
      max: 2000,
      section: 'activity',
      field: 'fullDescription',
      label: 'Full description',
      error: error,
    );
    if (draft.mainCategory.trim().isEmpty) {
      error(
        'category_required',
        'activity',
        'mainCategory',
        'Choose a category',
      );
    }
    if (draft.subcategory.trim().isEmpty) {
      error(
        'subcategory_required',
        'activity',
        'subcategory',
        'Choose a subcategory',
      );
    }
    if (draft.tags.length > 8) {
      error('tags_limit', 'activity', 'tags', 'Use no more than 8 tags');
    }
    if (data.languageCodes.isEmpty || data.languageCodes.length > 3) {
      error(
        'languages_count',
        'activity',
        'languageCodes',
        'Choose 1–3 communication languages',
      );
    }
    final RegExp languagePattern = RegExp(
      r'^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$',
    );
    if (data.languageCodes.any(
      (String code) => !languagePattern.hasMatch(code),
    )) {
      error(
        'language_invalid',
        'activity',
        'languageCodes',
        'Language codes must use BCP-47 format',
      );
    }
    _max(
      data.equipmentNotes,
      500,
      'activity',
      'equipmentNotes',
      'Equipment notes',
      error,
    );
    _max(
      data.accessibilityNotes,
      500,
      'activity',
      'accessibilityNotes',
      'Accessibility notes',
      error,
    );
    _max(
      data.houseRulesNote,
      500,
      'activity',
      'houseRulesNote',
      'House rules note',
      error,
    );
    if (data.houseRuleIds.length > 10) {
      error(
        'house_rules_limit',
        'activity',
        'houseRuleIds',
        'Use no more than 10 house rules',
      );
    }
    final Map<String, String> publicText = <String, String>{
      'title': draft.title,
      'shortDescription': draft.shortDescription,
      'fullDescription': draft.fullDescription,
      'equipmentNotes': data.equipmentNotes ?? '',
      'accessibilityNotes': data.accessibilityNotes ?? '',
      'houseRulesNote': data.houseRulesNote ?? '',
      'costNote': data.costNote ?? '',
    };
    for (final MapEntry<String, String> entry in publicText.entries) {
      if (_containsContactOrPayment(entry.value)) {
        error(
          'public_contact_forbidden',
          'activity',
          entry.key,
          'Public text cannot contain contacts, payment links, or messenger handles',
        );
      }
    }

    _validateSchedule(draft, data, error);
    _validateMeeting(data, error);
    _validateGroup(data, error);
    _validatePublishing(draft, data, error);
    return issues;
  }

  void _validateSchedule(
    CreateDraftEntity draft,
    FindPeopleDraftData data,
    void Function(String, String, String, String) error,
  ) {
    final slots = draft.scheduleSlots.toList(growable: false);
    if (data.scheduleMode == FindPeopleScheduleMode.single &&
        slots.length != 1) {
      error(
        'single_slot_count',
        'schedule',
        'scheduleSlots',
        'Single schedule requires exactly one slot',
      );
    }
    if (data.scheduleMode == FindPeopleScheduleMode.timePoll &&
        slots.length < 2) {
      error(
        'poll_slot_count',
        'schedule',
        'scheduleSlots',
        'Time poll requires at least two options',
      );
    }
    if (data.scheduleMode == FindPeopleScheduleMode.recurring) {
      if (slots.isEmpty) {
        error(
          'recurring_slots',
          'schedule',
          'scheduleSlots',
          'Recurring schedule needs at least one materialized slot',
        );
      }
      if ((data.recurrenceRule?.trim().isEmpty ?? true)) {
        error(
          'recurrence_rule',
          'schedule',
          'recurrenceRule',
          'Add a recurrence rule',
        );
      }
      if (data.seriesEndAtUtc == null && data.maxOccurrences == null) {
        error(
          'recurrence_horizon',
          'schedule',
          'seriesEndAtUtc',
          'Recurring schedule must have a finite horizon',
        );
      }
      if (data.maxOccurrences != null &&
          (data.maxOccurrences! < 2 || data.maxOccurrences! > 52)) {
        error(
          'occurrence_limit',
          'schedule',
          'maxOccurrences',
          'Occurrence count must be between 2 and 52',
        );
      }
    }
    DateTime? previousEnd;
    for (final slot in slots) {
      final int duration = slot.endAtUtc.difference(slot.startAtUtc).inMinutes;
      if (duration < 30 || duration > 24 * 60) {
        error(
          'slot_duration',
          'schedule',
          'scheduleSlots',
          'Each slot must last from 30 minutes to 24 hours',
        );
      }
      if (previousEnd != null && slot.startAtUtc.isBefore(previousEnd)) {
        error(
          'slot_overlap',
          'schedule',
          'scheduleSlots',
          'Schedule options cannot overlap',
        );
      }
      previousEnd = slot.endAtUtc;
    }
    final DateTime? firstStart = slots.isEmpty ? null : slots.first.startAtUtc;
    if (data.scheduleMode == FindPeopleScheduleMode.timePoll) {
      final DateTime? deadline = data.pollResponseDeadlineUtc;
      if (deadline == null ||
          (firstStart != null && !deadline.isBefore(firstStart))) {
        error(
          'poll_deadline',
          'schedule',
          'pollResponseDeadlineUtc',
          'Poll deadline must be before the first option',
        );
      }
    } else if (draft.registrationDeadlineUtc == null ||
        (firstStart != null &&
            !draft.registrationDeadlineUtc!.isBefore(firstStart))) {
      error(
        'application_deadline',
        'schedule',
        'registrationDeadlineUtc',
        'Application deadline must be before the first meeting',
      );
    }
    if (data.publishAtUtc != null &&
        firstStart != null &&
        !data.publishAtUtc!.isBefore(firstStart)) {
      error(
        'scheduled_publish',
        'publish',
        'publishAtUtc',
        'Scheduled publish must be before the first meeting',
      );
    }
  }

  void _validateMeeting(
    FindPeopleDraftData data,
    void Function(String, String, String, String) error,
  ) {
    final bool physical = data.meetingMode != FindPeopleMeetingMode.online;
    final bool online = data.meetingMode != FindPeopleMeetingMode.inPerson;
    if (physical) {
      if ((data.meetingPlaceName?.trim().isEmpty ?? true)) {
        error(
          'meeting_name',
          'meeting',
          'meetingPlaceName',
          'Add a public meeting place',
        );
      }
      if ((data.publicAreaLabel?.trim().isEmpty ?? true)) {
        error(
          'public_area',
          'meeting',
          'publicAreaLabel',
          'Add a safe public area label',
        );
      }
      if (data.publicGeo == null || !data.publicGeo!.isValid) {
        error(
          'public_geo',
          'meeting',
          'publicGeo',
          'Add a valid approximate public map point',
        );
      }
      if (data.exactGeo == null || !data.exactGeo!.isValid) {
        error(
          'exact_geo',
          'meeting',
          'exactGeo',
          'Add a valid exact meeting point',
        );
      }
      if ((data.exactAddressLine?.trim().isEmpty ?? true)) {
        error(
          'exact_address',
          'meeting',
          'exactAddressLine',
          'Add the private exact address',
        );
      }
      if (!data.publicPlaceConfirmed) {
        error(
          'public_place',
          'meeting',
          'publicPlaceConfirmed',
          'Confirm that the meeting point is a public place',
        );
      }
      if (_looksResidential(data.exactAddressLine ?? '')) {
        error(
          'unsafe_location',
          'meeting',
          'exactAddressLine',
          'Private homes and residential access details are not allowed',
        );
      }
    } else if (data.publicGeo != null ||
        data.exactGeo != null ||
        data.exactAddressLine != null) {
      error(
        'online_geo_forbidden',
        'meeting',
        'meetingMode',
        'Online requests cannot publish fake map coordinates or an address',
      );
    }
    if (online) {
      if ((data.onlineProvider?.trim().isEmpty ?? true)) {
        error(
          'online_provider',
          'meeting',
          'onlineProvider',
          'Choose an online provider',
        );
      }
      if ((data.onlineAccessSecretRef?.trim().isEmpty ?? true)) {
        error(
          'online_secret',
          'meeting',
          'onlineAccessSecretRef',
          'Add a private session-scoped access reference',
        );
      }
    } else if (data.onlineProvider != null ||
        data.onlineAccessSecretRef != null) {
      error(
        'offline_secret_forbidden',
        'meeting',
        'onlineProvider',
        'In-person requests cannot contain online access data',
      );
    }
    _max(
      data.meetingInstructions,
      500,
      'meeting',
      'meetingInstructions',
      'Meeting instructions',
      error,
    );
  }

  void _validateGroup(
    FindPeopleDraftData data,
    void Function(String, String, String, String) error,
  ) {
    if (data.targetGroupSize < 2 || data.targetGroupSize > 20) {
      error(
        'group_size',
        'group',
        'targetGroupSize',
        'Group size must be between 2 and 20',
      );
    }
    if (data.hostSeatCount < 1 || data.hostSeatCount >= data.targetGroupSize) {
      error(
        'host_seats',
        'group',
        'hostSeatCount',
        'Host seats must be lower than total group size',
      );
    }
    final int maxApplicantSeats = data.targetGroupSize - data.hostSeatCount;
    if (!data.allowPartyApplications && data.maxSeatsPerApplication != 1) {
      error(
        'party_disabled',
        'group',
        'maxSeatsPerApplication',
        'Single-person applications must reserve exactly one seat',
      );
    }
    if (data.allowPartyApplications &&
        (data.maxSeatsPerApplication < 1 ||
            data.maxSeatsPerApplication > 4 ||
            data.maxSeatsPerApplication > maxApplicantSeats)) {
      error(
        'party_seats',
        'group',
        'maxSeatsPerApplication',
        'Party applications can request 1–4 available seats',
      );
    }
    if (data.applicationQuestions.length > 8) {
      error(
        'questions_limit',
        'group',
        'applicationQuestions',
        'Use no more than 8 application questions',
      );
    }
    if (data.applicationQuestions.any(
      (item) => item.id.trim().isEmpty || item.prompt.trim().isEmpty,
    )) {
      error(
        'question_invalid',
        'group',
        'applicationQuestions',
        'Every application question needs an ID and prompt',
      );
    }
    if (data.approvalMode == FindPeopleApprovalMode.inviteOnly &&
        data.visibility != FindPeopleVisibility.inviteOnly) {
      error(
        'invite_visibility',
        'hosts',
        'visibility',
        'Invite-only approval requires invite-only visibility',
      );
    }
    if (data.visibility == FindPeopleVisibility.inviteOnly &&
        data.approvalMode != FindPeopleApprovalMode.inviteOnly) {
      error(
        'visibility_approval',
        'group',
        'approvalMode',
        'Invite-only visibility requires invite-only approval',
      );
    }
    if (data.costType == FindPeopleCostType.estimated &&
        (data.expectedSpendAmount == null ||
            data.expectedSpendAmount! <= 0 ||
            data.currencyCode.trim().isEmpty)) {
      error(
        'estimated_cost',
        'group',
        'expectedSpendAmount',
        'Estimated cost requires a positive amount and currency',
      );
    }
    if (data.costType != FindPeopleCostType.estimated &&
        data.expectedSpendAmount != null &&
        data.expectedSpendAmount! != 0) {
      error(
        'cost_amount_forbidden',
        'group',
        'expectedSpendAmount',
        'Only estimated cost can contain an amount',
      );
    }
    if (data.expenseSplitMode == FindPeopleExpenseSplitMode.itemized &&
        data.plannedExpenseItems.isEmpty) {
      error(
        'expense_items',
        'group',
        'plannedExpenseItems',
        'Itemized split requires planned expense items',
      );
    }
    if (data.plannedExpenseItems.any(
      (item) =>
          item.id.trim().isEmpty ||
          item.category.trim().isEmpty ||
          item.amount <= 0,
    )) {
      error(
        'expense_invalid',
        'group',
        'plannedExpenseItems',
        'Every expense item needs an ID, category, and positive amount',
      );
    }
    _max(data.costNote, 300, 'group', 'costNote', 'Cost note', error);
  }

  void _validatePublishing(
    CreateDraftEntity draft,
    FindPeopleDraftData data,
    void Function(String, String, String, String) error,
  ) {
    if (data.publisherId.trim().isEmpty) {
      error('publisher', 'hosts', 'publisherId', 'Publisher is required');
    }
    if (data.responsibleHostUserIds.isEmpty) {
      error(
        'responsible_host',
        'hosts',
        'responsibleHostUserIds',
        'At least one responsible host is required',
      );
    }
    if (data.publisherType == FindPeoplePublisherType.page &&
        data.responsibleHostUserIds.isEmpty) {
      error(
        'page_host',
        'hosts',
        'responsibleHostUserIds',
        'A page request needs a responsible host',
      );
    }
    if (data.coHosts.any(
      (item) =>
          item.userId.trim().isEmpty ||
          item.capabilityIds.difference(_allowedCoHostCapabilities).isNotEmpty,
    )) {
      error(
        'cohost_grants',
        'hosts',
        'coHosts',
        'Co-host grants must use supported capabilities',
      );
    }
    if ((data.quietHoursStartMinute != null &&
            (data.quietHoursStartMinute! < 0 ||
                data.quietHoursStartMinute! > 1439)) ||
        (data.quietHoursEndMinute != null &&
            (data.quietHoursEndMinute! < 0 ||
                data.quietHoursEndMinute! > 1439))) {
      error(
        'quiet_hours',
        'hosts',
        'quietHoursStartMinute',
        'Quiet-hour minutes must be between 0 and 1439',
      );
    }
    if (!data.safetyRulesAccepted) {
      error(
        'safety_rules',
        'publish',
        'safetyRulesAccepted',
        'Accept the Find People safety rules',
      );
    }
    if (!data.accuracyConfirmed) {
      error(
        'accuracy',
        'publish',
        'accuracyConfirmed',
        'Confirm that the request details are accurate',
      );
    }
    if (!data.ageRequirementConfirmed) {
      error(
        'adult_only',
        'publish',
        'ageRequirementConfirmed',
        'Confirm that this request is for adults 18+',
      );
    }
    if (!data.responsibleHostUserIds.contains(draft.organizerId) &&
        data.publisherType == FindPeoplePublisherType.user) {
      error(
        'publisher_host_mismatch',
        'hosts',
        'responsibleHostUserIds',
        'A personal request must include its owner as responsible host',
      );
    }
  }

  static const Set<String> _allowedCoHostCapabilities = <String>{
    'review_applications',
    'manage_schedule',
    'manage_participants',
    'moderate_conversation',
  };

  static void _length(
    String value, {
    required int min,
    required int max,
    required String section,
    required String field,
    required String label,
    required void Function(String, String, String, String) error,
  }) {
    final int length = value.trim().length;
    if (length < min || length > max) {
      error(
        '${field}_length',
        section,
        field,
        '$label must contain $min–$max characters',
      );
    }
  }

  static void _max(
    String? value,
    int max,
    String section,
    String field,
    String label,
    void Function(String, String, String, String) error,
  ) {
    if ((value?.trim().length ?? 0) > max) {
      error(
        '${field}_length',
        section,
        field,
        '$label cannot exceed $max characters',
      );
    }
  }

  static bool _containsContactOrPayment(String value) {
    final String normalized = value.toLowerCase();
    return RegExp(
          r'\b[\w.+-]+@[\w.-]+\.[a-z]{2,}\b',
          caseSensitive: false,
        ).hasMatch(value) ||
        RegExp(r'https?://|www\.', caseSensitive: false).hasMatch(value) ||
        RegExp(
          r'(?<!\w)@[a-z0-9_]{3,}',
          caseSensitive: false,
        ).hasMatch(value) ||
        RegExp(r'\+?\d[\d\s().-]{7,}\d').hasMatch(value) ||
        normalized.contains('paypal') ||
        normalized.contains('revolut') ||
        normalized.contains('bank transfer');
  }

  static bool _looksResidential(String value) {
    final String normalized = value.toLowerCase();
    return <String>[
      'apartment',
      'flat ',
      'door code',
      'home address',
      'квартира',
      'код двери',
      'домашний адрес',
    ].any(normalized.contains);
  }
}
