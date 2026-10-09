import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  attemptIdFor,
  finishedAttempt,
  isTerminalStatus,
  minimalReceipt,
  notificationDeliveryConfig,
  retryBackoffMs,
  startedAttempt,
  terminalReceiptExpiresAt,
} from '../../../src/modules/notifications/domain/delivery_attempt.js';

void test('a minimal receipt carries no recipient, event, aggregate, payload or reference', () => {
  const receipt = minimalReceipt({
    receiptId: 'nrc_1',
    status: 'erased',
    reason: null,
    terminalAtUtc: '2026-08-29T12:00:00.000Z',
    deliverUntilUtc: '2026-09-05T12:00:00.000Z',
  });
  assert.deepEqual(Object.keys(receipt).sort(), [
    'consumer',
    'consumerVersion',
    'evidence',
    'expiresAt',
    'reason',
    'receiptId',
    'schemaVersion',
    'shape',
    'status',
    'terminalAtUtc',
  ]);
  assert.deepEqual(receipt.evidence, {});
  const serialized = JSON.stringify(receipt);
  for (const leak of ['recipient', 'eventId', 'aggregate', 'payload', 'variables', 'booking'])
    assert.equal(serialized.includes(leak), false, leak);
});

void test('terminal retention never ends before the source outbox record can be gone', () => {
  assert.equal(
    terminalReceiptExpiresAt('2026-08-29T12:00:00.000Z', '2026-09-05T12:00:00.000Z').toISOString(),
    '2026-10-05T12:00:00.000Z',
  );
  assert.equal(
    terminalReceiptExpiresAt('2026-09-10T00:00:00.000Z', '2026-09-05T12:00:00.000Z').toISOString(),
    '2026-10-10T00:00:00.000Z',
  );
  assert.equal(
    terminalReceiptExpiresAt('2026-08-29T12:00:00.000Z', null).toISOString(),
    '2026-09-28T12:00:00.000Z',
  );
});

void test('backoff doubles per attempt and attempts have their own identity and retention', () => {
  assert.deepEqual([1, 2, 3, 4].map(retryBackoffMs), [30_000, 60_000, 120_000, 240_000]);
  assert.equal(attemptIdFor('nrc_1', 3), 'nrc_1_a03');
  const started = startedAttempt({
    receiptId: 'nrc_1',
    attemptNumber: 1,
    leaseId: 'lease',
    startedAtUtc: '2026-08-29T12:00:00.000Z',
  });
  assert.equal(started.status, 'started');
  assert.equal(started.expiresAt.toISOString(), '2026-09-28T12:00:00.000Z');
  const failed = finishedAttempt(started, {
    status: 'failed',
    failureClass: 'transient',
    failureCode: 'store_unavailable',
    finishedAtUtc: '2026-08-29T12:00:01.000Z',
  });
  assert.equal(failed.failureCode, 'store_unavailable');
  assert.equal(failed.leaseId, 'lease');
  assert.equal(notificationDeliveryConfig.maxAttempts, 5);
});

void test('only created, suppressed, expired and erased are terminal', () => {
  assert.deepEqual(
    [
      'claimed',
      'retry_scheduled',
      'dead_lettered',
      'created',
      'suppressed',
      'expired',
      'erased',
    ].map((status) => isTerminalStatus(status as never)),
    [false, false, false, true, true, true, true],
  );
});
