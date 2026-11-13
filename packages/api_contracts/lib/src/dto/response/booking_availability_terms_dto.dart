import '../../contracts/booking/booking_contract.dart';

/// Party rule of one occurrence, as the Booking projection holds it.
enum BookingPartyMode { selfOnly, partyWithoutNames }

/// Status of a non-reserving availability answer
/// (`booking_availability.schema.json`).
enum BookingAvailabilityStatus {
  notOpen,
  available,
  limited,
  soldOut,
  closed,
  stale,
  unknown,
  unsupported,
}

enum BookingAvailabilityCapacityMode { finite, unlimited, notApplicable }

/// E2.0: the booking terms of one exact occurrence, a copy of the
/// authoritative Booking projection carried by `getEventAvailability`. The
/// client books with exactly these values and never derives them itself.
class BookingAvailabilityTermsDto {
  BookingAvailabilityTermsDto({
    this.inventoryPoolId,
    this.channel,
    required this.partyMode,
    required this.maxParticipantUnits,
    this.registrationOpensAt,
    this.registrationClosesAt,
    this.cancellationDeadline,
  }) {
    if (maxParticipantUnits < 1 || maxParticipantUnits > 21) {
      throw const BookingContractFormatException(
        'terms.maxParticipantUnits must be within 1..21',
      );
    }
    if (partyMode == BookingPartyMode.selfOnly && maxParticipantUnits != 1) {
      throw const BookingContractFormatException(
        'terms.selfOnly allows exactly one participant unit',
      );
    }
  }

  factory BookingAvailabilityTermsDto.fromJson(Map<String, Object?> json) {
    requireExactKeys(
      json,
      allowed: const <String>{
        'inventoryPoolId',
        'channel',
        'partyMode',
        'maxParticipantUnits',
        'registrationOpensAt',
        'registrationClosesAt',
        'cancellationDeadline',
      },
      required: const <String>{'partyMode', 'maxParticipantUnits'},
      objectName: 'terms',
    );
    return BookingAvailabilityTermsDto(
      inventoryPoolId: optionalNonBlankString(
        json['inventoryPoolId'],
        'terms.inventoryPoolId',
      ),
      channel: json['channel'] == null
          ? null
          : parseWireEnum(
              json['channel'],
              BookingChannel.values,
              field: 'terms.channel',
            ),
      partyMode: parseWireEnum(
        json['partyMode'],
        BookingPartyMode.values,
        field: 'terms.partyMode',
      ),
      maxParticipantUnits: requirePositiveInt(
        json['maxParticipantUnits'],
        'terms.maxParticipantUnits',
      ),
      registrationOpensAt: optionalUtcTimestamp(
        json['registrationOpensAt'],
        'terms.registrationOpensAt',
      ),
      registrationClosesAt: optionalUtcTimestamp(
        json['registrationClosesAt'],
        'terms.registrationClosesAt',
      ),
      cancellationDeadline: optionalUtcTimestamp(
        json['cancellationDeadline'],
        'terms.cancellationDeadline',
      ),
    );
  }

  final String? inventoryPoolId;
  final BookingChannel? channel;
  final BookingPartyMode partyMode;
  final int maxParticipantUnits;
  final DateTime? registrationOpensAt;
  final DateTime? registrationClosesAt;
  final DateTime? cancellationDeadline;
}

/// The availability object of a succeeded `getEventAvailability` answer.
/// Only the authoritative shapes may carry [terms].
class BookingAvailabilityDto {
  BookingAvailabilityDto({
    required this.eventId,
    required this.occurrenceId,
    this.channel,
    required this.asOf,
    required this.eventRevision,
    required this.status,
    required this.authoritative,
    required this.capacityMode,
    this.availableUnits,
    this.terms,
  }) {
    if (terms != null && !authoritative) {
      throw const BookingContractFormatException(
        'A non-authoritative availability carries no terms',
      );
    }
  }

  factory BookingAvailabilityDto.fromJson(Map<String, Object?> json) {
    requireExactKeys(
      json,
      allowed: const <String>{
        'eventId',
        'occurrenceId',
        'channel',
        'asOf',
        'eventRevision',
        'status',
        'authority',
        'capacityMode',
        'ledgerRevision',
        'availableUnits',
        'registrationOpensAt',
        'registrationClosesAt',
        'reasonCode',
        'terms',
      },
      required: const <String>{
        'eventId',
        'occurrenceId',
        'asOf',
        'eventRevision',
        'status',
        'authority',
        'capacityMode',
      },
      objectName: 'availability',
    );
    final Object? authority = json['authority'];
    if (authority != 'authoritative' && authority != 'nonAuthoritative') {
      throw BookingContractFormatException('Unsupported authority: $authority');
    }
    final Object? terms = json['terms'];
    return BookingAvailabilityDto(
      eventId: requireNonBlankString(json['eventId'], 'eventId'),
      occurrenceId: requireNonBlankString(json['occurrenceId'], 'occurrenceId'),
      channel: json['channel'] == null
          ? null
          : parseWireEnum(
              json['channel'],
              BookingChannel.values,
              field: 'channel',
            ),
      asOf: requireUtcTimestamp(json['asOf'], 'asOf'),
      eventRevision: requireNonNegativeInt(
        json['eventRevision'],
        'eventRevision',
      ),
      status: parseWireEnum(
        json['status'],
        BookingAvailabilityStatus.values,
        field: 'status',
      ),
      authoritative: authority == 'authoritative',
      capacityMode: parseWireEnum(
        json['capacityMode'],
        BookingAvailabilityCapacityMode.values,
        field: 'capacityMode',
      ),
      availableUnits: json['availableUnits'] == null
          ? null
          : requireNonNegativeInt(json['availableUnits'], 'availableUnits'),
      terms: terms == null
          ? null
          : BookingAvailabilityTermsDto.fromJson(freezeJsonMap(terms, 'terms')),
    );
  }

  final String eventId;
  final String occurrenceId;
  final BookingChannel? channel;
  final DateTime asOf;
  final int eventRevision;
  final BookingAvailabilityStatus status;
  final bool authoritative;
  final BookingAvailabilityCapacityMode capacityMode;
  final int? availableUnits;
  final BookingAvailabilityTermsDto? terms;
}
