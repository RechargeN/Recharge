import 'package:flutter/foundation.dart';

import '../../features/booking/data/booking_callable_adapter.dart';
import '../../features/booking/data/booking_transport_runtime.dart';
import '../../features/notifications/data/remote/notifications_inbox_port.dart';
import '../../features/notifications/data/remote/server_notifications_repository.dart';
import '../../features/notifications/domain/entities/notification_item_entity.dart';
import '../../features/notifications/domain/repositories/notifications_repository.dart';
import 'backend_binding_manifest.dart';
import 'booking_backend_selection.dart';
import 'booking_test_entry_guard.dart';

/// Capability id under which the Notifications inbox binding is recorded in a
/// [BackendBindingManifest] (F1).
const String notificationsInboxCapabilityId = 'notifications.inbox';

/// Compile-time switch, separate from the Booking, Publication and Discover
/// ones: `--dart-define=RECHARGE_TEST_NOTIFICATIONS_INBOX=true`.
const bool notificationsInboxTestEntryDefined = bool.fromEnvironment(
  'RECHARGE_TEST_NOTIFICATIONS_INBOX',
);

/// Default-off test entry for the server Notifications inbox (F1). All four
/// conditions must hold at once, and the same check protects every call: the
/// define is `true`, the build is not release, the binding is `testBackend`,
/// and the endpoint is the loopback `demo-recharge/europe-west1` Emulator.
final class NotificationsInboxTestEntryGuard {
  NotificationsInboxTestEntryGuard({
    required this.flag,
    required this.releaseMode,
    required BookingBackendBindingController binding,
  }) : _binding = binding;

  factory NotificationsInboxTestEntryGuard.fromEnvironment(
    BookingBackendBindingController binding,
  ) => NotificationsInboxTestEntryGuard(
    flag: notificationsInboxTestEntryDefined,
    releaseMode: kReleaseMode,
    binding: binding,
  );

  final bool flag;
  final bool releaseMode;
  final BookingBackendBindingController _binding;

  bool get allowed =>
      flag &&
      !releaseMode &&
      _binding.mode == BackendBindingMode.testBackend &&
      isLoopbackDemoEmulatorBinding(_binding);
}

/// The inbox binding manifest: `testBackend` only while the whole test entry is
/// allowed, otherwise the existing local inbox (`localOnly`). A release build
/// never reaches the server inbox.
BackendBindingManifest notificationsBindingManifest(
  NotificationsInboxTestEntryGuard guard,
) => BackendBindingManifest(
  revision: 1,
  bindings: <String, BackendBindingMode>{
    notificationsInboxCapabilityId: guard.allowed
        ? BackendBindingMode.testBackend
        : BackendBindingMode.localOnly,
  },
);

/// Lets Notifications use the authenticated Functions transport without the
/// Notifications feature importing the Booking feature. Every call re-checks
/// the guard, so a binding rolled back to `localOnly` stops reaching the server.
final class BookingPortNotificationsAdapter implements NotificationsInboxPort {
  const BookingPortNotificationsAdapter({
    required Future<BookingTransportRuntime> Function() runtime,
    required NotificationsInboxTestEntryGuard guard,
  }) : _runtime = runtime,
       _guard = guard;

  final Future<BookingTransportRuntime> Function() _runtime;
  final NotificationsInboxTestEntryGuard _guard;

  @override
  Future<Map<String, Object?>> query(Map<String, Object?> request) =>
      _invoke('notificationsQueryV1', request);

  @override
  Future<Map<String, Object?>> command(Map<String, Object?> request) =>
      _invoke('notificationsCommandV1', request);

  Future<Map<String, Object?>> _invoke(
    String callable,
    Map<String, Object?> request,
  ) async {
    if (!_guard.allowed) {
      throw const NotificationsInboxFailure('test_entry_disabled');
    }
    final BookingTransportRuntime runtime = await _runtime();
    final BookingCallablePort? port = runtime.port;
    if (!runtime.remoteCommandsEnabled || port == null) {
      throw const NotificationsInboxFailure('transport_unavailable');
    }
    try {
      return await port.invoke(callable, request);
    } on BookingCallableFailure catch (error) {
      throw NotificationsInboxFailure(error.code);
    }
  }
}

/// A capability bound to `disabled`: every call is a typed refusal.
final class DisabledNotificationsRepository implements NotificationsRepository {
  const DisabledNotificationsRepository();

  @override
  Future<List<NotificationItemEntity>> getNotifications({
    required String userId,
  }) => Future<List<NotificationItemEntity>>.error(
    const NotificationsInboxFailure('notifications_disabled'),
  );

  @override
  Future<void> markNotificationRead({
    required String userId,
    required String notificationId,
  }) => Future<void>.error(
    const NotificationsInboxFailure('notifications_disabled'),
  );
}

/// The inbox for the binding: the server inbox under `testBackend`, the
/// existing local inbox under `localOnly`. The local identity-event sink is
/// registered separately and keeps writing to the local inbox either way.
NotificationsRepository notificationsRepositoryFor({
  required BackendBindingManifest manifest,
  required NotificationsRepository Function() local,
  required NotificationsInboxPort port,
}) => switch (manifest.modeFor(notificationsInboxCapabilityId)) {
  BackendBindingMode.testBackend => ServerNotificationsRepository(port: port),
  BackendBindingMode.localOnly => local(),
  BackendBindingMode.disabled => const DisabledNotificationsRepository(),
};
