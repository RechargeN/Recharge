import assert from 'node:assert/strict';
import test from 'node:test';

import { PrivacyOrchestrationService } from '../../src/modules/privacy_orchestration/application/privacy_orchestration_service.js';
import { privacyDomainTaskId } from '../../src/modules/privacy_orchestration/application/dispatch_privacy_tasks.js';
import {
  createPrivacyRequest,
  transitionPrivacyRequest,
} from '../../src/modules/privacy_orchestration/domain/privacy_request.js';
import { InMemoryPrivacyOrchestrationRepository } from '../../src/modules/privacy_orchestration/infrastructure/in_memory_privacy_orchestration_repository.js';
import { fixtureIds } from '../support/platform_fixtures.js';

const ids = {
  evidenceA: '01BX5ZZKBKACTAV9WEVGEMMVS3',
  evidenceB: '01BX5ZZKBKACTAV9WEVGEMMVS4',
} as const;

void test('DSR is idempotent, revisioned and completes only after every domain evidence', async () => {
  const repository = new InMemoryPrivacyOrchestrationRepository();
  const service = new PrivacyOrchestrationService(repository, repository, repository);
  const submit = {
    requestId: fixtureIds.first,
    subjectId: fixtureIds.second,
    requestType: 'erasure' as const,
    idempotencyKey: 'privacy-001',
    semanticHash: `sha256:${'a'.repeat(64)}`,
    requiredDomainIds: ['booking', 'identity'],
    occurredAtUtc: '2026-09-22T10:00:00.000Z',
  };
  assert.equal((await service.submit(submit)).ok, true);
  assert.equal((await service.submit({ ...submit, requestId: fixtureIds.third })).ok, true);
  assert.deepEqual(
    await service.submit({
      ...submit,
      requestId: fixtureIds.third,
      semanticHash: `sha256:${'b'.repeat(64)}`,
    }),
    { ok: false, code: 'idempotency_conflict' },
  );
  assert.equal((await service.verify(fixtureIds.first, 1, '2026-09-22T10:01:00.000Z')).ok, true);
  assert.equal(
    (
      await service.dispatch(
        fixtureIds.first,
        2,
        [
          { domainId: 'booking', marketId: 'LV', targetRevision: 1 },
          { domainId: 'identity', marketId: null, targetRevision: 1 },
        ],
        '2026-09-22T10:02:00.000Z',
      )
    ).ok,
    true,
  );
  await service.recordTaskOutcome({
    requestId: fixtureIds.first,
    taskId: privacyDomainTaskId(fixtureIds.first, 'booking', 'LV', 1),
    expectedTaskRevision: 1,
    nextStatus: 'dispatched',
    occurredAtUtc: '2026-09-22T10:03:00.000Z',
  });
  await service.recordTaskOutcome({
    requestId: fixtureIds.first,
    taskId: privacyDomainTaskId(fixtureIds.first, 'booking', 'LV', 1),
    expectedTaskRevision: 2,
    nextStatus: 'succeeded',
    evidenceId: ids.evidenceA,
    occurredAtUtc: '2026-09-22T10:04:00.000Z',
  });
  const pending = await service.reconcile(fixtureIds.first, 3, '2026-09-22T10:05:00.000Z');
  assert.equal(pending.ok && pending.request.status, 'dispatched');
  await service.recordTaskOutcome({
    requestId: fixtureIds.first,
    taskId: privacyDomainTaskId(fixtureIds.first, 'identity', null, 1),
    expectedTaskRevision: 1,
    nextStatus: 'dispatched',
    occurredAtUtc: '2026-09-22T10:06:00.000Z',
  });
  await service.recordTaskOutcome({
    requestId: fixtureIds.first,
    taskId: privacyDomainTaskId(fixtureIds.first, 'identity', null, 1),
    expectedTaskRevision: 2,
    nextStatus: 'succeeded',
    evidenceId: ids.evidenceB,
    occurredAtUtc: '2026-09-22T10:07:00.000Z',
  });
  const completed = await service.reconcile(fixtureIds.first, 3, '2026-09-22T10:08:00.000Z');
  assert.equal(completed.ok && completed.request.status, 'completed');
});

void test('request fails only after every domain task is terminal and duplicate dispatch is rejected', async () => {
  const repository = new InMemoryPrivacyOrchestrationRepository();
  const service = new PrivacyOrchestrationService(repository, repository, repository);
  const input = {
    requestId: fixtureIds.third,
    subjectId: fixtureIds.second,
    requestType: 'restriction' as const,
    idempotencyKey: 'privacy-failure-001',
    semanticHash: `sha256:${'c'.repeat(64)}`,
    requiredDomainIds: ['booking', 'identity'],
    occurredAtUtc: '2026-09-22T11:00:00.000Z',
  };
  await service.submit(input);
  await service.verify(fixtureIds.third, 1, '2026-09-22T11:01:00.000Z');
  const seeds = [
    { domainId: 'booking', marketId: 'LV' as const, targetRevision: 1 },
    { domainId: 'identity', marketId: null, targetRevision: 1 },
  ];
  assert.equal(
    (await service.dispatch(fixtureIds.third, 2, seeds, '2026-09-22T11:02:00.000Z')).ok,
    true,
  );
  assert.deepEqual(await service.dispatch(fixtureIds.third, 2, seeds, '2026-09-22T11:02:00.000Z'), {
    ok: false,
    code: 'revision_conflict',
  });
  for (const seed of seeds) {
    const taskId = privacyDomainTaskId(
      fixtureIds.third,
      seed.domainId,
      seed.marketId,
      seed.targetRevision,
    );
    await service.recordTaskOutcome({
      requestId: fixtureIds.third,
      taskId,
      expectedTaskRevision: 1,
      nextStatus: 'dispatched',
      occurredAtUtc: '2026-09-22T11:03:00.000Z',
    });
    await service.recordTaskOutcome({
      requestId: fixtureIds.third,
      taskId,
      expectedTaskRevision: 2,
      nextStatus: 'failed',
      occurredAtUtc: '2026-09-22T11:04:00.000Z',
    });
  }
  const failed = await service.reconcile(fixtureIds.third, 3, '2026-09-22T11:05:00.000Z');
  assert.equal(failed.ok && failed.request.status, 'failed');
});

void test('legal-hold release creates one linked idempotent erasure follow-up', async () => {
  const repository = new InMemoryPrivacyOrchestrationRepository();
  const service = new PrivacyOrchestrationService(repository, repository, repository);
  const original = createCompletedWithRetentionRequest();
  await repository.create(original);

  const input = {
    originalRequestId: original.requestId,
    requestId: fixtureIds.third,
    subjectId: original.subjectId,
    holdReleaseRevision: 2,
    semanticHash: `sha256:${'d'.repeat(64)}`,
    requiredDomainIds: ['booking'],
    occurredAtUtc: '2026-09-22T12:00:00.000Z',
  } as const;
  const first = await service.submitLegalHoldReleaseFollowUp(input);
  const replay = await service.submitLegalHoldReleaseFollowUp({
    ...input,
    requestId: '01BX5ZZKBKACTAV9WEVGEMMVS5',
  });
  assert.equal(first.ok && first.request.followUpOfRequestId, original.requestId);
  assert.equal(replay.ok && replay.request.requestId, fixtureIds.third);
});

function createCompletedWithRetentionRequest() {
  const submitted = createPrivacyRequest({
    requestId: fixtureIds.first,
    subjectId: fixtureIds.second,
    requestType: 'erasure',
    idempotencyKey: 'privacy-held-001',
    semanticHash: `sha256:${'e'.repeat(64)}`,
    requiredDomainIds: ['booking'],
    occurredAtUtc: '2026-09-22T10:00:00.000Z',
  });
  const verified = transitionPrivacyRequest({
    request: submitted,
    nextStatus: 'verified',
    occurredAtUtc: '2026-09-22T10:01:00.000Z',
  });
  const dispatched = transitionPrivacyRequest({
    request: verified,
    nextStatus: 'dispatched',
    occurredAtUtc: '2026-09-22T10:02:00.000Z',
  });
  return transitionPrivacyRequest({
    request: dispatched,
    nextStatus: 'completedWithRetention',
    occurredAtUtc: '2026-09-22T10:05:00.000Z',
    terminalEvidenceIds: [ids.evidenceA],
  });
}
