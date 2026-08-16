import '../../contracts/booking/booking_contract.dart';

class BookingDto {
  BookingDto({
    required this.id,
    required this.schemaVersion,
    required this.revision,
    required this.userId,
    required this.eventId,
    required this.occurrenceId,
    required this.admissionMode,
    required this.confirmationMode,
    required this.state,
    required this.participantUnits,
    required this.reconfirmationState,
    required this.createdAt,
    required this.updatedAt,
    this.inventoryPoolId,
    this.channel,
    this.auxiliaryTrackId,
    List<Map<String, Object?>> namedGuests = const [],
    this.eligibilitySnapshotRef,
    this.activeHoldId,
    this.terminalReason,
    this.confirmedAt,
    this.cancelledAt,
    this.expiredAt,
  }) : namedGuests = List<Map<String, Object?>>.unmodifiable(
          namedGuests.map((guest) => freezeJsonMap(guest, 'namedGuests')),
        ) {
    if (schemaVersion != bookingContractSchemaVersion) {
      throw BookingContractFormatException(
        'Unsupported Booking schemaVersion: $schemaVersion',
      );
    }
    if ((inventoryPoolId == null) != (channel == null)) {
      throw const BookingContractFormatException(
        'inventoryPoolId and channel must be present together',
      );
    }
    if (state != BookingState.waitlisted && activeHoldId != null) {
      throw const BookingContractFormatException(
        'Only waitlisted Booking may reference an active hold',
      );
    }
  }

  factory BookingDto.fromJson(Map<String, Object?> json) {
    const required = <String>{
      'id',
      'schemaVersion',
      'revision',
      'userId',
      'eventId',
      'occurrenceId',
      'admissionMode',
      'confirmationMode',
      'state',
      'participantUnits',
      'reconfirmationState',
      'createdAt',
      'updatedAt',
    };
    const allowed = <String>{
      ...required,
      'inventoryPoolId',
      'channel',
      'auxiliaryTrackId',
      'namedGuests',
      'eligibilitySnapshotRef',
      'activeHoldId',
      'terminalReason',
      'confirmedAt',
      'cancelledAt',
      'expiredAt',
    };
    requireExactKeys(
      json,
      allowed: allowed,
      required: required,
      objectName: 'Booking',
    );
    final rawGuests = json['namedGuests'];
    final guests = <Map<String, Object?>>[];
    if (rawGuests != null) {
      if (rawGuests is! List || rawGuests.length > 20) {
        throw const BookingContractFormatException(
          'namedGuests must be a list with at most 20 entries',
        );
      }
      for (final rawGuest in rawGuests) {
        guests.add(freezeJsonMap(rawGuest, 'namedGuests[]'));
      }
    }
    return BookingDto(
      id: requireNonBlankString(json['id'], 'id'),
      schemaVersion: requireNonNegativeInt(
        json['schemaVersion'],
        'schemaVersion',
      ),
      revision: requireNonNegativeInt(json['revision'], 'revision'),
      userId: requireNonBlankString(json['userId'], 'userId'),
      eventId: requireNonBlankString(json['eventId'], 'eventId'),
      occurrenceId: requireNonBlankString(
        json['occurrenceId'],
        'occurrenceId',
      ),
      inventoryPoolId: optionalNonBlankString(
        json['inventoryPoolId'],
        'inventoryPoolId',
      ),
      channel: json['channel'] == null
          ? null
          : parseWireEnum(
              json['channel'],
              BookingChannel.values,
              field: 'channel',
            ),
      auxiliaryTrackId: optionalNonBlankString(
        json['auxiliaryTrackId'],
        'auxiliaryTrackId',
      ),
      admissionMode: parseWireEnum(
        json['admissionMode'],
        BookingAdmissionMode.values,
        field: 'admissionMode',
      ),
      confirmationMode: parseWireEnum(
        json['confirmationMode'],
        BookingConfirmationMode.values,
        field: 'confirmationMode',
      ),
      state: parseWireEnum(
        json['state'],
        BookingState.values,
        field: 'state',
      ),
      participantUnits: requirePositiveInt(
        json['participantUnits'],
        'participantUnits',
      ),
      namedGuests: guests,
      eligibilitySnapshotRef: optionalNonBlankString(
        json['eligibilitySnapshotRef'],
        'eligibilitySnapshotRef',
      ),
      activeHoldId: optionalNonBlankString(
        json['activeHoldId'],
        'activeHoldId',
      ),
      reconfirmationState: parseWireEnum(
        json['reconfirmationState'],
        BookingReconfirmationState.values,
        field: 'reconfirmationState',
      ),
      terminalReason: json['terminalReason'] == null
          ? null
          : parseWireEnum(
              json['terminalReason'],
              BookingTerminalReason.values,
              field: 'terminalReason',
            ),
      createdAt: requireUtcTimestamp(json['createdAt'], 'createdAt'),
      updatedAt: requireUtcTimestamp(json['updatedAt'], 'updatedAt'),
      confirmedAt: optionalUtcTimestamp(json['confirmedAt'], 'confirmedAt'),
      cancelledAt: optionalUtcTimestamp(json['cancelledAt'], 'cancelledAt'),
      expiredAt: optionalUtcTimestamp(json['expiredAt'], 'expiredAt'),
    );
  }

  final String id;
  final int schemaVersion;
  final int revision;
  final String userId;
  final String eventId;
  final String occurrenceId;
  final String? inventoryPoolId;
  final BookingChannel? channel;
  final String? auxiliaryTrackId;
  final BookingAdmissionMode admissionMode;
  final BookingConfirmationMode confirmationMode;
  final BookingState state;
  final int participantUnits;
  final List<Map<String, Object?>> namedGuests;
  final String? eligibilitySnapshotRef;
  final String? activeHoldId;
  final BookingReconfirmationState reconfirmationState;
  final BookingTerminalReason? terminalReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? confirmedAt;
  final DateTime? cancelledAt;
  final DateTime? expiredAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'schemaVersion': schemaVersion,
        'revision': revision,
        'userId': userId,
        'eventId': eventId,
        'occurrenceId': occurrenceId,
        if (inventoryPoolId != null) 'inventoryPoolId': inventoryPoolId,
        if (channel != null) 'channel': channel!.name,
        if (auxiliaryTrackId != null) 'auxiliaryTrackId': auxiliaryTrackId,
        'admissionMode': admissionMode.name,
        'confirmationMode': confirmationMode.name,
        'state': state.name,
        'participantUnits': participantUnits,
        if (namedGuests.isNotEmpty)
          'namedGuests': namedGuests.map(thawJsonMap).toList(),
        if (eligibilitySnapshotRef != null)
          'eligibilitySnapshotRef': eligibilitySnapshotRef,
        if (activeHoldId != null) 'activeHoldId': activeHoldId,
        'reconfirmationState': reconfirmationState.name,
        if (terminalReason != null) 'terminalReason': terminalReason!.name,
        'createdAt': utcTimestamp(createdAt),
        'updatedAt': utcTimestamp(updatedAt),
        if (confirmedAt != null) 'confirmedAt': utcTimestamp(confirmedAt!),
        if (cancelledAt != null) 'cancelledAt': utcTimestamp(cancelledAt!),
        if (expiredAt != null) 'expiredAt': utcTimestamp(expiredAt!),
      };
}
