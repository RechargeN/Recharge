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
        Uri.parse('http://127.0.0.1:5001'),
      ).enabled,
      isTrue,
    );
    expect(const BookingBackendEndpoint.productionDisabled().enabled, isFalse);
    expect(
      () =>
          BookingBackendEndpoint.devEmulator(Uri.parse('https://example.com')),
      throwsArgumentError,
    );
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
