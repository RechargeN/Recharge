import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/notifications_inbox_composition.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/notifications/data/remote/notifications_inbox_port.dart';
import 'package:recharge/features/notifications/data/remote/server_notifications_repository.dart';
import 'package:recharge/features/notifications/domain/entities/notification_item_entity.dart';
import 'package:recharge/features/notifications/domain/repositories/notifications_repository.dart';

final class _LocalInbox implements NotificationsRepository {
  @override
  Future<List<NotificationItemEntity>> getNotifications({
    required String userId,
  }) async => const <NotificationItemEntity>[];

  @override
  Future<void> markNotificationRead({
    required String userId,
    required String notificationId,
  }) async {}
}

BookingBackendBindingController _binding(BackendBindingMode mode) =>
    BookingBackendBindingController(
      emulatorBase: Uri.parse(
        'http://127.0.0.1:5001/demo-recharge/europe-west1',
      ),
      releaseMode: false,
      initial: mode,
    );

NotificationsInboxTestEntryGuard _guard({
  bool flag = true,
  bool releaseMode = false,
  BackendBindingMode mode = BackendBindingMode.testBackend,
}) => NotificationsInboxTestEntryGuard(
  flag: flag,
  releaseMode: releaseMode,
  binding: _binding(mode),
);

void main() {
  test('the server inbox needs all four guard conditions', () {
    expect(_guard().allowed, isTrue);
    expect(_guard(flag: false).allowed, isFalse);
    expect(_guard(releaseMode: true).allowed, isFalse);
    expect(_guard(mode: BackendBindingMode.localOnly).allowed, isFalse);
    expect(notificationsInboxTestEntryDefined, isFalse, reason: 'default off');
  });

  test(
    'the manifest selects the server inbox only while the entry is allowed',
    () {
      final _LocalInbox local = _LocalInbox();
      NotificationsRepository select(NotificationsInboxTestEntryGuard guard) =>
          notificationsRepositoryFor(
            manifest: notificationsBindingManifest(guard),
            local: () => local,
            port: BookingPortNotificationsAdapter(
              runtime: () => Future<BookingTransportRuntime>.error(
                StateError('no transport in unit tests'),
              ),
              guard: guard,
            ),
          );
      expect(select(_guard()), isA<ServerNotificationsRepository>());
      expect(select(_guard(flag: false)), same(local));
      expect(
        notificationsBindingManifest(
          _guard(releaseMode: true),
        ).modeFor(notificationsInboxCapabilityId),
        BackendBindingMode.localOnly,
      );
    },
  );

  test('a rolled-back guard stops every call before the transport', () async {
    final NotificationsInboxTestEntryGuard guard = _guard(flag: false);
    final BookingPortNotificationsAdapter adapter =
        BookingPortNotificationsAdapter(
          runtime: () => fail('the transport must not be reached'),
          guard: guard,
        );
    await expectLater(
      adapter.query(<String, Object?>{}),
      throwsA(
        isA<NotificationsInboxFailure>().having(
          (NotificationsInboxFailure failure) => failure.code,
          'code',
          'test_entry_disabled',
        ),
      ),
    );
    await expectLater(
      const DisabledNotificationsRepository().getNotifications(userId: 'u'),
      throwsA(isA<NotificationsInboxFailure>()),
    );
  });
}
