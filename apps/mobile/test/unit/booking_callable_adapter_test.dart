import 'dart:convert';
import 'dart:io';

import 'package:api_contracts/api_contracts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/network/backend_contract.dart';
import 'package:recharge/core/network/backend_clients.dart';
import 'package:recharge/core/network/backend_transport.dart';
import 'package:recharge/core/sync/backend_import.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/booking/data/booking_persistence_store.dart';

void main() {
  const nowText = '2026-09-25T12:00:00.000Z';
  final now = DateTime.parse(nowText);

  BookingCommandDto command([String key = 'idem_booking_001']) =>
      BookingCommandDto(
        schemaVersion: 1,
        commandType: BookingCommandType.createBooking,
        requestId: 'request_booking_001',
        idempotencyKey: key,
        occurredAgainstEventRevision: 7,
        payload: const <String, Object?>{
          'occurrenceId': 'occurrence_001',
          'participantUnits': 1,
        },
      );

  Map<String, Object?> result(
    String kind, {
    String code = 'temporarily_unavailable',
    bool retryable = true,
    int? retryAfterSeconds,
  }) => <String, Object?>{
    'schemaVersion': 1,
    'kind': kind,
    'requestId': 'request_booking_001',
    'correlationId': 'correlation_booking_001',
    'serverTime': nowText,
    if (kind == 'rejected' || kind == 'retryableFailure')
      'error': <String, Object?>{
        'schemaVersion': 1,
        'code': code,
        'retryable': retryable,
        'correlationId': 'correlation_booking_001',
        if (retryAfterSeconds != null)
          'details': <String, Object?>{'retryAfterSeconds': retryAfterSeconds},
      },
    if (kind == 'unsupportedContract')
      'unsupportedPayload': <String, Object?>{'schemaVersion': 99},
  };

  test('maps success, typed failure and unsupported contract', () async {
    for (final entry in <(Map<String, Object?>, Type)>[
      (result('succeeded'), BackendSuccess<BookingResultDto>),
      (
        result('rejected', code: 'not_authorized', retryable: false),
        BackendRejected<BookingResultDto>,
      ),
      (result('retryableFailure'), BackendRejected<BookingResultDto>),
      (result('unsupportedContract'), BackendRejected<BookingResultDto>),
    ]) {
      final adapter = BookingCallableAdapter(
        port: _FakePort(response: entry.$1),
        operations: InMemoryBookingOperationStore(),
        clock: () => now,
      );
      final mapped = await adapter.execute(
        'createInternalBookingV1',
        command('idem_${entry.$1['kind']}'),
        cancellationToken: BackendCancellationToken(),
      );
      expect(mapped.runtimeType, entry.$2);
    }
  });

  test('duplicate success is served from the persistent receipt', () async {
    final port = _CountingPort(result('succeeded'));
    final receipts = InMemoryBackendReceiptStore();
    final adapter = BookingCallableAdapter(
      port: port,
      operations: InMemoryBookingOperationStore(),
      receipts: receipts,
      clock: () => now,
    );
    final bookingCommand = command('idem_duplicate');

    expect(
      await adapter.execute(
        'createInternalBookingV1',
        bookingCommand,
        cancellationToken: BackendCancellationToken(),
      ),
      isA<BackendSuccess<BookingResultDto>>(),
    );
    expect(
      await adapter.execute(
        'createInternalBookingV1',
        bookingCommand,
        cancellationToken: BackendCancellationToken(),
      ),
      isA<BackendSuccess<BookingResultDto>>(),
    );
    expect(port.calls, 1);
  });

  test(
    'timeout after dispatch is unknown while pre-send failure is retryable unavailable',
    () async {
      final afterSend = BookingCallableAdapter(
        port: const _FakePort(
          failure: BookingCallableFailure(
            code: 'deadline-exceeded',
            dispatched: true,
          ),
        ),
        operations: InMemoryBookingOperationStore(),
        clock: () => now,
      );
      expect(
        await afterSend.execute(
          'createInternalBookingV1',
          command(),
          cancellationToken: BackendCancellationToken(),
        ),
        isA<BackendUnknownOutcome<BookingResultDto>>(),
      );
      final beforeSend = BookingCallableAdapter(
        port: const _FakePort(
          failure: BookingCallableFailure(
            code: 'unavailable',
            dispatched: false,
          ),
        ),
        operations: InMemoryBookingOperationStore(),
        clock: () => now,
      );
      final resultBefore = await beforeSend.execute(
        'createInternalBookingV1',
        command('idem_before_send'),
        cancellationToken: BackendCancellationToken(),
      );
      expect(resultBefore, isA<BackendRejected<BookingResultDto>>());
      expect(
        (resultBefore as BackendRejected<BookingResultDto>).failure.retryable,
        isTrue,
      );
    },
  );

  test('all ambiguous post-dispatch failures remain unknown', () async {
    for (final code in const <String>{
      'internal',
      'unknown',
      'aborted',
      'cancelled',
    }) {
      final adapter = BookingCallableAdapter(
        port: _FakePort(
          failure: BookingCallableFailure(code: code, dispatched: true),
        ),
        operations: InMemoryBookingOperationStore(),
        clock: () => now,
      );
      expect(
        await adapter.execute(
          'createInternalBookingV1',
          command('idem_$code'),
          cancellationToken: BackendCancellationToken(),
        ),
        isA<BackendUnknownOutcome<BookingResultDto>>(),
      );
    }
  });

  test(
    'cancellation before send is terminal but after dispatch is unknown',
    () async {
      final beforeToken = BackendCancellationToken()..cancel();
      final beforeStore = InMemoryBookingOperationStore();
      final before = BookingCallableAdapter(
        port: _FakePort(response: result('succeeded')),
        operations: beforeStore,
        clock: () => now,
      );
      expect(
        await before.execute(
          'createInternalBookingV1',
          command('idem_cancel_before'),
          cancellationToken: beforeToken,
        ),
        isA<BackendCancelled<BookingResultDto>>(),
      );
      expect(
        beforeStore.read('idem_cancel_before')?.state,
        BookingOperationState.cancelled,
      );

      final afterToken = BackendCancellationToken();
      final afterStore = InMemoryBookingOperationStore();
      final after = BookingCallableAdapter(
        port: _CancellingPort(afterToken, result('succeeded')),
        operations: afterStore,
        clock: () => now,
      );
      expect(
        await after.execute(
          'createInternalBookingV1',
          command('idem_cancel_after'),
          cancellationToken: afterToken,
        ),
        isA<BackendUnknownOutcome<BookingResultDto>>(),
      );
      expect(
        afterStore.read('idem_cancel_after')?.state,
        BookingOperationState.unknownOutcome,
      );
    },
  );

  test(
    'rate limit preserves retryAfter and reconciliation cadence is fixed',
    () async {
      final adapter = BookingCallableAdapter(
        port: _FakePort(
          response: result(
            'retryableFailure',
            code: 'rate_limited',
            retryAfterSeconds: 10,
          ),
        ),
        operations: InMemoryBookingOperationStore(),
        clock: () => now,
      );
      final mapped = await adapter.execute(
        'createInternalBookingV1',
        command('idem_rate_limited'),
        cancellationToken: BackendCancellationToken(),
      );
      expect(mapped, isA<BackendRejected<BookingResultDto>>());
      expect(
        (mapped as BackendRejected<BookingResultDto>).failure.retryAfter,
        const Duration(seconds: 10),
      );
      expect(BookingCallableAdapter.reconciliationSchedule, const <Duration>[
        Duration.zero,
        Duration(minutes: 1),
        Duration(minutes: 5),
        Duration(minutes: 15),
        Duration(hours: 1),
        Duration(hours: 6),
      ]);
    },
  );

  test(
    'persistent operation survives restart and seven-day retry window fails closed',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'recharge_booking_store_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/booking-state.json');
      final first = FileBookingPersistenceStore(file);
      first.operationStore.write(
        BookingOperationRecord(
          idempotencyKey: 'idem_expired',
          firstAttemptAtUtc: now.subtract(const Duration(days: 8)),
          state: BookingOperationState.unknownOutcome,
        ),
      );
      final restarted = FileBookingPersistenceStore(file);
      final adapter = BookingCallableAdapter(
        port: _FakePort(response: result('succeeded')),
        operations: restarted.operationStore,
        clock: () => now,
      );
      expect(
        await adapter.execute(
          'createInternalBookingV1',
          command('idem_expired'),
          cancellationToken: BackendCancellationToken(),
        ),
        isA<BackendUnknownOutcome<BookingResultDto>>(),
      );
      final expired = restarted.operationStore.read('idem_expired');
      expect(expired?.operationId, 'idem_expired');
      expect(expired?.state, BookingOperationState.expiredUnknownAfter7d);
      expect(expired?.isTerminal, isTrue);
    },
  );

  test('receipt and import checkpoint survive a store restart', () async {
    final directory = await Directory.systemTemp.createTemp(
      'recharge_booking_receipts_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/booking-state.json');
    final first = FileBookingPersistenceStore(file);
    first.receiptStore.write(
      'idem_receipt',
      BackendReceipt(
        operation: 'createInternalBookingV1',
        semanticHash: 'hash',
        response: BackendResponse(statusCode: 200, body: result('succeeded')),
      ),
    );
    first.importStore.write(
      const ImportReceipt(
        localId: 'local-1',
        serverId: 'server-1',
        semanticHash: 'semantic-1',
        serverRevision: 3,
      ),
    );
    final restarted = FileBookingPersistenceStore(file);
    expect(
      restarted.receiptStore.read('idem_receipt')?.operation,
      'createInternalBookingV1',
    );
    expect(restarted.importStore.read('local-1')?.serverId, 'server-1');
  });

  test(
    'persisted unknown outcome reconciles through getMyBooking query',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'recharge_booking_reconcile_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final fixture =
          jsonDecode(
                await File(
                  '../../packages/api_contracts/schema/booking/v1/fixtures/valid.json',
                ).readAsString(),
              )
              as Map<String, dynamic>;
      final booking = Map<String, Object?>.from(
        (fixture['bookings']! as List<dynamic>).first as Map,
      );
      final file = File('${directory.path}/booking-state.json');
      final first = FileBookingPersistenceStore(file, clock: () => now);
      final reconciliation = BookingReconciliationRequest(
        callableName: 'getMyBookingV1',
        query: const <String, Object?>{
          'schemaVersion': 1,
          'queryType': 'getMyBooking',
          'requestId': 'reconcile_request_001',
          'payload': <String, Object?>{
            'bookingId': '01JBOOKING0000000000000001',
          },
        },
      );
      first.operationStore.write(
        BookingOperationRecord(
          idempotencyKey: 'idem_reconcile',
          firstAttemptAtUtc: now,
          state: BookingOperationState.unknownOutcome,
          reconciliationCallableName: reconciliation.callableName,
          reconciliationQuery: reconciliation.query,
        ),
      );
      final restarted = FileBookingPersistenceStore(file, clock: () => now);
      final adapter = BookingCallableAdapter(
        port: _FakePort(
          response: <String, Object?>{
            'schemaVersion': 1,
            'queryType': 'getMyBooking',
            'requestId': 'reconcile_request_001',
            'serverTime': nowText,
            'kind': 'found',
            'booking': booking,
          },
        ),
        operations: restarted.operationStore,
        clock: () => now,
      );

      expect(
        await adapter.reconcileStored('idem_reconcile'),
        isA<BackendSuccess<BookingResultDto>>(),
      );
      expect(
        restarted.operationStore.read('idem_reconcile')?.state,
        BookingOperationState.succeeded,
      );
    },
  );

  test('reconciliation refuses client authority and non-read callables', () {
    expect(
      () => BookingReconciliationRequest(
        callableName: 'createInternalBookingV1',
        query: const <String, Object?>{'queryType': 'createBooking'},
      ),
      throwsArgumentError,
    );
    expect(
      () => BookingReconciliationRequest(
        callableName: 'getMyBookingV1',
        query: const <String, Object?>{
          'queryType': 'getMyBooking',
          'capabilities': <String>['booking.self_service'],
        },
      ),
      throwsArgumentError,
    );
  });

  test('shared Booking fixture remains parseable by Dart DTOs', () async {
    final fixture =
        jsonDecode(
              await File(
                '../../packages/api_contracts/schema/booking/v1/fixtures/valid.json',
              ).readAsString(),
            )
            as Map<String, dynamic>;
    final results = fixture['results']! as List<dynamic>;
    expect(
      results
          .cast<Map<String, dynamic>>()
          .map(
            (value) =>
                BookingResultDto.fromJson(Map<String, Object?>.from(value)),
          )
          .length,
      results.length,
    );
  });

  test('dev binding accepts loopback only and production remains disabled', () {
    expect(
      BookingBackendEndpoint.devEmulator(
        Uri.parse('http://127.0.0.1:5001/demo-recharge/europe-west1'),
      ).enabled,
      isTrue,
    );
    expect(const BookingBackendEndpoint.productionDisabled().enabled, isFalse);
    expect(
      () =>
          BookingBackendEndpoint.devEmulator(Uri.parse('https://example.com')),
      throwsArgumentError,
    );
    expect(const BookingBackendEndpoint.localMock().enabled, isFalse);
  });
}

final class _FakePort implements BookingCallablePort {
  const _FakePort({this.response, this.failure});
  final Map<String, Object?>? response;
  final BookingCallableFailure? failure;

  @override
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> command,
  ) async {
    if (failure case final value?) throw value;
    return response!;
  }
}

final class _CancellingPort implements BookingCallablePort {
  const _CancellingPort(this.token, this.response);

  final BackendCancellationToken token;
  final Map<String, Object?> response;

  @override
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> command,
  ) async {
    token.cancel();
    return response;
  }
}

final class _CountingPort implements BookingCallablePort {
  _CountingPort(this.response);
  final Map<String, Object?> response;
  int calls = 0;

  @override
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> command,
  ) async {
    calls++;
    return response;
  }
}
