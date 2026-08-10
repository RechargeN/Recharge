import '../../contracts/booking/booking_contract.dart';

class BookingHoldDto {
  const BookingHoldDto({
    required this.schemaVersion,
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.occurrenceId,
    required this.inventoryPoolId,
    required this.units,
    required this.kind,
    required this.state,
    required this.createdAt,
    required this.expiresAt,
    required this.revision,
    this.resolvedAt,
  });

  factory BookingHoldDto.fromJson(Map<String, Object?> json) {
    const required = <String>{
      'schemaVersion',
      'id',
      'bookingId',
      'userId',
      'occurrenceId',
      'inventoryPoolId',
      'units',
      'kind',
      'state',
      'createdAt',
      'expiresAt',
      'revision',
    };
    requireExactKeys(
      json,
      allowed: <String>{...required, 'resolvedAt'},
      required: required,
      objectName: 'BookingHold',
    );
    final state = parseWireEnum(
      json['state'],
      BookingHoldState.values,
      field: 'state',
    );
    final resolvedAt = optionalUtcTimestamp(json['resolvedAt'], 'resolvedAt');
    if (state == BookingHoldState.active && resolvedAt != null) {
      throw const BookingContractFormatException(
        'Active hold cannot have resolvedAt',
      );
    }
    if (state != BookingHoldState.active && resolvedAt == null) {
      throw const BookingContractFormatException(
        'Resolved hold must have resolvedAt',
      );
    }
    return BookingHoldDto(
      schemaVersion: _requireSchemaVersion(json['schemaVersion']),
      id: requireNonBlankString(json['id'], 'id'),
      bookingId: requireNonBlankString(json['bookingId'], 'bookingId'),
      userId: requireNonBlankString(json['userId'], 'userId'),
      occurrenceId: requireNonBlankString(
        json['occurrenceId'],
        'occurrenceId',
      ),
      inventoryPoolId: requireNonBlankString(
        json['inventoryPoolId'],
        'inventoryPoolId',
      ),
      units: requirePositiveInt(json['units'], 'units'),
      kind: parseWireEnum(
        json['kind'],
        BookingHoldKind.values,
        field: 'kind',
      ),
      state: state,
      createdAt: requireUtcTimestamp(json['createdAt'], 'createdAt'),
      expiresAt: requireUtcTimestamp(json['expiresAt'], 'expiresAt'),
      resolvedAt: resolvedAt,
      revision: requireNonNegativeInt(json['revision'], 'revision'),
    );
  }

  final int schemaVersion;
  final String id;
  final String bookingId;
  final String userId;
  final String occurrenceId;
  final String inventoryPoolId;
  final int units;
  final BookingHoldKind kind;
  final BookingHoldState state;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? resolvedAt;
  final int revision;

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'id': id,
        'bookingId': bookingId,
        'userId': userId,
        'occurrenceId': occurrenceId,
        'inventoryPoolId': inventoryPoolId,
        'units': units,
        'kind': kind.name,
        'state': state.name,
        'createdAt': utcTimestamp(createdAt),
        'expiresAt': utcTimestamp(expiresAt),
        if (resolvedAt != null) 'resolvedAt': utcTimestamp(resolvedAt!),
        'revision': revision,
      };

  static int _requireSchemaVersion(Object? raw) {
    final value = requireNonNegativeInt(raw, 'schemaVersion');
    if (value != bookingContractSchemaVersion) {
      throw BookingContractFormatException(
        'Unsupported BookingHold schemaVersion: $value',
      );
    }
    return value;
  }
}
