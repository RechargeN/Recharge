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
    void error(
      String code,
      String section,
      String field, [
      Map<String, int> params = const <String, int>{},
    ]) {
      issues.add(
        FindPeopleValidationIssue(
          code: code,
          sectionId: section,
          fieldId: field,
          params: params,
        ),
      );
    }

    final FindPeopleDraftData? data = draft.findPeopleData;
    if (data == null) {
      error('details_missing', 'activity', 'findPeopleData');
      return issues;
    }

    _length(
      draft.title,
      min: 5,
      max: 80,
      section: 'activity',
      field: 'title',
      error: error,
    );
    _length(
      draft.shortDescription,
      min: 20,
      max: 180,
      section: 'activity',
      field: 'shortDescription',
      error: error,
    );
    _length(
      draft.fullDescription,
      min: 50,
      max: 2000,
      section: 'activity',
      field: 'fullDescription',
      error: error,
    );
    if (draft.mainCategory.trim().isEmpty) {
      error('category_required', 'activity', 'mainCategory');
    }
    if (draft.subcategory.trim().isEmpty) {
      error('subcategory_required', 'activity', 'subcategory');
    }
    if (draft.tags.length > 8) {
      error('tags_limit', 'activity', 'tags');
    }
    if (data.languageCodes.isEmpty || data.languageCodes.length > 3) {
      error('languages_count', 'activity', 'languageCodes');
    }
    final RegExp languagePattern = RegExp(
      r'^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$',
    );
    if (data.languageCodes.any(
      (String code) => !languagePattern.hasMatch(code),
    )) {
      error('language_invalid', 'activity', 'languageCodes');
    }
    _max(data.equipmentNotes, 500, 'activity', 'equipmentNotes', error);
    _max(data.accessibilityNotes, 500, 'activity', 'accessibilityNotes', error);
    _max(data.houseRulesNote, 500, 'activity', 'houseRulesNote', error);
    if (data.houseRuleIds.length > 10) {
      error('house_rules_limit', 'activity', 'houseRuleIds');
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
        error('public_contact_forbidden', 'activity', entry.key);
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
    void Function(String, String, String, [Map<String, int>]) error,
  ) {
    final slots = draft.scheduleSlots.toList(growable: false);
    if (data.scheduleMode == FindPeopleScheduleMode.single &&
        slots.length != 1) {
      error('single_slot_count', 'schedule', 'scheduleSlots');
    }
    if (data.scheduleMode == FindPeopleScheduleMode.timePoll &&
        slots.length < 2) {
      error('poll_slot_count', 'schedule', 'scheduleSlots');
    }
    if (data.scheduleMode == FindPeopleScheduleMode.recurring) {
      if (slots.isEmpty) {
        error('recurring_slots', 'schedule', 'scheduleSlots');
      }
      if ((data.recurrenceRule?.trim().isEmpty ?? true)) {
        error('recurrence_rule', 'schedule', 'recurrenceRule');
      }
      if (data.seriesEndAtUtc == null && data.maxOccurrences == null) {
        error('recurrence_horizon', 'schedule', 'seriesEndAtUtc');
      }
      if (data.maxOccurrences != null &&
          (data.maxOccurrences! < 2 || data.maxOccurrences! > 52)) {
        error('occurrence_limit', 'schedule', 'maxOccurrences');
      }
    }
    DateTime? previousEnd;
    for (final slot in slots) {
      final int duration = slot.endAtUtc.difference(slot.startAtUtc).inMinutes;
      if (duration < 30 || duration > 24 * 60) {
        error('slot_duration', 'schedule', 'scheduleSlots');
      }
      if (previousEnd != null && slot.startAtUtc.isBefore(previousEnd)) {
        error('slot_overlap', 'schedule', 'scheduleSlots');
      }
      previousEnd = slot.endAtUtc;
    }
    final DateTime? firstStart = slots.isEmpty ? null : slots.first.startAtUtc;
    if (data.scheduleMode == FindPeopleScheduleMode.timePoll) {
      final DateTime? deadline = data.pollResponseDeadlineUtc;
      if (deadline == null ||
          (firstStart != null && !deadline.isBefore(firstStart))) {
        error('poll_deadline', 'schedule', 'pollResponseDeadlineUtc');
      }
    } else if (draft.registrationDeadlineUtc == null ||
        (firstStart != null &&
            !draft.registrationDeadlineUtc!.isBefore(firstStart))) {
      error('application_deadline', 'schedule', 'registrationDeadlineUtc');
    }
    if (data.publishAtUtc != null &&
        firstStart != null &&
        !data.publishAtUtc!.isBefore(firstStart)) {
      error('scheduled_publish', 'publish', 'publishAtUtc');
    }
  }

  void _validateMeeting(
    FindPeopleDraftData data,
    void Function(String, String, String, [Map<String, int>]) error,
  ) {
    final bool physical = data.meetingMode != FindPeopleMeetingMode.online;
    final bool online = data.meetingMode != FindPeopleMeetingMode.inPerson;
    if (physical) {
      if ((data.meetingPlaceName?.trim().isEmpty ?? true)) {
        error('meeting_name', 'meeting', 'meetingPlaceName');
      }
      if ((data.publicAreaLabel?.trim().isEmpty ?? true)) {
        error('public_area', 'meeting', 'publicAreaLabel');
      }
      if (data.publicGeo == null || !data.publicGeo!.isValid) {
        error('public_geo', 'meeting', 'publicGeo');
      }
      if (data.exactGeo == null || !data.exactGeo!.isValid) {
        error('exact_geo', 'meeting', 'exactGeo');
      }
      if ((data.exactAddressLine?.trim().isEmpty ?? true)) {
        error('exact_address', 'meeting', 'exactAddressLine');
      }
      if (!data.publicPlaceConfirmed) {
        error('public_place', 'meeting', 'publicPlaceConfirmed');
      }
      if (_looksResidential(data.exactAddressLine ?? '')) {
        error('unsafe_location', 'meeting', 'exactAddressLine');
      }
    } else if (data.publicGeo != null ||
        data.exactGeo != null ||
        data.exactAddressLine != null) {
      error('online_geo_forbidden', 'meeting', 'meetingMode');
    }
    if (online) {
      if ((data.onlineProvider?.trim().isEmpty ?? true)) {
        error('online_provider', 'meeting', 'onlineProvider');
      }
      if ((data.onlineAccessSecretRef?.trim().isEmpty ?? true)) {
        error('online_secret', 'meeting', 'onlineAccessSecretRef');
      }
    } else if (data.onlineProvider != null ||
        data.onlineAccessSecretRef != null) {
      error('offline_secret_forbidden', 'meeting', 'onlineProvider');
    }
    _max(
      data.meetingInstructions,
      500,
      'meeting',
      'meetingInstructions',
      error,
    );
  }

  void _validateGroup(
    FindPeopleDraftData data,
    void Function(String, String, String, [Map<String, int>]) error,
  ) {
    if (data.targetGroupSize < 2 || data.targetGroupSize > 20) {
      error('group_size', 'group', 'targetGroupSize');
    }
    if (data.hostSeatCount < 1 || data.hostSeatCount >= data.targetGroupSize) {
      error('host_seats', 'group', 'hostSeatCount');
    }
    final int maxApplicantSeats = data.targetGroupSize - data.hostSeatCount;
    if (!data.allowPartyApplications && data.maxSeatsPerApplication != 1) {
      error('party_disabled', 'group', 'maxSeatsPerApplication');
    }
    if (data.allowPartyApplications &&
        (data.maxSeatsPerApplication < 1 ||
            data.maxSeatsPerApplication > 4 ||
            data.maxSeatsPerApplication > maxApplicantSeats)) {
      error('party_seats', 'group', 'maxSeatsPerApplication');
    }
    if (data.applicationQuestions.length > 8) {
      error('questions_limit', 'group', 'applicationQuestions');
    }
    if (data.applicationQuestions.any(
      (item) => item.id.trim().isEmpty || item.prompt.trim().isEmpty,
    )) {
      error('question_invalid', 'group', 'applicationQuestions');
    }
    if (data.approvalMode == FindPeopleApprovalMode.inviteOnly &&
        data.visibility != FindPeopleVisibility.inviteOnly) {
      error('invite_visibility', 'hosts', 'visibility');
    }
    if (data.visibility == FindPeopleVisibility.inviteOnly &&
        data.approvalMode != FindPeopleApprovalMode.inviteOnly) {
      error('visibility_approval', 'group', 'approvalMode');
    }
    if (data.costType == FindPeopleCostType.estimated &&
        (data.expectedSpendAmount == null ||
            data.expectedSpendAmount!.minorUnits <= 0 ||
            data.currencyCode.trim().isEmpty)) {
      error('estimated_cost', 'group', 'expectedSpendAmount');
    }
    if (data.costType != FindPeopleCostType.estimated &&
        data.expectedSpendAmount != null &&
        data.expectedSpendAmount!.minorUnits != 0) {
      error('cost_amount_forbidden', 'group', 'expectedSpendAmount');
    }
    if (data.expenseSplitMode == FindPeopleExpenseSplitMode.itemized &&
        data.plannedExpenseItems.isEmpty) {
      error('expense_items', 'group', 'plannedExpenseItems');
    }
    if (data.plannedExpenseItems.any(
      (item) =>
          item.id.trim().isEmpty ||
          item.category.trim().isEmpty ||
          item.amount.minorUnits <= 0,
    )) {
      error('expense_invalid', 'group', 'plannedExpenseItems');
    }
    _max(data.costNote, 300, 'group', 'costNote', error);
  }

  void _validatePublishing(
    CreateDraftEntity draft,
    FindPeopleDraftData data,
    void Function(String, String, String, [Map<String, int>]) error,
  ) {
    if (data.publisherId.trim().isEmpty) {
      error('publisher', 'hosts', 'publisherId');
    }
    if (data.responsibleHostUserIds.isEmpty) {
      error('responsible_host', 'hosts', 'responsibleHostUserIds');
    }
    if (data.publisherType == FindPeoplePublisherType.page &&
        data.responsibleHostUserIds.isEmpty) {
      error('page_host', 'hosts', 'responsibleHostUserIds');
    }
    if (data.coHosts.any(
      (item) =>
          item.userId.trim().isEmpty ||
          item.capabilityIds.difference(_allowedCoHostCapabilities).isNotEmpty,
    )) {
      error('cohost_grants', 'hosts', 'coHosts');
    }
    if ((data.quietHoursStartMinute != null &&
            (data.quietHoursStartMinute! < 0 ||
                data.quietHoursStartMinute! > 1439)) ||
        (data.quietHoursEndMinute != null &&
            (data.quietHoursEndMinute! < 0 ||
                data.quietHoursEndMinute! > 1439))) {
      error('quiet_hours', 'hosts', 'quietHoursStartMinute');
    }
    if (!data.safetyRulesAccepted) {
      error('safety_rules', 'publish', 'safetyRulesAccepted');
    }
    if (!data.accuracyConfirmed) {
      error('accuracy', 'publish', 'accuracyConfirmed');
    }
    if (!data.ageRequirementConfirmed) {
      error('adult_only', 'publish', 'ageRequirementConfirmed');
    }
    if (!data.responsibleHostUserIds.contains(draft.organizerId) &&
        data.publisherType == FindPeoplePublisherType.user) {
      error('publisher_host_mismatch', 'hosts', 'responsibleHostUserIds');
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
    required void Function(String, String, String, [Map<String, int>]) error,
  }) {
    final int length = value.trim().length;
    if (length < min || length > max) {
      error('${field}_length', section, field, <String, int>{
        'min': min,
        'max': max,
      });
    }
  }

  static void _max(
    String? value,
    int max,
    String section,
    String field,
    void Function(String, String, String, [Map<String, int>]) error,
  ) {
    if ((value?.trim().length ?? 0) > max) {
      error('${field}_length', section, field, <String, int>{'max': max});
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
      // l10n-ignore: keyword matching, never displayed.
      'квартира', // l10n-ignore
      'код двери', // l10n-ignore
      'домашний адрес', // l10n-ignore
    ].any(normalized.contains);
  }
}
