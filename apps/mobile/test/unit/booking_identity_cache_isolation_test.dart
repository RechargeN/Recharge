import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/booking/data/booking_functions_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Session handles and installation ids never cross Local, Emulator or dev',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const storage = FlutterSecureStorage();
      final contexts =
          <BookingIdentityCacheEnvironment, BookingIdentitySessionContext>{};
      final ids = <String>{};
      for (final environment in BookingIdentityCacheEnvironment.values) {
        final sessions = SecureBookingIdentitySessionStore(
          storage,
          environment: environment,
        );
        expect(await sessions.read(), isNull);
        final installation = await SecureBookingInstallationIdProvider(
          storage,
          environment: environment,
        ).current();
        expect(ids.add(installation), isTrue);
        final context = BookingIdentitySessionContext(
          sessionId: 'session_${environment.name}',
          sessionHandle: 'A' * 43,
          installationId: installation,
        );
        contexts[environment] = context;
        await sessions.saveServerIssued(context);
      }
      for (final environment in BookingIdentityCacheEnvironment.values) {
        final session = await SecureBookingIdentitySessionStore(
          storage,
          environment: environment,
        ).read();
        expect(session!.sessionId, contexts[environment]!.sessionId);
        expect(
          await SecureBookingInstallationIdProvider(
            storage,
            environment: environment,
          ).current(),
          contexts[environment]!.installationId,
        );
      }
      await const SecureBookingIdentitySessionStore(
        storage,
        environment: BookingIdentityCacheEnvironment.dev,
      ).clear();
      expect(
        await const SecureBookingIdentitySessionStore(
          storage,
          environment: BookingIdentityCacheEnvironment.dev,
        ).read(),
        isNull,
      );
      expect(
        await const SecureBookingIdentitySessionStore(storage).read(),
        isNotNull,
      );
      expect(
        await const SecureBookingIdentitySessionStore(
          storage,
          environment: BookingIdentityCacheEnvironment.emulator,
        ).read(),
        isNotNull,
      );
    },
  );
}
