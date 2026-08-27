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
    _validateRequestId(requestId);
    _requireBoundedId(idempotencyKey, 'idempotencyKey');
    _validateExpectedRevision(commandType, expectedBookingRevision);
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
      requestId: _requireString(json['requestId'], 'requestId'),
      idempotencyKey: _requireString(json['idempotencyKey'], 'idempotencyKey'),
      expectedBookingRevision: !json.containsKey('expectedBookingRevision')
          ? null
          : requireNonNegativeInt(
              json['expectedBookingRevision'],
              'expectedBookingRevision',
            ),
      occurredAgainstEventRevision:
          !json.containsKey('occurredAgainstEventRevision')
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

  static const Set<BookingCommandType> _commandsRequiringExpectedRevision = {
    BookingCommandType.cancelBooking,
    BookingCommandType.approveApplication,
    BookingCommandType.rejectApplication,
    BookingCommandType.leaveWaitlist,
    BookingCommandType.acceptWaitlistHold,
    BookingCommandType.declineWaitlistHold,
    BookingCommandType.reconfirmBooking,
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
      if (payload.containsKey(key)) _requireBoundedId(payload[key], key);
    }
    for (final key in const ['inventoryPoolId', 'auxiliaryTrackId']) {
      if (payload.containsKey(key)) _requireBoundedId(payload[key], key);
    }
    if (payload.containsKey('participantUnits')) {
      final units = requirePositiveInt(
        payload['participantUnits'],
        'participantUnits',
      );
      if (units > 21) {
        throw const BookingContractFormatException(
          'participantUnits must be at most 21',
        );
      }
    }
    if (payload.containsKey('channel')) {
      parseWireEnum(
        payload['channel'],
        BookingChannel.values,
        field: 'channel',
      );
    }
    if (payload.containsKey('reasonCode')) {
      _requireBoundedNonBlankString(payload['reasonCode'], 'reasonCode', 64);
    }
    if (payload.containsKey('namedGuests')) {
      _validateNamedGuests(payload['namedGuests']);
    }
    if (payload.containsKey('applicationFields') &&
        payload['applicationFields'] is! Map) {
      throw const BookingContractFormatException(
        'applicationFields must be an object',
      );
    }
    _rejectNonFiniteNumbers(payload);
    final hasPool = payload.containsKey('inventoryPoolId');
    final hasChannel = payload.containsKey('channel');
    if (hasPool != hasChannel &&
        commandType != BookingCommandType.approveApplication) {
      throw const BookingContractFormatException(
        'inventoryPoolId and channel must be present together',
      );
    }
  }

  static String _requireString(Object? raw, String field) {
    if (raw is! String) {
      throw BookingContractFormatException('$field must be a string');
    }
    return raw;
  }

  static void _requireBoundedId(Object? raw, String field) {
    _requireBoundedNonBlankString(raw, field, 128);
  }

  static void _validateExpectedRevision(
    BookingCommandType commandType,
    int? expectedBookingRevision,
  ) {
    final required = _commandsRequiringExpectedRevision.contains(commandType);
    if (required && expectedBookingRevision == null) {
      throw BookingContractFormatException(
        '${commandType.name} requires expectedBookingRevision',
      );
    }
    if (!required && expectedBookingRevision != null) {
      throw BookingContractFormatException(
        '${commandType.name} forbids expectedBookingRevision',
      );
    }
  }

  static void _validateRequestId(String value) {
    final scalars = _unicodeScalarValues(value, 'requestId');
    if (scalars.isEmpty || scalars.length > 128) {
      throw const BookingContractFormatException(
        'requestId must contain 1 to 128 Unicode scalar values',
      );
    }
    if (scalars.every(_isBookingRequestIdBlankScalar)) {
      throw const BookingContractFormatException(
        'requestId must contain a non-blank Unicode scalar value',
      );
    }
  }

  static void _requireBoundedNonBlankString(
    Object? raw,
    String field,
    int maximumScalars,
  ) {
    if (raw is! String) {
      throw BookingContractFormatException('$field must be a string');
    }
    final scalars = _unicodeScalarValues(raw, field);
    if (scalars.isEmpty || scalars.length > maximumScalars) {
      throw BookingContractFormatException(
        '$field must contain 1 to $maximumScalars Unicode scalar values',
      );
    }
    if (scalars.every(_isGenericBlankScalar)) {
      throw BookingContractFormatException('$field must be non-blank');
    }
  }

  static List<int> _unicodeScalarValues(String value, String field) {
    final scalars = <int>[];
    final units = value.codeUnits;
    for (var index = 0; index < units.length; index++) {
      final unit = units[index];
      if (unit >= 0xD800 && unit <= 0xDBFF) {
        if (index + 1 >= units.length) {
          throw BookingContractFormatException(
            '$field contains an unpaired UTF-16 surrogate',
          );
        }
        final low = units[++index];
        if (low < 0xDC00 || low > 0xDFFF) {
          throw BookingContractFormatException(
            '$field contains an unpaired UTF-16 surrogate',
          );
        }
        scalars.add(0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00));
      } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
        throw BookingContractFormatException(
          '$field contains an unpaired UTF-16 surrogate',
        );
      } else {
        scalars.add(unit);
      }
    }
    return scalars;
  }

  static bool _isBookingRequestIdBlankScalar(int scalar) =>
      (scalar >= 0x0009 && scalar <= 0x000D) ||
      scalar == 0x0020 ||
      scalar == 0x0085 ||
      scalar == 0x00A0 ||
      scalar == 0x1680 ||
      (scalar >= 0x2000 && scalar <= 0x200A) ||
      scalar == 0x2028 ||
      scalar == 0x2029 ||
      scalar == 0x202F ||
      scalar == 0x205F ||
      scalar == 0x3000;

  static bool _isGenericBlankScalar(int scalar) =>
      _isBookingRequestIdBlankScalar(scalar) || scalar == 0xFEFF;

  static void _validateNamedGuests(Object? value) {
    if (value is! List || value.length > 20) {
      throw const BookingContractFormatException(
        'namedGuests must be an array with at most 20 items',
      );
    }
    for (final rawGuest in value) {
      if (rawGuest is! Map) {
        throw const BookingContractFormatException(
          'namedGuests entries must be objects',
        );
      }
      final guest = rawGuest.cast<String, Object?>();
      requireExactKeys(
        guest,
        allowed: const {'displayName'},
        required: const {'displayName'},
        objectName: 'namedGuest',
      );
      _requireBoundedNonBlankString(
        guest['displayName'],
        'namedGuest.displayName',
        120,
      );
    }
  }

  static void _rejectNonFiniteNumbers(Object? value) {
    if (value is num && !value.isFinite) {
      throw const BookingContractFormatException(
        'Command payload numbers must be finite',
      );
    }
    if (value is Map) {
      for (final nested in value.values) {
        _rejectNonFiniteNumbers(nested);
      }
    } else if (value is List) {
      for (final nested in value) {
        _rejectNonFiniteNumbers(nested);
      }
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
