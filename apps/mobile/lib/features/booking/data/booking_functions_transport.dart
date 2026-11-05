import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'booking_callable_adapter.dart';

final class BookingIdentitySessionContext {
  BookingIdentitySessionContext({
    required this.sessionId,
    required this.sessionHandle,
    required this.installationId,
  }) {
    if (!_safeId.hasMatch(sessionId)) {
      throw const FormatException('Invalid Booking session id');
    }
    if (!_sessionHandle.hasMatch(sessionHandle)) {
      throw const FormatException('Invalid Booking session handle');
    }
    if (!_installationId.hasMatch(installationId)) {
      throw const FormatException('Invalid Booking installation id');
    }
  }

  factory BookingIdentitySessionContext.fromJson(Map<String, Object?> json) {
    if (json.keys.toSet().difference(_allowedSessionFields).isNotEmpty) {
      throw const FormatException('Booking session contains authority fields');
    }
    return BookingIdentitySessionContext(
      sessionId: json['sessionId'] as String,
      sessionHandle: json['sessionHandle'] as String,
      installationId: json['installationId'] as String,
    );
  }

  /// Parses the Identity callable result while deliberately discarding User,
  /// expiry and every server-side authorization field.
  factory BookingIdentitySessionContext.fromServerResponse(
    Map<String, Object?> json,
  ) => BookingIdentitySessionContext(
    sessionId: json['sessionId'] as String,
    sessionHandle: json['sessionHandle'] as String,
    installationId: json['installationId'] as String,
  );

  final String sessionId;
  final String sessionHandle;
  final String installationId;

  Map<String, Object?> toJson() => <String, Object?>{
    'sessionId': sessionId,
    'sessionHandle': sessionHandle,
    'installationId': installationId,
  };

  static final RegExp _safeId = RegExp(r'^(?!__name__$)[A-Za-z0-9_-]{1,128}$');
  static final RegExp _sessionHandle = RegExp(r'^[A-Za-z0-9_-]{43}$');
  static final RegExp _installationId = RegExp(
    r'^(?!__name__$)[A-Za-z0-9._:-]{1,128}$',
  );
  static const Set<String> _allowedSessionFields = <String>{
    'sessionId',
    'sessionHandle',
    'installationId',
  };
}

abstract interface class BookingIdentitySessionStore {
  Future<BookingIdentitySessionContext?> read();
  Future<void> saveServerIssued(BookingIdentitySessionContext session);
  Future<void> clear();
}

final class SecureBookingIdentitySessionStore
    implements BookingIdentitySessionStore {
  const SecureBookingIdentitySessionStore(
    this._storage, {
    this.environment = BookingIdentityCacheEnvironment.local,
  });

  final BookingIdentityCacheEnvironment environment;

  String get _key => '${environment.namespace}.server_identity_session.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<BookingIdentitySessionContext?> read() async {
    final encoded = await _storage.read(key: _key);
    if (encoded == null) return null;
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid persisted Booking session');
    }
    return BookingIdentitySessionContext.fromJson(
      Map<String, Object?>.from(decoded),
    );
  }

  @override
  Future<void> saveServerIssued(BookingIdentitySessionContext session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

final class InMemoryBookingIdentitySessionStore
    implements BookingIdentitySessionStore {
  BookingIdentitySessionContext? _value;

  @override
  Future<BookingIdentitySessionContext?> read() async => _value;

  @override
  Future<void> saveServerIssued(BookingIdentitySessionContext session) async {
    _value = session;
  }

  @override
  Future<void> clear() async {
    _value = null;
  }
}

abstract interface class BookingFirebaseIdTokenProvider {
  Future<String?> currentIdToken({bool forceRefresh = false});
}

/// Default until the separately gated Firebase Auth mobile adapter exists.
/// A mock Auth access token must never be promoted to backend authority.
final class DisabledBookingFirebaseIdTokenProvider
    implements BookingFirebaseIdTokenProvider {
  const DisabledBookingFirebaseIdTokenProvider();

  @override
  Future<String?> currentIdToken({bool forceRefresh = false}) async => null;
}

abstract interface class BookingInstallationIdProvider {
  Future<String> current();
}

final class SecureBookingInstallationIdProvider
    implements BookingInstallationIdProvider {
  SecureBookingInstallationIdProvider(
    this._storage, {
    Uuid? uuid,
    this.environment = BookingIdentityCacheEnvironment.local,
  }) : _uuid = uuid ?? const Uuid();

  final BookingIdentityCacheEnvironment environment;
  String get _key => '${environment.namespace}.installation_id.v1';
  final FlutterSecureStorage _storage;
  final Uuid _uuid;

  @override
  Future<String> current() async {
    final existing = await _storage.read(key: _key);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = _uuid.v4();
    await _storage.write(key: _key, value: created);
    return created;
  }
}

abstract interface class BookingAppCheckTokenProvider {
  Future<String> currentToken({bool forceRefresh = false});
}

final class FunctionsIdentitySessionClient {
  FunctionsIdentitySessionClient({
    required BookingBackendEndpoint endpoint,
    required http.Client client,
    required BookingFirebaseIdTokenProvider tokens,
    required BookingInstallationIdProvider installations,
    required BookingIdentitySessionStore sessions,
    this.timeout = const Duration(seconds: 35),
    BookingAppCheckTokenProvider? appCheck,
    this.observeAppCheck = false,
    String? identityProvider,
  }) : _appCheck = appCheck,
       _identityProvider = identityProvider,
       _endpoint = endpoint,
       _client = client,
       _tokens = tokens,
       _installations = installations,
       _sessions = sessions;

  final bool observeAppCheck;
  final BookingAppCheckTokenProvider? _appCheck;
  final String? _identityProvider;
  final BookingBackendEndpoint _endpoint;
  final http.Client _client;
  final BookingFirebaseIdTokenProvider _tokens;
  final BookingInstallationIdProvider _installations;
  final BookingIdentitySessionStore _sessions;
  final Duration timeout;

  bool isDevGoogleFor(
    BookingIdentitySessionStore store,
    BookingFirebaseIdTokenProvider tokens,
  ) =>
      _endpoint.binding == BookingBackendBinding.devIdentity &&
      _identityProvider == 'google' &&
      _appCheck != null &&
      identical(_sessions, store) &&
      identical(_tokens, tokens);

  Future<BookingIdentitySessionContext> establish({
    required String requestId,
    Future<void> Function(Map<String, Object?> data)? onAuthContext,
  }) async {
    return _sessionCommand(
      callableName: 'establishIdentitySessionV1',
      commandType: 'establishIdentitySession',
      requestId: requestId,
      onAuthContext: onAuthContext,
      body: <String, Object?>{'installationId': await _installations.current()},
    );
  }

  Future<BookingIdentitySessionContext> refresh({
    required String requestId,
    bool requireExistingSession = false,
    bool forceRefreshToken = false,
    Future<void> Function(Map<String, Object?> data)? onAuthContext,
  }) async {
    final current = await _sessions.read();
    if (current == null) {
      if (requireExistingSession) {
        throw const BookingCallableFailure(
          code: 'unauthenticated',
          dispatched: false,
        );
      }
      return establish(requestId: requestId, onAuthContext: onAuthContext);
    }
    try {
      return await _sessionCommand(
        callableName: 'refreshIdentitySessionV1',
        commandType: 'refreshIdentitySession',
        forceRefreshToken: forceRefreshToken,
        requestId: requestId,
        onAuthContext: onAuthContext,
        body: <String, Object?>{'sessionContext': current.toJson()},
      );
    } catch (error) {
      if (_endpoint.binding == BookingBackendBinding.devIdentity) {
        await _sessions.clear();
        rethrow;
      }
      if (error is! BookingCallableFailure) rethrow;
      if (error.code != 'session-revoked' && error.code != 'session-expired') {
        rethrow;
      }
      await _sessions.clear();
      return establish(requestId: const Uuid().v4());
    }
  }

  Future<BookingIdentitySessionContext> readCurrent({
    required String requestId,
    required Future<void> Function(Map<String, Object?> data) onAuthContext,
  }) async {
    final session = await _sessions.read();
    if (_endpoint.binding != BookingBackendBinding.devIdentity ||
        session == null) {
      throw const BookingCallableFailure(
        code: 'unauthenticated',
        dispatched: false,
      );
    }
    return _sessionCommand(
      callableName: 'readIdentitySessionV1',
      commandType: 'readIdentitySession',
      requestId: requestId,
      onAuthContext: onAuthContext,
      body: {'sessionContext': session.toJson()},
    );
  }

  Future<void> revoke({
    required String requestId,
    bool allSessions = false,
  }) async {
    if (_endpoint.binding != BookingBackendBinding.devIdentity ||
        _appCheck == null ||
        !const {'google', 'apple'}.contains(_identityProvider)) {
      throw const BookingCallableFailure(
        code: 'failed-precondition',
        dispatched: false,
      );
    }
    final session = await _sessions.read();
    if (session == null) return;
    final token = await _tokens.currentIdToken(forceRefresh: true);
    if (token == null || token.isEmpty) {
      throw const BookingCallableFailure(
        code: 'unauthenticated',
        dispatched: false,
      );
    }
    final check = await _appCheck.currentToken();
    if (check.trim().isEmpty && !observeAppCheck) {
      throw const BookingCallableFailure(
        code: 'app-check-required',
        dispatched: false,
      );
    }
    final response = await _invokeCallable(
      client: _client,
      endpoint: _endpoint,
      callableName: 'revokeIdentitySessionV1',
      idToken: token,
      timeout: timeout,
      additionalHeaders: {
        if (check.isNotEmpty) 'X-Firebase-AppCheck': check,
        'X-Recharge-Identity-Provider': _identityProvider!,
      },
      data: {
        'schemaVersion': 1,
        'commandType': 'revokeIdentitySession',
        'requestId': requestId,
        'sessionContext': session.toJson(),
        'allSessions': allSessions,
      },
    );
    final data = response['data'];
    if (response['schemaVersion'] != 1 ||
        response['requestId'] != requestId ||
        response['commandType'] != 'revokeIdentitySession' ||
        response['kind'] != 'succeeded' ||
        data is! Map ||
        data['revoked'] != true) {
      throw const BookingCallableFailure(
        code: 'revoke-unconfirmed',
        dispatched: true,
      );
    }
    await _sessions.clear();
  }

  Future<BookingIdentitySessionContext> recover({
    required String requestId,
  }) async {
    await _sessions.clear();
    return _sessionCommand(
      callableName: 'recoverIdentitySessionsV1',
      commandType: 'recoverIdentitySessions',
      requestId: requestId,
      forceRefreshToken: true,
      body: <String, Object?>{'installationId': await _installations.current()},
    );
  }

  Future<BookingIdentitySessionContext> _sessionCommand({
    required String callableName,
    required String commandType,
    required String requestId,
    required Map<String, Object?> body,
    bool forceRefreshToken = false,
    Future<void> Function(Map<String, Object?> data)? onAuthContext,
  }) async {
    final token = await _tokens.currentIdToken(forceRefresh: forceRefreshToken);
    if (token == null || token.isEmpty) {
      throw const BookingCallableFailure(
        code: 'unauthenticated',
        dispatched: false,
      );
    }
    final headers = <String, String>{};
    if (_endpoint.binding == BookingBackendBinding.devIdentity) {
      if (_appCheck == null ||
          !const {'google', 'apple'}.contains(_identityProvider)) {
        throw const BookingCallableFailure(
          code: 'app-check-required',
          dispatched: false,
        );
      }
      final appCheckToken = await _appCheck.currentToken();
      if (appCheckToken.trim().isEmpty && !observeAppCheck) {
        throw const BookingCallableFailure(
          code: 'app-check-required',
          dispatched: false,
        );
      }
      if (appCheckToken.isNotEmpty) {
        headers['X-Firebase-AppCheck'] = appCheckToken;
      }
      headers['X-Recharge-Identity-Provider'] = _identityProvider!;
    }
    final result = await _invokeCallable(
      client: _client,
      endpoint: _endpoint,
      callableName: callableName,
      additionalHeaders: headers,
      data: <String, Object?>{
        'schemaVersion': 1,
        'commandType': commandType,
        'requestId': requestId,
        ...body,
      },
      idToken: token,
      timeout: timeout,
    );
    if (_endpoint.binding == BookingBackendBinding.devIdentity &&
        (result['schemaVersion'] != 1 ||
            result['requestId'] != requestId ||
            result['commandType'] != commandType)) {
      await _sessions.clear();
      throw const FormatException('dev_identity_response_mismatch');
    }
    if (result['kind'] != 'succeeded') {
      final error = result['error'];
      final code = error is Map ? error['code'] : null;
      final details = error is Map ? error['details'] : null;
      final retryAfterSeconds = details is Map
          ? (details['retryAfter'] ?? details['retryAfterSeconds'])
          : null;
      throw BookingCallableFailure(
        code: code is String ? code.replaceAll('_', '-') : 'unauthenticated',
        dispatched: true,
        retryAfter: retryAfterSeconds is num
            ? Duration(seconds: retryAfterSeconds.toInt())
            : null,
      );
    }
    final data = result['data'];
    final rawSession = data is Map ? data['sessionContext'] : null;
    if (rawSession is! Map) {
      throw const FormatException('Identity response has no session context');
    }
    final session = BookingIdentitySessionContext.fromServerResponse(
      Map<String, Object?>.from(rawSession),
    );
    if (_endpoint.binding == BookingBackendBinding.devIdentity) {
      final expires = rawSession['expiresAtUtc'];
      final expiry = expires is String ? DateTime.tryParse(expires) : null;
      final installation = await _installations.current();
      if (expiry == null ||
          !expiry.isUtc ||
          !expiry.isAfter(DateTime.now().toUtc()) ||
          session.installationId != installation) {
        await _sessions.clear();
        throw const FormatException('dev_identity_session_binding_invalid');
      }
    }
    if (onAuthContext != null) {
      if (_endpoint.binding != BookingBackendBinding.devIdentity ||
          data is! Map) {
        throw const FormatException('server_auth_context_binding_invalid');
      }
      await onAuthContext(Map<String, Object?>.from(data));
    }
    await _sessions.saveServerIssued(session);
    return session;
  }
}

final class FunctionsBookingCallablePort implements BookingCallablePort {
  FunctionsBookingCallablePort({
    required BookingBackendEndpoint endpoint,
    required http.Client client,
    required BookingFirebaseIdTokenProvider tokens,
    required BookingIdentitySessionStore sessions,
    FunctionsIdentitySessionClient? identitySessions,
    this.timeout = const Duration(seconds: 35),
  }) : _endpoint = endpoint,
       _client = client,
       _tokens = tokens,
       _sessions = sessions,
       _identitySessions = identitySessions;

  final BookingBackendEndpoint _endpoint;
  final http.Client _client;
  final BookingFirebaseIdTokenProvider _tokens;
  final BookingIdentitySessionStore _sessions;
  final FunctionsIdentitySessionClient? _identitySessions;
  final Duration timeout;

  @override
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> command,
  ) async {
    return _invokeWithSession(callableName, command, allowSessionRepair: true);
  }

  Future<Map<String, Object?>> _invokeWithSession(
    String callableName,
    Map<String, Object?> command, {
    required bool allowSessionRepair,
  }) async {
    var token = await _tokens.currentIdToken();
    final session = await _sessions.read();
    if (token == null || token.isEmpty || session == null) {
      throw const BookingCallableFailure(
        code: 'unauthenticated',
        dispatched: false,
      );
    }
    _rejectTransportAuthority(
      command,
      scenarioContent: callableName == 'scenarioCommandV1',
    );
    final payload = Map<String, Object?>.from(command)
      ..remove('sessionContext')
      ..['sessionContext'] = session.toJson();
    Map<String, Object?> result;
    try {
      result = await _invokeCallable(
        client: _client,
        endpoint: _endpoint,
        callableName: callableName,
        data: payload,
        idToken: token,
        timeout: timeout,
      );
    } on BookingCallableFailure catch (error) {
      if (!allowSessionRepair || error.code != 'unauthenticated') rethrow;
      token = await _tokens.currentIdToken(forceRefresh: true);
      if (token == null || token.isEmpty) rethrow;
      result = await _invokeCallable(
        client: _client,
        endpoint: _endpoint,
        callableName: callableName,
        data: payload,
        idToken: token,
        timeout: timeout,
      );
    }
    final error = result['error'];
    final code = error is Map ? error['code'] : null;
    if (allowSessionRepair &&
        _identitySessions != null &&
        (code == 'session_refresh_required' ||
            code == 'session_revoked' ||
            code == 'session_expired')) {
      await _identitySessions.refresh(requestId: const Uuid().v4());
      final retry = Map<String, Object?>.from(command)
        ..['requestId'] = const Uuid().v4();
      return _invokeWithSession(callableName, retry, allowSessionRepair: false);
    }
    return result;
  }
}

Future<Map<String, Object?>> _invokeCallable({
  required http.Client client,
  required BookingBackendEndpoint endpoint,
  required String callableName,
  required Map<String, Object?> data,
  required String idToken,
  required Duration timeout,
  Map<String, String> additionalHeaders = const {},
}) async {
  late http.StreamedResponse response;
  var dispatched = false;
  try {
    final request = http.Request('POST', endpoint.callableUri(callableName))
      ..headers.addAll(<String, String>{
        ...additionalHeaders,
        HttpHeaders.authorizationHeader: 'Bearer $idToken',
        HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
      })
      ..body = jsonEncode(<String, Object?>{'data': data});
    dispatched = true;
    response = await client.send(request).timeout(timeout);
  } on TimeoutException {
    throw BookingCallableFailure(
      code: 'deadline-exceeded',
      dispatched: dispatched,
    );
  } on SocketException {
    throw BookingCallableFailure(code: 'unavailable', dispatched: dispatched);
  } on http.ClientException {
    throw BookingCallableFailure(code: 'unknown', dispatched: dispatched);
  }

  final bytes = <int>[];
  try {
    await for (final chunk in response.stream.timeout(timeout)) {
      bytes.addAll(chunk);
      if (bytes.length > _maximumCallableResponseBytes) {
        throw const BookingCallableFailure(code: 'internal', dispatched: true);
      }
    }
  } on TimeoutException {
    throw const BookingCallableFailure(
      code: 'deadline-exceeded',
      dispatched: true,
    );
  }
  Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
  } on Object {
    throw const FormatException('Malformed Functions callable response');
  }
  if (decoded is! Map) {
    throw const FormatException('Functions callable response is not an object');
  }
  final envelope = Map<String, Object?>.from(decoded);
  final error = envelope['error'];
  if (error is Map) {
    final status = error['status'];
    throw BookingCallableFailure(
      code: status is String
          ? status.toLowerCase().replaceAll('_', '-')
          : response.statusCode >= 500
          ? 'internal'
          : 'unknown',
      dispatched: true,
    );
  }
  final result = envelope['result'];
  if (response.statusCode < 200 ||
      response.statusCode >= 300 ||
      result is! Map) {
    throw BookingCallableFailure(
      code: response.statusCode >= 500 ? 'internal' : 'unknown',
      dispatched: true,
    );
  }
  return Map<String, Object?>.from(result);
}

void _rejectTransportAuthority(
  Object? value, {
  bool root = true,
  bool scenarioContent = false,
  String path = '',
}) {
  const forbidden = <String>{
    'actorid',
    'userid',
    'publisherid',
    'pageid',
    'creatorid',
    'adminid',
    'capabilities',
    'roles',
    'accesssnapshot',
  };
  if (value is Map) {
    for (final entry in value.entries) {
      final key = entry.key.toString().toLowerCase();
      final childPath = path.isEmpty ? key : '$path.$key';
      final contentCapabilities =
          scenarioContent &&
          childPath == 'draft.scenario.capabilities' &&
          entry.value is Map &&
          (entry.value as Map).entries.every(
            (e) =>
                const {
                  'multiDay',
                  'stay',
                  'plannedTransport',
                  'alternatives',
                  'multiCurrency',
                  'optimizer',
                  'unlistedShare',
                  'publicPublish',
                  'liveLogistics',
                }.contains(e.key) &&
                e.value is bool,
          );
      final snapshotPublisher =
          scenarioContent &&
          childPath == 'draft.scenario.items.[].source.snapshot.publisherid' &&
          (entry.value == null || entry.value is String);
      if ((forbidden.contains(key) &&
              !contentCapabilities &&
              !snapshotPublisher) ||
          (!root && key == 'sessioncontext')) {
        throw const BookingCallableFailure(
          code: 'invalid-argument',
          dispatched: false,
        );
      }
      _rejectTransportAuthority(
        entry.value,
        root: false,
        scenarioContent: scenarioContent,
        path: childPath,
      );
    }
  } else if (value is List) {
    for (final item in value) {
      _rejectTransportAuthority(
        item,
        root: false,
        scenarioContent: scenarioContent,
        path: '$path.[]',
      );
    }
  }
}

const int _maximumCallableResponseBytes = 256 * 1024;

/// Exact persistence boundaries; keys/handles are never migrated on mode switch.
enum BookingIdentityCacheEnvironment {
  local('booking'),
  emulator('booking.emulator.demo-recharge'),
  dev('booking.dev.recharge-dev-n2a01');

  const BookingIdentityCacheEnvironment(this.namespace);
  final String namespace;
}
