import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/dev_content_media_port.dart';
import 'package:recharge/app/di/place_publication_composition.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';

/// N3a.2: the dev-cloud Place draft path. Its own define, debug only, the dev
/// auth bundle's port; the dev endpoint serves the five Content/Media calls
/// and nothing of Booking.
final class _NoPort implements BookingCallablePort {
  @override
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> command,
  ) => throw StateError('not called');
}

void main() {
  final BookingBackendBindingController localOnly =
      BookingBackendBindingController(
        emulatorBase: Uri.parse(
          'http://127.0.0.1:5001/demo-recharge/europe-west1',
        ),
        releaseMode: false,
        initial: BackendBindingMode.localOnly,
      );

  PlacePublicationTestEntryGuard guard({
    bool devFlag = true,
    bool release = false,
    bool withPort = true,
  }) => PlacePublicationTestEntryGuard(
    flag: false,
    releaseMode: release,
    binding: localOnly,
    devFlag: devFlag,
    devPort: withPort ? DevContentMediaPort(_NoPort()) : null,
  );

  test(
    'dev-cloud Place draft: define, debug build and the dev port at once',
    () {
      expect(guard().allowed, isTrue);
      expect(guard().devCloudAllowed, isTrue);
      expect(guard(devFlag: false).allowed, isFalse);
      expect(guard(release: true).allowed, isFalse);
      expect(guard(withPort: false).allowed, isFalse);
    },
  );

  test('the Emulator test entry is unchanged by the dev path', () {
    final PlacePublicationTestEntryGuard emulatorOnly =
        PlacePublicationTestEntryGuard(
          flag: true,
          releaseMode: false,
          binding: localOnly,
        );
    expect(emulatorOnly.allowed, isFalse);
    expect(emulatorOnly.devCloudAllowed, isFalse);
  });

  test(
    'dev endpoint: Content/Media calls allowed, Booking still forbidden',
    () {
      final BookingBackendEndpoint endpoint =
          BookingBackendEndpoint.devIdentity(
            Uri.parse(
              'https://europe-west1-recharge-dev-n2a01.cloudfunctions.net',
            ),
          );
      for (final String name in <String>[
        'contentCommandV1',
        'contentQueryV1',
        'mediaCommandV1',
        'mediaQueryV1',
        'uploadMediaBytesV1',
        'establishIdentitySessionV1',
      ]) {
        expect(
          endpoint.callableUri(name).toString(),
          'https://europe-west1-recharge-dev-n2a01.cloudfunctions.net/$name',
        );
      }
      for (final String name in <String>[
        'createInternalBookingV1',
        'getMyBookingV1',
        'mediaDeliveryV1',
        'moderationCommandV1',
      ]) {
        expect(() => endpoint.callableUri(name), throwsArgumentError);
      }
    },
  );
}
