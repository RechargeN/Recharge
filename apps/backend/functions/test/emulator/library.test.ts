import { spawn } from 'node:child_process';
import path from 'node:path';
import { getAuth } from 'firebase-admin/auth';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { after, before, test } from 'node:test';
import { FirestoreLibraryService } from '../../src/modules/library/firestore_library_service.js';
import { LibraryPrivacyTaskHandler } from '../../src/modules/library/library_privacy_task_handler.js';
import {
  libraryCollections as cols,
  libraryFlagId,
  placeToday,
  parseLibraryCommand,
  type LibraryEntry,
} from '../../src/modules/library/library_contract.js';
import { canonicalJson, sha256Hex } from '../../src/modules/content/domain/published_revision.js';
import { contentCollections } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { establishEmulatorIdentitySession } from '../../src/modules/identity_publisher/application/emulator_identity_session_service.js';
import { PrivacyDomainTaskRunner } from '../../src/modules/privacy_orchestration/application/privacy_domain_task_runner.js';
import { privacyDomainTaskId } from '../../src/modules/privacy_orchestration/application/dispatch_privacy_tasks.js';
import { PrivacyOrchestrationService } from '../../src/modules/privacy_orchestration/application/privacy_orchestration_service.js';
import { FirestorePrivacyOrchestrationRepository } from '../../src/modules/privacy_orchestration/infrastructure/firestore_privacy_orchestration_repository.js';
import { cleanupBookingEmulator, emulatorFirestore } from '../support/booking_emulator.js';
import { setLocalFlag } from '../support/notifications_world.js';

const db = emulatorFirestore();
const now = new Date();
const service = new FirestoreLibraryService(db, { now: () => now });
const placeId = randomUUID(),
  eventId = randomUUID();
const names = [
  ...Object.values(cols),
  'privacyRequests',
  'privacyDomainTasks',
  contentCollections.pointers,
  contentCollections.publishedRevisions,
];
async function cleanup() {
  for (const name of names) {
    for (;;) {
      const page = await db.collection(name).limit(200).get();
      if (page.empty) break;
      const batch = db.batch();
      page.docs.forEach((d) => batch.delete(d.ref));
      await batch.commit();
    }
  }
}
async function target(id: string, typeId: string, timezoneId = 'Europe/Riga') {
  const revisionId = randomUUID();
  const body = {
    title: 'Synthetic library target',
    visibility: 'public',
    location: { timezoneId },
  };
  await db
    .collection(contentCollections.publishedRevisions)
    .doc(revisionId)
    .set({
      contentId: id,
      publishedRevisionId: revisionId,
      typeId,
      marketId: 'LV',
      body,
      bodyHash: sha256Hex(canonicalJson(body)),
    });
  await db.collection(contentCollections.pointers).doc(id).set({
    contentId: id,
    currentPublishedRevisionId: revisionId,
    visibility: 'visible',
    revision: 1,
  });
}
async function identity(firebaseUid: string, installationId: string) {
  const session = await establishEmulatorIdentitySession({
    firestore: db,
    firebaseUid,
    installationId,
    attemptRequestId: randomUUID(),
    now,
  });
  return {
    userId: session.userId,
    hint: {
      firebaseUid,
      sessionId: session.sessionId,
      sessionHandle: session.sessionHandle,
      installationId,
    },
  };
}
function command(type: string, revision = 0, id = placeId, key = randomUUID(), day?: string) {
  return {
    schemaVersion: 1,
    requestId: randomUUID(),
    ownerContext: a?.userId,
    idempotencyKey: key,
    commandType: type,
    payload: {
      objectId: id,
      objectType: id === eventId ? 'event' : 'place',
      expectedRevision: revision,
      proposedEntryId: randomUUID(),
      ...(day ? { visitedOn: day } : {}),
    },
  };
}
function query(afterRevision = 0, expectedOwnerRevision?: number, limit = 100) {
  return {
    schemaVersion: 1,
    requestId: randomUUID(),
    afterRevision,
    limit,
    ...(expectedOwnerRevision === undefined ? {} : { expectedOwnerRevision }),
  };
}
let a: Awaited<ReturnType<typeof identity>>, b: typeof a, other: typeof a;
before(async () => {
  await cleanupBookingEmulator(db);
  await cleanup();
  await setLocalFlag(db, libraryFlagId, true);
  await setLocalFlag(db, 'identity.session.establish', true);
  a = await identity('library-owner', 'library-client-a');
  b = await identity('library-owner', 'library-client-b');
  other = await identity('library-other', 'library-client-other');
  assert.equal(a.userId, b.userId);
  await target(placeId, 'place');
  await target(eventId, 'event');
});
after(async () => {
  await cleanup();
  await cleanupBookingEmulator(db);
});

void test('two independent API clients converge; retries do not duplicate or resurrect', async () => {
  const add = command('addFavorite');
  const first = await service.command(a.hint, add);
  assert.equal(first.kind, 'succeeded');
  assert.deepEqual(await service.command(b.hint, { ...add, requestId: randomUUID() }), first);
  const page = await service.query(b.hint, query());
  assert.equal((page.entries as LibraryEntry[]).length, 1);
  assert.equal((await service.query(other.hint, query())).entries instanceof Array, true);
  assert.deepEqual((await service.query(other.hint, query())).entries, []);
  const removed = await service.command(b.hint, command('removeFavorite', 1));
  assert.equal(removed.kind, 'succeeded');
  const delta = await service.query(a.hint, query(1));
  assert.equal((delta.entries as LibraryEntry[])[0]!.status, 'removed');
  assert.deepEqual(await service.command(a.hint, add), first);
  assert.equal((await service.command(a.hint, command('addFavorite'))).code, 'revision_conflict');
  assert.equal(
    (
      await service.command(a.hint, {
        ...add,
        payload: { ...add.payload, objectId: eventId, objectType: 'event' },
      })
    ).code,
    'idempotency_conflict',
  );
  assert.equal((await service.command(a.hint, command('addFavorite', 2))).kind, 'succeeded');
});

void test('simultaneous add/remove at the same revision commits exactly one deterministic revision', async () => {
  const results = await Promise.all([
    service.command(a.hint, command('removeFavorite', 3)),
    service.command(b.hint, command('addFavorite', 3)),
  ]);
  // Same-state add may be a no-op; removal always wins over a stale delayed add.
  assert.ok(results.every((r) => r.kind === 'succeeded' || r.code === 'revision_conflict'));
  const page = await service.query(a.hint, query());
  const entry = (page.entries as LibraryEntry[])[0]!;
  assert.equal(entry.status, 'removed');
  assert.equal(entry.revision, 4);
  assert.equal(
    (await service.command(b.hint, command('addFavorite', 3))).code,
    'revision_conflict',
  );
});

void test('explicit visits only, same day dedupe, different days, place timezone and no automatic visit', async () => {
  const day = '2026-01-01';
  const c = command('recordVisit', 0, placeId, randomUUID(), day);
  const first = await service.command(a.hint, c);
  assert.equal(first.kind, 'succeeded');
  assert.equal((first.entry as LibraryEntry).evidence, 'selfReported');
  assert.equal((first.entry as LibraryEntry).timezoneId, 'Europe/Riga');
  assert.deepEqual(await service.command(b.hint, c), first);
  assert.equal(
    (await service.command(b.hint, command('recordVisit', 1, placeId, randomUUID(), day))).kind,
    'succeeded',
  );
  assert.equal(
    (await service.command(a.hint, command('recordVisit', 0, placeId, randomUUID(), '2026-01-02')))
      .kind,
    'succeeded',
  );
  assert.equal(
    (await service.command(a.hint, command('recordVisit', 0, placeId, randomUUID(), '2999-01-01')))
      .code,
    'visit_date_future',
  );
  assert.equal(
    (await service.command(a.hint, command('recordVisit', 0, eventId, randomUUID(), day))).code,
    'request_invalid',
  );
  assert.equal(
    (await service.command(a.hint, { ...c, commandType: 'bookingConfirmed' })).code,
    'request_invalid',
  );
  assert.equal(
    (
      await service.command(a.hint, {
        ...c,
        payload: { ...c.payload, evidence: 'attendanceConfirmed' },
      })
    ).code,
    'request_invalid',
  );
  const entries = (await service.query(a.hint, query())).entries as LibraryEntry[];
  assert.equal(entries.filter((e) => e.kind === 'visit').length, 2);
  assert.equal(placeToday(new Date('2026-07-21T22:00:00Z'), 'Europe/Riga'), '2026-07-22');
  assert.equal(placeToday(new Date('2026-07-21T02:00:00Z'), 'America/Los_Angeles'), '2026-07-20');
  assert.equal(placeToday(new Date('2026-10-25T01:30:00Z'), 'Europe/Riga'), '2026-10-25');
  assert.equal(
    parseLibraryCommand(command('recordVisit', 0, placeId, randomUUID(), '2026-02-30')),
    null,
  );
});

void test('page revision pin fails closed on concurrent writes, tombstones remain in deltas', async () => {
  const page = await service.query(a.hint, query(0, undefined, 1));
  assert.equal(page.hasMore, true);
  await service.command(b.hint, command('addFavorite', 0, eventId));
  assert.equal(
    (await service.query(a.hint, query(Number(page.nextRevision), Number(page.ownerRevision), 1)))
      .code,
    'snapshot_changed',
  );
  assert.equal(
    (await service.query(a.hint, { ...query(), ownerId: other.userId })).code,
    'request_invalid',
  );
});

void test('default-off flag, forged session, stale session and unavailable objects fail closed', async () => {
  await setLocalFlag(db, libraryFlagId, false);
  assert.equal((await service.query(a.hint, query())).code, 'feature_disabled');
  await setLocalFlag(db, libraryFlagId, true);
  await setLocalFlag(db, 'identity.session.establish', true);
  assert.equal(
    (await service.command({ ...a.hint, sessionHandle: 'forged' }, command('addFavorite'))).code,
    'unauthenticated',
  );
  const missing = command('addFavorite', 0, randomUUID());
  assert.equal((await service.command(a.hint, missing)).code, 'object_unavailable');
  assert.equal(
    (await service.command(a.hint, { ...missing, ownerId: other.userId })).code,
    'request_invalid',
  );
});

void test('Privacy runner links erasure to completion, fences in-flight writers and removes receipts', async () => {
  const subject = await identity('library-dsr', 'library-dsr-a');
  const c = { ...command('addFavorite'), ownerContext: subject.userId };
  assert.equal((await service.command(subject.hint, c)).kind, 'succeeded');
  const handler = new LibraryPrivacyTaskHandler(db);
  assert.equal(
    (await handler.handle({ taskType: 'access', subjectId: subject.userId })).kind,
    'succeeded',
  );
  const repository = new FirestorePrivacyOrchestrationRepository(db);
  const orchestration = new PrivacyOrchestrationService(repository, repository, repository);
  const runner = new PrivacyDomainTaskRunner(db, repository, orchestration);
  const requestId = randomUUID(),
    time = now.toISOString();
  assert.equal(
    (
      await orchestration.submit({
        requestId,
        subjectId: subject.userId,
        requestType: 'erasure',
        idempotencyKey: randomUUID(),
        semanticHash: 'sha256:' + 'd'.repeat(64),
        requiredDomainIds: ['library'],
        occurredAtUtc: time,
      })
    ).ok,
    true,
  );
  await orchestration.verify(requestId, 1, time);
  await orchestration.dispatch(
    requestId,
    2,
    [{ domainId: 'library', marketId: 'LV', targetRevision: 1 }],
    time,
  );
  const run = () =>
    runner.runLibraryTask({
      requestId,
      taskId: privacyDomainTaskId(requestId, 'library', 'LV', 1),
      nowUtc: time,
    });
  const [result] = await Promise.all([
    run(),
    service.command(subject.hint, {
      ...command('addFavorite', 0, eventId),
      ownerContext: subject.userId,
    }),
  ]);
  assert.equal(result, 'succeeded');
  assert.equal(await run(), 'succeeded');
  const reconciled = await orchestration.reconcile(requestId, 3, time);
  assert.ok(reconciled.ok && reconciled.request.status === 'completed');
  for (const name of [cols.entries, cols.receipts])
    assert.equal(
      (await db.collection(name).where('ownerId', '==', subject.userId).get()).empty,
      true,
    );
  assert.notEqual((await service.command(subject.hint, c)).kind, 'succeeded');
  assert.equal(
    (await handler.handle({ taskType: 'erasure', subjectId: subject.userId })).kind,
    'succeeded',
  );
  // Another owner's history is untouched.
  assert.ok(((await service.query(a.hint, query())).entries as LibraryEntry[]).length >= 3);
});

void test('restriction fences writes independently of Identity account changes', async () => {
  await new LibraryPrivacyTaskHandler(db).handle({
    taskType: 'restriction',
    subjectId: other.userId,
  });
  assert.equal(
    (await service.command(other.hint, { ...command('addFavorite'), ownerContext: other.userId }))
      .code,
    'processing_restricted',
  );
});

void test('two HTTP callable clients share one owner and observe each other; direct Firestore remains denied', async () => {
  const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST!;
  const signed = await fetch(
    'http://' + authHost + '/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key',
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ returnSecureToken: true }),
    },
  );
  assert.equal(signed.status, 200);
  const auth = (await signed.json()) as { idToken: string; localId: string };
  async function client(install: string) {
    const session = await identity(auth.localId, install);
    return async (surface: string, data: unknown) => {
      const response = await fetch('http://127.0.0.1:5001/demo-recharge/europe-west1/' + surface, {
        method: 'POST',
        headers: { authorization: 'Bearer ' + auth.idToken, 'content-type': 'application/json' },
        body: JSON.stringify({
          data: {
            ...(data as object),
            ...(surface === 'libraryCommandV1' ? { ownerContext: session.userId } : {}),
            sessionContext: {
              sessionId: session.hint.sessionId,
              sessionHandle: session.hint.sessionHandle,
              installationId: install,
            },
          },
        }),
      });
      assert.equal(response.status, 200, await response.clone().text());
      const body = (await response.json()) as { result: Record<string, unknown> };
      return body.result;
    };
  }
  const clientA = await client('library-http-a'),
    clientB = await client('library-http-b');
  const added = await clientA('libraryCommandV1', command('addFavorite'));
  assert.equal(added.kind, 'succeeded', JSON.stringify(added));
  const page = await clientB('libraryQueryV1', query());
  assert.equal((page.entries as LibraryEntry[])[0]!.status, 'active');
  await clientB('libraryCommandV1', command('removeFavorite', 1));
  const delta = await clientA('libraryQueryV1', query(1));
  assert.equal((delta.entries as LibraryEntry[])[0]!.status, 'removed');
  const direct = await fetch(
    'http://' +
      process.env.FIRESTORE_EMULATOR_HOST +
      '/v1/projects/demo-recharge/databases/(default)/documents/' +
      cols.entries +
      '/probe',
    {
      method: 'PATCH',
      headers: { authorization: 'Bearer ' + auth.idToken, 'content-type': 'application/json' },
      body: JSON.stringify({ fields: { ownerId: { stringValue: 'forged' } } }),
    },
  );
  assert.ok([401, 403].includes(direct.status));
});

void test(
  'real Flutter repositories synchronize with independent transport sessions',
  {
    skip: process.env.RECHARGE_G_MOBILE !== '1',
  },
  async () => {
    await getAuth().createUser({
      uid: 'stand-user-library-g',
      email: 'stand-user-library-g@example.invalid',
      password: 'emulator-only-password-123',
    });
    const dart = process.env.RECHARGE_DART;
    const flutterTool = process.env.RECHARGE_FLUTTER_TOOL;
    assert.ok(dart && flutterTool, 'Set the local Dart executable and Flutter tool snapshot');
    const result = await new Promise<number>((resolve, reject) => {
      const child = spawn(
        dart,
        [
          flutterTool,
          'test',
          '--no-pub',
          '--dart-define=RECHARGE_TEST_LIBRARY=true',
          'test/backend_local/library_client_test.dart',
        ],
        {
          cwd: path.resolve(process.cwd(), '../../mobile'),
          env: { ...process.env, RECHARGE_G_LOCAL: '1', RECHARGE_G_PLACE_ID: placeId },
          stdio: ['ignore', 'pipe', 'pipe'],
          shell: false,
        },
      );
      child.stdout.on('data', (data: Buffer) => process.stdout.write(data));
      child.stderr.on('data', (data: Buffer) => process.stderr.write(data));
      child.once('error', reject);
      child.once('close', (code) => resolve(code ?? 1));
    });
    assert.equal(result, 0);
  },
);
