import assert from 'node:assert/strict';
import test from 'node:test';

import type { Firestore } from 'firebase-admin/firestore';

import {
  admitRestoredCopy,
  PrivacyRunnerRedeletion,
} from '../../../src/modules/operations/restore_admission.js';

// The real re-deletion runs; only the database below it fails. What is pinned is
// the classification of a given failure, not that a PITR clone produces it.
const now = '2026-11-22T10:00:00.000Z';
const clock = { now: () => new Date(now) };
const restoring = Object.assign(new Error('9 FAILED_PRECONDITION'), {
  code: 9,
  details: 'Cannot serve requests when the database is undergoing a restore.',
});
const otherPrecondition = Object.assign(new Error('9 FAILED_PRECONDITION'), {
  code: 9,
  details: 'The query requires an index.',
});

function admitWith(failures: readonly Error[]) {
  let call = 0;
  const restored = {
    databaseId: 'isolated-copy',
    runTransaction: () => Promise.reject(failures[call++]!),
  } as unknown as Firestore;
  return admitRestoredCopy({
    restored,
    liveDatabaseId: '(default)',
    restoreStartedAtUtc: now,
    authority: {
      snapshot: () =>
        Promise.resolve({
          asOfUtc: now,
          decisions: failures.map((_, index) => ({
            requestId: `00000000-0000-4000-8000-00000000000${index}`,
            subjectId: `00000000-0000-4000-9000-00000000000${index}`,
            requestType: 'erasure' as const,
          })),
        }),
    },
    redeletion: new PrivacyRunnerRedeletion(restored, clock, ['notifications']),
    clock,
  });
}

void test('a copy refusing every re-deletion while restoring stays closed as restore_in_progress', async () => {
  assert.deepEqual(await admitWith([restoring, restoring]), {
    state: 'closed',
    reason: 'restore_in_progress',
    decisions: 2,
    failed: 2,
  });
});

void test('one unrelated failure keeps the copy closed as redeletion_failed', async () => {
  assert.deepEqual(await admitWith([restoring, otherPrecondition]), {
    state: 'closed',
    reason: 'redeletion_failed',
    decisions: 2,
    failed: 2,
  });
});
