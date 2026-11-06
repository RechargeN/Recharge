import 'package:firebase_auth/firebase_auth.dart';

import 'booking_callable_adapter.dart';

/// Server identity refusals (dash form of the `identity_session_result`
/// failure codes and HTTP envelope statuses) that decide against the account
/// or its Session. Only these clear the stored Session and the SDK user.
const Set<String> terminalIdentityCallableCodes = <String>{
  'unauthenticated',
  'session-expired',
  'session-revoked',
  'session-limit-reached',
  'account-blocked',
  'account-restricted',
  'account-creation-disabled',
  'provider-assertion-invalid',
  'provider-subject-conflict',
  'recent-auth-required',
  'not-found-or-not-accessible',
  'invalid-contract',
  'unsupported-schema',
  'invalid-argument',
  'permission-denied',
  'not-found',
};

/// Firebase Auth outcomes that mean the provider account itself is gone or
/// its credentials are no longer valid.
const Set<String> terminalFirebaseAuthCodes = <String>{
  'user-disabled',
  'user-not-found',
  'user-token-expired',
  'invalid-user-token',
  'user-mismatch',
};

/// Our own fail-closed states that are not account decisions (busy guards,
/// missing optional attestation).
const Set<String> _transientStateErrors = <String>{
  'dev_identity_operation_in_progress',
  'dev_app_check_token_missing',
};

const Set<String> _undecodableResponses = <String>{
  'Malformed Functions callable response', // l10n-ignore: exception id
  'Functions callable response is not an object', // l10n-ignore: exception id
};

/// Mainstream-app persistence: only an explicit refusal ends the sign-in.
/// Everything else (offline, Doze, DNS, timeouts, overload, unknown SDK or
/// platform errors) keeps the stored Session and SDK user; callers still grant
/// no authority until the server answers, and they retry later.
bool isTerminalIdentityFailure(Object error) {
  if (error is BookingCallableFailure) {
    return terminalIdentityCallableCodes.contains(error.code);
  }
  if (error is FirebaseAuthException) {
    return terminalFirebaseAuthCodes.contains(error.code);
  }
  // Undecodable bodies (captive portal HTML, truncated proxy reply) say
  // nothing about the account; correlation/binding violations are refusals.
  if (error is FormatException) {
    return !_undecodableResponses.contains(error.message);
  }
  if (error is StateError) {
    return !_transientStateErrors.contains(error.message);
  }
  return false;
}

bool isTransientIdentityFailure(Object error) =>
    !isTerminalIdentityFailure(error);

/// Safe diagnostic code (constants only, never messages, tokens or ids).
String identityFailureCode(Object error) => switch (error) {
  BookingCallableFailure(:final code) => code,
  FirebaseAuthException(:final code) => 'firebase:$code',
  StateError(:final message) => 'state:$message',
  _ => error.runtimeType.toString(),
};
