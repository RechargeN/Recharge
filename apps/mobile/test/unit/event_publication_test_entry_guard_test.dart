import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/event_publication_composition.dart';
import 'package:recharge/features/create/data/functions_event_publication_gateway.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';

void main() {
  final base = Uri.parse('http://127.0.0.1:5001/demo-recharge/europe-west1');

  EventPublicationTestEntryGuard guard({
    bool flag = true,
    bool release = false,
    BackendBindingMode mode = BackendBindingMode.testBackend,
    Uri? emulatorBase,
  }) => EventPublicationTestEntryGuard(
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
    'the compile-time define is off unless set to true',
    () {
      expect(eventPublicationTestEntryDefined, isFalse);
      expect(
        EventPublicationTestEntryGuard.fromEnvironment(
          BookingBackendBindingController(
            emulatorBase: base,
            releaseMode: false,
            initial: BackendBindingMode.testBackend,
          ),
        ).allowed,
        isFalse,
      );
    },
    skip: eventPublicationTestEntryDefined ? 'run with the define on' : false,
  );

  test('the route redirect refuses unless the guard allows', () {
    expect(eventPublicationTestEntryRedirect(null, fallback: '/x'), '/x');
    expect(
      eventPublicationTestEntryRedirect(guard(flag: false), fallback: '/x'),
      '/x',
    );
    expect(eventPublicationTestEntryRedirect(guard(), fallback: '/x'), isNull);
  });

  test('the Content gateway sends nothing when the gate denies', () async {
    final port = _CountingPort();
    final gateway = FunctionsEventPublicationGateway(
      port: port,
      gate: guard(flag: false),
    );
    await expectLater(gateway.status('content'), throwsStateError);
    await expectLater(
      gateway.createDraft(
        publisherRef: const PublisherRef(type: PublisherType.page, id: 'p'),
        marketId: 'LV',
        body: const <String, Object?>{},
        idempotencyKey: 'key-00000001',
      ),
      throwsStateError,
    );
    expect(port.calls, 0, reason: 'nothing may reach the transport');
  });
}

final class _CountingPort implements ContentCallablePort {
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
