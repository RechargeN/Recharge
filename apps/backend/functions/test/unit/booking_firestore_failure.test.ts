import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  classifyFirestoreFailure,
  type FirestoreFailureLogRecord,
} from '../../src/shared/firestore_failure.js';

void test('classifies retryable Firestore transport failures exactly', () => {
  const context = { correlationId: 'req_failure_01', operationName: 'test_operation' };
  assert.deepEqual(classifyFirestoreFailure({ code: 10 }, context), {
    kind: 'retryableFailure',
    code: 'contention',
  });
  assert.deepEqual(classifyFirestoreFailure({ code: 'ABORTED' }, context), {
    kind: 'retryableFailure',
    code: 'contention',
  });
  assert.deepEqual(classifyFirestoreFailure({ code: 14 }, context), {
    kind: 'retryableFailure',
    code: 'temporarily_unavailable',
  });
  assert.deepEqual(classifyFirestoreFailure({ code: 'deadline-exceeded' }, context), {
    kind: 'retryableFailure',
    code: 'temporarily_unavailable',
  });
});

void test('unknown failures are non-retryable and emit only safe metadata', () => {
  const records: FirestoreFailureLogRecord[] = [];
  const result = classifyFirestoreFailure(new TypeError('secret payload must not be logged'), {
    correlationId: 'req_failure_02',
    operationName: 'create_internal_booking',
    logger: { error: (record) => records.push(record) },
  });
  assert.deepEqual(result, { kind: 'rejected', code: 'temporarily_unavailable' });
  assert.deepEqual(records, [
    {
      eventName: 'booking.firestore_failure',
      correlationId: 'req_failure_02',
      operationName: 'create_internal_booking',
      safeErrorType: 'TypeError',
      code: 'unexpected_firestore_failure',
    },
  ]);
  assert.equal(JSON.stringify(records).includes('secret payload'), false);
});
