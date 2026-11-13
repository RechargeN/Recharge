import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/dev_notifications_bundle.dart';
import 'package:recharge/app/di/dev_push_registrar.dart';
import 'package:recharge/features/auth/data/models/server_auth_context.dart';
import 'package:recharge/features/auth/data/repositories/dev_server_auth_repository.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/notifications/data/remote/notifications_inbox_port.dart';

import '../fixtures/auth/server_auth_packet.dart';

/// N3c (2026-11-13): push registration follows the Session, never blocks
/// auth and sends the token to the server only; preferences carry revisions.
class _Port implements BookingCallablePort {
  final List<(String, Map<String, Object?>)> calls =
      <(String, Map<String, Object?>)>[];
  Map<String, Object?> Function(String, Map<String, Object?>) answer =
      (String _, Map<String, Object?> _) => <String, Object?>{
        'kind': 'succeeded',
        'registered': true,
      };
  Object? failure;

  @override
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> command,
  ) async {
    calls.add((callableName, command));
    final Object? error = failure;
    if (error != null) throw error;
    return answer(callableName, command);
  }
}

class _Messages implements DevPushMessages {
  bool permission = true;
  String? current = 'fcm-token-${'a' * 40}';
  final StreamController<String> refresh = StreamController<String>();
  final StreamController<void> openedTaps = StreamController<void>();
  final StreamController<void> arrivals = StreamController<void>();
  bool launchedFromPush = false;

  @override
  Future<bool> requestPermission() async => permission;
  @override
  Future<String?> token() async => current;
  @override
  Stream<String> get tokenRefresh => refresh.stream;
  @override
  Stream<void> get opened => openedTaps.stream;
  @override
  Future<bool> openedAtLaunch() async => launchedFromPush;
  @override
  Stream<void> get foreground => arrivals.stream;
}

ServerAuthContext _context() => ServerAuthContext.fromResponse(
  packet(),
  installationId: 'dev-install',
  now: now,
);

class _Gateway implements DevAuthSessionGateway {
  final List<String> events = <String>[];
  bool restored = true;

  @override
  Future<ServerAuthContext> signInWithGoogle() async {
    events.add('signIn');
    return _context();
  }

  @override
  Future<ServerAuthContext?> refresh() async {
    events.add('refresh');
    return restored ? _context() : null;
  }

  @override
  Future<ServerAuthContext?> current() async => _context();

  @override
  Future<void> revokeAndSignOut() async => events.add('revoke');

  @override
  Future<void> clearLocal() async => events.add('clear');
}

void main() {
  test(
    'register sends the current token to pushDeviceCommandV1 only',
    () async {
      final port = _Port();
      final messages = _Messages();
      final registrar = DevPushRegistrar(
        port: port,
        messages: messages,
        newRequestId: () => 'req-1',
      );
      expect(await registrar.register(), isTrue);
      expect(port.calls.single.$1, 'pushDeviceCommandV1');
      expect(port.calls.single.$2, <String, Object?>{
        'schemaVersion': 1,
        'requestId': 'req-1',
        'commandType': 'registerPushDevice',
        'payload': <String, Object?>{
          'platform': 'android',
          'token': messages.current,
        },
      });
    },
  );

  test('no consent means no token on the server', () async {
    final port = _Port();
    final registrar = DevPushRegistrar(
      port: port,
      messages: _Messages()..permission = false,
    );
    expect(await registrar.register(), isFalse);
    expect(port.calls.single.$2['commandType'], 'unregisterPushDevice');
  });

  test(
    'a rotated token re-registers while signed in, not after sign-out',
    () async {
      final port = _Port();
      final messages = _Messages();
      final registrar = DevPushRegistrar(port: port, messages: messages);
      await registrar.register();
      messages.refresh.add('fcm-rotated-${'b' * 40}');
      await pumpEventQueue();
      expect(
        (port.calls.last.$2['payload']! as Map<String, Object?>)['token'],
        'fcm-rotated-${'b' * 40}',
      );
      await registrar.unregister();
      final int before = port.calls.length;
      messages.refresh.add('fcm-late-${'c' * 40}');
      await pumpEventQueue();
      expect(port.calls.length, before);
    },
  );

  test('failures never escape: push is a hint', () async {
    final port = _Port()
      ..failure = const BookingCallableFailure(
        code: 'temporarily_unavailable',
        dispatched: true,
      );
    final registrar = DevPushRegistrar(port: port, messages: _Messages());
    expect(await registrar.register(), isFalse);
    await registrar.unregister();
  });

  test('a tap (or a launch from a push) opens the inbox', () async {
    final messages = _Messages()..launchedFromPush = true;
    final registrar = DevPushRegistrar(port: _Port(), messages: messages);
    var opened = 0;
    var announced = 0;
    await registrar.attach(
      openInbox: () => opened++,
      foreground: () => announced++,
    );
    messages.openedTaps.add(null);
    messages.arrivals.add(null);
    await pumpEventQueue();
    expect(opened, 2);
    expect(announced, 1);
  });

  test(
    'the gateway registers after sign-in/restore, unregisters before revoke',
    () async {
      final port = _Port();
      final inner = _Gateway();
      final gateway = PushAwareDevAuthSessionGateway(
        inner: inner,
        registrar: DevPushRegistrar(port: port, messages: _Messages()),
      );
      await gateway.signInWithGoogle();
      await pumpEventQueue();
      expect(port.calls.single.$2['commandType'], 'registerPushDevice');
      inner.restored = false;
      await gateway.refresh();
      await pumpEventQueue();
      expect(port.calls, hasLength(1), reason: 'no Session, no registration');
      await gateway.revokeAndSignOut();
      expect(port.calls.last.$2['commandType'], 'unregisterPushDevice');
      expect(inner.events.last, 'revoke');
    },
  );

  test('preferences: revisioned push switch, server answer only', () async {
    final port = _Port()
      ..answer = (String callable, Map<String, Object?> request) {
        final bool update = request['commandType'] == 'updatePreferences';
        return <String, Object?>{
          'schemaVersion': 1,
          'requestId': request['requestId'],
          'kind': 'succeeded',
          'revision': update ? 1 : 0,
          'policyRevision': 2,
          'channels': <String>['inApp', 'push'],
          'categories': <Object?>[
            <String, Object?>{
              'category': 'booking.changes',
              'inApp': <String, Object?>{'enabled': true, 'locked': true},
              'push': <String, Object?>{'enabled': !update, 'locked': false},
            },
          ],
        };
      };
    final bundle = DevNotificationsBundle(
      port: DevNotificationsPort(port),
      registrar: DevPushRegistrar(port: port, messages: _Messages()),
    );
    final loaded = await bundle.settings.load();
    expect(port.calls.single.$1, 'notificationsQueryV1');
    expect(loaded.categories.single.inAppLocked, isTrue);
    expect(loaded.categories.single.pushEnabled, isTrue);
    final updated = await bundle.settings.update(
      expectedRevision: loaded.revision,
      category: 'booking.changes',
      push: false,
    );
    final (String callable, Map<String, Object?> command) = port.calls.last;
    expect(callable, 'notificationsCommandV1');
    expect(command['payload'], <String, Object?>{
      'expectedRevision': 0,
      'categories': <String, Object?>{
        'booking.changes': <String, Object?>{'push': false},
      },
    });
    expect(updated.revision, 1);
    expect(updated.categories.single.pushEnabled, isFalse);
  });

  test('self-test and refusals map to typed inbox failures', () async {
    final port = _Port()
      ..answer = (String _, Map<String, Object?> _) => <String, Object?>{
        'schemaVersion': 1,
        'kind': 'rejected',
        'code': 'unauthenticated',
      };
    final bundle = DevNotificationsBundle(
      port: DevNotificationsPort(port),
      registrar: DevPushRegistrar(port: port, messages: _Messages()),
    );
    await expectLater(
      bundle.settings.sendTestNotification(),
      throwsA(
        isA<NotificationsInboxFailure>().having(
          (NotificationsInboxFailure f) => f.code,
          'code',
          'unauthenticated',
        ),
      ),
    );
    expect(port.calls.single.$1, 'sendSelfTestNotificationV1');
    port.failure = const BookingCallableFailure(
      code: 'transport_unavailable',
      dispatched: false,
    );
    await expectLater(
      bundle.settings.load(),
      throwsA(isA<NotificationsInboxFailure>()),
    );
  });
}
