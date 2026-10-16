import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { before, after, test } from 'node:test';
import { createK1, handleK1 } from '../../src/moderation_entry.js';
import { ModerationService } from '../../src/modules/moderation/application/moderation_service.js';
import {
  FirestoreModerationRepository,
  moderationCollections,
} from '../../src/modules/moderation/infrastructure/firestore_moderation_repository.js';
import { k1Collections } from '../../src/modules/moderation/application/k1_workflows.js';
import { emulatorFirestore, createFirebaseActor } from '../support/booking_emulator.js';
import { cleanupContentEmulatorState } from '../support/content_emulator_cleanup.js';
import { createPublishingActors, type PublishingActor } from '../support/content_event_world.js';
import { createStandModeration, submitEventForReview } from '../stand/stand_moderation.js';
import { setLocalFlag } from '../support/notifications_world.js';

const db = emulatorFirestore(),
  clock = { now: () => new Date() };
const k1 = createK1(db, clock),
  stand = createStandModeration(db);
let actors: Awaited<ReturnType<typeof createPublishingActors>>;
let submitted: Awaited<ReturnType<typeof submitEventForReview>>;
const actions = [
  'queue',
  'approve',
  'reject',
  'restrict',
  'withdraw',
  'restore',
  'requestRemoderation',
  'reviewRemoderation',
  'triage',
];
const hint = (p: PublishingActor) => ({
  firebaseUid: p.firebaseUid,
  sessionId: p.actor.sessionId,
  sessionHandle: p.sessionHandle,
  installationId: p.installationId,
});
async function grant(typeId = 'event') {
  const now = new Date();
  await k1.staff.grantScoped(
    actors.staff.actor.userId,
    [{ marketId: 'LV', typeId, actions }],
    new Date(now.getTime() + 3600000).toISOString(),
    now.toISOString(),
  );
}
async function pointer() {
  const p = await stand.contentRepository.transact((tx) => tx.pointer(submitted.contentId));
  assert.ok(p);
  return p;
}
const command = (action: string, revision: number, extra: Record<string, unknown> = {}) => ({
  schemaVersion: 1,
  action,
  idempotencyKey: randomUUID(),
  reason: 'Synthetic operator review',
  target: { contentId: submitted.contentId, expectedRevision: revision },
  ...extra,
});
before(async () => {
  await cleanupContentEmulatorState(db, Object.values(k1Collections));
  await setLocalFlag(db, 'moderation.staff', true);
  await setLocalFlag(db, 'trustSafety.reports', true);
  actors = await createPublishingActors(db, 'k1-' + randomUUID());
  await grant();
  submitted = await submitEventForReview(stand, actors.creator.actor, {
    type: 'page',
    id: actors.pageId,
  });
});
// Published Content and moderation state must not leak into later groups.
after(() => cleanupContentEmulatorState(db, Object.values(k1Collections)));

void test('scoped queues deny non-staff, foreign type/market, expired grants and legacy broad grants', async () => {
  assert.equal(
    (await k1.moderation.queue(actors.creator.actor, 50, { marketId: 'LV', typeId: 'event' })).kind,
    'rejected',
  );
  assert.equal(
    (await k1.moderation.queue(actors.staff.actor, 50, { marketId: 'EE', typeId: 'event' })).kind,
    'rejected',
  );
  assert.equal(
    (await k1.moderation.queue(actors.staff.actor, 50, { marketId: 'LV', typeId: 'place' })).kind,
    'rejected',
  );
  const page = await k1.moderation.queue(actors.staff.actor, 50, {
    marketId: 'LV',
    typeId: 'event',
  });
  assert.equal(page.kind, 'succeeded');
  if (page.kind === 'succeeded')
    assert.ok(page.data.pending.some((i) => i.submissionId === submitted.submissionId));
  await k1.staff.grantScoped(
    actors.staff.actor.userId,
    [{ marketId: 'LV', typeId: 'event', actions }],
    new Date(Date.now() - 1000).toISOString(),
    new Date(Date.now() - 10000).toISOString(),
  );
  assert.equal(
    (await k1.moderation.queue(actors.staff.actor, 50, { marketId: 'LV', typeId: 'event' })).kind,
    'rejected',
  );
  await db.collection(moderationCollections.staffAuthority).doc(actors.staff.actor.userId).delete();
  await k1.staff.grant(actors.staff.actor.userId, new Date().toISOString());
  assert.equal(
    (await k1.moderation.queue(actors.staff.actor, 50, { marketId: 'LV', typeId: 'event' })).kind,
    'rejected',
  );
  await grant();
});

void test('scoped approval pins submission revision and owner alone publishes', async () => {
  const target = {
    contentId: submitted.contentId,
    submissionId: submitted.submissionId,
    expectedRevision: 99,
  };
  assert.equal(
    (await k1.moderation.decide(actors.staff.actor, { ...command('approve', 1), target })).kind,
    'rejected',
  );
  const c = { ...command('approve', 1), target: { ...target, expectedRevision: 1 } };
  const result = await k1.moderation.decide(actors.staff.actor, c);
  assert.equal(result.kind, 'succeeded', JSON.stringify(result));
  if (result.kind !== 'succeeded') return;
  assert.equal(result.data.decision.target.marketId, 'LV');
  assert.equal(result.data.decision.target.typeId, 'event');
  assert.equal(result.data.receipt.outcome, 'applied');
  assert.deepEqual(await k1.moderation.decide(actors.staff.actor, c), result);
  const published = await stand.contentService.execute(actors.creator.actor, {
    schemaVersion: 1,
    commandType: 'publishApprovedRevision',
    idempotencyKey: randomUUID(),
    payload: { submissionId: submitted.submissionId, expectedPointerRevision: 0 },
  });
  assert.equal(published.kind, 'succeeded', JSON.stringify(published));
  assert.equal((await pointer()).visibility, 'visible');
});

void test('hide and restore use verified Content commands and refuse stale revisions', async () => {
  const before = await pointer();
  assert.equal(
    (await k1.moderation.decide(actors.staff.actor, command('restrict', before.revision + 10)))
      .kind,
    'rejected',
  );
  const hide = await k1.moderation.decide(actors.staff.actor, command('restrict', before.revision));
  assert.equal(hide.kind, 'succeeded', JSON.stringify(hide));
  if (hide.kind !== 'succeeded') return;
  assert.equal(hide.data.receipt.outcome, 'applied');
  const held = await pointer();
  assert.equal(held.visibility, 'restricted');
  const restored = await k1.moderation.decide(
    actors.staff.actor,
    command('restore', held.revision, {
      restoresDecisionId: hide.data.decision.decisionId,
    }),
  );
  assert.equal(restored.kind, 'succeeded', JSON.stringify(restored));
  assert.equal((await pointer()).visibility, 'visible');
});

void test('remoderation queues pin exact publication, replay safely, and hide only through owner commands', async () => {
  const pin = await pointer();
  const request = {
    queueItemId: randomUUID(),
    contentId: submitted.contentId,
    expectedRevision: pin.revision,
    reason: 'New evidence needs review',
    idempotencyKey: randomUUID(),
  };
  const queued = await k1.workflows.request(actors.staff.actor, request);
  assert.equal(queued.kind, 'succeeded', JSON.stringify(queued));
  assert.deepEqual(await k1.workflows.request(actors.staff.actor, request), queued);
  const noAction = {
    queueItemId: request.queueItemId,
    expectedRevision: 1,
    outcome: 'noAction',
    reason: 'Review requires no action',
    idempotencyKey: randomUUID(),
  };
  assert.equal((await k1.workflows.review(actors.staff.actor, noAction)).kind, 'succeeded');
  assert.equal((await pointer()).revision, pin.revision);
  const second = { ...request, queueItemId: randomUUID(), idempotencyKey: randomUUID() };
  assert.equal((await k1.workflows.request(actors.staff.actor, second)).kind, 'succeeded');
  const hide = {
    ...noAction,
    queueItemId: second.queueItemId,
    outcome: 'restrict',
    idempotencyKey: randomUUID(),
  };
  const result = await k1.workflows.review(actors.staff.actor, hide);
  assert.equal(result.kind, 'succeeded', JSON.stringify(result));
  assert.deepEqual(await k1.workflows.review(actors.staff.actor, hide), result);
  assert.equal((await pointer()).visibility, 'restricted');
  if (result.kind !== 'succeeded') return;
  const restored = await k1.moderation.decide(
    actors.staff.actor,
    command('restore', (await pointer()).revision, {
      restoresDecisionId: result.data.decisionId,
    }),
  );
  assert.equal(restored.kind, 'succeeded', JSON.stringify(restored));
});

void test('revocation fences recorded decisions on retry, then the same key resumes after authorized regrant', async () => {
  let outage = true;
  const service = new ModerationService({
    repository: new FirestoreModerationRepository(db),
    staff: k1.staff,
    clock,
    requireScope: true,
    content: {
      reviewQueue: (...args) => k1.content.reviewQueue(...args),
      submission: (id) => k1.content.submission(id),
      publication: (id) => k1.content.publication(id),
      enforce: (instruction) => {
        if (outage) {
          outage = false;
          throw new Error('synthetic outage');
        }
        return k1.content.enforce(instruction);
      },
    },
  });
  const pin = await pointer(),
    c = command('restrict', pin.revision);
  assert.equal((await service.decide(actors.staff.actor, c)).kind, 'rejected');
  await db.collection(moderationCollections.staffAuthority).doc(actors.staff.actor.userId).delete();
  assert.equal((await service.decide(actors.staff.actor, c)).kind, 'rejected');
  assert.equal((await pointer()).revision, pin.revision);
  await grant();
  const resumed = await service.decide(actors.staff.actor, c);
  assert.equal(resumed.kind, 'succeeded', JSON.stringify(resumed));
  if (resumed.kind !== 'succeeded') return;
  await k1.moderation.decide(
    actors.staff.actor,
    command('restore', (await pointer()).revision, {
      restoresDecisionId: resumed.data.decision.decisionId,
    }),
  );
});

void test('reports preserve each reporter, return minimized own receipts, route to T&S and never hide content', async () => {
  const pin = await pointer();
  const report = {
    schemaVersion: 1,
    reportId: randomUUID(),
    requestId: randomUUID(),
    idempotencyKey: randomUUID(),
    target: { contentId: submitted.contentId, publishedRevisionId: pin.currentPublishedRevisionId },
    reasonCode: 'safety',
    narrative: 'Confidential synthetic report',
  };
  const first = await k1.reports.submit(hint(actors.creator), report);
  assert.equal(first.kind, 'succeeded', JSON.stringify(first));
  assert.deepEqual(await k1.reports.submit(hint(actors.creator), report), first);
  assert.equal(JSON.stringify(first).includes('Confidential'), false);
  assert.equal((await k1.reports.receipt(hint(actors.staff), report.reportId)).kind, 'rejected');
  const second = await k1.reports.submit(hint(actors.staff), {
    ...report,
    reportId: randomUUID(),
    idempotencyKey: randomUUID(),
  });
  assert.equal(second.kind, 'succeeded');
  assert.equal((await pointer()).revision, pin.revision);
  const route = await db.collection(k1Collections.routes).doc(report.reportId).get();
  assert.equal(route.get('ownerService'), 'trustSafety');
  assert.equal(
    (await k1.reports.submit(hint(actors.creator), { ...report, reasonCode: 'spam' })).kind,
    'rejected',
  );
  await grant('place');
  assert.equal((await k1.reports.queue(actors.staff.actor, 'LV', 'event')).kind, 'rejected');
  await grant();
  const page = await k1.reports.queue(actors.staff.actor, 'LV', 'event');
  assert.equal(page.kind, 'succeeded');
  const triage = { reportId: report.reportId, expectedRevision: 1, classification: 'accepted' };
  assert.equal((await k1.reports.triage(actors.staff.actor, triage)).kind, 'succeeded');
  assert.equal((await k1.reports.triage(actors.staff.actor, triage)).kind, 'succeeded');
  assert.equal(
    (await db.collection(k1Collections.routes).doc(report.reportId).get()).get('destination'),
    'investigation',
  );
});

void test('authenticated HTTP K1 rejects role injection and direct staff writes; reports route through owner service', async () => {
  const staffToken = await createFirebaseActor(actors.staff.firebaseUid);
  const creatorToken = await createFirebaseActor(actors.creator.firebaseUid);
  async function call(
    name: string,
    token: string,
    actor: PublishingActor,
    data: Record<string, unknown>,
  ) {
    const response = await fetch('http://127.0.0.1:5001/demo-recharge/europe-west1/' + name, {
      method: 'POST',
      headers: { authorization: 'Bearer ' + token, 'content-type': 'application/json' },
      body: JSON.stringify({
        data: {
          ...data,
          sessionContext: {
            sessionId: actor.actor.sessionId,
            sessionHandle: actor.sessionHandle,
            installationId: actor.installationId,
          },
        },
      }),
    });
    assert.equal(response.status, 200, await response.clone().text());
    return ((await response.json()) as { result: { kind: string; data?: Record<string, unknown> } })
      .result;
  }
  const q = {
    schemaVersion: 1,
    requestId: randomUUID(),
    queryType: 'queue',
    marketId: 'LV',
    typeId: 'event',
  };
  assert.equal((await call('moderationQueryV1', staffToken, actors.staff, q)).kind, 'succeeded');
  assert.equal((await call('moderationQueryV1', creatorToken, actors.creator, q)).kind, 'rejected');
  assert.equal(
    (await call('moderationQueryV1', staffToken, actors.staff, { ...q, roles: ['Admin'] })).kind,
    'rejected',
  );
  const pin = await pointer();
  const report = {
    schemaVersion: 1,
    reportId: randomUUID(),
    requestId: randomUUID(),
    idempotencyKey: randomUUID(),
    target: { contentId: submitted.contentId, publishedRevisionId: pin.currentPublishedRevisionId },
    reasonCode: 'spam',
  };
  assert.equal(
    (await call('reportCommandV1', creatorToken, actors.creator, report)).kind,
    'succeeded',
  );
  const receipt = await call('reportQueryV1', creatorToken, actors.creator, {
    schemaVersion: 1,
    requestId: randomUUID(),
    reportId: report.reportId,
  });
  assert.equal(receipt.kind, 'succeeded');
  assert.deepEqual(Object.keys(receipt.data!).sort(), ['reportId', 'status']);
  const denied = await fetch(
    'http://' +
      process.env.FIRESTORE_EMULATOR_HOST +
      '/v1/projects/demo-recharge/databases/(default)/documents/contentPublicationPointers/' +
      submitted.contentId,
    {
      method: 'PATCH',
      headers: { authorization: 'Bearer ' + staffToken, 'content-type': 'application/json' },
      body: JSON.stringify({ fields: { visibility: { stringValue: 'visible' } } }),
    },
  );
  assert.ok([401, 403].includes(denied.status));
});

void test('disabled K1 surfaces refuse every authenticated staff and report operation', async () => {
  await setLocalFlag(db, 'moderation.staff', false);
  const result = await handleK1(
    db,
    hint(actors.staff),
    'moderationQueryV1',
    {
      schemaVersion: 1,
      requestId: randomUUID(),
      queryType: 'queue',
      marketId: 'LV',
      typeId: 'event',
    },
    clock,
  );
  assert.equal(result.kind, 'rejected');
  await setLocalFlag(db, 'trustSafety.reports', false);
  assert.equal((await k1.reports.receipt(hint(actors.creator), randomUUID())).kind, 'rejected');
});
