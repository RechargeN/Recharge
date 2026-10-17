import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { getStorage } from 'firebase-admin/storage';
import { before, after, test, mock } from 'node:test';
import {
  AdminSupportService,
  adminCollections as ac,
  adminActions,
} from '../../src/modules/admin_support/admin_support_service.js';
import { createK1 } from '../../src/moderation_entry.js';
import { digest } from '../../src/modules/moderation/application/k1_workflows.js';
import { moderationCollections as mc } from '../../src/modules/moderation/infrastructure/firestore_moderation_repository.js';
import { identityAuthorityCollections as ic } from '../../src/modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import { contentCollections as cc } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import {
  featureFlagPointerCollection,
  featureFlagRevisionCollection,
} from '../../src/platform/config/feature_flag_repository.js';
import { createPublishingActors } from '../support/content_event_world.js';
import { emulatorFirestore } from '../support/booking_emulator.js';
import { cleanupContentEmulatorState } from '../support/content_emulator_cleanup.js';
import { setLocalFlag } from '../support/notifications_world.js';
import { createStandModeration, submitEventForReview } from '../stand/stand_moderation.js';
import type { StaffActor } from '../../src/modules/moderation/application/ports.js';

const db = emulatorFirestore();
let now = new Date();
const clock = { now: () => new Date(now) };
const k1 = createK1(db, clock);
const service = new AdminSupportService(db, clock, k1.moderation, k1.content);
const stand = createStandModeration(db);
let a: Awaited<ReturnType<typeof createPublishingActors>>;
let b: Awaited<ReturnType<typeof createPublishingActors>>;
let contentId: string;
let secondId: string;
let originalFiles = new Set<string>();
const bucket = getStorage().bucket('demo-recharge.appspot.com');
const caseId = randomUUID();
const allActions = [...Object.values(adminActions), 'approve', 'restrict', 'restore'];
const preserved = new Map<string, Map<string, FirebaseFirestore.DocumentData>>();
const fixtureCollections = [
  ...Object.values(ic),
  featureFlagPointerCollection,
  featureFlagRevisionCollection,
];
const proposalRef = (p: { proposalId: string; revision: number }) =>
  db.collection(ac.proposals).doc(digest([p.proposalId, p.revision]));
const executionRef = (p: { proposalId: string; revision: number }) =>
  db.collection(ac.executions).doc(digest([p.proposalId, p.revision]));
const pointer = () => db.collection(cc.pointers).doc(contentId).get();
async function grant(actor: StaffActor, actions = allActions, typeId = 'event') {
  await k1.staff.grantScoped(
    actor.userId,
    [{ marketId: 'LV', typeId, actions }],
    new Date(now.getTime() + 3600000).toISOString(),
    now.toISOString(),
  );
}
async function proposal(extra: Record<string, unknown> = {}) {
  return {
    proposalId: randomUUID(),
    revision: 1,
    caseId,
    reason: 'Synthetic K3 repair',
    targets: [
      {
        contentId,
        expectedRevision: (await pointer()).get('revision') as number,
        action: 'restrict',
      },
    ],
    ...extra,
  };
}
const approved = async () => {
  const p = await proposal();
  assert.equal((await service.propose(a.staff.actor, p)).kind, 'succeeded');
  assert.equal((await service.approve(b.staff.actor, p.proposalId, p.revision)).kind, 'succeeded');
  return p;
};
before(async () => {
  await cleanupContentEmulatorState(db, Object.values(ac));
  for (const name of fixtureCollections)
    preserved.set(
      name,
      new Map((await db.collection(name).get()).docs.map((d) => [d.id, d.data()])),
    );
  originalFiles = new Set((await bucket.getFiles())[0].map((f) => f.name));
  await setLocalFlag(db, 'moderation.staff', true);
  a = await createPublishingActors(db, 'k3-a-' + randomUUID());
  b = await createPublishingActors(db, 'k3-b-' + randomUUID());
  now = new Date();
  await grant(a.staff.actor);
  await grant(b.staff.actor);
  const publishFixture = async () => {
    const submitted = await submitEventForReview(stand, a.creator.actor, {
      type: 'page',
      id: a.pageId,
    });
    const review = await k1.moderation.decide(a.staff.actor, {
      schemaVersion: 1,
      action: 'approve',
      idempotencyKey: randomUUID(),
      reason: 'Synthetic K3 source',
      target: {
        contentId: submitted.contentId,
        submissionId: submitted.submissionId,
        expectedRevision: 1,
      },
    });
    assert.equal(review.kind, 'succeeded', JSON.stringify(review));
    const published = await stand.contentService.execute(a.creator.actor, {
      schemaVersion: 1,
      commandType: 'publishApprovedRevision',
      idempotencyKey: randomUUID(),
      payload: { submissionId: submitted.submissionId, expectedPointerRevision: 0 },
    });
    assert.equal(published.kind, 'succeeded', JSON.stringify(published));
    return submitted.contentId;
  };
  contentId = await publishFixture();
  secondId = await publishFixture();
  await db
    .collection(ac.cases)
    .doc(caseId)
    .create({
      status: 'active',
      marketId: 'LV',
      typeId: 'event',
      contentIds: [contentId, secondId],
      members: {
        [a.staff.actor.userId]: Object.values(adminActions),
        [b.staff.actor.userId]: Object.values(adminActions),
      },
      approvalTtlMs: 60000,
      policy: 'test-only-k3-two-person-v1',
    });
});
after(async () => {
  mock.restoreAll();
  for (const file of (await bucket.getFiles())[0])
    if (!originalFiles.has(file.name)) await file.delete();
  assert.deepEqual(new Set((await bucket.getFiles())[0].map((f) => f.name)), originalFiles);
  await cleanupContentEmulatorState(db, Object.values(ac));
  // Restore existing flag fixtures and remove every Identity fixture created by this group.
  for (const [name, originals] of preserved) {
    for (const d of (await db.collection(name).get()).docs) {
      const original = originals.get(d.id);
      if (original) await d.ref.set(original);
      else await d.ref.delete();
    }
    assert.deepEqual(
      new Map((await db.collection(name).get()).docs.map((d) => [d.id, d.data()])),
      originals,
    );
  }
  for (const name of Object.values(ac))
    assert.equal((await db.collection(name).get()).size, 0, name);
  console.log(
    'K3 fixture cleanup verified: Admin, Content/Media/Moderation/Booking, Identity and flag snapshots',
  );
});

void test('K3 read denies absent capability, foreign scope/target, expired/revoked session and revoked grant', async () => {
  assert.equal((await service.reveal(a.creator.actor, caseId, contentId)).kind, 'rejected');
  await grant(a.staff.actor, allActions, 'place');
  assert.equal((await service.reveal(a.staff.actor, caseId, contentId)).kind, 'rejected');
  await grant(a.staff.actor);
  assert.equal((await service.reveal(a.staff.actor, caseId, randomUUID())).kind, 'rejected');
  const session = db.collection(ic.sessions).doc(a.staff.actor.sessionId);
  const original = (await session.get()).data()!;
  for (const patch of [
    { status: 'expired' },
    { status: 'revoked' },
    { idleExpiresAtUtc: new Date(now.getTime() - 1).toISOString() },
  ]) {
    await session.update(patch);
    assert.equal((await service.reveal(a.staff.actor, caseId, contentId)).kind, 'rejected');
    await session.set(original);
  }
  await db.collection(mc.staffAuthority).doc(a.staff.actor.userId).delete();
  assert.equal((await service.reveal(a.staff.actor, caseId, contentId)).kind, 'rejected');
  await grant(a.staff.actor);
});
void test('K3 response allowlist and audit fail closed with a real owner read', async () => {
  const before = (await db.collection(ac.audit).get()).size;
  const result = await service.reveal(a.staff.actor, caseId, contentId);
  assert.equal(result.kind, 'succeeded');
  if (result.kind === 'succeeded')
    assert.deepEqual(Object.keys(result.data).sort(), ['contentId', 'revision', 'visibility']);
  assert.equal((await db.collection(ac.audit).get()).size, before + 1);
  const audit = mock.method(service as unknown as { audit(): void }, 'audit', () => {
    throw new Error('audit unavailable');
  });
  assert.deepEqual(await service.reveal(a.staff.actor, caseId, contentId), {
    kind: 'rejected',
    code: 'audit_or_source_unavailable',
  });
  audit.mock.restore();
});
void test('K3 immutable proposal: self-approval, missing approval, new revision, payload tamper and stale target', async () => {
  const p = await proposal();
  assert.equal((await service.propose(a.staff.actor, p)).kind, 'succeeded');
  const original = (await proposalRef(p).get()).data();
  assert.equal((await service.approve(a.staff.actor, p.proposalId, 1)).kind, 'rejected');
  assert.equal((await service.execute(a.staff.actor, p.proposalId, 1)).kind, 'rejected');
  assert.equal(
    (await service.propose(a.staff.actor, { ...p, reason: 'Changed payload' })).kind,
    'rejected',
  );
  assert.equal((await service.approve(b.staff.actor, p.proposalId, 1)).kind, 'succeeded');
  assert.deepEqual((await proposalRef(p).get()).data(), original);
  const newer = { ...p, revision: 2 };
  assert.equal((await service.propose(a.staff.actor, newer)).kind, 'succeeded');
  assert.equal((await service.execute(a.staff.actor, p.proposalId, 2)).kind, 'rejected');
  await proposalRef(p).update({ reason: 'Tampered after approval' });
  assert.equal((await service.execute(a.staff.actor, p.proposalId, 1)).kind, 'rejected');
  await proposalRef(p).set(original!);
  const stale = await proposal({
    targets: [{ contentId, expectedRevision: 999999, action: 'restrict' }],
  });
  await service.propose(a.staff.actor, stale);
  await service.approve(b.staff.actor, stale.proposalId, 1);
  const before = (await pointer()).data();
  const result = await service.execute(a.staff.actor, stale.proposalId, 1);
  assert.equal(result.kind, 'pending', JSON.stringify(result));
  assert.deepEqual((await pointer()).data(), before);
  assert.equal(
    ((await executionRef(stale).get()).get('steps') as { state: string }[])[0]!.state,
    'refused',
  );
});
void test('K3 expiry, approver revoke, executor revoke and closed case fence execution', async () => {
  const p = await approved();
  now = new Date(now.getTime() + 60001);
  assert.equal((await service.execute(a.staff.actor, p.proposalId, 1)).kind, 'rejected');
  now = new Date(now.getTime() - 60001);
  await db.collection(mc.staffAuthority).doc(b.staff.actor.userId).delete();
  assert.equal((await service.execute(a.staff.actor, p.proposalId, 1)).kind, 'rejected');
  await grant(b.staff.actor);
  await grant(
    a.staff.actor,
    allActions.filter((x) => x !== adminActions.execute),
  );
  assert.equal((await service.execute(a.staff.actor, p.proposalId, 1)).kind, 'rejected');
  await grant(a.staff.actor);
  await db.collection(ac.cases).doc(caseId).update({ status: 'closed' });
  assert.equal((await service.execute(a.staff.actor, p.proposalId, 1)).kind, 'rejected');
  await db.collection(ac.cases).doc(caseId).update({ status: 'active' });
});
void test('K3 owner commit then lost result: visible unknown, stable receipt, one effect, original fields preserved', async () => {
  const p = await approved();
  const original = (await proposalRef(p).get()).data();
  const before = (await pointer()).data()!;
  let crash = true;
  const interrupted = new AdminSupportService(db, clock, k1.moderation, k1.content, () => {
    if (crash) {
      crash = false;
      throw new Error('lost result');
    }
  });
  const first = await interrupted.execute(a.staff.actor, p.proposalId, 1);
  assert.equal(first.kind, 'pending', JSON.stringify(first));
  assert.equal(
    ((await executionRef(p).get()).get('steps') as { state: string }[])[0]!.state,
    'unknown',
  );
  const changed = (await pointer()).data()!;
  assert.equal(changed.visibility, 'restricted');
  assert.equal(changed.revision, Number(before.revision) + 1);
  for (const field of Object.keys(before).filter(
    (f) => !['revision', 'updatedAtUtc', 'visibility', 'moderationHold'].includes(f),
  ))
    assert.deepEqual(changed[field], before[field], field);
  const resumed = await interrupted.execute(a.staff.actor, p.proposalId, 1);
  assert.equal(resumed.kind, 'succeeded', JSON.stringify(resumed));
  assert.deepEqual(await interrupted.execute(a.staff.actor, p.proposalId, 1), resumed);
  assert.equal((await pointer()).get('revision'), changed.revision);
  assert.deepEqual((await proposalRef(p).get()).data(), original);
  if (resumed.kind !== 'succeeded') return;
  const receipt = resumed.data.steps[0]!.receiptId!;
  assert.ok((await db.collection(mc.receipts).doc(receipt).get()).exists);
  const restore = await proposal({
    targets: [
      {
        contentId,
        expectedRevision: changed.revision,
        action: 'restore',
        restoresDecisionId: receipt,
      },
    ],
  });
  await service.propose(a.staff.actor, restore);
  await service.approve(b.staff.actor, restore.proposalId, 1);
  await grant(
    a.staff.actor,
    allActions.filter((x) => x !== 'restore'),
  );
  assert.equal((await service.execute(a.staff.actor, restore.proposalId, 1)).kind, 'rejected');
  assert.equal((await pointer()).get('visibility'), 'restricted');
  await grant(a.staff.actor);
  assert.equal((await service.execute(a.staff.actor, restore.proposalId, 1)).kind, 'succeeded');
  assert.equal((await pointer()).get('visibility'), 'visible');
});

void test('K3 multi-target repair retains first owner receipt when later target is stale', async () => {
  const p = await proposal({
    targets: [
      {
        contentId,
        expectedRevision: Number((await pointer()).get('revision')),
        action: 'restrict',
      },
      { contentId: secondId, expectedRevision: 999999, action: 'restrict' },
    ],
  });
  await service.propose(a.staff.actor, p);
  await service.approve(b.staff.actor, p.proposalId, 1);
  const original = (await proposalRef(p).get()).data();
  const other = (await db.collection(cc.pointers).doc(secondId).get()).data();
  await grant(
    a.staff.actor,
    allActions.filter((x) => x !== 'restrict'),
  );
  assert.equal((await service.execute(a.staff.actor, p.proposalId, 1)).kind, 'rejected');
  await grant(a.staff.actor);
  const first = await service.execute(a.staff.actor, p.proposalId, 1);
  assert.equal(first.kind, 'pending', JSON.stringify(first));
  if (first.kind !== 'pending') return;
  assert.deepEqual(
    first.data.steps.map((s) => s.state),
    ['completed', 'refused'],
  );
  assert.ok(first.data.steps[0]!.receiptId);
  const held = (await pointer()).data();
  assert.deepEqual(await service.execute(a.staff.actor, p.proposalId, 1), first);
  assert.deepEqual((await pointer()).data(), held);
  assert.deepEqual((await db.collection(cc.pointers).doc(secondId).get()).data(), other);
  assert.deepEqual((await proposalRef(p).get()).data(), original);
});
void test('K3 absent local policy and client capability/actor assertions never create authority', async () => {
  const p = await proposal();
  const c = db.collection(ac.cases).doc(caseId),
    original = (await c.get()).data()!;
  await c.delete();
  assert.equal((await service.propose(a.staff.actor, p)).kind, 'rejected');
  await c.set(original);
  assert.equal(
    (await service.propose(a.creator.actor, { ...p, capabilities: allActions, isAdmin: true }))
      .kind,
    'rejected',
  );
  assert.equal(
    (await service.propose(a.staff.actor, { ...p, proposer: b.staff.actor })).kind,
    'rejected',
  );
});
