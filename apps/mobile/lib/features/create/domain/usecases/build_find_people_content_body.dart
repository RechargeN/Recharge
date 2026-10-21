import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../entities/create_draft_entity.dart';
import '../entities/find_people_draft_data.dart';
import '../entities/publisher_ref.dart';

/// Stable ids and keys of one Find People publication (D3.7): every id is a
/// UUIDv5 in [namespace] under a scope of the signed-in account, the publisher
/// and the local Create draft, so another account, publisher or draft can never
/// reuse them, and every save of the same draft repeats them.
final class FindPeoplePublicationScope {
  FindPeoplePublicationScope({
    required this.accountId,
    required this.publisherRef,
    required this.localDraftId,
  });

  /// D3.7; fixed here and in the tests.
  static const String namespace = '9c0b6d7e-3a41-4f5e-8b2c-7d1e0f4a6b39';

  final String accountId;
  final PublisherRef publisherRef;
  final String localDraftId;

  String get value =>
      'recharge:find-people-publication:v1:$accountId:'
      '${publisherRef.type.wireName}:${publisherRef.id}:$localDraftId';

  String _id(String name) => const Uuid().v5(namespace, '$value:$name');

  /// The server id of a Create time slot (its local id may be `loc_*`).
  String slotId(String localSlotId) => _id('slot:$localSlotId');

  /// Prefix of every Content and consent idempotency key of this publication.
  String get keyBase =>
      'fp1-${sha256.convert(utf8.encode(value)).toString().substring(0, 24)}';
}

final class FindPeopleContentBody {
  const FindPeopleContentBody({required this.body, required this.unsupported});

  /// The private source body (D3.7 §3.1). The server builds the public
  /// projection from it; the client never sends a public point.
  final Map<String, Object?> body;

  /// Draft content the T3 server subset cannot carry; a draft that has any is
  /// not sent at all (nothing is dropped silently).
  final List<String> unsupported;
}

/// Find People Create draft → D3.7 wire body. The local approximate
/// `publicGeo` is a Create preview only and is never sent: the public cell is
/// computed by the server from the exact point (FP-OD-02).
final class FindPeopleContentBodyMapper {
  const FindPeopleContentBodyMapper();

  FindPeopleContentBody map(
    CreateDraftEntity draft, {
    required FindPeoplePublicationScope scope,
    required String serverOwnerUserId,
    required String defaultContentLocale,
  }) {
    final FindPeopleDraftData? data = draft.findPeopleData;
    if (draft.objectType != CreateObjectType.findPeople || data == null) {
      throw ArgumentError('Not a Find People draft');
    }
    final List<String> unsupported = <String>[
      if (data.scheduleMode != FindPeopleScheduleMode.single) 'schedule_mode',
      if (draft.scheduleSlots.length != 1) 'schedule_slots',
      if (data.meetingMode != FindPeopleMeetingMode.inPerson) 'meeting_mode',
      if (data.onlineProvider != null || data.onlineAccessSecretRef != null)
        'online_access',
      if (data.backupMeetingPlan != null) 'backup_plan',
      if (data.visibility != FindPeopleVisibility.public) 'visibility',
      if (data.approvalMode == FindPeopleApprovalMode.inviteOnly)
        'approval_mode',
      if (data.coHosts.isNotEmpty) 'co_hosts',
      if (data.applicationQuestions.isNotEmpty) 'application_questions',
      if (data.expenseSplitMode == FindPeopleExpenseSplitMode.itemized ||
          data.plannedExpenseItems.isNotEmpty)
        'expense_items',
      if (data.shareLinkExpiresAtUtc != null) 'share_links',
      if (data.allowParticipantInvites) 'participant_invites',
      if (data.publishAtUtc != null) 'scheduled_publish',
      if (draft.media.coverImage.trim().isNotEmpty ||
          draft.media.gallery.isNotEmpty)
        'media',
      if (data.responsibleHostUserIds.length != 1 ||
          data.responsibleHostUserIds.single != draft.organizerId)
        'responsible_hosts',
    ];
    final DateTime? deadline = draft.registrationDeadlineUtc;
    final Map<String, Object?> body = <String, Object?>{
      'title': draft.title,
      'shortDescription': draft.shortDescription,
      'fullDescription': draft.fullDescription,
      'contentLocale': defaultContentLocale,
      'categoryId': draft.mainCategory,
      'subcategoryId': draft.subcategory,
      if (draft.tags.isNotEmpty) 'tags': List<String>.of(draft.tags),
      'findPeople': <String, Object?>{
        'schemaVersion': 1,
        'revision': data.revision,
        'skillLevel': _snake(data.skillLevel.name),
        if (data.pace != null) 'pace': data.pace,
        'languageCodes': data.languageCodes.toList(),
        'participationGoal': _snake(data.participationGoal.name),
        'experienceRequirements': List<String>.of(data.experienceRequirements),
        if (data.equipmentNotes != null) 'equipmentNotes': data.equipmentNotes,
        if (data.accessibilityNotes != null)
          'accessibilityNotes': data.accessibilityNotes,
        'houseRuleIds': data.houseRuleIds.toList(),
        if (data.houseRulesNote != null) 'houseRulesNote': data.houseRulesNote,
        'visibility': _snake(data.visibility.name),
        'schedule': <String, Object?>{
          'mode': _snake(data.scheduleMode.name),
          'timezoneId': draft.timezone,
          if (draft.scheduleSlots.length == 1)
            'slot': <String, Object?>{
              'id': scope.slotId(draft.scheduleSlots.single.localId),
              'startAtUtc': _instant(draft.scheduleSlots.single.startAtUtc),
              'endAtUtc': _instant(draft.scheduleSlots.single.endAtUtc),
            },
          if (deadline != null) 'applicationDeadlineUtc': _instant(deadline),
        },
        'meeting': <String, Object?>{
          'mode': _snake(data.meetingMode.name),
          if (data.publicAreaLabel != null)
            'publicAreaLabel': data.publicAreaLabel,
          'publicPlaceConfirmed': data.publicPlaceConfirmed,
          if (data.exactGeo != null)
            'exact': <String, Object?>{
              'latitude': data.exactGeo!.latitude,
              'longitude': data.exactGeo!.longitude,
              if (data.meetingPlaceName != null)
                'placeName': data.meetingPlaceName,
              if (data.exactAddressLine != null)
                'addressLine': data.exactAddressLine,
              if (data.meetingInstructions != null)
                'instructions': data.meetingInstructions,
            },
        },
        'group': <String, Object?>{
          'targetGroupSize': data.targetGroupSize,
          'hostSeatCount': data.hostSeatCount,
          'approvalMode': _snake(data.approvalMode.name),
          'allowPartyApplications': data.allowPartyApplications,
          'maxSeatsPerApplication': data.maxSeatsPerApplication,
          'verificationRequirement': _snake(data.verificationRequirement.name),
          'waitlistEnabled': data.waitlistEnabled,
          'waitlistPolicy': _snake(data.waitlistPolicy.name),
          'waitlistSeatFitPolicy': _snake(data.waitlistSeatFitPolicy.name),
          'attendanceConfirmationRequired': data.attendanceConfirmationRequired,
          'guestPolicy': data.guestPolicy,
        },
        'cost': <String, Object?>{
          'costType': _snake(data.costType.name),
          if (data.costType == FindPeopleCostType.estimated &&
              data.expectedSpendAmount != null)
            'expectedSpend': <String, Object?>{
              'amountMinor': data.expectedSpendAmount!.minorUnits,
              'currencyCode': data.expectedSpendAmount!.currencyCode,
            },
          if (data.costNote != null) 'costNote': data.costNote,
          'expenseSplitMode': _snake(data.expenseSplitMode.name),
          'cancellationPolicyId': data.cancellationPolicyId,
        },
        'hosts': <String, Object?>{
          // The server's recorded author, never a client-chosen host id.
          'responsibleHostUserIds': <String>[serverOwnerUserId],
          'conversationPolicy': _snake(data.conversationPolicy.name),
          if (data.quietHoursStartMinute != null)
            'quietHoursStartMinute': data.quietHoursStartMinute,
          if (data.quietHoursEndMinute != null)
            'quietHoursEndMinute': data.quietHoursEndMinute,
        },
        'confirmations': <String, Object?>{
          'safetyRulesAccepted': data.safetyRulesAccepted,
          'accuracyConfirmed': data.accuracyConfirmed,
          'ageRequirementConfirmed': data.ageRequirementConfirmed,
        },
      },
    };
    return FindPeopleContentBody(
      body: body,
      unsupported: List<String>.unmodifiable(unsupported),
    );
  }

  static String _instant(DateTime value) => value.toUtc().toIso8601String();

  /// `teamUp` → `team_up`, the wire spelling of the server contract.
  static String _snake(String value) => value.replaceAllMapped(
    RegExp('[A-Z]'),
    (Match match) => '_${match.group(0)!.toLowerCase()}',
  );
}
