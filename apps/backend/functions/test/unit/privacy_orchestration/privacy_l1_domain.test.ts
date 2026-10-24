import assert from 'node:assert/strict';
import test from 'node:test';

import { reconcilePrivacyRequest } from '../../../src/modules/privacy_orchestration/application/reconcile_privacy_request.js';
import {
  createPrivacyDomainTask,
  leasePrivacyDomainTask,
  releasePrivacyDomainTaskLease,
  transitionPrivacyDomainTask,
} from '../../../src/modules/privacy_orchestration/domain/privacy_domain_task.js';
import {
  changePrivacyLegalHold,
  placePrivacyLegalHold,
  privacyHoldApplies,
  releasePrivacyLegalHold,
} from '../../../src/modules/privacy_orchestration/domain/privacy_legal_hold.js';
import {
  createPrivacyRequest,
  transitionPrivacyRequest,
} from '../../../src/modules/privacy_orchestration/domain/privacy_request.js';
import { fixtureIds } from '../../support/platform_fixtures.js';

const evidenceId = '01BX5ZZKBKACTAV9WEVGEMMVS2';

function dispatchedTask(domainId: string, taskId = '01BX5ZZKBKACTAV9WEVGEMMVS1') {
  return transitionPrivacyDomainTask({
    task: createPrivacyDomainTask({
      taskId,
      requestId: fixtureIds.first,
      subjectId: fixtureIds.second,
      domainId,
      marketId: 'LV',
      targetRevision: 1,
      occurredAtUtc: '2026-10-24T10:00:00.000Z',
    }),
    nextStatus: 'dispatched',
    occurredAtUtc: '2026-10-24T10:00:00.000Z',
  });
}

void test('blocked is visible, needs named blockers and can be continued', () => {
  const task = dispatchedTask('content');
  assert.throws(
    () =>
      transitionPrivacyDomainTask({
        task,
        nextStatus: 'blocked',
        occurredAtUtc: '2026-10-24T10:01:00.000Z',
      }),
    /blocked_codes_invalid/,
  );
  assert.throws(
    () =>
      transitionPrivacyDomainTask({
        task,
        nextStatus: 'succeeded',
        evidenceId,
        blockedCodes: ['PB-02'],
        occurredAtUtc: '2026-10-24T10:01:00.000Z',
      }),
    /blocked_codes_invalid/,
  );
  const blocked = transitionPrivacyDomainTask({
    task,
    nextStatus: 'blocked',
    blockedCodes: ['PB-18', 'PB-02', 'PB-18'],
    occurredAtUtc: '2026-10-24T10:01:00.000Z',
  });
  assert.deepEqual(blocked.blockedCodes, ['PB-02', 'PB-18']);
  // A later policy decision can continue the same task.
  const resumed = leasePrivacyDomainTask({
    task: blocked,
    leaseOwner: 'runner:a',
    nowUtc: '2026-10-24T11:00:00.000Z',
    leaseSeconds: 60,
    policyRevision: 'p2',
  });
  assert.equal(resumed.status, 'dispatched');
  assert.deepEqual(resumed.blockedCodes, []);
});

void test('a live lease is exclusive, an expired one is taken over and fences by revision', () => {
  const task = dispatchedTask('route');
  const leased = leasePrivacyDomainTask({
    task,
    leaseOwner: 'runner:a',
    nowUtc: '2026-10-24T10:00:00.000Z',
    leaseSeconds: 60,
    policyRevision: 'p1',
  });
  assert.equal(leased.revision, task.revision + 1);
  assert.equal(leased.attempts, task.attempts);
  assert.throws(
    () =>
      leasePrivacyDomainTask({
        task: leased,
        leaseOwner: 'runner:b',
        nowUtc: '2026-10-24T10:00:30.000Z',
        leaseSeconds: 60,
        policyRevision: 'p1',
      }),
    /lease_held/,
  );
  const takenOver = leasePrivacyDomainTask({
    task: leased,
    leaseOwner: 'runner:b',
    nowUtc: '2026-10-24T10:01:01.000Z',
    leaseSeconds: 60,
    policyRevision: 'p1',
  });
  assert.equal(takenOver.leaseOwner, 'runner:b');
  const released = releasePrivacyDomainTaskLease({
    task: takenOver,
    nowUtc: '2026-10-24T10:01:02.000Z',
  });
  assert.equal(released.leaseOwner, null);
  assert.equal(released.status, 'dispatched');
});

void test('a request with a blocked task is partial and never completed', () => {
  const request = transitionPrivacyRequest({
    request: transitionPrivacyRequest({
      request: createPrivacyRequest({
        requestId: fixtureIds.first,
        subjectId: fixtureIds.second,
        requestType: 'erasure',
        idempotencyKey: 'privacy-l1-001',
        semanticHash: `sha256:${'a'.repeat(64)}`,
        requiredDomainIds: ['content', 'library'],
        occurredAtUtc: '2026-10-24T10:00:00.000Z',
      }),
      nextStatus: 'verified',
      occurredAtUtc: '2026-10-24T10:00:00.000Z',
    }),
    nextStatus: 'dispatched',
    occurredAtUtc: '2026-10-24T10:00:00.000Z',
  });
  const library = transitionPrivacyDomainTask({
    task: dispatchedTask('library', '01BX5ZZKBKACTAV9WEVGEMMVS3'),
    nextStatus: 'succeeded',
    evidenceId,
    occurredAtUtc: '2026-10-24T10:02:00.000Z',
  });
  const content = transitionPrivacyDomainTask({
    task: dispatchedTask('content'),
    nextStatus: 'blocked',
    blockedCodes: ['PB-18'],
    occurredAtUtc: '2026-10-24T10:02:00.000Z',
  });
  const partial = reconcilePrivacyRequest(request, [content, library], '2026-10-24T10:03:00.000Z');
  assert.equal(partial.status, 'partially_completed');
  // Still dispatched work is not reported as partial or complete.
  assert.equal(
    reconcilePrivacyRequest(
      request,
      [dispatchedTask('content'), library],
      '2026-10-24T10:03:00.000Z',
    ).status,
    'dispatched',
  );
  const failed = transitionPrivacyDomainTask({
    task: dispatchedTask('library', '01BX5ZZKBKACTAV9WEVGEMMVS3'),
    nextStatus: 'failed',
    occurredAtUtc: '2026-10-24T10:02:00.000Z',
  });
  assert.equal(
    reconcilePrivacyRequest(partial, [content, failed], '2026-10-24T10:04:00.000Z').status,
    'failed',
  );
});

void test('a hold has an exact scope, a future review, a revision and never widens on its own', () => {
  const place = (scope: { domainId: string; collection: string; recordId: string | null }) =>
    placePrivacyLegalHold({
      holdId: fixtureIds.first,
      subjectId: fixtureIds.second,
      scope,
      basisRef: 'case-1',
      reviewAtUtc: '2026-12-01T00:00:00.000Z',
      placedBy: 'officer',
      nowUtc: '2026-10-24T10:00:00.000Z',
    });
  assert.throws(
    () => place({ domainId: '*', collection: 'quickPlans', recordId: null }),
    /scope_invalid/,
  );
  assert.throws(
    () => place({ domainId: 'route', collection: '*', recordId: 'x' }),
    /scope_invalid/,
  );
  assert.throws(
    () =>
      placePrivacyLegalHold({
        holdId: fixtureIds.first,
        subjectId: fixtureIds.second,
        scope: { domainId: 'route', collection: 'routes', recordId: null },
        basisRef: 'case-1',
        reviewAtUtc: '2026-10-01T00:00:00.000Z',
        placedBy: 'officer',
        nowUtc: '2026-10-24T10:00:00.000Z',
      }),
    /review_invalid/,
  );
  const hold = place({ domainId: 'route', collection: 'routes', recordId: 'r1' });
  assert.equal(
    privacyHoldApplies(hold, { domainId: 'route', collection: 'routes', recordId: 'r1' }),
    true,
  );
  assert.equal(
    privacyHoldApplies(hold, { domainId: 'route', collection: 'routes', recordId: 'r2' }),
    false,
  );
  assert.equal(
    privacyHoldApplies(hold, { domainId: 'scenario', collection: 'routes', recordId: 'r1' }),
    false,
  );
  const changed = changePrivacyLegalHold({
    hold,
    scope: { domainId: 'route', collection: '*', recordId: null },
    nowUtc: '2026-10-24T11:00:00.000Z',
  });
  assert.equal(changed.revision, 2);
  const released = releasePrivacyLegalHold({ hold: changed, nowUtc: '2026-10-24T12:00:00.000Z' });
  assert.equal(released.status, 'released');
  assert.equal(
    privacyHoldApplies(released, { domainId: 'route', collection: 'routes', recordId: 'r1' }),
    false,
  );
  assert.throws(
    () => releasePrivacyLegalHold({ hold: released, nowUtc: '2026-10-24T13:00:00.000Z' }),
    /not_active/,
  );
});
