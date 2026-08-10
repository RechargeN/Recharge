import '../../contracts/booking/booking_contract.dart';
import 'booking_dto.dart';
import 'booking_error_dto.dart';
import 'booking_hold_dto.dart';
import 'booking_policy_dto.dart';

class BookingResultDto {
  BookingResultDto({
    required this.schemaVersion,
    required this.kind,
    required this.requestId,
    required this.correlationId,
    required this.serverTime,
    this.booking,
    this.hold,
    this.policy,
    this.error,
    Map<String, Object?>? unsupportedPayload,
  }) : unsupportedPayload = unsupportedPayload == null
            ? null
            : freezeJsonMap(unsupportedPayload, 'unsupportedPayload') {
    if (kind == BookingResultKind.succeeded && error != null) {
      throw const BookingContractFormatException(
        'Succeeded result cannot contain error',
      );
    }
    if ((kind == BookingResultKind.rejected ||
            kind == BookingResultKind.retryableFailure) &&
        error == null) {
      throw const BookingContractFormatException(
        'Failed result must contain error',
      );
    }
    if (kind == BookingResultKind.unsupportedContract &&
        unsupportedPayload == null) {
      throw const BookingContractFormatException(
        'Unsupported result must preserve raw payload',
      );
    }
  }

  factory BookingResultDto.fromJson(Map<String, Object?> json) {
    const required = <String>{
      'schemaVersion',
      'kind',
      'requestId',
      'correlationId',
      'serverTime',
    };
    requireExactKeys(
      json,
      allowed: <String>{
        ...required,
        'booking',
        'hold',
        'policy',
        'error',
        'unsupportedPayload',
      },
      required: required,
      objectName: 'BookingResult',
    );
    final schemaVersion = requireNonNegativeInt(
      json['schemaVersion'],
      'schemaVersion',
    );
    if (schemaVersion != bookingContractSchemaVersion) {
      throw BookingContractFormatException(
        'Unsupported result schemaVersion: $schemaVersion',
      );
    }
    return BookingResultDto(
      schemaVersion: schemaVersion,
      kind: parseWireEnum(
        json['kind'],
        BookingResultKind.values,
        field: 'kind',
      ),
      requestId: requireNonBlankString(json['requestId'], 'requestId'),
      correlationId: requireNonBlankString(
        json['correlationId'],
        'correlationId',
      ),
      serverTime: requireUtcTimestamp(json['serverTime'], 'serverTime'),
      booking: json['booking'] == null
          ? null
          : BookingDto.fromJson(freezeJsonMap(json['booking'], 'booking')),
      hold: json['hold'] == null
          ? null
          : BookingHoldDto.fromJson(freezeJsonMap(json['hold'], 'hold')),
      policy: json['policy'] == null
          ? null
          : BookingPolicyDto.fromJson(freezeJsonMap(json['policy'], 'policy')),
      error: json['error'] == null
          ? null
          : BookingErrorDto.fromJson(freezeJsonMap(json['error'], 'error')),
      unsupportedPayload: json['unsupportedPayload'] == null
          ? null
          : freezeJsonMap(json['unsupportedPayload'], 'unsupportedPayload'),
    );
  }

  factory BookingResultDto.fromJsonFailClosed(Map<String, Object?> json) {
    try {
      return BookingResultDto.fromJson(json);
    } on FormatException {
      final requestId = json['requestId'];
      final correlationId = json['correlationId'];
      final serverTime = json['serverTime'];
      return BookingResultDto(
        schemaVersion: bookingContractSchemaVersion,
        kind: BookingResultKind.unsupportedContract,
        requestId: requestId is String && requestId.trim().isNotEmpty
            ? requestId
            : 'unsupported-request',
        correlationId:
            correlationId is String && correlationId.trim().isNotEmpty
                ? correlationId
                : 'unsupported-correlation',
        serverTime: serverTime is String && serverTime.endsWith('Z')
            ? DateTime.tryParse(serverTime)?.toUtc() ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
            : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        unsupportedPayload: json,
      );
    }
  }

  final int schemaVersion;
  final BookingResultKind kind;
  final String requestId;
  final String correlationId;
  final DateTime serverTime;
  final BookingDto? booking;
  final BookingHoldDto? hold;
  final BookingPolicyDto? policy;
  final BookingErrorDto? error;
  final Map<String, Object?>? unsupportedPayload;

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'kind': kind.name,
        'requestId': requestId,
        'correlationId': correlationId,
        'serverTime': utcTimestamp(serverTime),
        if (booking != null) 'booking': booking!.toJson(),
        if (hold != null) 'hold': hold!.toJson(),
        if (policy != null) 'policy': policy!.toJson(),
        if (error != null) 'error': error!.toJson(),
        if (unsupportedPayload != null)
          'unsupportedPayload': thawJsonMap(unsupportedPayload!),
      };
}
