import '../../domain/entities/find_people_draft_data.dart';

class FindPeopleDraftMapper {
  const FindPeopleDraftMapper._();

  static Map<String, Object?> toJson(FindPeopleDraftData value) {
    return <String, Object?>{
      'revision': value.revision,
      'skillLevel': value.skillLevel.name,
      'pace': value.pace,
      'languageCodes': value.languageCodes.toList(growable: false),
      'participationGoal': value.participationGoal.name,
      'experienceRequirements': value.experienceRequirements,
      'equipmentNotes': value.equipmentNotes,
      'accessibilityNotes': value.accessibilityNotes,
      'houseRuleIds': value.houseRuleIds.toList(growable: false),
      'houseRulesNote': value.houseRulesNote,
      'scheduleMode': value.scheduleMode.name,
      'recurrenceRule': value.recurrenceRule,
      'seriesEndAtUtc': value.seriesEndAtUtc?.toIso8601String(),
      'maxOccurrences': value.maxOccurrences,
      'pollResponseDeadlineUtc': value.pollResponseDeadlineUtc
          ?.toIso8601String(),
      'meetingMode': value.meetingMode.name,
      'meetingPlaceName': value.meetingPlaceName,
      'publicAreaLabel': value.publicAreaLabel,
      'publicGeo': _geoToJson(value.publicGeo),
      'exactGeo': _geoToJson(value.exactGeo),
      'exactAddressLine': value.exactAddressLine,
      'meetingInstructions': value.meetingInstructions,
      'publicPlaceConfirmed': value.publicPlaceConfirmed,
      'onlineProvider': value.onlineProvider,
      'onlineAccessSecretRef': value.onlineAccessSecretRef,
      'backupMeetingPlan': value.backupMeetingPlan,
      'targetGroupSize': value.targetGroupSize,
      'hostSeatCount': value.hostSeatCount,
      'approvalMode': value.approvalMode.name,
      'allowPartyApplications': value.allowPartyApplications,
      'maxSeatsPerApplication': value.maxSeatsPerApplication,
      'applicationQuestions': value.applicationQuestions
          .map(
            (FindPeopleApplicationQuestionDraft item) => <String, Object?>{
              'id': item.id,
              'prompt': item.prompt,
              'type': item.type.name,
              'options': item.options,
              'required': item.required,
            },
          )
          .toList(growable: false),
      'verificationRequirement': value.verificationRequirement.name,
      'waitlistEnabled': value.waitlistEnabled,
      'waitlistPolicy': value.waitlistPolicy.name,
      'waitlistSeatFitPolicy': value.waitlistSeatFitPolicy.name,
      'attendanceConfirmationRequired': value.attendanceConfirmationRequired,
      'guestPolicy': value.guestPolicy,
      'costType': value.costType.name,
      'expectedSpendAmount': value.expectedSpendAmount,
      'currencyCode': value.currencyCode,
      'costNote': value.costNote,
      'expenseSplitMode': value.expenseSplitMode.name,
      'plannedExpenseItems': value.plannedExpenseItems
          .map(
            (FindPeopleExpenseItemDraft item) => <String, Object?>{
              'id': item.id,
              'category': item.category,
              'amount': item.amount,
              'payerNote': item.payerNote,
            },
          )
          .toList(growable: false),
      'cancellationPolicyId': value.cancellationPolicyId,
      'publisherType': value.publisherType.name,
      'publisherId': value.publisherId,
      'responsibleHostUserIds': value.responsibleHostUserIds.toList(
        growable: false,
      ),
      'coHosts': value.coHosts
          .map(
            (FindPeopleCoHostDraft item) => <String, Object?>{
              'id': item.id,
              'userId': item.userId,
              'capabilityIds': item.capabilityIds.toList(growable: false),
              'accepted': item.accepted,
              'occupiesSeat': item.occupiesSeat,
            },
          )
          .toList(growable: false),
      'visibility': value.visibility.name,
      'conversationPolicy': value.conversationPolicy.name,
      'allowParticipantInvites': value.allowParticipantInvites,
      'shareLinkExpiresAtUtc': value.shareLinkExpiresAtUtc?.toIso8601String(),
      'quietHoursStartMinute': value.quietHoursStartMinute,
      'quietHoursEndMinute': value.quietHoursEndMinute,
      'safetyRulesAccepted': value.safetyRulesAccepted,
      'accuracyConfirmed': value.accuracyConfirmed,
      'ageRequirementConfirmed': value.ageRequirementConfirmed,
      'publishAtUtc': value.publishAtUtc?.toIso8601String(),
    };
  }

  static FindPeopleDraftData fromJson(
    Object? source, {
    required FindPeopleDraftData defaults,
  }) {
    if (source is! Map<dynamic, dynamic>) return defaults;
    final Map<String, Object?> json = source.map(
      (dynamic key, dynamic value) =>
          MapEntry<String, Object?>(key.toString(), value),
    );
    return defaults.copyWith(
      revision: _int(json['revision']) ?? defaults.revision,
      skillLevel:
          _enumValue(FindPeopleSkillLevel.values, json['skillLevel']) ??
          defaults.skillLevel,
      pace: _text(json['pace']),
      clearPace: json.containsKey('pace') && _text(json['pace']) == null,
      languageCodes: json.containsKey('languageCodes')
          ? _strings(json['languageCodes']).toSet()
          : defaults.languageCodes,
      participationGoal:
          _enumValue(
            FindPeopleParticipationGoal.values,
            json['participationGoal'],
          ) ??
          defaults.participationGoal,
      experienceRequirements: _strings(json['experienceRequirements']),
      equipmentNotes: _text(json['equipmentNotes']),
      clearEquipmentNotes:
          json.containsKey('equipmentNotes') &&
          _text(json['equipmentNotes']) == null,
      accessibilityNotes: _text(json['accessibilityNotes']),
      clearAccessibilityNotes:
          json.containsKey('accessibilityNotes') &&
          _text(json['accessibilityNotes']) == null,
      houseRuleIds: _strings(json['houseRuleIds']).toSet(),
      houseRulesNote: _text(json['houseRulesNote']),
      clearHouseRulesNote:
          json.containsKey('houseRulesNote') &&
          _text(json['houseRulesNote']) == null,
      scheduleMode:
          _enumValue(FindPeopleScheduleMode.values, json['scheduleMode']) ??
          defaults.scheduleMode,
      recurrenceRule: _text(json['recurrenceRule']),
      clearRecurrenceRule:
          json.containsKey('recurrenceRule') &&
          _text(json['recurrenceRule']) == null,
      seriesEndAtUtc: _date(json['seriesEndAtUtc']),
      clearSeriesEndAtUtc:
          json.containsKey('seriesEndAtUtc') &&
          _date(json['seriesEndAtUtc']) == null,
      maxOccurrences: _int(json['maxOccurrences']),
      clearMaxOccurrences:
          json.containsKey('maxOccurrences') &&
          _int(json['maxOccurrences']) == null,
      pollResponseDeadlineUtc: _date(json['pollResponseDeadlineUtc']),
      clearPollResponseDeadlineUtc:
          json.containsKey('pollResponseDeadlineUtc') &&
          _date(json['pollResponseDeadlineUtc']) == null,
      meetingMode:
          _enumValue(FindPeopleMeetingMode.values, json['meetingMode']) ??
          defaults.meetingMode,
      meetingPlaceName: _text(json['meetingPlaceName']),
      clearMeetingPlaceName:
          json.containsKey('meetingPlaceName') &&
          _text(json['meetingPlaceName']) == null,
      publicAreaLabel: _text(json['publicAreaLabel']),
      clearPublicAreaLabel:
          json.containsKey('publicAreaLabel') &&
          _text(json['publicAreaLabel']) == null,
      publicGeo: _geoFromJson(json['publicGeo']),
      clearPublicGeo:
          json.containsKey('publicGeo') &&
          _geoFromJson(json['publicGeo']) == null,
      exactGeo: _geoFromJson(json['exactGeo']),
      clearExactGeo:
          json.containsKey('exactGeo') &&
          _geoFromJson(json['exactGeo']) == null,
      exactAddressLine: _text(json['exactAddressLine']),
      clearExactAddressLine:
          json.containsKey('exactAddressLine') &&
          _text(json['exactAddressLine']) == null,
      meetingInstructions: _text(json['meetingInstructions']),
      clearMeetingInstructions:
          json.containsKey('meetingInstructions') &&
          _text(json['meetingInstructions']) == null,
      publicPlaceConfirmed:
          _bool(json['publicPlaceConfirmed']) ?? defaults.publicPlaceConfirmed,
      onlineProvider: _text(json['onlineProvider']),
      clearOnlineProvider:
          json.containsKey('onlineProvider') &&
          _text(json['onlineProvider']) == null,
      onlineAccessSecretRef: _text(json['onlineAccessSecretRef']),
      clearOnlineAccessSecretRef:
          json.containsKey('onlineAccessSecretRef') &&
          _text(json['onlineAccessSecretRef']) == null,
      backupMeetingPlan: _text(json['backupMeetingPlan']),
      clearBackupMeetingPlan:
          json.containsKey('backupMeetingPlan') &&
          _text(json['backupMeetingPlan']) == null,
      targetGroupSize:
          _int(json['targetGroupSize']) ?? defaults.targetGroupSize,
      hostSeatCount: _int(json['hostSeatCount']) ?? defaults.hostSeatCount,
      approvalMode:
          _enumValue(FindPeopleApprovalMode.values, json['approvalMode']) ??
          defaults.approvalMode,
      allowPartyApplications:
          _bool(json['allowPartyApplications']) ??
          defaults.allowPartyApplications,
      maxSeatsPerApplication:
          _int(json['maxSeatsPerApplication']) ??
          defaults.maxSeatsPerApplication,
      applicationQuestions: _questions(json['applicationQuestions']),
      verificationRequirement:
          _enumValue(
            FindPeopleVerificationLevel.values,
            json['verificationRequirement'],
          ) ??
          defaults.verificationRequirement,
      waitlistEnabled:
          _bool(json['waitlistEnabled']) ?? defaults.waitlistEnabled,
      waitlistPolicy:
          _enumValue(FindPeopleWaitlistPolicy.values, json['waitlistPolicy']) ??
          defaults.waitlistPolicy,
      waitlistSeatFitPolicy:
          _enumValue(
            FindPeopleSeatFitPolicy.values,
            json['waitlistSeatFitPolicy'],
          ) ??
          defaults.waitlistSeatFitPolicy,
      attendanceConfirmationRequired:
          _bool(json['attendanceConfirmationRequired']) ??
          defaults.attendanceConfirmationRequired,
      guestPolicy: _text(json['guestPolicy']) ?? defaults.guestPolicy,
      costType:
          _enumValue(FindPeopleCostType.values, json['costType']) ??
          defaults.costType,
      expectedSpendAmount: _double(json['expectedSpendAmount']),
      clearExpectedSpendAmount:
          json.containsKey('expectedSpendAmount') &&
          _double(json['expectedSpendAmount']) == null,
      currencyCode: _text(json['currencyCode']) ?? defaults.currencyCode,
      costNote: _text(json['costNote']),
      clearCostNote:
          json.containsKey('costNote') && _text(json['costNote']) == null,
      expenseSplitMode:
          _enumValue(
            FindPeopleExpenseSplitMode.values,
            json['expenseSplitMode'],
          ) ??
          defaults.expenseSplitMode,
      plannedExpenseItems: _expenses(json['plannedExpenseItems']),
      cancellationPolicyId:
          _text(json['cancellationPolicyId']) ?? defaults.cancellationPolicyId,
      publisherType:
          _enumValue(FindPeoplePublisherType.values, json['publisherType']) ??
          defaults.publisherType,
      publisherId: _text(json['publisherId']) ?? defaults.publisherId,
      responsibleHostUserIds: json.containsKey('responsibleHostUserIds')
          ? _strings(json['responsibleHostUserIds']).toSet()
          : defaults.responsibleHostUserIds,
      coHosts: _coHosts(json['coHosts']),
      visibility:
          _enumValue(FindPeopleVisibility.values, json['visibility']) ??
          defaults.visibility,
      conversationPolicy:
          _enumValue(
            FindPeopleConversationPolicy.values,
            json['conversationPolicy'],
          ) ??
          defaults.conversationPolicy,
      allowParticipantInvites:
          _bool(json['allowParticipantInvites']) ??
          defaults.allowParticipantInvites,
      shareLinkExpiresAtUtc: _date(json['shareLinkExpiresAtUtc']),
      clearShareLinkExpiresAtUtc:
          json.containsKey('shareLinkExpiresAtUtc') &&
          _date(json['shareLinkExpiresAtUtc']) == null,
      quietHoursStartMinute: _int(json['quietHoursStartMinute']),
      clearQuietHoursStartMinute:
          json.containsKey('quietHoursStartMinute') &&
          _int(json['quietHoursStartMinute']) == null,
      quietHoursEndMinute: _int(json['quietHoursEndMinute']),
      clearQuietHoursEndMinute:
          json.containsKey('quietHoursEndMinute') &&
          _int(json['quietHoursEndMinute']) == null,
      safetyRulesAccepted:
          _bool(json['safetyRulesAccepted']) ?? defaults.safetyRulesAccepted,
      accuracyConfirmed:
          _bool(json['accuracyConfirmed']) ?? defaults.accuracyConfirmed,
      ageRequirementConfirmed:
          _bool(json['ageRequirementConfirmed']) ??
          defaults.ageRequirementConfirmed,
      publishAtUtc: _date(json['publishAtUtc']),
      clearPublishAtUtc:
          json.containsKey('publishAtUtc') &&
          _date(json['publishAtUtc']) == null,
    );
  }

  static Map<String, Object?>? _geoToJson(FindPeopleGeoPointDraft? value) =>
      value == null
      ? null
      : <String, Object?>{
          'latitude': value.latitude,
          'longitude': value.longitude,
        };

  static FindPeopleGeoPointDraft? _geoFromJson(Object? source) {
    if (source is! Map<dynamic, dynamic>) return null;
    final double? latitude = _double(source['latitude']);
    final double? longitude = _double(source['longitude']);
    if (latitude == null || longitude == null) return null;
    return FindPeopleGeoPointDraft(latitude: latitude, longitude: longitude);
  }

  static T? _enumValue<T extends Enum>(Iterable<T> values, Object? source) {
    final String? name = _text(source);
    if (name == null) return null;
    for (final T value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  static String? _text(Object? source) {
    final String value = source?.toString().trim() ?? '';
    return value.isEmpty ? null : value;
  }

  static int? _int(Object? source) =>
      source is num ? source.toInt() : int.tryParse(source?.toString() ?? '');
  static double? _double(Object? source) => source is num
      ? source.toDouble()
      : double.tryParse(source?.toString() ?? '');
  static bool? _bool(Object? source) => source is bool ? source : null;
  static DateTime? _date(Object? source) =>
      DateTime.tryParse(source?.toString() ?? '')?.toUtc();
  static List<String> _strings(Object? source) => source is List<dynamic>
      ? source
            .map((dynamic item) => item.toString().trim())
            .where((String item) => item.isNotEmpty)
            .toList(growable: false)
      : const <String>[];

  static List<FindPeopleApplicationQuestionDraft> _questions(Object? source) {
    if (source is! List<dynamic>) {
      return const <FindPeopleApplicationQuestionDraft>[];
    }
    return source
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> json) {
          return FindPeopleApplicationQuestionDraft(
            id: _text(json['id']) ?? '',
            prompt: _text(json['prompt']) ?? '',
            type:
                _enumValue(FindPeopleQuestionType.values, json['type']) ??
                FindPeopleQuestionType.text,
            options: _strings(json['options']),
            required: _bool(json['required']) ?? false,
          );
        })
        .toList(growable: false);
  }

  static List<FindPeopleExpenseItemDraft> _expenses(Object? source) {
    if (source is! List<dynamic>) return const <FindPeopleExpenseItemDraft>[];
    return source
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> json) {
          return FindPeopleExpenseItemDraft(
            id: _text(json['id']) ?? '',
            category: _text(json['category']) ?? '',
            amount: _double(json['amount']) ?? 0,
            payerNote: _text(json['payerNote']) ?? '',
          );
        })
        .toList(growable: false);
  }

  static List<FindPeopleCoHostDraft> _coHosts(Object? source) {
    if (source is! List<dynamic>) return const <FindPeopleCoHostDraft>[];
    return source
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> json) {
          return FindPeopleCoHostDraft(
            id: _text(json['id']) ?? '',
            userId: _text(json['userId']) ?? '',
            capabilityIds: _strings(json['capabilityIds']).toSet(),
            accepted: _bool(json['accepted']) ?? false,
            occupiesSeat: _bool(json['occupiesSeat']) ?? false,
          );
        })
        .toList(growable: false);
  }
}
