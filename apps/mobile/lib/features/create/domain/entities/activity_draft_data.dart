import 'publisher_ref.dart';

enum ActivityContributionKind { purchase, donation, other }

enum ActivityTimeOfDay { morning, afternoon, evening, night, any }

enum ActivitySeason { winter, spring, summer, autumn, any }

class ActivityIntRangeDraft {
  const ActivityIntRangeDraft({required this.min, required this.max});

  final int min;
  final int max;

  ActivityIntRangeDraft copyWith({int? min, int? max}) => ActivityIntRangeDraft(
    min: min ?? this.min,
    max: max ?? this.max,
  );
}

class ActivityAccessCautionDraft {
  const ActivityAccessCautionDraft({this.isInformal = false, this.note});

  final bool isInformal;
  final String? note;

  ActivityAccessCautionDraft copyWith({
    bool? isInformal,
    String? note,
    bool clearNote = false,
  }) => ActivityAccessCautionDraft(
    isInformal: isInformal ?? this.isInformal,
    note: clearNote ? null : (note ?? this.note),
  );
}

class ActivityLocationDraft {
  const ActivityLocationDraft({
    this.latitude,
    this.longitude,
    this.pinConfirmed = false,
    this.addressLine,
    this.accessNotes = '',
    this.accessCaution,
    this.linkedPlaceId,
  });

  final double? latitude;
  final double? longitude;
  final bool pinConfirmed;
  final String? addressLine;
  final String accessNotes;
  final ActivityAccessCautionDraft? accessCaution;
  final String? linkedPlaceId;

  ActivityLocationDraft copyWith({
    double? latitude,
    bool clearLatitude = false,
    double? longitude,
    bool clearLongitude = false,
    bool? pinConfirmed,
    String? addressLine,
    bool clearAddressLine = false,
    String? accessNotes,
    ActivityAccessCautionDraft? accessCaution,
    bool clearAccessCaution = false,
    String? linkedPlaceId,
    bool clearLinkedPlaceId = false,
  }) => ActivityLocationDraft(
    latitude: clearLatitude ? null : (latitude ?? this.latitude),
    longitude: clearLongitude ? null : (longitude ?? this.longitude),
    pinConfirmed: pinConfirmed ?? this.pinConfirmed,
    addressLine: clearAddressLine ? null : (addressLine ?? this.addressLine),
    accessNotes: accessNotes ?? this.accessNotes,
    accessCaution: clearAccessCaution
        ? null
        : (accessCaution ?? this.accessCaution),
    linkedPlaceId: clearLinkedPlaceId
        ? null
        : (linkedPlaceId ?? this.linkedPlaceId),
  );
}

class ActivityContributionAmountDraft {
  const ActivityContributionAmountDraft({
    required this.amountMinor,
    required this.currencyCode,
  });

  final int amountMinor;
  final String currencyCode;

  ActivityContributionAmountDraft copyWith({
    int? amountMinor,
    String? currencyCode,
  }) => ActivityContributionAmountDraft(
    amountMinor: amountMinor ?? this.amountMinor,
    currencyCode: currencyCode ?? this.currencyCode,
  );
}

class ActivityOptionalContributionDraft {
  const ActivityOptionalContributionDraft({
    this.kind,
    this.note,
    this.amountHint,
  });

  final ActivityContributionKind? kind;
  final String? note;
  final ActivityContributionAmountDraft? amountHint;

  ActivityOptionalContributionDraft copyWith({
    ActivityContributionKind? kind,
    bool clearKind = false,
    String? note,
    bool clearNote = false,
    ActivityContributionAmountDraft? amountHint,
    bool clearAmountHint = false,
  }) => ActivityOptionalContributionDraft(
    kind: clearKind ? null : (kind ?? this.kind),
    note: clearNote ? null : (note ?? this.note),
    amountHint: clearAmountHint ? null : (amountHint ?? this.amountHint),
  );
}

class ActivityBestTimeDraft {
  const ActivityBestTimeDraft({this.timeOfDay, this.season});

  final ActivityTimeOfDay? timeOfDay;
  final ActivitySeason? season;

  ActivityBestTimeDraft copyWith({
    ActivityTimeOfDay? timeOfDay,
    bool clearTimeOfDay = false,
    ActivitySeason? season,
    bool clearSeason = false,
  }) => ActivityBestTimeDraft(
    timeOfDay: clearTimeOfDay ? null : (timeOfDay ?? this.timeOfDay),
    season: clearSeason ? null : (season ?? this.season),
  );
}

class ActivityDraftData {
  const ActivityDraftData({
    required this.schemaVersion,
    required this.revision,
    required this.publisherRef,
    required this.location,
    required this.typicalDurationMinutes,
    this.suggestedGroupSize,
    this.optionalContribution,
    this.bestTime,
    this.unknownFields = const <String, Object?>{},
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final int revision;
  final PublisherRef publisherRef;
  final ActivityLocationDraft location;
  final ActivityIntRangeDraft typicalDurationMinutes;
  final ActivityIntRangeDraft? suggestedGroupSize;
  final ActivityOptionalContributionDraft? optionalContribution;
  final ActivityBestTimeDraft? bestTime;
  final Map<String, Object?> unknownFields;

  factory ActivityDraftData.defaults({
    required String userId,
    required String currencyCode,
  }) {
    return ActivityDraftData(
      schemaVersion: currentSchemaVersion,
      revision: 0,
      publisherRef: PublisherRef(type: PublisherType.user, id: userId),
      location: const ActivityLocationDraft(),
      typicalDurationMinutes: const ActivityIntRangeDraft(min: 30, max: 240),
    );
  }

  ActivityDraftData nextRevision() => copyWith(revision: revision + 1);

  /// Activity has no nested entities with their own client-generated
  /// (`loc_`-prefixed) ids — location/duration/group-size/contribution/
  /// bestTime are plain value objects, not addressable sub-records. Kept
  /// for interface parity with `PlaceDraftData.replaceLocalIds`/
  /// `FindPeopleDraftData.replaceLocalIds` so `CreateRepositoryImpl`
  /// can call it unconditionally alongside the other typed payloads.
  ActivityDraftData replaceLocalIds(String Function() generateId) => this;

  ActivityDraftData copyWith({
    int? schemaVersion,
    int? revision,
    PublisherRef? publisherRef,
    ActivityLocationDraft? location,
    ActivityIntRangeDraft? typicalDurationMinutes,
    ActivityIntRangeDraft? suggestedGroupSize,
    bool clearSuggestedGroupSize = false,
    ActivityOptionalContributionDraft? optionalContribution,
    bool clearOptionalContribution = false,
    ActivityBestTimeDraft? bestTime,
    bool clearBestTime = false,
    Map<String, Object?>? unknownFields,
  }) {
    return ActivityDraftData(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      revision: revision ?? this.revision,
      publisherRef: publisherRef ?? this.publisherRef,
      location: location ?? this.location,
      typicalDurationMinutes:
          typicalDurationMinutes ?? this.typicalDurationMinutes,
      suggestedGroupSize: clearSuggestedGroupSize
          ? null
          : (suggestedGroupSize ?? this.suggestedGroupSize),
      optionalContribution: clearOptionalContribution
          ? null
          : (optionalContribution ?? this.optionalContribution),
      bestTime: clearBestTime ? null : (bestTime ?? this.bestTime),
      unknownFields: unknownFields ?? this.unknownFields,
    );
  }
}
