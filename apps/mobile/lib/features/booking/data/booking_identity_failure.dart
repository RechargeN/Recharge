import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'booking_callable_adapter.dart';

/// Server-side and network outcomes after which the stored Recharge Session
/// and the Firebase SDK user are kept: nothing was decided against the
/// account, the request simply did not complete. Callers still grant no
/// authority until the server answers; they retry later.
const Set<String> transientIdentityCallableCodes = <String>{
  'unavailable',
  'deadline-exceeded',
  'resource-exhausted',
  'rate-limited',
  'temporarily-unavailable',
  'internal',
};

const Set<String> _transientFirebaseAuthCodes = <String>{
  'network-request-failed',
  'too-many-requests',
};

/// True only for failures that say nothing about the account itself
/// (offline, Doze, timeout, overloaded or rate-limited backend). Revoked,
/// expired or foreign Sessions, 401 and contract errors are terminal.
bool isTransientIdentityFailure(Object error) {
  if (error is TimeoutException ||
      error is SocketException ||
      error is http.ClientException) {
    return true;
  }
  if (error is FirebaseAuthException) {
    return _transientFirebaseAuthCodes.contains(error.code);
  }
  if (error is BookingCallableFailure) {
    return transientIdentityCallableCodes.contains(error.code);
  }
  return false;
}
