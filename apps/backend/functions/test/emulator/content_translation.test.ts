import { spawn } from 'node:child_process';
import path from 'node:path';
import { getAuth } from 'firebase-admin/auth';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { after, before, beforeEach, test } from 'node:test';
import { canonicalJson, sha256Hex } from '../../src/modules/content/domain/published_revision.js';
import { contentCollections } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import {
  contentTranslationCollections as cols,
  contentTranslationStageOneLimits,
  type ContentTranslationLimits,
} from '../../src/modules/content_translation/content_translation_contract.js';
import {
  MockTranslationProvider,
  type TranslationProvider,
  type TranslationProviderRequest,
} from '../../src/modules/content_translation/content_translation_provider.js';
import { FirestoreContentTranslationService } from '../../src/modules/content_translation/firestore_content_translation_service.js';
import { establishEmulatorIdentitySession } from '../../src/modules/identity_publisher/application/emulator_identity_session_service.js';
import {
  contentTranslationFlagIds,
  operationsEmergencySwitchIds,
} from '../../src/shared/feature_flags.js';
import { cleanupBookingEmulator, emulatorFirestore } from '../support/booking_emulator.js';
import { setLocalFlag } from '../support/notifications_world.js';

const db = emulatorFirestore();
const now = new Date();
const clock = { now: () => now };
const names = [
  ...Object.values(cols),
  contentCollections.pointers,
  contentCollections.publishedRevisions,
  'contentSafetyHolds',
];

async function clear() {
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

class SpyProvider implements TranslationProvider {
  readonly providerRef = 'spy';
  readonly engineRevision = 'spy-1';
  readonly rateMinorPerMillionChars = 1000;
  readonly currency = 'EUR';
  readonly calls: TranslationProviderRequest[] = [];
  answer: (request: TranslationProviderRequest) => Promise<unknown> = (request) =>
    new MockTranslationProvider().translate(request);
  translate(request: TranslationProviderRequest): Promise<unknown> {
    this.calls.push(request);
    return this.answer(request);
  }
}

const publisherId = randomUUID();
const secretField = 'SECRET-TERMS-TEXT';
const baseBody = {
  title: 'Atvērto durvju diena',
  shortDescription: 'Nāc ciemos un raksti host@example.com vai zvani +371 2000 0000.',
  fullDescription: 'Pilns apraksts par notikumu ar pietiekami garu tekstu lasītājam.',
  contentLocale: 'lv',
  visibility: 'public',
  cancellationPolicy: secretField,
  safetyNotice: secretField,
  venueName: secretField,
};

async function publish(
  typeId = 'place',
  body: Record<string, unknown> = baseBody,
  contentId: string = randomUUID(),
) {
  const revisionId = randomUUID();
  await db
    .collection(contentCollections.publishedRevisions)
    .doc(revisionId)
    .set({
      contentId,
      publishedRevisionId: revisionId,
      typeId,
      marketId: 'LV',
      publisherRef: { type: 'user', id: publisherId },
      body,
      bodyHash: sha256Hex(canonicalJson(body)),
    });
  await db.collection(contentCollections.pointers).doc(contentId).set({
    contentId,
    currentPublishedRevisionId: revisionId,
    visibility: 'visible',
    revision: 1,
  });
  return { contentId, revisionId };
}

async function reader(firebaseUid = 'translation-' + randomUUID()) {
  const installationId = randomUUID();
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

const ask = (target: { contentId: string; revisionId: string }, targetLocale = 'ru') => ({
  schemaVersion: 1,
  requestId: randomUUID(),
  contentId: target.contentId,
  publishedRevisionId: target.revisionId,
  targetLocale,
});

const fixtures = () => {
  const provider = new SpyProvider();
  const service = (limits?: Partial<ContentTranslationLimits>) =>
    new FirestoreContentTranslationService(db, clock, provider, {
      ...contentTranslationStageOneLimits,
      waitMs: 20,
      ...limits,
    });
  return { provider, service };
};

const count = async (name: string) => (await db.collection(name).count().get()).data().count;

/** The real Firestore trigger runs in the Functions Emulator of this group. */
async function untilNoEntries(contentId: string) {
  for (let attempt = 0; ; attempt++) {
    const left = await db
      .collection(cols.entries)
      .where('contentId', '==', contentId)
      .count()
      .get();
    if (left.data().count === 0) return;
    assert.ok(attempt < 100, 'the purge trigger did not remove the entries');
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
}

before(async () => {
  await clear();
  await setLocalFlag(db, 'identity.session.establish', true);
});
beforeEach(async () => {
  await clear();
  await setLocalFlag(db, operationsEmergencySwitchIds.contentTranslation, false);
  await setLocalFlag(db, contentTranslationFlagIds.onDemand, true);
});
after(async () => {
  await clear();
  await setLocalFlag(db, contentTranslationFlagIds.onDemand, false);
  await cleanupBookingEmulator(db);
});

void test('off by default: the flag refuses before anything is read or called', async () => {
  await setLocalFlag(db, contentTranslationFlagIds.onDemand, false);
  const { provider, service } = fixtures();
  const { hint } = await reader();
  const target = await publish();
  for (const answer of [
    await service().offer(hint, ask(target)),
    await service().translate(hint, ask(target)),
  ])
    assert.deepEqual(answer, { schemaVersion: 1, kind: 'rejected', code: 'translation_disabled' });
  assert.equal(provider.calls.length, 0);
});

void test('an invalid Session or a request with text is refused', async () => {
  const { provider, service } = fixtures();
  const { hint } = await reader();
  const target = await publish();
  const refused = await service().translate(
    { ...hint, sessionHandle: 'not-a-session' },
    ask(target),
  );
  assert.equal(refused.kind === 'rejected' && refused.code, 'unauthenticated');
  const withText = await service().translate(hint, { ...ask(target), text: 'free translator' });
  assert.equal(withText.kind === 'rejected' && withText.code, 'request_invalid');
  assert.equal(provider.calls.length, 0);
});

void test('translates once, serves the cache free, and only allowlisted fields reach the adapter', async () => {
  const { provider, service } = fixtures();
  const { hint, userId } = await reader();
  const other = await reader();
  const target = await publish();
  const pointerBefore = (
    await db.collection(contentCollections.pointers).doc(target.contentId).get()
  ).data();
  const revisionBefore = (
    await db.collection(contentCollections.publishedRevisions).doc(target.revisionId).get()
  ).data();

  const offer = await service().offer(hint, ask(target));
  assert.equal(offer.kind, 'offered');
  assert.equal(provider.calls.length, 0);

  const first = await service().translate(hint, ask(target));
  assert.equal(first.kind, 'translated');
  if (first.kind !== 'translated') return;
  assert.equal(first.machineTranslated, true);
  assert.equal(first.sourceLocale, 'lv');
  assert.deepEqual(Object.keys(first.fields).sort(), [
    'fullDescription',
    'shortDescription',
    'title',
  ]);
  // Contacts travel as tokens and come back in the answer.
  assert.match(first.fields.shortDescription!, /host@example\.com/u);
  assert.match(first.fields.shortDescription!, /\+371 2000 0000/u);
  assert.equal(provider.calls.length, 1);
  const sent = JSON.stringify(provider.calls[0]);
  assert.doesNotMatch(sent, /host@example\.com|2000 0000/u);
  assert.ok(!sent.includes(secretField), 'a field outside the allowlist reached the adapter');

  const usageBefore = await count(cols.accountUsage);
  const second = await service().translate(other.hint, ask(target));
  assert.deepEqual(second, first);
  assert.equal(provider.calls.length, 1);
  assert.equal(await count(cols.accountUsage), usageBefore, 'a cache hit spends no quota');

  // Original untouched; entries, ledger and budget carry no reader and no text.
  assert.deepEqual(
    (await db.collection(contentCollections.pointers).doc(target.contentId).get()).data(),
    pointerBefore,
  );
  assert.deepEqual(
    (
      await db.collection(contentCollections.publishedRevisions).doc(target.revisionId).get()
    ).data(),
    revisionBefore,
  );
  const entry = (await db.collection(cols.entries).limit(1).get()).docs[0]!.data();
  assert.ok(!JSON.stringify(entry).includes(userId));
  for (const name of [
    cols.costLedger,
    cols.budgets,
    cols.leases,
    cols.accountUsage,
    cols.objectUsage,
  ]) {
    const rows = JSON.stringify((await db.collection(name).get()).docs.map((d) => d.data()));
    assert.ok(!rows.includes('Atvērto'), name);
    assert.ok(!rows.includes('host@example.com'), name);
    assert.ok(!rows.includes('[lv→ru]'), name);
  }
  const ledger = (await db.collection(cols.costLedger).limit(1).get()).docs[0]!.data();
  assert.ok(Number.isSafeInteger(ledger.amountMinor));
  assert.equal(ledger.currency, 'EUR');
});

void test('nothing is logged with the text', async () => {
  const { service } = fixtures();
  const { hint } = await reader();
  const target = await publish();
  const lines: string[] = [];
  const methods = ['log', 'info', 'warn', 'error', 'debug'] as const;
  const originals = methods.map((name) => console[name].bind(console));
  for (const name of methods)
    console[name] = (...args: unknown[]) => void lines.push(JSON.stringify(args));
  try {
    assert.equal((await service().translate(hint, ask(target))).kind, 'translated');
  } finally {
    methods.forEach((name, index) => (console[name] = originals[index]!));
  }
  assert.ok(!lines.join('\n').includes('Atvērto'));
});

void test('hide, restriction and deletion refuse the cache; the real trigger removes the entries', async () => {
  const { service } = fixtures();
  const { hint } = await reader();
  const hidden = await publish();
  assert.equal((await service().translate(hint, ask(hidden))).kind, 'translated');
  await db
    .collection(contentCollections.pointers)
    .doc(hidden.contentId)
    .set({ visibility: 'hidden' }, { merge: true });
  const refused = await service().translate(hint, ask(hidden));
  assert.equal(refused.kind === 'rejected' && refused.code, 'source_unavailable');
  await untilNoEntries(hidden.contentId);

  const restricted = await publish();
  assert.equal((await service().translate(hint, ask(restricted))).kind, 'translated');
  await db.collection('contentSafetyHolds').doc(randomUUID()).set({
    subjectUserId: publisherId,
    contentId: restricted.contentId,
    desired: 'active',
    family: 'contentHide',
    untilUtc: null,
  });
  const safety = await service().translate(hint, ask(restricted));
  assert.equal(safety.kind === 'rejected' && safety.code, 'source_unavailable');
  await untilNoEntries(restricted.contentId);

  // A hold on the whole publisher names no object; its sweep finds the sources.
  const publisherWide = await publish();
  assert.equal((await service().translate(hint, ask(publisherWide))).kind, 'translated');
  await db.collection('contentSafetyHolds').doc(randomUUID()).set({
    subjectUserId: publisherId,
    contentId: null,
    desired: 'active',
    family: 'temporarySuspend',
    untilUtc: null,
  });
  await untilNoEntries(publisherWide.contentId);
  for (const hold of (await db.collection('contentSafetyHolds').get()).docs)
    await hold.ref.delete();

  const deleted = await publish();
  assert.equal((await service().translate(hint, ask(deleted))).kind, 'translated');
  await db.collection(contentCollections.pointers).doc(deleted.contentId).delete();
  const gone = await service().translate(hint, ask(deleted));
  assert.equal(gone.kind === 'rejected' && gone.code, 'source_unavailable');
  await untilNoEntries(deleted.contentId);
});

void test('a new revision never serves the old translation', async () => {
  const { provider, service } = fixtures();
  const { hint } = await reader();
  const old = await publish();
  assert.equal((await service().translate(hint, ask(old))).kind, 'translated');
  const next = await publish('place', { ...baseBody, title: 'Jauns nosaukums' }, old.contentId);
  const stale = await service().translate(hint, ask(old));
  assert.equal(stale.kind === 'rejected' && stale.code, 'revision_changed');
  const fresh = await service().translate(hint, ask(next));
  assert.equal(fresh.kind === 'translated' && fresh.fields.title, '[lv→ru] Jauns nosaukums');
  assert.equal(provider.calls.length, 2);
});

void test('concurrent requests for one key make one provider call', async () => {
  const { provider, service } = fixtures();
  const readers = await Promise.all([reader(), reader(), reader(), reader()]);
  const target = await publish();
  let release: () => void = () => {};
  const gate = new Promise<void>((resolve) => (release = resolve));
  provider.answer = async (request) => {
    await gate;
    return new MockTranslationProvider().translate(request);
  };
  const running = readers.map(({ hint }) => service().translate(hint, ask(target)));
  while (provider.calls.length === 0) await new Promise((resolve) => setTimeout(resolve, 20));
  await new Promise((resolve) => setTimeout(resolve, 100));
  release();
  const answers = await Promise.all(running);
  assert.deepEqual(
    answers.map((answer) => answer.kind),
    ['translated', 'translated', 'translated', 'translated'],
  );
  assert.equal(provider.calls.length, 1);
  assert.equal(await count(cols.accountUsage), 1, 'waiters are not charged');
  assert.equal(await count(cols.leases), 0);
});

void test('a lost worker: an expired lease is replaced and cannot write afterwards', async () => {
  const { provider } = fixtures();
  const { hint } = await reader();
  const target = await publish();
  let later = now;
  const moving = new FirestoreContentTranslationService(
    db,
    { now: () => later },
    provider,
    contentTranslationStageOneLimits,
  );
  let release: () => void = () => {};
  const gate = new Promise<void>((resolve) => (release = resolve));
  provider.answer = async (request) => {
    await gate;
    return new MockTranslationProvider().translate(request);
  };
  const lost = moving.translate(hint, ask(target));
  while (provider.calls.length === 0) await new Promise((resolve) => setTimeout(resolve, 20));
  later = new Date(now.getTime() + contentTranslationStageOneLimits.leaseMs + 1000);
  provider.answer = (request) => new MockTranslationProvider().translate(request);
  assert.equal((await moving.translate(hint, ask(target))).kind, 'translated');
  release();
  const answer = await lost;
  assert.equal(answer.kind === 'rejected' && answer.code, 'provider_unavailable');
  assert.equal(provider.calls.length, 2);
  assert.equal(await count(cols.costLedger), 1);
  const budget = (await db.collection(cols.budgets).limit(1).get()).docs[0]!.data();
  assert.equal(budget.reservedMinor, 0, 'the replaced reservation was released');
});

void test('quota, object limit, budget and kill switch stop before the provider', async () => {
  const { provider, service } = fixtures();
  const { hint } = await reader();
  const first = await publish();
  const second = await publish();
  const limited = service({ accountPerDay: 1 });
  assert.equal((await limited.translate(hint, ask(first))).kind, 'translated');
  const quota = await limited.translate(hint, ask(second));
  assert.equal(quota.kind === 'rejected' && quota.code, 'quota_exceeded');
  assert.equal(provider.calls.length, 1);
  // The cache keeps working past the quota.
  assert.equal((await limited.translate(hint, ask(first))).kind, 'translated');

  const objectLimited = service({ objectPerDay: 1 });
  const stranger = await reader();
  const perObject = await objectLimited.translate(stranger.hint, ask(first, 'en'));
  assert.equal(perObject.kind === 'rejected' && perObject.code, 'quota_exceeded');

  const broke = service({ monthlyCapMinor: 0 });
  const budget = await broke.translate(stranger.hint, ask(second));
  assert.equal(budget.kind === 'rejected' && budget.code, 'budget_exhausted');
  assert.equal(
    (await broke.translate(stranger.hint, ask(first))).kind,
    'translated',
    'the cache keeps working past the budget',
  );
  assert.equal(provider.calls.length, 1);

  await setLocalFlag(db, operationsEmergencySwitchIds.contentTranslation, true);
  const killed = await service().translate(stranger.hint, ask(first));
  assert.equal(killed.kind === 'rejected' && killed.code, 'translation_disabled');
  const offer = await service().offer(stranger.hint, ask(first));
  assert.equal(offer.kind === 'rejected' && offer.code, 'translation_disabled');
  assert.equal(await count(cols.entries), 1, 'the switch keeps the cache');
  assert.equal(provider.calls.length, 1);
});

void test('a provider failure or bad output caches nothing and releases the reservation', async () => {
  const { provider, service } = fixtures();
  const { hint } = await reader();
  const target = await publish();
  for (const bad of [
    () => Promise.reject(new Error('Atvērto provider said no')),
    () => Promise.resolve({ title: '<b>markup</b>' }),
    () => Promise.resolve({ title: 'x', shortDescription: 'tokens lost', fullDescription: 'y' }),
  ]) {
    provider.answer = bad;
    const answer = await service().translate(hint, ask(target));
    assert.deepEqual(answer, { schemaVersion: 1, kind: 'rejected', code: 'provider_unavailable' });
    assert.equal(await count(cols.entries), 0);
    assert.equal(await count(cols.leases), 0);
    assert.equal(await count(cols.costLedger), 0);
    const budget = (await db.collection(cols.budgets).limit(1).get()).docs[0]!.data();
    assert.equal(budget.reservedMinor, 0);
    assert.equal(budget.spentMinor, 0);
  }
  provider.answer = (request) => new MockTranslationProvider().translate(request);
  assert.equal((await service().translate(hint, ask(target))).kind, 'translated');
});

void test('hidden during the provider call: the answer is refused and nothing is kept', async () => {
  const { provider, service } = fixtures();
  const { hint } = await reader();
  const target = await publish();
  provider.answer = async (request) => {
    await db
      .collection(contentCollections.pointers)
      .doc(target.contentId)
      .set({ visibility: 'hidden' }, { merge: true });
    return new MockTranslationProvider().translate(request);
  };
  const answer = await service().translate(hint, ask(target));
  assert.equal(answer.kind === 'rejected' && answer.code, 'source_unavailable');
  assert.equal(await count(cols.entries), 0);
});

void test('Find People, an undeclared language and a wrong target are refused', async () => {
  const { provider, service } = fixtures();
  const { hint } = await reader();
  const findPeople = await service().translate(hint, ask(await publish('find_people')));
  assert.equal(findPeople.kind === 'rejected' && findPeople.code, 'source_unavailable');
  const { contentLocale, ...undeclared } = baseBody;
  void contentLocale;
  const noLocale = await service().translate(hint, ask(await publish('event', undeclared)));
  assert.equal(noLocale.kind === 'rejected' && noLocale.code, 'source_unavailable');
  const target = await publish();
  const same = await service().translate(hint, ask(target, 'lv'));
  assert.equal(same.kind === 'rejected' && same.code, 'same_language');
  const unsupported = await service().offer(hint, ask(target, 'de'));
  assert.equal(unsupported.kind === 'rejected' && unsupported.code, 'unsupported_locale');
  assert.equal(provider.calls.length, 0);
  // Positive control: the same type with a declared language is translated.
  const declared = await service().translate(hint, ask(await publish('event')));
  assert.equal(declared.kind, 'translated');
});

void test(
  'the real Flutter client translates through the Session transport',
  { skip: process.env.RECHARGE_G_MOBILE !== '1' },
  async () => {
    await getAuth().createUser({
      uid: 'stand-user-translation',
      email: 'stand-user-translation@example.invalid',
      password: 'emulator-only-password-123',
    });
    const target = await publish();
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
          '--dart-define=RECHARGE_TEST_CONTENT_TRANSLATION=true',
          'test/backend_local/content_translation_client_test.dart',
        ],
        {
          cwd: path.resolve(process.cwd(), '../../mobile'),
          env: {
            ...process.env,
            RECHARGE_CT_LOCAL: '1',
            RECHARGE_CT_CONTENT_ID: target.contentId,
            RECHARGE_CT_REVISION_ID: target.revisionId,
          },
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

void test('the sweep removes expired entries and counters and keeps live ones', async () => {
  const { service } = fixtures();
  const { hint } = await reader();
  const target = await publish();
  assert.equal((await service().translate(hint, ask(target))).kind, 'translated');
  const keeps = await service().sweep();
  assert.equal(keeps.removed, 0);
  const future = new Date(
    now.getTime() + (contentTranslationStageOneLimits.cacheTtlDays + 1) * 86_400_000,
  );
  const expired = new FirestoreContentTranslationService(
    db,
    { now: () => future },
    new MockTranslationProvider(),
  );
  const swept = await expired.sweep();
  assert.equal(swept.removed, 3);
  assert.equal(await count(cols.entries), 0);
  assert.equal(await count(cols.accountUsage), 0);
  assert.equal(await count(cols.objectUsage), 0);
});
