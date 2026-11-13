import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:uuid/uuid.dart';

import '../../features/booking/data/booking_callable_adapter.dart';

/// N3c compile-time switch, separate from N2c and N3a.2: FCM push and the
/// server inbox against the dev-cloud Notifications codebase.
/// `--dart-define=N3C_DEV_PUSH=true` (debug dev flavor only).
const bool n3cDevPushDefined = bool.fromEnvironment('N3C_DEV_PUSH');

/// The parts of FCM the registrar uses; a thin seam for tests.
abstract interface class DevPushMessages {
  /// Android 13+ asks the user once; `false` means no consent for push.
  Future<bool> requestPermission();
  Future<String?> token();
  Stream<String> get tokenRefresh;

  /// The user tapped a push while the app was in the background.
  Stream<void> get opened;

  /// The app was started by a tap on a push.
  Future<bool> openedAtLaunch();

  /// A push arrived while the app was in the foreground (not shown by Android).
  Stream<void> get foreground;
}

final class FirebaseDevPushMessages implements DevPushMessages {
  FirebaseDevPushMessages(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Future<bool> requestPermission() async {
    final NotificationSettings settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() => _messaging.getToken();

  @override
  Stream<String> get tokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<void> get opened => FirebaseMessaging.onMessageOpenedApp.map((_) {});

  @override
  Future<bool> openedAtLaunch() async =>
      await _messaging.getInitialMessage() != null;

  @override
  Stream<void> get foreground => FirebaseMessaging.onMessage.map((_) {});
}

/// Keeps the server registration of this installation's FCM token in step
/// with the Session: register after sign-in or restore (and on rotation),
/// unregister before sign-out. The token goes to the server only; it is never
/// stored, logged or shown here. Every failure is swallowed: push is a hint
/// and never blocks authentication.
final class DevPushRegistrar {
  DevPushRegistrar({
    required BookingCallablePort port,
    required DevPushMessages messages,
    String Function()? newRequestId,
  }) : _port = port,
       _messages = messages,
       _newRequestId = newRequestId ?? const Uuid().v4;

  static const String callable = 'pushDeviceCommandV1';
  static const Duration _unregisterTimeout = Duration(seconds: 8);

  final BookingCallablePort _port;
  final DevPushMessages _messages;
  final String Function() _newRequestId;
  StreamSubscription<String>? _rotation;
  bool _signedIn = false;

  /// After sign-in or a restored Session. Returns whether a token is registered.
  Future<bool> register() async {
    _signedIn = true;
    _rotation ??= _messages.tokenRefresh.listen((String token) {
      if (_signedIn) unawaited(_register(token));
    });
    try {
      if (!await _messages.requestPermission()) {
        // No consent: the server keeps no token for this installation.
        await _unregister();
        return false;
      }
      final String? token = await _messages.token();
      if (token == null || token.isEmpty) return false;
      return await _register(token);
    } on Object {
      return false;
    }
  }

  /// Before the Session is revoked (the server also ends it with the Session).
  Future<void> unregister() async {
    _signedIn = false;
    await _unregister();
  }

  /// A tap on a push opens the inbox; a push in the foreground is announced.
  Future<void> attach({
    required void Function() openInbox,
    required void Function() foreground,
  }) async {
    _messages.opened.listen((_) => openInbox());
    _messages.foreground.listen((_) => foreground());
    try {
      if (await _messages.openedAtLaunch()) openInbox();
    } on Object {
      // No launch message: nothing to open.
    }
  }

  Future<bool> _register(String token) async {
    try {
      final Map<String, Object?> answer = await _port.invoke(
        callable,
        <String, Object?>{
          'schemaVersion': 1,
          'requestId': _newRequestId(),
          'commandType': 'registerPushDevice',
          'payload': <String, Object?>{'platform': 'android', 'token': token},
        },
      );
      return answer['kind'] == 'succeeded' && answer['registered'] == true;
    } on Object {
      return false;
    }
  }

  Future<void> _unregister() async {
    try {
      await _port
          .invoke(callable, <String, Object?>{
            'schemaVersion': 1,
            'requestId': _newRequestId(),
            'commandType': 'unregisterPushDevice',
            'payload': const <String, Object?>{},
          })
          .timeout(_unregisterTimeout);
    } on Object {
      // The server also stops pushing once the Session ends.
    }
  }
}
