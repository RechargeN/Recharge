import 'dart:async';

import '../../features/auth/data/models/server_auth_context.dart';
import '../../features/auth/data/repositories/dev_server_auth_repository.dart';
import '../../features/booking/data/booking_callable_adapter.dart';
import '../../features/notifications/data/remote/notifications_inbox_port.dart';
import '../../features/notifications/data/remote/server_notification_channel_settings_repository.dart';
import '../../features/notifications/domain/repositories/notification_channel_settings_repository.dart';
import 'dev_push_registrar.dart';

/// N3c: the authenticated dev transport for the dev-cloud Notifications
/// codebase (inbox, preferences and the owner's self-test).
final class DevNotificationsPort implements NotificationsInboxPort {
  const DevNotificationsPort(this.port);

  final BookingCallablePort port;

  @override
  Future<Map<String, Object?>> query(Map<String, Object?> request) =>
      _invoke('notificationsQueryV1', request);

  @override
  Future<Map<String, Object?>> command(Map<String, Object?> request) =>
      _invoke('notificationsCommandV1', request);

  Future<Map<String, Object?>> selfTest(Map<String, Object?> request) =>
      _invoke('sendSelfTestNotificationV1', request);

  Future<Map<String, Object?>> _invoke(
    String callable,
    Map<String, Object?> request,
  ) async {
    try {
      return await port.invoke(callable, request);
    } on BookingCallableFailure catch (error) {
      throw NotificationsInboxFailure(error.code);
    }
  }
}

/// Present only with `N3C_DEV_PUSH=true` in the dev flavor.
final class DevNotificationsBundle {
  DevNotificationsBundle({required this.port, required this.registrar})
    : settings = ServerNotificationChannelSettingsRepository(
        port: port,
        selfTest: port.selfTest,
      );

  final DevNotificationsPort port;
  final DevPushRegistrar registrar;
  final NotificationChannelSettingsRepository settings;
}

/// Ties the push registration to the Session lifecycle without touching the
/// Session itself: register after sign-in or restore, unregister before the
/// remote revoke. Registration runs in the background and never fails auth.
final class PushAwareDevAuthSessionGateway implements DevAuthSessionGateway {
  PushAwareDevAuthSessionGateway({
    required DevAuthSessionGateway inner,
    required DevPushRegistrar registrar,
  }) : _inner = inner,
       _registrar = registrar;

  final DevAuthSessionGateway _inner;
  final DevPushRegistrar _registrar;

  @override
  Future<ServerAuthContext> signInWithGoogle() async {
    final ServerAuthContext context = await _inner.signInWithGoogle();
    unawaited(_registrar.register());
    return context;
  }

  @override
  Future<ServerAuthContext?> refresh() async {
    final ServerAuthContext? context = await _inner.refresh();
    if (context != null) unawaited(_registrar.register());
    return context;
  }

  @override
  Future<ServerAuthContext?> current() => _inner.current();

  @override
  Future<void> revokeAndSignOut() async {
    await _registrar.unregister();
    await _inner.revokeAndSignOut();
  }

  @override
  Future<void> clearLocal() => _inner.clearLocal();
}
