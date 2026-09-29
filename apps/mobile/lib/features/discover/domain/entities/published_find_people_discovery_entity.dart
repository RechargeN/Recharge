import 'publisher_verification_display_state.dart';

enum PublishedFindPeopleScheduleMode { single, timePoll, recurring }

enum PublishedFindPeopleMeetingMode { inPerson, online, hybrid }

enum PublishedFindPeopleRecruitmentStatus {
  collectingAvailability,
  open,
  waitlistOnly,
  full,
  completed,
  cancelled,
  expired,
}

enum PublishedFindPeopleCostType { free, estimated, unknown }

enum PublishedFindPeopleTimeOptionKind { confirmed, candidate }

final class PublishedFindPeopleTimeOption {
  PublishedFindPeopleTimeOption({
    required this.id,
    required this.startAtUtc,
    required this.endAtUtc,
    required this.kind,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (!startAtUtc.isUtc || !endAtUtc.isUtc) {
      throw ArgumentError('Find People time options must use UTC values.');
    }
    if (!endAtUtc.isAfter(startAtUtc)) {
      throw ArgumentError('endAtUtc must be after startAtUtc.');
    }
  }

  final String id;
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final PublishedFindPeopleTimeOptionKind kind;
}

sealed class PublishedFindPeoplePublicLocation {
  const PublishedFindPeoplePublicLocation();

  PublishedFindPeopleMeetingMode get meetingMode;
}

final class PublishedFindPeoplePointLocation
    extends PublishedFindPeoplePublicLocation {
  PublishedFindPeoplePointLocation({
    required this.meetingMode,
    required this.areaLabel,
    required this.latitude,
    required this.longitude,
  }) {
    if (meetingMode == PublishedFindPeopleMeetingMode.online) {
      throw ArgumentError('A point location cannot use online meeting mode.');
    }
    if (areaLabel.trim().isEmpty) {
      throw ArgumentError.value(
        areaLabel,
        'areaLabel',
        'must not be empty for a public point',
      );
    }
    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      throw ArgumentError.value(latitude, 'latitude', 'must be valid');
    }
    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      throw ArgumentError.value(longitude, 'longitude', 'must be valid');
    }
  }

  @override
  final PublishedFindPeopleMeetingMode meetingMode;
  final String areaLabel;
  final double latitude;
  final double longitude;
}

final class PublishedFindPeopleOnlineLocation
    extends PublishedFindPeoplePublicLocation {
  const PublishedFindPeopleOnlineLocation({this.providerLabel = ''});

  @override
  PublishedFindPeopleMeetingMode get meetingMode =>
      PublishedFindPeopleMeetingMode.online;

  /// Public provider name only. Never an access URL, passcode, or secret ref.
  final String providerLabel;
}

final class PublishedFindPeopleHiddenLocation
    extends PublishedFindPeoplePublicLocation {
  PublishedFindPeopleHiddenLocation({
    required this.meetingMode,
    this.safeAreaLabel = '',
  }) {
    if (meetingMode == PublishedFindPeopleMeetingMode.online) {
      throw ArgumentError('Online meetings use the online location variant.');
    }
  }

  @override
  final PublishedFindPeopleMeetingMode meetingMode;
  final String safeAreaLabel;
}

/// Discover-owned public read projection for one published Find People
/// request and one already-selected occurrence (`DTL-FP-01` §3).
///
/// This type intentionally cannot carry exact meeting data, applicant data,
/// or online secrets. Those values belong to policy-aware private stores and
/// are not merely optional fields hidden by the UI.
final class PublishedFindPeopleDiscoveryEntity {
  PublishedFindPeopleDiscoveryEntity({
    required this.requestId,
    required this.occurrenceId,
    required this.publisherId,
    required this.publisherType,
    required this.publisherName,
    this.publisherHandle = '',
    this.publisherVerification = PublisherVerificationDisplayState.none,
    required this.title,
    this.purposeLabel = '',
    this.fullDescription = '',
    required this.category,
    this.subcategory = '',
    this.coverImageUrl = '',
    required this.scheduleMode,
    required List<PublishedFindPeopleTimeOption> timeOptions,
    required this.timezoneId,
    this.durationMinutes,
    this.currentGroupSize,
    required this.targetGroupSize,
    this.remainingSeats,
    required this.recruitmentStatus,
    this.skillLevelLabel = '',
    this.paceLabel = '',
    List<String> languageLabels = const <String>[],
    List<String> publicRequirements = const <String>[],
    this.equipmentNote = '',
    this.accessibilityNote = '',
    required this.costType,
    this.expectedSpendAmount,
    this.currencyCode = '',
    this.costNote = '',
    required this.publicLocation,
    required this.publishedAtUtc,
  }) : timeOptions = List<PublishedFindPeopleTimeOption>.unmodifiable(
         timeOptions,
       ),
       languageLabels = List<String>.unmodifiable(languageLabels),
       publicRequirements = List<String>.unmodifiable(publicRequirements) {
    _validate();
  }

  final String requestId;
  final String occurrenceId;

  final String publisherId;
  final String publisherType;
  final String publisherName;
  final String publisherHandle;
  final PublisherVerificationDisplayState publisherVerification;

  final String title;
  final String purposeLabel;
  final String fullDescription;
  final String category;
  final String subcategory;
  final String coverImageUrl;

  final PublishedFindPeopleScheduleMode scheduleMode;
  final List<PublishedFindPeopleTimeOption> timeOptions;
  final String timezoneId;
  final int? durationMinutes;

  final int? currentGroupSize;
  final int targetGroupSize;
  final int? remainingSeats;
  final PublishedFindPeopleRecruitmentStatus recruitmentStatus;

  final String skillLevelLabel;
  final String paceLabel;
  final List<String> languageLabels;
  final List<String> publicRequirements;
  final String equipmentNote;
  final String accessibilityNote;

  final PublishedFindPeopleCostType costType;
  final double? expectedSpendAmount;
  final String currencyCode;
  final String costNote;

  final PublishedFindPeoplePublicLocation publicLocation;
  final DateTime publishedAtUtc;

  void _validate() {
    for (final (String name, String value) in <(String, String)>[
      ('requestId', requestId),
      ('occurrenceId', occurrenceId),
      ('publisherId', publisherId),
      ('title', title),
      ('category', category),
      ('timezoneId', timezoneId),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be empty');
      }
    }
    if (publisherType != 'user' && publisherType != 'page') {
      throw ArgumentError.value(
        publisherType,
        'publisherType',
        'must be user or page',
      );
    }
    if (!publishedAtUtc.isUtc) {
      throw ArgumentError('publishedAtUtc must use UTC.');
    }
    if (timeOptions.isEmpty) {
      throw ArgumentError('A published request needs public time options.');
    }
    if (timeOptions.map((option) => option.id).toSet().length !=
        timeOptions.length) {
      throw ArgumentError('Find People time option ids must be unique.');
    }
    switch (scheduleMode) {
      case PublishedFindPeopleScheduleMode.single:
        if (timeOptions.length != 1 ||
            timeOptions.single.kind !=
                PublishedFindPeopleTimeOptionKind.confirmed) {
          throw ArgumentError('Single schedule requires one confirmed time.');
        }
      case PublishedFindPeopleScheduleMode.timePoll:
        if (timeOptions.length < 2 ||
            timeOptions.any(
              (option) =>
                  option.kind != PublishedFindPeopleTimeOptionKind.candidate,
            )) {
          throw ArgumentError(
            'Time poll requires at least two candidate times.',
          );
        }
      case PublishedFindPeopleScheduleMode.recurring:
        if (timeOptions.any(
          (option) =>
              option.kind != PublishedFindPeopleTimeOptionKind.confirmed,
        )) {
          throw ArgumentError('Recurring Details uses confirmed times only.');
        }
    }
    if (durationMinutes != null && durationMinutes! <= 0) {
      throw ArgumentError.value(
        durationMinutes,
        'durationMinutes',
        'must be positive',
      );
    }
    if (targetGroupSize < 2 || targetGroupSize > 20) {
      throw ArgumentError.value(
        targetGroupSize,
        'targetGroupSize',
        'must be between 2 and 20',
      );
    }
    if (currentGroupSize != null &&
        (currentGroupSize! < 0 || currentGroupSize! > targetGroupSize)) {
      throw ArgumentError.value(
        currentGroupSize,
        'currentGroupSize',
        'must be within target group size',
      );
    }
    if (remainingSeats != null &&
        (remainingSeats! < 0 || remainingSeats! > targetGroupSize)) {
      throw ArgumentError.value(
        remainingSeats,
        'remainingSeats',
        'must be within target group size',
      );
    }
    switch (costType) {
      case PublishedFindPeopleCostType.free:
        if (expectedSpendAmount != null && expectedSpendAmount! > 0) {
          throw ArgumentError('Free request cannot have a positive spend.');
        }
      case PublishedFindPeopleCostType.estimated:
        if (expectedSpendAmount == null ||
            expectedSpendAmount! <= 0 ||
            currencyCode.trim().isEmpty) {
          throw ArgumentError(
            'Estimated cost requires a positive amount and currency.',
          );
        }
      case PublishedFindPeopleCostType.unknown:
        if (expectedSpendAmount != null) {
          throw ArgumentError('Unknown cost cannot carry an amount.');
        }
    }
  }
}
