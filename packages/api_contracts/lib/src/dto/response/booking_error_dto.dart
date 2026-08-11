import '../../contracts/booking/booking_contract.dart';

class BookingErrorDto {
  BookingErrorDto({
    required this.schemaVersion,
    required this.code,
    required this.retryable,
    required this.correlationId,
    Map<String, Object?> details = const {},
  }) : details = freezeJsonMap(details, 'details') {
    _validateDetails(this.details);
  }

  factory BookingErrorDto.fromJson(Map<String, Object?> json) {
    const required = <String>{
      'schemaVersion',
      'code',
      'retryable',
      'correlationId',
    };
    requireExactKeys(
      json,
      allowed: <String>{...required, 'details'},
      required: required,
      objectName: 'BookingError',
    );
    final retryable = json['retryable'];
    if (retryable is! bool) {
      throw const BookingContractFormatException('retryable must be bool');
    }
    return BookingErrorDto(
      schemaVersion: _requireSchemaVersion(json['schemaVersion']),
      code: parseWireEnum(
        json['code'],
        BookingErrorCode.values,
        field: 'code',
        wireValue: (value) => value.wireValue,
      ),
      retryable: retryable,
      correlationId: requireNonBlankString(
        json['correlationId'],
        'correlationId',
      ),
      details: json['details'] == null
          ? const {}
          : freezeJsonMap(json['details'], 'details'),
    );
  }

  final int schemaVersion;
  final BookingErrorCode code;
  final bool retryable;
  final String correlationId;
  final Map<String, Object?> details;

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'code': code.wireValue,
        'retryable': retryable,
        'correlationId': correlationId,
        if (details.isNotEmpty) 'details': thawJsonMap(details),
      };

  static int _requireSchemaVersion(Object? raw) {
    final value = requireNonNegativeInt(raw, 'schemaVersion');
    if (value != bookingContractSchemaVersion) {
      throw BookingContractFormatException(
        'Unsupported BookingError schemaVersion: $value',
      );
    }
    return value;
  }

  static const Set<String> _allowedDetailKeys = {
    'field',
    'retryAfterSeconds',
    'limit',
    'policyVersion',
    'currentRevision',
    'reasonCode',
  };

  static const List<String> _prohibitedFragments = [
    'name',
    'email',
    'phone',
    'token',
    'secret',
    'guest',
    'eligibility',
    'application',
    'accesscode',
    'joinlink',
  ];

  static void _validateDetails(Map<String, Object?> details) {
    for (final entry in details.entries) {
      if (!_allowedDetailKeys.contains(entry.key)) {
        throw BookingContractFormatException(
          'Error detail is not allowlisted: ${entry.key}',
        );
      }
      final normalized = entry.key.toLowerCase();
      if (_prohibitedFragments.any(normalized.contains)) {
        throw BookingContractFormatException(
          'Error detail contains prohibited data: ${entry.key}',
        );
      }
      final value = entry.value;
      if (value != null &&
          value is! String &&
          value is! num &&
          value is! bool) {
        throw BookingContractFormatException(
          'Error detail must be scalar: ${entry.key}',
        );
      }
    }
  }
}
