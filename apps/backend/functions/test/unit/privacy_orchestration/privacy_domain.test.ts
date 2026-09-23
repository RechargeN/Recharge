import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createPrivacyDomainTask,
  transitionPrivacyDomainTask,
} from '../../../src/modules/privacy_orchestration/domain/privacy_domain_task.js';
import {
  createPrivacyRequest,
  transitionPrivacyRequest,
} from '../../../src/modules/privacy_orchestration/domain/privacy_request.js';
import { fixtureIds } from '../../support/platform_fixtures.js';

const taskId = '01BX5ZZKBKACTAV9WEVGEMMVS1';
const evidenceId = '01BX5ZZKBKACTAV9WEVGEMMVS2';

void test('request cannot skip verification or complete without all evidence', () => {
  const request = createPrivacyRequest({
    requestId: fixtureIds.first,
    subjectId: fixtureIds.second,
    requestType: 'erasure',
    idempotencyKey: 'privacy-001',
    semanticHash: `sha256:${'a'.repeat(64)}`,
    requiredDomainIds: ['identity'],
    occurredAtUtc: '2026-09-22T10:00:00.000Z',
  });
  assert.throws(
    () =>
      transitionPrivacyRequest({
        request,
        nextStatus: 'completed',
        occurredAtUtc: '2026-09-22T10:01:00.000Z',
      }),
    /transition_invalid/,
  );
  const verified = transitionPrivacyRequest({
    request,
    nextStatus: 'verified',
    occurredAtUtc: '2026-09-22T10:01:00.000Z',
  });
  const dispatched = transitionPrivacyRequest({
    request: verified,
    nextStatus: 'dispatched',
    occurredAtUtc: '2026-09-22T10:02:00.000Z',
  });
  assert.throws(
    () =>
      transitionPrivacyRequest({
        request: dispatched,
        nextStatus: 'completed',
        occurredAtUtc: '2026-09-22T10:03:00.000Z',
      }),
    /terminal_evidence_missing/,
  );
  assert.equal(
    transitionPrivacyRequest({
      request: dispatched,
      nextStatus: 'completed',
      occurredAtUtc: '2026-09-22T10:03:00.000Z',
      terminalEvidenceIds: [evidenceId],
    }).status,
    'completed',
  );
});

void test('domain task retry is revisioned and success requires evidence', () => {
  const pending = createPrivacyDomainTask({
    taskId,
    requestId: fixtureIds.first,
    subjectId: fixtureIds.second,
    domainId: 'identity',
    marketId: null,
    targetRevision: 1,
    occurredAtUtc: '2026-09-22T10:00:00.000Z',
  });
  const dispatched = transitionPrivacyDomainTask({
    task: pending,
    nextStatus: 'dispatched',
    occurredAtUtc: '2026-09-22T10:01:00.000Z',
  });
  assert.equal(dispatched.attempts, 1);
  assert.throws(
    () =>
      transitionPrivacyDomainTask({
        task: dispatched,
        nextStatus: 'succeeded',
        occurredAtUtc: '2026-09-22T10:02:00.000Z',
      }),
    /evidence_missing/,
  );
  assert.equal(
    transitionPrivacyDomainTask({
      task: dispatched,
      nextStatus: 'succeeded',
      evidenceId,
      occurredAtUtc: '2026-09-22T10:02:00.000Z',
    }).status,
    'succeeded',
  );
});
