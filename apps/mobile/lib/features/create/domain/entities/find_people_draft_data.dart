enum FindPeopleScheduleMode { single, timePoll, recurring }

enum FindPeopleMeetingMode { inPerson, online, hybrid }

enum FindPeopleSkillLevel { any, beginner, intermediate, advanced }

enum FindPeopleParticipationGoal {
  social,
  practice,
  teamUp,
  sharedTrip,
  accountability,
  other,
}

enum FindPeopleApprovalMode { manual, automatic, inviteOnly }

enum FindPeopleVerificationLevel { none, phone, identityDocument, organization }

enum FindPeopleWaitlistPolicy { firstCome, hostReview }

enum FindPeopleSeatFitPolicy { strictOrder, firstFitting }

enum FindPeopleCostType { free, estimated, unknown }

enum FindPeopleExpenseSplitMode { none, equal, itemized, settleLater }

enum FindPeoplePublisherType { user, page }

enum FindPeopleVisibility { public, unlisted, inviteOnly }

enum FindPeopleConversationPolicy { acceptedOnly, applicantsAndAccepted }

enum FindPeopleQuestionType { text, singleChoice, multipleChoice, yesNo }

class FindPeopleGeoPointDraft {
  const FindPeopleGeoPointDraft({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  bool get isValid =>
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}

class FindPeopleApplicationQuestionDraft {
  const FindPeopleApplicationQuestionDraft({
    required this.id,
    required this.prompt,
    required this.type,
    this.options = const <String>[],
    this.required = false,
  });

  final String id;
  final String prompt;
  final FindPeopleQuestionType type;
  final List<String> options;
  final bool required;

  FindPeopleApplicationQuestionDraft copyWith({String? id}) {
    return FindPeopleApplicationQuestionDraft(
      id: id ?? this.id,
      prompt: prompt,
      type: type,
      options: options,
      required: required,
    );
  }
}

class FindPeopleExpenseItemDraft {
  const FindPeopleExpenseItemDraft({
    required this.id,
    required this.category,
    required this.amount,
    required this.payerNote,
  });

  final String id;
  final String category;
  final double amount;
  final String payerNote;

  FindPeopleExpenseItemDraft copyWith({String? id}) {
    return FindPeopleExpenseItemDraft(
      id: id ?? this.id,
      category: category,
      amount: amount,
      payerNote: payerNote,
    );
  }
}

class FindPeopleCoHostDraft {
  const FindPeopleCoHostDraft({
    required this.id,
    required this.userId,
    required this.capabilityIds,
    required this.accepted,
    required this.occupiesSeat,
  });

  final String id;
  final String userId;
  final Set<String> capabilityIds;
  final bool accepted;
  final bool occupiesSeat;

  FindPeopleCoHostDraft copyWith({String? id}) {
    return FindPeopleCoHostDraft(
      id: id ?? this.id,
      userId: userId,
      capabilityIds: capabilityIds,
      accepted: accepted,
      occupiesSeat: occupiesSeat,
    );
  }
}

class FindPeopleDraftData {
  const FindPeopleDraftData({
    required this.revision,
    required this.skillLevel,
    required this.pace,
    required this.languageCodes,
    required this.participationGoal,
    required this.experienceRequirements,
    required this.equipmentNotes,
    required this.accessibilityNotes,
    required this.houseRuleIds,
    required this.houseRulesNote,
    required this.scheduleMode,
    required this.recurrenceRule,
    required this.seriesEndAtUtc,
    required this.maxOccurrences,
    required this.pollResponseDeadlineUtc,
    required this.meetingMode,
    required this.meetingPlaceName,
    required this.publicAreaLabel,
    required this.publicGeo,
    required this.exactGeo,
    required this.exactAddressLine,
    required this.meetingInstructions,
    required this.publicPlaceConfirmed,
    required this.onlineProvider,
    required this.onlineAccessSecretRef,
    required this.backupMeetingPlan,
    required this.targetGroupSize,
    required this.hostSeatCount,
    required this.approvalMode,
    required this.allowPartyApplications,
    required this.maxSeatsPerApplication,
    required this.applicationQuestions,
    required this.verificationRequirement,
    required this.waitlistEnabled,
    required this.waitlistPolicy,
    required this.waitlistSeatFitPolicy,
    required this.attendanceConfirmationRequired,
    required this.guestPolicy,
    required this.costType,
    required this.expectedSpendAmount,
    required this.currencyCode,
    required this.costNote,
    required this.expenseSplitMode,
    required this.plannedExpenseItems,
    required this.cancellationPolicyId,
    required this.publisherType,
    required this.publisherId,
    required this.responsibleHostUserIds,
    required this.coHosts,
    required this.visibility,
    required this.conversationPolicy,
    required this.allowParticipantInvites,
    required this.shareLinkExpiresAtUtc,
    required this.quietHoursStartMinute,
    required this.quietHoursEndMinute,
    required this.safetyRulesAccepted,
    required this.accuracyConfirmed,
    required this.ageRequirementConfirmed,
    required this.publishAtUtc,
  });

  final int revision;
  final FindPeopleSkillLevel skillLevel;
  final String? pace;
  final Set<String> languageCodes;
  final FindPeopleParticipationGoal participationGoal;
  final List<String> experienceRequirements;
  final String? equipmentNotes;
  final String? accessibilityNotes;
  final Set<String> houseRuleIds;
  final String? houseRulesNote;

  final FindPeopleScheduleMode scheduleMode;
  final String? recurrenceRule;
  final DateTime? seriesEndAtUtc;
  final int? maxOccurrences;
  final DateTime? pollResponseDeadlineUtc;

  final FindPeopleMeetingMode meetingMode;
  final String? meetingPlaceName;
  final String? publicAreaLabel;
  final FindPeopleGeoPointDraft? publicGeo;
  final FindPeopleGeoPointDraft? exactGeo;
  final String? exactAddressLine;
  final String? meetingInstructions;
  final bool publicPlaceConfirmed;
  final String? onlineProvider;
  final String? onlineAccessSecretRef;
  final String? backupMeetingPlan;

  final int targetGroupSize;
  final int hostSeatCount;
  final FindPeopleApprovalMode approvalMode;
  final bool allowPartyApplications;
  final int maxSeatsPerApplication;
  final List<FindPeopleApplicationQuestionDraft> applicationQuestions;
  final FindPeopleVerificationLevel verificationRequirement;
  final bool waitlistEnabled;
  final FindPeopleWaitlistPolicy waitlistPolicy;
  final FindPeopleSeatFitPolicy waitlistSeatFitPolicy;
  final bool attendanceConfirmationRequired;
  final String guestPolicy;

  final FindPeopleCostType costType;
  final double? expectedSpendAmount;
  final String currencyCode;
  final String? costNote;
  final FindPeopleExpenseSplitMode expenseSplitMode;
  final List<FindPeopleExpenseItemDraft> plannedExpenseItems;
  final String cancellationPolicyId;

  final FindPeoplePublisherType publisherType;
  final String publisherId;
  final Set<String> responsibleHostUserIds;
  final List<FindPeopleCoHostDraft> coHosts;
  final FindPeopleVisibility visibility;
  final FindPeopleConversationPolicy conversationPolicy;
  final bool allowParticipantInvites;
  final DateTime? shareLinkExpiresAtUtc;
  final int? quietHoursStartMinute;
  final int? quietHoursEndMinute;

  final bool safetyRulesAccepted;
  final bool accuracyConfirmed;
  final bool ageRequirementConfirmed;
  final DateTime? publishAtUtc;

  factory FindPeopleDraftData.defaults({
    required String userId,
    required String currencyCode,
    String defaultLanguageCode = 'en',
  }) {
    return FindPeopleDraftData(
      revision: 0,
      skillLevel: FindPeopleSkillLevel.any,
      pace: null,
      languageCodes: <String>{defaultLanguageCode},
      participationGoal: FindPeopleParticipationGoal.social,
      experienceRequirements: const <String>[],
      equipmentNotes: null,
      accessibilityNotes: null,
      houseRuleIds: const <String>{},
      houseRulesNote: null,
      scheduleMode: FindPeopleScheduleMode.single,
      recurrenceRule: null,
      seriesEndAtUtc: null,
      maxOccurrences: null,
      pollResponseDeadlineUtc: null,
      meetingMode: FindPeopleMeetingMode.inPerson,
      meetingPlaceName: null,
      publicAreaLabel: null,
      publicGeo: null,
      exactGeo: null,
      exactAddressLine: null,
      meetingInstructions: null,
      publicPlaceConfirmed: false,
      onlineProvider: null,
      onlineAccessSecretRef: null,
      backupMeetingPlan: null,
      targetGroupSize: 4,
      hostSeatCount: 1,
      approvalMode: FindPeopleApprovalMode.manual,
      allowPartyApplications: false,
      maxSeatsPerApplication: 1,
      applicationQuestions: const <FindPeopleApplicationQuestionDraft>[],
      verificationRequirement: FindPeopleVerificationLevel.none,
      waitlistEnabled: true,
      waitlistPolicy: FindPeopleWaitlistPolicy.firstCome,
      waitlistSeatFitPolicy: FindPeopleSeatFitPolicy.strictOrder,
      attendanceConfirmationRequired: true,
      guestPolicy: 'authenticated_adults_only',
      costType: FindPeopleCostType.free,
      expectedSpendAmount: null,
      currencyCode: currencyCode,
      costNote: null,
      expenseSplitMode: FindPeopleExpenseSplitMode.none,
      plannedExpenseItems: const <FindPeopleExpenseItemDraft>[],
      cancellationPolicyId: 'standard_respectful_notice',
      publisherType: FindPeoplePublisherType.user,
      publisherId: userId,
      responsibleHostUserIds: userId.isEmpty
          ? const <String>{}
          : <String>{userId},
      coHosts: const <FindPeopleCoHostDraft>[],
      visibility: FindPeopleVisibility.public,
      conversationPolicy: FindPeopleConversationPolicy.applicantsAndAccepted,
      allowParticipantInvites: false,
      shareLinkExpiresAtUtc: null,
      quietHoursStartMinute: 22 * 60,
      quietHoursEndMinute: 8 * 60,
      safetyRulesAccepted: false,
      accuracyConfirmed: false,
      ageRequirementConfirmed: false,
      publishAtUtc: null,
    );
  }

  FindPeopleDraftData nextRevision() => copyWith(revision: revision + 1);

  FindPeopleDraftData replaceLocalIds(String Function() generateId) {
    String permanent(String value) =>
        value.startsWith('loc_') ? generateId() : value;
    return copyWith(
      applicationQuestions: applicationQuestions
          .map(
            (FindPeopleApplicationQuestionDraft item) =>
                item.copyWith(id: permanent(item.id)),
          )
          .toList(growable: false),
      plannedExpenseItems: plannedExpenseItems
          .map(
            (FindPeopleExpenseItemDraft item) =>
                item.copyWith(id: permanent(item.id)),
          )
          .toList(growable: false),
      coHosts: coHosts
          .map(
            (FindPeopleCoHostDraft item) =>
                item.copyWith(id: permanent(item.id)),
          )
          .toList(growable: false),
    );
  }

  FindPeopleDraftData copyWith({
    int? revision,
    FindPeopleSkillLevel? skillLevel,
    String? pace,
    bool clearPace = false,
    Set<String>? languageCodes,
    FindPeopleParticipationGoal? participationGoal,
    List<String>? experienceRequirements,
    String? equipmentNotes,
    bool clearEquipmentNotes = false,
    String? accessibilityNotes,
    bool clearAccessibilityNotes = false,
    Set<String>? houseRuleIds,
    String? houseRulesNote,
    bool clearHouseRulesNote = false,
    FindPeopleScheduleMode? scheduleMode,
    String? recurrenceRule,
    bool clearRecurrenceRule = false,
    DateTime? seriesEndAtUtc,
    bool clearSeriesEndAtUtc = false,
    int? maxOccurrences,
    bool clearMaxOccurrences = false,
    DateTime? pollResponseDeadlineUtc,
    bool clearPollResponseDeadlineUtc = false,
    FindPeopleMeetingMode? meetingMode,
    String? meetingPlaceName,
    bool clearMeetingPlaceName = false,
    String? publicAreaLabel,
    bool clearPublicAreaLabel = false,
    FindPeopleGeoPointDraft? publicGeo,
    bool clearPublicGeo = false,
    FindPeopleGeoPointDraft? exactGeo,
    bool clearExactGeo = false,
    String? exactAddressLine,
    bool clearExactAddressLine = false,
    String? meetingInstructions,
    bool clearMeetingInstructions = false,
    bool? publicPlaceConfirmed,
    String? onlineProvider,
    bool clearOnlineProvider = false,
    String? onlineAccessSecretRef,
    bool clearOnlineAccessSecretRef = false,
    String? backupMeetingPlan,
    bool clearBackupMeetingPlan = false,
    int? targetGroupSize,
    int? hostSeatCount,
    FindPeopleApprovalMode? approvalMode,
    bool? allowPartyApplications,
    int? maxSeatsPerApplication,
    List<FindPeopleApplicationQuestionDraft>? applicationQuestions,
    FindPeopleVerificationLevel? verificationRequirement,
    bool? waitlistEnabled,
    FindPeopleWaitlistPolicy? waitlistPolicy,
    FindPeopleSeatFitPolicy? waitlistSeatFitPolicy,
    bool? attendanceConfirmationRequired,
    String? guestPolicy,
    FindPeopleCostType? costType,
    double? expectedSpendAmount,
    bool clearExpectedSpendAmount = false,
    String? currencyCode,
    String? costNote,
    bool clearCostNote = false,
    FindPeopleExpenseSplitMode? expenseSplitMode,
    List<FindPeopleExpenseItemDraft>? plannedExpenseItems,
    String? cancellationPolicyId,
    FindPeoplePublisherType? publisherType,
    String? publisherId,
    Set<String>? responsibleHostUserIds,
    List<FindPeopleCoHostDraft>? coHosts,
    FindPeopleVisibility? visibility,
    FindPeopleConversationPolicy? conversationPolicy,
    bool? allowParticipantInvites,
    DateTime? shareLinkExpiresAtUtc,
    bool clearShareLinkExpiresAtUtc = false,
    int? quietHoursStartMinute,
    bool clearQuietHoursStartMinute = false,
    int? quietHoursEndMinute,
    bool clearQuietHoursEndMinute = false,
    bool? safetyRulesAccepted,
    bool? accuracyConfirmed,
    bool? ageRequirementConfirmed,
    DateTime? publishAtUtc,
    bool clearPublishAtUtc = false,
  }) {
    return FindPeopleDraftData(
      revision: revision ?? this.revision,
      skillLevel: skillLevel ?? this.skillLevel,
      pace: clearPace ? null : (pace ?? this.pace),
      languageCodes: languageCodes ?? this.languageCodes,
      participationGoal: participationGoal ?? this.participationGoal,
      experienceRequirements:
          experienceRequirements ?? this.experienceRequirements,
      equipmentNotes: clearEquipmentNotes
          ? null
          : (equipmentNotes ?? this.equipmentNotes),
      accessibilityNotes: clearAccessibilityNotes
          ? null
          : (accessibilityNotes ?? this.accessibilityNotes),
      houseRuleIds: houseRuleIds ?? this.houseRuleIds,
      houseRulesNote: clearHouseRulesNote
          ? null
          : (houseRulesNote ?? this.houseRulesNote),
      scheduleMode: scheduleMode ?? this.scheduleMode,
      recurrenceRule: clearRecurrenceRule
          ? null
          : (recurrenceRule ?? this.recurrenceRule),
      seriesEndAtUtc: clearSeriesEndAtUtc
          ? null
          : (seriesEndAtUtc ?? this.seriesEndAtUtc),
      maxOccurrences: clearMaxOccurrences
          ? null
          : (maxOccurrences ?? this.maxOccurrences),
      pollResponseDeadlineUtc: clearPollResponseDeadlineUtc
          ? null
          : (pollResponseDeadlineUtc ?? this.pollResponseDeadlineUtc),
      meetingMode: meetingMode ?? this.meetingMode,
      meetingPlaceName: clearMeetingPlaceName
          ? null
          : (meetingPlaceName ?? this.meetingPlaceName),
      publicAreaLabel: clearPublicAreaLabel
          ? null
          : (publicAreaLabel ?? this.publicAreaLabel),
      publicGeo: clearPublicGeo ? null : (publicGeo ?? this.publicGeo),
      exactGeo: clearExactGeo ? null : (exactGeo ?? this.exactGeo),
      exactAddressLine: clearExactAddressLine
          ? null
          : (exactAddressLine ?? this.exactAddressLine),
      meetingInstructions: clearMeetingInstructions
          ? null
          : (meetingInstructions ?? this.meetingInstructions),
      publicPlaceConfirmed: publicPlaceConfirmed ?? this.publicPlaceConfirmed,
      onlineProvider: clearOnlineProvider
          ? null
          : (onlineProvider ?? this.onlineProvider),
      onlineAccessSecretRef: clearOnlineAccessSecretRef
          ? null
          : (onlineAccessSecretRef ?? this.onlineAccessSecretRef),
      backupMeetingPlan: clearBackupMeetingPlan
          ? null
          : (backupMeetingPlan ?? this.backupMeetingPlan),
      targetGroupSize: targetGroupSize ?? this.targetGroupSize,
      hostSeatCount: hostSeatCount ?? this.hostSeatCount,
      approvalMode: approvalMode ?? this.approvalMode,
      allowPartyApplications:
          allowPartyApplications ?? this.allowPartyApplications,
      maxSeatsPerApplication:
          maxSeatsPerApplication ?? this.maxSeatsPerApplication,
      applicationQuestions: applicationQuestions ?? this.applicationQuestions,
      verificationRequirement:
          verificationRequirement ?? this.verificationRequirement,
      waitlistEnabled: waitlistEnabled ?? this.waitlistEnabled,
      waitlistPolicy: waitlistPolicy ?? this.waitlistPolicy,
      waitlistSeatFitPolicy:
          waitlistSeatFitPolicy ?? this.waitlistSeatFitPolicy,
      attendanceConfirmationRequired:
          attendanceConfirmationRequired ?? this.attendanceConfirmationRequired,
      guestPolicy: guestPolicy ?? this.guestPolicy,
      costType: costType ?? this.costType,
      expectedSpendAmount: clearExpectedSpendAmount
          ? null
          : (expectedSpendAmount ?? this.expectedSpendAmount),
      currencyCode: currencyCode ?? this.currencyCode,
      costNote: clearCostNote ? null : (costNote ?? this.costNote),
      expenseSplitMode: expenseSplitMode ?? this.expenseSplitMode,
      plannedExpenseItems: plannedExpenseItems ?? this.plannedExpenseItems,
      cancellationPolicyId: cancellationPolicyId ?? this.cancellationPolicyId,
      publisherType: publisherType ?? this.publisherType,
      publisherId: publisherId ?? this.publisherId,
      responsibleHostUserIds:
          responsibleHostUserIds ?? this.responsibleHostUserIds,
      coHosts: coHosts ?? this.coHosts,
      visibility: visibility ?? this.visibility,
      conversationPolicy: conversationPolicy ?? this.conversationPolicy,
      allowParticipantInvites:
          allowParticipantInvites ?? this.allowParticipantInvites,
      shareLinkExpiresAtUtc: clearShareLinkExpiresAtUtc
          ? null
          : (shareLinkExpiresAtUtc ?? this.shareLinkExpiresAtUtc),
      quietHoursStartMinute: clearQuietHoursStartMinute
          ? null
          : (quietHoursStartMinute ?? this.quietHoursStartMinute),
      quietHoursEndMinute: clearQuietHoursEndMinute
          ? null
          : (quietHoursEndMinute ?? this.quietHoursEndMinute),
      safetyRulesAccepted: safetyRulesAccepted ?? this.safetyRulesAccepted,
      accuracyConfirmed: accuracyConfirmed ?? this.accuracyConfirmed,
      ageRequirementConfirmed:
          ageRequirementConfirmed ?? this.ageRequirementConfirmed,
      publishAtUtc: clearPublishAtUtc
          ? null
          : (publishAtUtc ?? this.publishAtUtc),
    );
  }
}
