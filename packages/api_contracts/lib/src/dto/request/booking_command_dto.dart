import '../../contracts/booking/booking_contract.dart';

class BookingCommandDto {
  BookingCommandDto({
    required this.schemaVersion,
    required this.commandType,
    required this.requestId,
    required this.idempotencyKey,
    required Map<String, Object?> payload,
    this.expectedBookingRevision,
    this.occurredAgainstEventRevision,
  }) : payload = freezeJsonMap(payload, 'payload') {
    if (schemaVersion != bookingContractSchemaVersion) {
      throw BookingContractFormatException(
        'Unsupported command schemaVersion: $schemaVersion',
      );
    }
    if (expectedBookingRevision != null && expectedBookingRevision! < 0) {
      throw const BookingContractFormatException(
        'expectedBookingRevision must be non-negative',
      );
    }
    if (occurredAgainstEventRevision != null &&
        occurredAgainstEventRevision! < 0) {
      throw const BookingContractFormatException(
        'occurredAgainstEventRevision must be non-negative',
      );
    }
    _validatePayload(commandType, this.payload);
  }

  factory BookingCommandDto.fromJson(Map<String, Object?> json) {
    const required = <String>{
      'schemaVersion',
      'commandType',
      'requestId',
      'idempotencyKey',
      'payload',
    };
    requireExactKeys(
      json,
      allowed: <String>{
        ...required,
        'expectedBookingRevision',
        'occurredAgainstEventRevision',
      },
      required: required,
      objectName: 'BookingCommand',
    );
    return BookingCommandDto(
      schemaVersion: requireNonNegativeInt(
        json['schemaVersion'],
        'schemaVersion',
      ),
      commandType: parseWireEnum(
        json['commandType'],
        BookingCommandType.values,
        field: 'commandType',
      ),
      requestId: requireNonBlankString(json['requestId'], 'requestId'),
      idempotencyKey: requireNonBlankString(
        json['idempotencyKey'],
        'idempotencyKey',
      ),
      expectedBookingRevision: json['expectedBookingRevision'] == null
          ? null
          : requireNonNegativeInt(
              json['expectedBookingRevision'],
              'expectedBookingRevision',
            ),
      occurredAgainstEventRevision: json['occurredAgainstEventRevision'] == null
          ? null
          : requireNonNegativeInt(
              json['occurredAgainstEventRevision'],
              'occurredAgainstEventRevision',
            ),
      payload: freezeJsonMap(json['payload'], 'payload'),
    );
  }

  final int schemaVersion;
  final BookingCommandType commandType;
  final String requestId;
  final String idempotencyKey;
  final int? expectedBookingRevision;
  final int? occurredAgainstEventRevision;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'commandType': commandType.name,
        'requestId': requestId,
        'idempotencyKey': idempotencyKey,
        if (expectedBookingRevision != null)
          'expectedBookingRevision': expectedBookingRevision,
        if (occurredAgainstEventRevision != null)
          'occurredAgainstEventRevision': occurredAgainstEventRevision,
        'payload': thawJsonMap(payload),
      };

  static const Map<BookingCommandType, Set<String>> _requiredPayloadKeys = {
    BookingCommandType.createBooking: {'occurrenceId', 'participantUnits'},
    BookingCommandType.cancelBooking: {'bookingId'},
    BookingCommandType.approveApplication: {'bookingId'},
    BookingCommandType.rejectApplication: {'bookingId', 'reasonCode'},
    BookingCommandType.joinWaitlist: {
      'occurrenceId',
      'inventoryPoolId',
      'participantUnits',
    },
    BookingCommandType.leaveWaitlist: {'bookingId'},
    BookingCommandType.acceptWaitlistHold: {'bookingId', 'holdId'},
    BookingCommandType.declineWaitlistHold: {'bookingId', 'holdId'},
    BookingCommandType.reconfirmBooking: {'bookingId'},
  };

  static const Map<BookingCommandType, Set<String>> _allowedPayloadKeys = {
    BookingCommandType.createBooking: {
      'occurrenceId',
      'inventoryPoolId',
      'channel',
      'participantUnits',
      'namedGuests',
      'auxiliaryTrackId',
      'applicationFields',
    },
    BookingCommandType.cancelBooking: {'bookingId', 'reasonCode'},
    BookingCommandType.approveApplication: {'bookingId', 'inventoryPoolId'},
    BookingCommandType.rejectApplication: {'bookingId', 'reasonCode'},
    BookingCommandType.joinWaitlist: {
      'occurrenceId',
      'inventoryPoolId',
      'channel',
      'participantUnits',
    },
    BookingCommandType.leaveWaitlist: {'bookingId'},
    BookingCommandType.acceptWaitlistHold: {'bookingId', 'holdId'},
    BookingCommandType.declineWaitlistHold: {'bookingId', 'holdId'},
    BookingCommandType.reconfirmBooking: {'bookingId'},
  };

  static const Set<String> _forbiddenAuthorityKeys = {
    'actorid',
    'userid',
    'publisherid',
    'pageid',
    'creatorid',
    'adminid',
    'capabilities',
    'roles',
  };

  static void _validatePayload(
    BookingCommandType commandType,
    Map<String, Object?> payload,
  ) {
    requireExactKeys(
      payload,
      allowed: _allowedPayloadKeys[commandType]!,
      required: _requiredPayloadKeys[commandType]!,
      objectName: '${commandType.name}.payload',
    );
    _rejectAuthorityKeys(payload);

    for (final key in const ['bookingId', 'holdId', 'occurrenceId']) {
      if (payload.containsKey(key)) requireNonBlankString(payload[key], key);
    }
    for (final key in const ['inventoryPoolId', 'auxiliaryTrackId']) {
      if (payload[key] != null) requireNonBlankString(payload[key], key);
    }
    if (payload.containsKey('participantUnits')) {
      requirePositiveInt(payload['participantUnits'], 'participantUnits');
    }
    if (payload['channel'] != null) {
      parseWireEnum(
        payload['channel'],
        BookingChannel.values,
        field: 'channel',
      );
    }
    if (payload['reasonCode'] != null) {
      requireNonBlankString(payload['reasonCode'], 'reasonCode');
    }
    final hasPool = payload['inventoryPoolId'] != null;
    final hasChannel = payload['channel'] != null;
    if (hasPool != hasChannel &&
        commandType != BookingCommandType.approveApplication) {
      throw const BookingContractFormatException(
        'inventoryPoolId and channel must be present together',
      );
    }
  }

  static void _rejectAuthorityKeys(Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        final normalized = entry.key.toString().toLowerCase();
        if (_forbiddenAuthorityKeys.contains(normalized)) {
          throw BookingContractFormatException(
            'Command payload cannot contain authority field ${entry.key}',
          );
        }
        _rejectAuthorityKeys(entry.value);
      }
    } else if (value is List) {
      for (final item in value) {
        _rejectAuthorityKeys(item);
      }
    }
  }
}
