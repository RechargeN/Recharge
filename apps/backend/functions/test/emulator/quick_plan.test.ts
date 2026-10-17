import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { spawn } from 'node:child_process';
import path from 'node:path';
import { before, after, test } from 'node:test';
import { getAuth } from 'firebase-admin/auth';
import { canonicalJson, sha256Hex } from '../../src/modules/content/domain/published_revision.js';
import { catalogCollections } from '../../src/modules/catalog/infrastructure/firestore_catalog_repository.js';
import { contentCollections } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { FirestoreQuickPlanService } from '../../src/modules/quick_plan/firestore_quick_plan_service.js';
import {
  quickPlanCollections as cols,
  quickPlanFlag,
  parseCommand,
} from '../../src/modules/quick_plan/quick_plan_contract.js';
import { establishEmulatorIdentitySession } from '../../src/modules/identity_publisher/application/emulator_identity_session_service.js';
import { cleanupBookingEmulator, emulatorFirestore } from '../support/booking_emulator.js';
import { setLocalFlag } from '../support/notifications_world.js';

const db = emulatorFirestore(),
  now = new Date();
const service = new FirestoreQuickPlanService(db, { now: () => now });
async function identity(uid: string, installationId: string) {
  const s = await establishEmulatorIdentitySession({
    firestore: db,
    firebaseUid: uid,
    installationId,
    attemptRequestId: randomUUID(),
    now,
  });
  return {
    userId: s.userId,
    hint: {
      firebaseUid: uid,
      sessionId: s.sessionId,
      sessionHandle: s.sessionHandle,
      installationId,
    },
  };
}
let a: Awaited<ReturnType<typeof identity>>, b: typeof a, other: typeof a;
const uid = 'i1-' + randomUUID(),
  foreignUid = 'i1-' + randomUUID();
let protectedDigest: string;
async function sideEffectDigest() {
  const values = [];
  for (const name of [
    ...Object.values(catalogCollections),
    ...Object.values(contentCollections),
    'scenarios',
    'scenarioRevisions',
  ]) {
    const docs = await db.collection(name).get();
    values.push([name, docs.docs.map((d) => [d.id, d.data()]).sort()]);
  }
  return sha256Hex(canonicalJson(values));
}
async function cleanup() {
  for (const name of Object.values(cols)) {
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
  await setLocalFlag(db, quickPlanFlag, true);
  await setLocalFlag(db, 'identity.session.establish', true);
  a = await identity(uid + '-backend', 'i1-backend-a');
  b = await identity(uid + '-backend', 'i1-backend-b');
  other = await identity(foreignUid + '-backend', 'i1-other');
  protectedDigest = await sideEffectDigest();
});
after(async () => {
  try {
    assert.equal(
      await sideEffectDigest(),
      protectedDigest,
      'I1 must not mutate Catalog, Content or Scenario',
    );
  } finally {
    await cleanup();
    await cleanupBookingEmulator(db);
    for (const id of [uid, foreignUid]) {
      try {
        await getAuth().deleteUser(id);
      } catch (e) {
        if ((e as { code?: string }).code !== 'auth/user-not-found') throw e;
      }
    }
    process.stdout.write(
      'I1 cleanup verified: plans/receipts empty; owned Auth users deleted; Identity/flags cleared.\n',
    );
  }
});
function plan(id = randomUUID(), prompt = 'initial') {
  return {
    id,
    revision: 0,
    mood: 'calm',
    maxDurationMinutes: 150,
    freeOnly: false,
    walkingOnly: true,
    sourcePrompt: prompt,
    currencyCode: 'EUR',
    steps: [],
  };
}
function command(p: ReturnType<typeof plan>, revision = 0, type = 'save', key = randomUUID()) {
  return {
    schemaVersion: 1,
    requestId: randomUUID(),
    ownerContext: a.userId,
    idempotencyKey: key,
    commandType: type,
    planId: p.id,
    expectedRevision: revision,
    ...(type === 'delete' ? {} : { plan: p }),
  };
}
function query(id: string) {
  return { schemaVersion: 1, requestId: randomUUID(), planId: id };
}
void test('edit/edit both orders: first commit wins and stale edit explicitly conflicts', async () => {
  for (const reverse of [false, true]) {
    const p = plan();
    assert.equal((await service.command(a.hint, command(p))).kind, 'succeeded');
    const edits = [
      command({ ...p, sourcePrompt: 'A' }, 1),
      command({ ...p, sourcePrompt: 'B' }, 1),
    ];
    const first = reverse ? 1 : 0,
      second = 1 - first;
    assert.equal((await service.command(first ? a.hint : b.hint, edits[first]!)).kind, 'succeeded');
    assert.equal(
      (await service.command(second ? a.hint : b.hint, edits[second]!)).code,
      'revision_conflict',
    );
    const r = await service.query(a.hint, query(p.id));
    assert.equal(
      (r.entry as { plan: { sourcePrompt: string } }).plan.sourcePrompt,
      first ? 'B' : 'A',
    );
  }
});
void test('delete wins either order; offline edit, old command and import cannot resurrect', async () => {
  for (const deleteFirst of [false, true]) {
    const p = plan(),
      create = command(p);
    await service.command(a.hint, create);
    const edit = command({ ...p, sourcePrompt: 'offline' }, 1),
      del = command(p, 1, 'delete');
    if (deleteFirst) {
      await service.command(b.hint, del);
      assert.equal((await service.command(a.hint, edit)).code, 'deleted');
    } else {
      await service.command(a.hint, edit);
      assert.equal((await service.command(b.hint, del)).kind, 'succeeded');
    }
    assert.equal((await service.command(a.hint, create)).kind, 'succeeded');
    assert.equal((await service.command(a.hint, command(p, 0, 'import'))).code, 'deleted');
    const current = (await service.query(a.hint, query(p.id))).entry as Record<string, unknown>;
    assert.equal(current.status, 'deleted');
    assert.equal(current.plan, undefined);
  }
});
void test('lost response, stable import retry, collision and strict contract', async () => {
  const p = plan(),
    c = command(p, 0, 'import');
  const saved = await service.command(a.hint, c);
  assert.deepEqual(await service.command(b.hint, { ...c, requestId: randomUUID() }), saved);
  assert.equal(
    (await service.command(a.hint, { ...c, plan: { ...p, sourcePrompt: 'changed' } })).code,
    'idempotency_conflict',
  );
  assert.equal((await service.command(a.hint, command(p, 0, 'import'))).code, 'id_collision');
  for (const invalid of [
    { ...c, schemaVersion: 2 },
    { ...c, owner: true },
    { ...c, plan: { ...p, invited: true } },
    { ...c, plan: { ...p, steps: [{}] } },
  ])
    assert.equal(parseCommand(invalid), null);
});
void test('private queries, forged owner/invite claims and session expiry fail closed', async () => {
  const p = plan();
  await service.command(a.hint, command(p));
  assert.equal((await service.query(other.hint, query(p.id))).entry, null);
  assert.equal((await service.command(other.hint, command(p, 1))).code, 'owner_changed');
  assert.equal(
    (await service.query(other.hint, { ...query(p.id), ownerId: a.userId, invited: true })).code,
    'request_invalid',
  );
  const entry = (await service.query(a.hint, query(p.id))).entry as Record<string, unknown>;
  assert.deepEqual(
    Object.keys(entry).sort(),
    ['plan', 'planId', 'revision', 'status', 'updatedAtUtc'].sort(),
  );
  assert.equal(
    (await service.query({ ...a.hint, sessionHandle: 'forged' }, query(p.id))).code,
    'unauthenticated',
  );
  const sessionRef = db.collection('identitySessions').doc(b.hint.sessionId);
  const session = (await sessionRef.get()).data()!;
  await sessionRef.update({ idleExpiresAtUtc: '2020-01-01T00:00:00.000Z' });
  try {
    assert.equal((await service.command(b.hint, command(p, 1))).code, 'unauthenticated');
  } finally {
    await sessionRef.set(session);
  }
});
void test(
  'two real Flutter adapters: offline queue, restart, auth and import recovery',
  { timeout: 150000 },
  async () => {
    const dart = process.env.RECHARGE_DART,
      flutter = process.env.RECHARGE_FLUTTER_TOOL;
    assert.ok(
      dart && flutter,
      'I1 requires real Flutter adapters: set RECHARGE_DART and RECHARGE_FLUTTER_TOOL',
    );
    for (const id of [uid, foreignUid])
      await getAuth().createUser({
        uid: id,
        email: id + '@example.invalid',
        password: 'emulator-only-password-123',
      });
    const result = await new Promise<number>((resolve, reject) => {
      const child = spawn(
        dart,
        [
          flutter,
          'test',
          '--no-pub',
          '--dart-define=RECHARGE_TEST_QUICK_PLAN=true',
          'test/backend_local/quick_plan_client_test.dart',
        ],
        {
          cwd: path.resolve(process.cwd(), '../../mobile'),
          env: {
            ...process.env,
            RECHARGE_I1_LOCAL: '1',
            RECHARGE_I1_UID: uid,
            RECHARGE_I1_OTHER_UID: foreignUid,
          },
          stdio: ['ignore', 'pipe', 'pipe'],
          shell: false,
        },
      );
      child.stdout.on('data', (d: Buffer) => process.stdout.write(d));
      child.stderr.on('data', (d: Buffer) => process.stderr.write(d));
      child.once('error', reject);
      child.once('close', (code) => resolve(code ?? 1));
    });
    assert.equal(result, 0);
  },
);
