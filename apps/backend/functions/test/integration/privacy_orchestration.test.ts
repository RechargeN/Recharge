import assert from 'node:assert/strict';
import test from 'node:test';

import { PrivacyOrchestrationService } from '../../src/modules/privacy_orchestration/application/privacy_orchestration_service.js';
import { InMemoryPrivacyRequestRepository } from '../../src/modules/privacy_orchestration/infrastructure/in_memory_privacy_request_repository.js';
import { InMemoryPrivacyTaskRepository } from '../../src/modules/privacy_orchestration/infrastructure/in_memory_privacy_task_repository.js';
import { fixtureIds } from '../support/platform_fixtures.js';

const ids = {
  taskA: '01BX5ZZKBKACTAV9WEVGEMMVS1',
  taskB: '01BX5ZZKBKACTAV9WEVGEMMVS2',
  evidenceA: '01BX5ZZKBKACTAV9WEVGEMMVS3',
  evidenceB: '01BX5ZZKBKACTAV9WEVGEMMVS4',
} as const;

void test('DSR is idempotent, revisioned and completes only after every domain evidence', async () => {
  const service = new PrivacyOrchestrationService(
    new InMemoryPrivacyRequestRepository(),
    new InMemoryPrivacyTaskRepository(),
  );
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
          { taskId: ids.taskA, domainId: 'booking', marketId: 'LV', targetRevision: 1 },
          { taskId: ids.taskB, domainId: 'identity', marketId: null, targetRevision: 1 },
        ],
        '2026-09-22T10:02:00.000Z',
      )
    ).ok,
    true,
  );
  await service.recordTaskOutcome({
    requestId: fixtureIds.first,
    taskId: ids.taskA,
    expectedTaskRevision: 1,
    nextStatus: 'dispatched',
    occurredAtUtc: '2026-09-22T10:03:00.000Z',
  });
  await service.recordTaskOutcome({
    requestId: fixtureIds.first,
    taskId: ids.taskA,
    expectedTaskRevision: 2,
    nextStatus: 'succeeded',
    evidenceId: ids.evidenceA,
    occurredAtUtc: '2026-09-22T10:04:00.000Z',
  });
  const partial = await service.reconcile(fixtureIds.first, 3, '2026-09-22T10:05:00.000Z');
  assert.equal(partial.ok && partial.request.status, 'partially_completed');
  await service.recordTaskOutcome({
    requestId: fixtureIds.first,
    taskId: ids.taskB,
    expectedTaskRevision: 1,
    nextStatus: 'dispatched',
    occurredAtUtc: '2026-09-22T10:06:00.000Z',
  });
  await service.recordTaskOutcome({
    requestId: fixtureIds.first,
    taskId: ids.taskB,
    expectedTaskRevision: 2,
    nextStatus: 'succeeded',
    evidenceId: ids.evidenceB,
    occurredAtUtc: '2026-09-22T10:07:00.000Z',
  });
  const completed = await service.reconcile(fixtureIds.first, 4, '2026-09-22T10:08:00.000Z');
  assert.equal(completed.ok && completed.request.status, 'completed');
});
