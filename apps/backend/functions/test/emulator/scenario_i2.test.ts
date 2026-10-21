import assert from 'node:assert/strict';
import { randomUUID, randomBytes } from 'node:crypto';
import { spawn } from 'node:child_process';
import path from 'node:path';
import { before, after, test } from 'node:test';
import { getAuth } from 'firebase-admin/auth';
import { readFileSync } from 'node:fs';
import {
  FirestoreScenarioService,
  scenarioCollections as cols,
  scenarioFlag,
} from '../../src/modules/quick_plan/firestore_scenario_service.js';
import { FirestoreQuickPlanService } from '../../src/modules/quick_plan/firestore_quick_plan_service.js';
import {
  quickPlanCollections,
  quickPlanFlag,
} from '../../src/modules/quick_plan/quick_plan_contract.js';
import { canonicalJson, sha256Hex } from '../../src/modules/content/domain/published_revision.js';
import { establishEmulatorIdentitySession } from '../../src/modules/identity_publisher/application/emulator_identity_session_service.js';
import { cleanupBookingEmulator, emulatorFirestore } from '../support/booking_emulator.js';
import { setLocalFlag } from '../support/notifications_world.js';
import { contentCollections } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { catalogCollections } from '../../src/modules/catalog/infrastructure/firestore_catalog_repository.js';

const db = emulatorFirestore(),
  now = new Date(),
  clock = { now: () => now };
class CreationProbe extends FirestoreScenarioService {
  calls = 0;
  failBeforeCommit = false;
  protected override saveInTransaction(
    ...args: Parameters<FirestoreScenarioService['saveInTransaction']>
  ) {
    this.calls++;
    const result = super.saveInTransaction(...args);
    if (this.failBeforeCommit) throw new Error('injected_before_receipt');
    return result;
  }
}
const service = new CreationProbe(db, clock),
  quick = new FirestoreQuickPlanService(db, clock);
const ulid = () => '0' + randomBytes(25).toString('hex').slice(0, 25).toUpperCase();
async function identity(name: string) {
  const s = await establishEmulatorIdentitySession({
    firestore: db,
    firebaseUid: name,
    installationId: name,
    attemptRequestId: randomUUID(),
    now,
  });
  return {
    userId: s.userId,
    hint: {
      firebaseUid: name,
      installationId: name,
      sessionId: s.sessionId,
      sessionHandle: s.sessionHandle,
    },
  };
}
type Actor = Awaited<ReturnType<typeof identity>>;
let owner: Actor, editor: Actor, stranger: Actor;
const authUids = ['i2-' + randomUUID(), 'i2-' + randomUUID()];
let protectedDigest: string;
async function sideEffectDigest() {
  const data = [];
  for (const name of [...Object.values(contentCollections), ...Object.values(catalogCollections)]) {
    const docs = await db.collection(name).get();
    data.push([name, docs.docs.map((d) => [d.id, d.data()]).sort()]);
  }
  return sha256Hex(canonicalJson(data));
}
async function cleanup() {
  for (const name of [...Object.values(cols), ...Object.values(quickPlanCollections)]) {
    // Suite owns its collections in this serial group, including Flutter fixtures.
    for (;;) {
      const docs = await db.collection(name).limit(200).get();
      if (docs.empty) break;
      const batch = db.batch();
      docs.docs.forEach((d) => batch.delete(d.ref));
      await batch.commit();
    }
    assert.equal((await db.collection(name).limit(1).get()).empty, true);
  }
}
before(async () => {
  await cleanupBookingEmulator(db);
  await cleanup();
  await setLocalFlag(db, scenarioFlag, true);
  await setLocalFlag(db, quickPlanFlag, true);
  await setLocalFlag(db, 'identity.session.establish', true);
  owner = await identity('i2-owner-' + randomUUID());
  editor = await identity('i2-editor-' + randomUUID());
  stranger = await identity('i2-stranger-' + randomUUID());
  protectedDigest = await sideEffectDigest();
});
after(async () => {
  const digest = await sideEffectDigest();
  await cleanup();
  await cleanupBookingEmulator(db);
  for (const uid of authUids) {
    try {
      await getAuth().deleteUser(uid);
    } catch (e) {
      if ((e as { code?: string }).code !== 'auth/user-not-found') throw e;
    }
  }
  process.stdout.write(
    'I2 cleanup verified: all Scenario/Quick Plan fixtures, Identity, flags and owned Auth users removed.\n',
  );
  assert.equal(digest, protectedDigest, 'I2 cannot mutate Content or Catalog');
});
function draft(title = 'initial', rev = 1) {
  return {
    title,
    scenario: {
      schemaVersion: 2,
      updatesEnabled: true,
      revision: rev,
      format: 'day',
      dateMode: 'template',
      defaultTimezoneId: 'Europe/Riga',
      displayCurrencyCode: 'EUR',
      party: { peopleCount: 1, kind: 'solo' },
      constraints: {},
      days: [],
      locations: [],
      items: [],
      unscheduledItemIds: [],
      legs: [],
      totals: {},
      origin: null,
      capabilities: { publicPublish: false, unlistedShare: false, liveLogistics: false },
    },
  };
}
function command(
  actor: Actor,
  id: string,
  type = 'save',
  expected = 0,
  extra: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    schemaVersion: 1,
    requestId: randomUUID(),
    actorContext: actor.userId,
    idempotencyKey: randomUUID(),
    commandType: type,
    scenarioId: id,
    expectedRevision: expected,
    generation: 0,
    ...extra,
  };
}
const query = (id: string) => ({ schemaVersion: 1, requestId: randomUUID(), scenarioId: id });
async function create() {
  const id = ulid();
  assert.equal(
    (await service.command(owner.hint, command(owner, id, 'save', 0, { draft: draft() }))).kind,
    'succeeded',
  );
  return id;
}
async function invite(id: string, role = 'editor', expected = 0) {
  const inviteId = randomUUID();
  const c = command(owner, id, 'invite', expected, {
    recipientId: editor.userId,
    role,
    inviteId,
    expiresAtUtc: new Date(now.getTime() + 3600000).toISOString(),
  });
  assert.equal((await service.command(owner.hint, c)).kind, 'succeeded');
  return command(editor, id, 'accept', 0, { inviteId });
}
async function accept(id: string) {
  const c = await invite(id);
  assert.equal((await service.command(editor.hint, c)).kind, 'succeeded');
  return c;
}
void test('authority: pending invite, wrong recipient, spoofed role, strangers, session expiry, minimal responses', async () => {
  const id = await create(),
    accept = await invite(id);
  assert.equal((await service.query(editor.hint, query(id))).code, 'not_found_or_forbidden');
  assert.equal(
    (await service.command(stranger.hint, { ...accept, actorContext: stranger.userId })).code,
    'not_found_or_forbidden',
  );
  assert.equal(
    (await service.command(editor.hint, { ...accept, role: 'owner' })).code,
    'request_invalid',
  );
  assert.equal((await service.command(editor.hint, accept)).kind, 'succeeded');
  assert.equal((await service.command(editor.hint, accept)).kind, 'succeeded');
  assert.equal(
    (
      await service.command(
        editor.hint,
        command(editor, id, 'revoke', 0, { recipientId: owner.userId, generation: 1 }),
      )
    ).code,
    'not_found_or_forbidden',
  );
  const response = await service.query(editor.hint, query(id));
  assert.deepEqual(Object.keys(response).sort(), ['schemaVersion', 'kind', 'entry'].sort());
  assert.deepEqual(
    Object.keys(response.entry as object).sort(),
    ['scenarioId', 'revision', 'status', 'generation', 'role', 'draft', 'updatedAtUtc'].sort(),
  );
  assert.equal(JSON.stringify(response).includes(owner.userId), false);
  assert.equal((await service.query(stranger.hint, query(id))).code, 'not_found_or_forbidden');
  assert.equal(
    (await service.command({ ...editor.hint, sessionHandle: 'forged' }, accept)).code,
    'unauthenticated',
  );
  const ref = db.collection('identitySessions').doc(editor.hint.sessionId),
    old = (await ref.get()).data()!;
  await ref.update({ idleExpiresAtUtc: '2000-01-01T00:00:00.000Z' });
  try {
    assert.equal((await service.command(editor.hint, accept)).code, 'unauthenticated');
  } finally {
    await ref.set(old);
  }
});
void test('malformed Scenario graph rejects without writes or conversion exceptions', async () => {
  const id = ulid(),
    s = await source(),
    c = expansion(id, s);
  const malformed = draft('malformed');
  malformed.scenario.days = [{ id: ulid(), itemIds: [ulid()] } as never];
  assert.equal(
    (await service.command(owner.hint, command(owner, id, 'save', 0, { draft: malformed }))).code,
    'request_invalid',
  );
  assert.equal(
    (await service.command(owner.hint, { ...c, draft: malformed })).code,
    'request_invalid',
  );
  assert.equal((await db.collection(cols.plans).doc(id).get()).exists, false);
});
void test('persistence budget rejects oversized drafts without partial writes', async () => {
  const id = ulid();
  const tooManyDays = draft();
  tooManyDays.scenario.days = Array.from({ length: 31 }, (_, dayIndex) => ({
    id: ulid(),
    dayIndex,
    title: 'Day',
    itemIds: [],
  })) as never;
  const tooManyItems = draft();
  tooManyItems.scenario.items = Array.from({ length: 251 }, () => ({
    id: ulid(),
    dayId: null,
    startLocationId: null,
    endLocationId: null,
    durationMinutes: null,
  })) as never;
  tooManyItems.scenario.unscheduledItemIds = tooManyItems.scenario.items.map(
    (item: { id: string }) => item.id,
  ) as never;
  const tooManyBytes = draft();
  tooManyBytes.scenario.constraints = { notes: 'x'.repeat(240 * 1024) };
  for (const oversized of [tooManyDays, tooManyItems, tooManyBytes]) {
    assert.equal(
      (await service.command(owner.hint, command(owner, id, 'save', 0, { draft: oversized }))).code,
      'request_invalid',
    );
    assert.equal((await db.collection(cols.plans).doc(id).get()).exists, false);
  }
});

void test('owner lists continue after 100 records without exposing foreign records', async () => {
  const ids = Array.from({ length: 101 }, () => ulid()).sort(),
    batch = db.batch();
  for (const id of ids)
    batch.set(db.collection(cols.plans).doc(id), {
      scenarioId: id,
      ownerId: stranger.userId,
      status: 'active',
      revision: 1,
      draft: draft('paged'),
      updatedAtUtc: now.toISOString(),
    });
  await batch.commit();
  const first = await service.query(stranger.hint, { schemaVersion: 1, requestId: randomUUID() });
  assert.equal((first.entries as unknown[]).length, 100);
  assert.equal(first.hasMore, true);
  const second = await service.query(stranger.hint, {
    schemaVersion: 1,
    requestId: randomUUID(),
    cursor: first.cursor,
  });
  assert.equal((second.entries as unknown[]).length, 1);
  assert.equal(second.hasMore, false);
  const seen = [
    ...(first.entries as { scenarioId: string }[]),
    ...(second.entries as { scenarioId: string }[]),
  ].map((e) => e.scenarioId);
  assert.deepEqual(seen, ids);
  // The same client-supplied cursor cannot grant access under a different actor.
  const foreign = await service.query(editor.hint, {
    schemaVersion: 1,
    requestId: randomUUID(),
    cursor: first.cursor,
  });
  assert.ok(
    (foreign.entries as { scenarioId: string }[]).every((e) => !ids.includes(e.scenarioId)),
  );
});
void test('cancel is terminal; accept/revoke in both orders; membership CAS and role generations', async () => {
  for (const accepted of [false, true]) {
    const id = await create(),
      a = await invite(id);
    if (accepted) assert.equal((await service.command(editor.hint, a)).kind, 'succeeded');
    const expected = accepted ? 2 : 1;
    assert.equal(
      (
        await service.command(
          owner.hint,
          command(owner, id, 'revoke', expected, { recipientId: editor.userId }),
        )
      ).kind,
      'succeeded',
    );
    assert.equal((await service.command(editor.hint, a)).code, 'not_found_or_forbidden');
  }
  const id = await create(),
    a = await invite(id);
  assert.equal(
    (
      await service.command(
        owner.hint,
        command(owner, id, 'cancel', 1, { recipientId: editor.userId, inviteId: a.inviteId }),
      )
    ).kind,
    'succeeded',
  );
  assert.equal((await service.command(editor.hint, a)).code, 'not_found_or_forbidden');
  const id2 = await create();
  await accept(id2);
  const results = await Promise.all(
    ['viewer', 'editor'].map((role) =>
      service.command(
        owner.hint,
        command(owner, id2, 'role', 2, { recipientId: editor.userId, role }),
      ),
    ),
  );
  assert.equal(results.filter((r) => r.kind === 'succeeded').length, 1);
  assert.equal(results.filter((r) => r.code === 'membership_conflict').length, 1);
});
void test('pending invite expires; accepted invite replay cannot expire or reactivate revoked membership', async () => {
  const late = new FirestoreScenarioService(db, { now: () => new Date(now.getTime() + 6000) });
  for (const accepted of [false, true]) {
    const id = await create(),
      inviteId = randomUUID();
    assert.equal(
      (
        await service.command(
          owner.hint,
          command(owner, id, 'invite', 0, {
            recipientId: editor.userId,
            role: 'viewer',
            inviteId,
            expiresAtUtc: new Date(now.getTime() + 5000).toISOString(),
          }),
        )
      ).kind,
      'succeeded',
    );
    const accept = command(editor, id, 'accept', 0, { inviteId });
    if (accepted) assert.equal((await service.command(editor.hint, accept)).kind, 'succeeded');
    assert.equal(
      (await late.command(editor.hint, accept)).kind,
      accepted ? 'succeeded' : 'rejected',
    );
  }
});
void test('two editors and both delivery orders: revision CAS prevents silent loss', async () => {
  for (const reverse of [false, true]) {
    const id = await create();
    await accept(id);
    const edits = [
      command(owner, id, 'save', 1, { draft: draft('owner', 2) }),
      command(editor, id, 'save', 1, { generation: 1, draft: draft('editor', 2) }),
    ];
    const actors = [owner, editor],
      first = reverse ? 1 : 0,
      other = 1 - first;
    assert.equal((await service.command(actors[first]!.hint, edits[first])).kind, 'succeeded');
    assert.equal(
      (await service.command(actors[other]!.hint, edits[other])).code,
      'revision_conflict',
    );
    const r = await service.query(owner.hint, query(id));
    assert.equal(
      ((r.entry as Record<string, unknown>).draft as { title: string }).title,
      reverse ? 'editor' : 'owner',
    );
  }
});
void test('revoke fences reads, saves, successful replay and queued generation even after re-invite', async () => {
  const id = await create();
  await accept(id);
  const edit = command(editor, id, 'save', 1, { generation: 1, draft: draft('before', 2) });
  assert.equal((await service.command(editor.hint, edit)).kind, 'succeeded');
  const queued = command(editor, id, 'save', 2, { generation: 1, draft: draft('offline', 3) });
  assert.equal(
    (
      await service.command(
        owner.hint,
        command(owner, id, 'revoke', 2, { recipientId: editor.userId }),
      )
    ).kind,
    'succeeded',
  );
  for (const c of [edit, queued])
    assert.equal((await service.command(editor.hint, c)).code, 'not_found_or_forbidden');
  assert.equal((await service.query(editor.hint, query(id))).code, 'not_found_or_forbidden');
  const a = await invite(id, 'editor', 3);
  assert.equal((await service.command(editor.hint, a)).kind, 'succeeded');
  assert.equal((await service.command(editor.hint, queued)).code, 'access_revoked');
  const r = await service.query(owner.hint, query(id));
  assert.equal((r.entry as { revision: number }).revision, 2);
});
void test('revoke racing transactions: once revoke commits, no later effect or disclosure', async () => {
  for (let i = 0; i < 4; i++) {
    const id = await create();
    await accept(id);
    await Promise.all([
      service.query(editor.hint, query(id)),
      service.command(
        editor.hint,
        command(editor, id, 'save', 1, { generation: 1, draft: draft('race', 2) }),
      ),
      service.command(owner.hint, command(owner, id, 'revoke', 2, { recipientId: editor.userId })),
    ]);
    const before = await service.query(owner.hint, query(id));
    assert.equal((await service.query(editor.hint, query(id))).kind, 'rejected');
    assert.equal(
      (
        await service.command(
          editor.hint,
          command(editor, id, 'save', 1, { generation: 1, draft: draft('late', 2) }),
        )
      ).kind,
      'rejected',
    );
    assert.deepEqual(await service.query(owner.hint, query(id)), before);
  }
});
void test('viewer cannot edit; role downgrade invalidates successful receipts', async () => {
  const id = await create(),
    a = await invite(id, 'viewer');
  await service.command(editor.hint, a);
  assert.equal(
    (
      await service.command(
        editor.hint,
        command(editor, id, 'save', 1, { generation: 1, draft: draft('forbidden', 2) }),
      )
    ).kind,
    'rejected',
  );
  assert.equal(
    (
      await service.command(
        owner.hint,
        command(owner, id, 'role', 2, { recipientId: editor.userId, role: 'editor' }),
      )
    ).kind,
    'succeeded',
  );
  assert.equal(
    (
      await service.command(
        editor.hint,
        command(editor, id, 'save', 1, { generation: 1, draft: draft('old queue', 2) }),
      )
    ).code,
    'access_revoked',
  );
});
async function source(actor: Actor = owner) {
  const id = randomUUID(),
    plan = {
      id,
      revision: 0,
      mood: 'calm',
      maxDurationMinutes: 150,
      freeOnly: false,
      walkingOnly: true,
      sourcePrompt: 'source',
      currencyCode: 'EUR',
      steps: [],
    };
  const c = {
    schemaVersion: 1,
    requestId: randomUUID(),
    ownerContext: actor.userId,
    idempotencyKey: randomUUID(),
    commandType: 'save',
    planId: id,
    expectedRevision: 0,
    plan,
  };
  assert.equal((await quick.command(actor.hint, c)).kind, 'succeeded');
  return { id, plan, c };
}
function expansion(id: string, s: Awaited<ReturnType<typeof source>>) {
  const d = draft('expanded');
  d.scenario.days = [{ id: ulid(), title: 'Day 1', dayIndex: 0, itemIds: [] } as never];
  d.scenario.origin = { type: 'quick_plan_conversion', sourceId: s.id, sourceRevision: 1 } as never;
  return command(owner, id, 'expand', 0, {
    draft: d,
    sourceId: s.id,
    sourceRevision: 1,
    sourceHash: sha256Hex(canonicalJson(s.plan)),
    selectedStopIds: [],
  });
}
void test('Expand lost response/restart: same intent creates once, new intent independent, source revision conflict', async () => {
  const s = await source(),
    id = ulid(),
    c = expansion(id, s);
  const first = await service.command(owner.hint, c);
  assert.equal(first.kind, 'succeeded');
  const restarted = new FirestoreScenarioService(db, clock);
  assert.deepEqual(await restarted.command(owner.hint, c), first);
  const compact = {
    ...c,
    replayHash: sha256Hex(
      canonicalJson(Object.fromEntries(Object.entries(c).filter(([k]) => k !== 'requestId'))),
    ),
  };
  delete (compact as Record<string, unknown>).draft;
  assert.deepEqual(await restarted.command(owner.hint, compact), first);
  assert.equal(
    (await restarted.command(owner.hint, { ...compact, scenarioId: ulid() })).code,
    'idempotency_conflict',
  );
  assert.equal(
    (await restarted.command(owner.hint, { ...compact, idempotencyKey: randomUUID() })).code,
    'intent_not_found',
  );
  assert.equal(
    (await service.command(owner.hint, { ...c, draft: draft('changed') })).code,
    'idempotency_conflict',
  );
  assert.equal(
    (
      await service.command(stranger.hint, {
        ...c,
        actorContext: stranger.userId,
        idempotencyKey: randomUUID(),
        scenarioId: ulid(),
      })
    ).code,
    'source_unavailable',
  );
  const next = expansion(ulid(), s);
  assert.equal((await service.command(owner.hint, next)).kind, 'succeeded');
  await quick.command(owner.hint, {
    ...s.c,
    idempotencyKey: randomUUID(),
    expectedRevision: 1,
    plan: { ...s.plan, sourcePrompt: 'changed' },
  });
  assert.equal(
    (await service.command(owner.hint, expansion(ulid(), s))).code,
    'source_revision_conflict',
  );
  assert.deepEqual(await restarted.command(owner.hint, c), first);
  await quick.command(owner.hint, {
    ...s.c,
    idempotencyKey: randomUUID(),
    commandType: 'delete',
    expectedRevision: 2,
    plan: undefined,
  });
  assert.equal((await restarted.command(owner.hint, compact)).code, 'source_unavailable');
  assert.equal((await service.query(owner.hint, query(id))).kind, 'succeeded');
  assert.equal(
    (await service.command(owner.hint, command(owner, id, 'delete', 1))).kind,
    'succeeded',
  );
  assert.equal(
    (await quick.query(owner.hint, { schemaVersion: 1, requestId: randomUUID(), planId: s.id }))
      .kind,
    'succeeded',
  );
});
void test('canonical creation command invoked once; interrupted transaction rolls back and recovers same intent', async () => {
  const sourcePlan = await source(),
    id = ulid(),
    c = expansion(id, sourcePlan);
  const previous = service.calls;
  service.failBeforeCommit = true;
  try {
    await assert.rejects(service.command(owner.hint, c), /injected_before_receipt/);
  } finally {
    service.failBeforeCommit = false;
  }
  assert.equal((await db.collection(cols.plans).doc(id).get()).exists, false);
  assert.equal((await service.command(owner.hint, c)).kind, 'succeeded');
  assert.equal(service.calls, previous + 2);
  const count = service.calls;
  assert.equal((await service.command(owner.hint, c)).kind, 'succeeded');
  assert.equal(service.calls, count);
  const ordinary = service.calls;
  await create();
  assert.equal(service.calls, ordinary + 1);
  const text = readFileSync(
    path.resolve('src/modules/quick_plan/firestore_scenario_service.ts'),
    'utf8',
  );
  assert.equal((text.match(/this\.saveInTransaction\(/g) ?? []).length, 1);
  assert.doesNotMatch(text, /from ['"].*(?:route|catalog).*['"]/);
  // I3 / SCN-PUB-01: the one accepted publication seam is Planning's own module.
  assert.doesNotMatch(text, /from ['"](?!\.\/scenario_publication\.js['"]).*publication.*['"]/);
  assert.doesNotMatch(text, /RouteMode|routeData|publishDraft|PublisherRef/);
});
void test('source edit racing Expand serializes a pinned snapshot or conflict; plans remain independent', async () => {
  for (const reverse of [false, true]) {
    const s = await source(),
      id = ulid(),
      c = expansion(id, s);
    const edit = () =>
      quick.command(owner.hint, {
        ...s.c,
        idempotencyKey: randomUUID(),
        expectedRevision: 1,
        plan: { ...s.plan, sourcePrompt: 'changed' },
      });
    const expand = () => service.command(owner.hint, c);
    const results = await Promise.all(reverse ? [edit(), expand()] : [expand(), edit()]);
    const result = results[reverse ? 1 : 0];
    assert.ok(result.kind === 'succeeded' || result.code === 'source_revision_conflict');
    const sourceRead = await quick.query(owner.hint, {
      schemaVersion: 1,
      requestId: randomUUID(),
      planId: s.id,
    });
    assert.equal((sourceRead.entry as { revision: number }).revision, 2);
    if (result.kind === 'succeeded') {
      await service.command(
        owner.hint,
        command(owner, id, 'save', 1, { draft: draft('target edited', 2) }),
      );
      assert.deepEqual(
        await quick.query(owner.hint, { schemaVersion: 1, requestId: randomUUID(), planId: s.id }),
        sourceRead,
      );
      await service.command(owner.hint, command(owner, id, 'delete', 2));
      assert.deepEqual(
        await quick.query(owner.hint, { schemaVersion: 1, requestId: randomUUID(), planId: s.id }),
        sourceRead,
      );
    }
  }
});
void test('shared responses redact private Quick Plan provenance; lists expose authorized summaries only', async () => {
  const s = await source(),
    id = ulid();
  assert.equal((await service.command(owner.hint, expansion(id, s))).kind, 'succeeded');
  await accept(id);
  const shared = await service.query(editor.hint, query(id));
  assert.equal(
    (shared.entry as { draft: { scenario: { origin: unknown } } }).draft.scenario.origin,
    null,
  );
  assert.equal(JSON.stringify(shared).includes(s.id), false);
  const listed = await service.query(editor.hint, { schemaVersion: 1, requestId: randomUUID() });
  assert.equal(listed.kind, 'succeeded');
  assert.equal(JSON.stringify(listed).includes(s.id), false);
  assert.ok(
    (listed.entries as Record<string, unknown>[]).every(
      (e) => !('draft' in e) && !('ownerId' in e),
    ),
  );
  assert.equal(
    (await service.query(editor.hint, { ...query(id), recipientId: owner.userId })).code,
    'not_found_or_forbidden',
  );
  assert.deepEqual(
    (await service.query(owner.hint, { ...query(id), recipientId: editor.userId })).membership,
    { status: 'active', role: 'editor', revision: 2 },
  );
});
void test(
  'two actual Flutter adapters against Emulator: invite, access, revoke, Expand and durable recovery',
  { timeout: 180000 },
  async () => {
    assert.ok(
      process.env.RECHARGE_DART && process.env.RECHARGE_FLUTTER_TOOL,
      'I2 requires Flutter adapters',
    );
    for (const uid of authUids)
      await getAuth().createUser({
        uid,
        email: uid + '@example.invalid',
        password: 'emulator-only-password-123',
      });
    const result = await new Promise<number>((resolve, reject) => {
      const child = spawn(
        process.env.RECHARGE_DART!,
        [
          process.env.RECHARGE_FLUTTER_TOOL!,
          'test',
          '--no-pub',
          '--dart-define=RECHARGE_TEST_SCENARIO_I2=true',
          'test/backend_local/scenario_i2_client_test.dart',
        ],
        {
          cwd: path.resolve(process.cwd(), '../../mobile'),
          env: {
            ...process.env,
            RECHARGE_I2_LOCAL: '1',
            RECHARGE_I2_OWNER: authUids[0]!,
            RECHARGE_I2_MEMBER: authUids[1]!,
          },
          stdio: ['ignore', 'pipe', 'pipe'],
          shell: false,
        },
      );
      child.stdout.on('data', (b: Buffer) => process.stdout.write(b));
      child.stderr.on('data', (b: Buffer) => process.stderr.write(b));
      child.once('error', reject);
      child.once('close', (code) => resolve(code ?? 1));
    });
    assert.equal(result, 0);
  },
);

void test('edit/delete keeps Scenario CAS, terminal deletion and no replay resurrection in both orders and a race', async () => {
  for (const order of ['edit-first', 'delete-first', 'race']) {
    const id = await create();
    await accept(id);
    const edit = command(editor, id, 'save', 1, {
      generation: 1,
      draft: draft('concurrent edit', 2),
    });
    const del = command(owner, id, 'delete', 1);
    if (order === 'edit-first') {
      assert.equal((await service.command(editor.hint, edit)).kind, 'succeeded');
      assert.equal((await service.command(owner.hint, del)).code, 'revision_conflict');
      assert.equal(
        (await service.command(owner.hint, command(owner, id, 'delete', 2))).kind,
        'succeeded',
      );
    } else if (order === 'delete-first') {
      assert.equal((await service.command(owner.hint, del)).kind, 'succeeded');
      assert.equal((await service.command(editor.hint, edit)).code, 'not_found_or_forbidden');
    } else {
      const results = await Promise.all([
        service.command(editor.hint, edit),
        service.command(owner.hint, del),
      ]);
      assert.equal(results.filter((r) => r.kind === 'succeeded').length, 1);
      if (results[0].kind === 'succeeded')
        assert.equal(
          (await service.command(owner.hint, command(owner, id, 'delete', 2))).kind,
          'succeeded',
        );
    }
    assert.equal((await service.command(editor.hint, edit)).code, 'not_found_or_forbidden');
    const stored = (await db.collection(cols.plans).doc(id).get()).data()!;
    assert.equal(stored.status, 'deleted');
    assert.equal(stored.draft, null);
  }
});
void test('I1/I2 Expand matrix: Scenario roles never grant Quick Plan copy; invited viewer read is not Expand authority', async () => {
  for (const role of ['owner', 'editor', 'viewer']) {
    const collaborative = await create(),
      actor = role === 'owner' ? owner : editor;
    if (role !== 'owner') await service.command(actor.hint, await invite(collaborative, role));
    assert.equal(
      ((await service.query(actor.hint, query(collaborative))).entry as { role: string }).role,
      role,
    );
    const owned = await source(actor),
      target = ulid();
    const before = service.calls;
    const allowed = await service.command(actor.hint, {
      ...expansion(target, owned),
      actorContext: actor.userId,
    });
    assert.equal(
      allowed.kind,
      'succeeded',
      role + ' may expand its own Quick Plan into a new owned Scenario',
    );
    assert.equal(service.calls, before + 1);
    assert.equal(
      ((await service.query(actor.hint, query(target))).entry as { role: string }).role,
      'owner',
    );
    const sourceOwner = actor === owner ? stranger : owner,
      foreign = await source(sourceOwner),
      invitationId = randomUUID();
    const inviteCommand = {
      schemaVersion: 1,
      requestId: randomUUID(),
      ownerContext: sourceOwner.userId,
      idempotencyKey: randomUUID(),
      commandType: 'invite',
      planId: foreign.id,
      expectedRevision: 0,
      planOwnerId: sourceOwner.userId,
      targetUserId: actor.userId,
      invitationId,
      generation: 0,
      previousStatus: 'none',
    };
    assert.equal((await quick.command(sourceOwner.hint, inviteCommand)).kind, 'succeeded');
    const deniedTarget = ulid(),
      attempt = { ...expansion(deniedTarget, foreign), actorContext: actor.userId };
    const writes = service.calls;
    assert.equal(
      (await service.command(actor.hint, attempt)).code,
      'source_unavailable',
      'pending invite conveys no copy authority',
    );
    const acceptCommand = {
      ...inviteCommand,
      requestId: randomUUID(),
      idempotencyKey: randomUUID(),
      ownerContext: actor.userId,
      commandType: 'accept',
      generation: 1,
    };
    delete (acceptCommand as Record<string, unknown>).previousStatus;
    assert.equal((await quick.command(actor.hint, acceptCommand)).kind, 'succeeded');
    assert.equal(
      (
        await quick.query(actor.hint, {
          schemaVersion: 1,
          requestId: randomUUID(),
          planId: foreign.id,
          planOwnerId: sourceOwner.userId,
          invitationId,
          generation: 1,
        })
      ).kind,
      'succeeded',
    );
    assert.equal(
      (await service.command(actor.hint, attempt)).code,
      'source_unavailable',
      'I1 viewer can read but cannot Expand, regardless of Scenario role',
    );
    const revokeCommand = {
      ...inviteCommand,
      requestId: randomUUID(),
      idempotencyKey: randomUUID(),
      commandType: 'revoke',
      generation: 1,
    };
    delete (revokeCommand as Record<string, unknown>).previousStatus;
    assert.equal((await quick.command(sourceOwner.hint, revokeCommand)).kind, 'succeeded');
    assert.equal((await service.command(actor.hint, attempt)).code, 'source_unavailable');
    assert.equal(
      service.calls,
      writes,
      'denied expansion must never invoke the canonical creation writer',
    );
    assert.equal((await db.collection(cols.plans).doc(deniedTarget).get()).exists, false);
  }
});
