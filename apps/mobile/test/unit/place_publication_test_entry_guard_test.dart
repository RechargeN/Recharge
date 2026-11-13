import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/event_publication_composition.dart';
import 'package:recharge/app/di/media_composition.dart';
import 'package:recharge/app/di/place_publication_composition.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/create/data/functions_event_publication_gateway.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';

/// D3.1 §5.1: the Place test entry is its own default-off switch with the same
/// four conditions as the Event one, and it closes the route, every Content
/// command and every Media upload.
void main() {
  final Uri base = Uri.parse(
    'http://127.0.0.1:5001/demo-recharge/europe-west1',
  );

  PlacePublicationTestEntryGuard guard({
    bool flag = true,
    bool release = false,
    BackendBindingMode mode = BackendBindingMode.testBackend,
    Uri? emulatorBase,
  }) => PlacePublicationTestEntryGuard(
    flag: flag,
    releaseMode: release,
    binding: BookingBackendBindingController(
      emulatorBase: emulatorBase ?? base,
      releaseMode: release,
      initial: mode,
    ),
  );

  test('allowed only when every condition holds at once', () {
    expect(guard().allowed, isTrue);
    expect(guard(flag: false).allowed, isFalse);
    expect(guard(release: true).allowed, isFalse);
    expect(guard(mode: BackendBindingMode.localOnly).allowed, isFalse);
    expect(guard(mode: BackendBindingMode.disabled).allowed, isFalse);
    expect(
      guard(
        emulatorBase: Uri.parse(
          'http://10.0.2.2:5001/demo-recharge/europe-west1',
        ),
      ).allowed,
      isFalse,
    );
    expect(
      guard(
        emulatorBase: Uri.parse(
          'http://127.0.0.1:5001/real-project/europe-west1',
        ),
      ).allowed,
      isFalse,
    );
  });

  test(
    'the compile-time define is off unless set, and separate from the Event one',
    () {
      expect(placePublicationTestEntryDefined, isFalse);
      expect(
        PlacePublicationTestEntryGuard.fromEnvironment(
          BookingBackendBindingController(
            emulatorBase: base,
            releaseMode: false,
            initial: BackendBindingMode.testBackend,
          ),
        ).allowed,
        isFalse,
      );
    },
    skip: placePublicationTestEntryDefined ? 'run with the define on' : false,
  );

  test('the route redirect refuses unless the guard allows', () {
    expect(placePublicationTestEntryRedirect(null, fallback: '/x'), '/x');
    expect(
      placePublicationTestEntryRedirect(guard(flag: false), fallback: '/x'),
      '/x',
    );
    expect(placePublicationTestEntryRedirect(guard(), fallback: '/x'), isNull);
  });

  test('neither Content nor Media is reached when the gate denies', () async {
    final _CountingPort port = _CountingPort();
    final PlacePublicationTestEntryGuard closed = guard(flag: false);
    final FunctionsEventPublicationGateway gateway =
        FunctionsEventPublicationGateway(
          port: BookingPortContentAdapter(port),
          gate: closed,
          typeId: 'place',
        );
    await expectLater(gateway.status('content'), throwsStateError);
    await expectLater(gateway.draft('draft'), throwsStateError);
    await expectLater(
      gateway.createDraft(
        publisherRef: const PublisherRef(type: PublisherType.page, id: 'p'),
        marketId: 'LV',
        body: const <String, Object?>{},
        idempotencyKey: 'key-00000001',
      ),
      throwsStateError,
    );
    final MediaEventCoverUploader uploader = MediaEventCoverUploader(
      mediaUploadGatewayFor(port: port, gate: closed),
    );
    await expectLater(
      uploader.upload(
        intentId: '7dd283c2-0e3c-41e1-b60f-7ed6bb9e0735',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        declaredMediaType: 'image/png',
        publisherRef: const PublisherRef(type: PublisherType.page, id: 'p'),
        contentId: 'content',
      ),
      throwsA(anything),
    );
    expect(port.calls, 0, reason: 'nothing may reach the transport');
  });
}

final class _CountingPort implements BookingCallablePort {
  int calls = 0;

  @override
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> data,
  ) async {
    calls += 1;
    return <String, Object?>{};
  }
}
