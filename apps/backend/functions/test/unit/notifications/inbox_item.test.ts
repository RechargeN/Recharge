import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  archiveInboxItem,
  createInboxItem,
  markInboxItemRead,
} from '../../../src/modules/notifications/domain/inbox_item.js';

const item = createInboxItem({
  notificationId: 'ntf_0123456789abcdef0123456789abcdef',
  recipientId: 'user-1',
  receiptId: 'nrc_x',
  category: 'booking.receipts',
  templateKey: 'booking.confirmed',
  templateRevision: 1,
  variables: {},
  eventContentId: 'evt-1',
  bookingId: 'booking-1',
  bookingRevision: 1,
  occurredAtUtc: '2026-08-29T11:59:00.000Z',
  createdAtUtc: '2026-08-29T12:00:00.000Z',
});

void test('a new record is unread, typed and retained for the item period', () => {
  assert.equal(item.status, 'unread');
  assert.equal(item.revision, 1);
  assert.deepEqual(item.navigation, {
    routeKind: 'eventDetails',
    objectRef: { type: 'event', id: 'evt-1' },
    routeContractVersion: 1,
  });
  assert.equal(item.expiresAt.toISOString(), '2026-11-27T12:00:00.000Z');
});

void test('read is idempotent and server-timed', () => {
  const read = markInboxItemRead(item, '2026-08-29T13:00:00.000Z');
  assert.equal(read.status, 'read');
  assert.equal(read.readAtUtc, '2026-08-29T13:00:00.000Z');
  assert.equal(read.revision, 2);
  assert.equal(markInboxItemRead(read, '2026-08-29T14:00:00.000Z'), read);
});

void test('archive checks the expected revision and keeps read state', () => {
  assert.deepEqual(archiveInboxItem(item, 2, '2026-08-29T13:00:00.000Z'), {
    kind: 'stale_revision',
    currentRevision: 1,
  });
  const archived = archiveInboxItem(item, 1, '2026-08-29T13:00:00.000Z');
  assert.equal(archived.kind, 'archived');
  if (archived.kind !== 'archived') return;
  assert.equal(archived.item.status, 'archived');
  assert.equal(archived.item.readAtUtc, '2026-08-29T13:00:00.000Z');
  assert.equal(archiveInboxItem(archived.item, 1, '2026-08-29T14:00:00.000Z').kind, 'archived');
});
