import 'dart:collection';

const int bookingContractSchemaVersion = 1;
const int bookingPolicyVersion = 1;
const int bookingMaxConcurrentFiniteAllocations = 5;

enum BookingAdmissionMode { rsvp, booking, application }

enum BookingConfirmationMode { instant, manualApproval }

enum BookingState { pending, confirmed, cancelled, expired, waitlisted }

enum BookingChannel { onsite, online, any }

enum BookingReconfirmationState {
  notRequired,
  notOpen,
  required,
  confirmed,
  missed,
}

enum BookingHoldKind { waitlistOffer }

enum BookingHoldState { active, accepted, declined, expired, released }

enum BookingCountingRule { onePerBookingOrActiveHold }

enum BookingCommandType {
  createBooking,
  cancelBooking,
  approveApplication,
  rejectApplication,
  joinWaitlist,
  leaveWaitlist,
  acceptWaitlistHold,
  declineWaitlistHold,
  reconfirmBooking,
}

enum BookingResultKind {
  succeeded,
  rejected,
  retryableFailure,
  unsupportedContract,
}

enum BookingErrorCode {
  notAuthenticated('not_authenticated'),
  notAuthorized('not_authorized'),
  featureDisabled('feature_disabled'),
  eventUnavailable('event_unavailable'),
  occurrenceCancelled('occurrence_cancelled'),
  registrationNotOpen('registration_not_open'),
  registrationClosed('registration_closed'),
  eligibilityNotSatisfied('eligibility_not_satisfied'),
  invalidGuestCount('invalid_guest_count'),
  poolRequired('pool_required'),
  poolUnavailable('pool_unavailable'),
  soldOut('sold_out'),
  alreadyActive('already_active'),
  concurrencyCapReached('concurrency_cap_reached'),
  revisionConflict('revision_conflict'),
  holdExpired('hold_expired'),
  cancellationDeadlinePassed('cancellation_deadline_passed'),
  idempotencyConflict('idempotency_conflict'),
  contention('contention'),
  forbidden('forbidden'),
  unsupportedSchema('unsupported_schema'),
  temporarilyUnavailable('temporarily_unavailable'),
  invalidContract('invalid_contract');

  const BookingErrorCode(this.wireValue);

  final String wireValue;
}

enum BookingTerminalReason {
  userCancelled,
  organizerCancelled,
  applicationRejected,
  occurrenceCancelled,
  eventCancelled,
  missedReconfirmation,
  waitlistOfferDeclined,
  waitlistOfferExpired,
  duplicateResolved,
  policyInvalidated,
}

class BookingContractFormatException implements FormatException {
  const BookingContractFormatException(this.message, {this.source});

  @override
  final String message;

  @override
  final Object? source;

  @override
  int? get offset => null;

  @override
  String toString() => 'BookingContractFormatException: $message';
}

T parseWireEnum<T extends Enum>(
  Object? raw,
  List<T> values, {
  required String field,
  String Function(T value)? wireValue,
}) {
  if (raw is! String) {
    throw BookingContractFormatException('$field must be a string');
  }
  for (final value in values) {
    final candidate = wireValue?.call(value) ?? value.name;
    if (candidate == raw) return value;
  }
  throw BookingContractFormatException('Unsupported $field: $raw');
}

String requireNonBlankString(Object? raw, String field) {
  if (raw is! String || raw.trim().isEmpty) {
    throw BookingContractFormatException('$field must be non-blank');
  }
  return raw;
}

int requireNonNegativeInt(Object? raw, String field) {
  if (raw is! int || raw < 0) {
    throw BookingContractFormatException('$field must be a non-negative int');
  }
  return raw;
}

int requirePositiveInt(Object? raw, String field) {
  if (raw is! int || raw <= 0) {
    throw BookingContractFormatException('$field must be a positive int');
  }
  return raw;
}

DateTime requireUtcTimestamp(Object? raw, String field) {
  final value = requireNonBlankString(raw, field);
  if (!value.endsWith('Z')) {
    throw BookingContractFormatException('$field must be UTC RFC 3339');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw BookingContractFormatException('$field must be UTC RFC 3339');
  }
  return parsed;
}

String utcTimestamp(DateTime value) {
  if (!value.isUtc) {
    throw const BookingContractFormatException('Timestamp must be UTC');
  }
  return value.toIso8601String();
}

void requireExactKeys(
  Map<String, Object?> json, {
  required Set<String> allowed,
  required Set<String> required,
  required String objectName,
}) {
  final unknown = json.keys.where((key) => !allowed.contains(key)).toList();
  if (unknown.isNotEmpty) {
    throw BookingContractFormatException(
      '$objectName contains unknown fields: ${unknown.join(', ')}',
    );
  }
  final missing = required.where((key) => !json.containsKey(key)).toList();
  if (missing.isNotEmpty) {
    throw BookingContractFormatException(
      '$objectName is missing fields: ${missing.join(', ')}',
    );
  }
}

Object? freezeJsonValue(Object? value) {
  if (value is Map) {
    return UnmodifiableMapView<String, Object?>(
      value.map(
        (key, nested) => MapEntry(key.toString(), freezeJsonValue(nested)),
      ),
    );
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(freezeJsonValue));
  }
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  throw BookingContractFormatException(
    'Unsupported JSON value type: ${value.runtimeType}',
  );
}

Map<String, Object?> freezeJsonMap(Object? value, String field) {
  if (value is! Map) {
    throw BookingContractFormatException('$field must be an object');
  }
  return freezeJsonValue(value) as Map<String, Object?>;
}

Object? thawJsonValue(Object? value) {
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key.toString(): thawJsonValue(entry.value),
    };
  }
  if (value is List) return value.map(thawJsonValue).toList();
  return value;
}

Map<String, Object?> thawJsonMap(Map<String, Object?> value) {
  return thawJsonValue(value) as Map<String, Object?>;
}

String? optionalNonBlankString(Object? raw, String field) {
  if (raw == null) return null;
  return requireNonBlankString(raw, field);
}

DateTime? optionalUtcTimestamp(Object? raw, String field) {
  if (raw == null) return null;
  return requireUtcTimestamp(raw, field);
}
