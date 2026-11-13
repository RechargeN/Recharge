/**
 * L3 — minimized product analytics (ANALYTICS_L3_PRODUCT_ANALYTICS_AMENDMENT.md
 * §12). The real ingress, aggregation, retention and reader over the Firestore
 * Emulator with a synthetic, test-only policy and consent port; the L1 DSR
 * runner and the L2 operations console as they are. No network destination,
 * SDK or trigger is involved. Every document this file creates is removed in
 * `after` and the removal is verified.
 */
import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { after, before, beforeEach, test } from 'node:test';
import type { Firestore } from 'firebase-admin/firestore';

import { establishEmulatorIdentitySession } from '../../src/modules/identity_publisher/application/emulator_identity_session_service.js';
import { identityAuthorityCollections as identity } from '../../src/modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import {
  grantOperationsAuthority,
  operationsCollections,
} from '../../src/modules/operations/operations_console.js';
import { privacyDomainTaskId } from '../../src/modules/privacy_orchestration/application/dispatch_privacy_tasks.js';
import { PrivacyDomainTaskRunner } from '../../src/modules/privacy_orchestration/application/privacy_domain_task_runner.js';
import { PrivacyOrchestrationService } from '../../src/modules/privacy_orchestration/application/privacy_orchestration_service.js';
import { FirestorePrivacyOrchestrationRepository } from '../../src/modules/privacy_orchestration/infrastructure/firestore_privacy_orchestration_repository.js';
import {
  FirestoreProductAnalyticsService,
  grantProductAnalyticsAccess,
  productAnalyticsAccessActions as actions,
  type ProductAnalyticsIngestResult,
  type ProductAnalyticsReader,
} from '../../src/modules/product_analytics/firestore_product_analytics_service.js';
import { productAnalyticsCollections as cols } from '../../src/modules/product_analytics/product_analytics_contract.js';
import type {
  ProductAnalyticsCollectionPolicy,
  ProductAnalyticsConsentState,
} from '../../src/modules/product_analytics/product_analytics_policy.js';
import {
  featureFlagKey,
  featureFlagPointerCollection,
  featureFlagRevisionCollection,
} from '../../src/platform/config/feature_flag_repository.js';
import { FirestoreAbuseRateLimiter } from '../../src/platform/security/firestore_abuse_rate_limiter.js';
import { createEmulatorOperationsConsole } from '../../src/operations_entry.js';
import { productAnalyticsFlagIds } from '../../src/shared/feature_flags.js';
import type { BookingAccessHint } from '../../src/shared/booking_access_authority.js';
import { emulatorFirestore } from '../support/booking_emulator.js';
import { FakeClock } from '../support/fake_clock.js';
import { setLocalFlag } from '../support/notifications_world.js';

const db: Firestore = emulatorFirestore();
const T0 = '2026-10-25T12:00:00.000Z';
const DAY = '2026-10-25';
const HOUR = '2026-10-25T11:00:00.000Z';
const hours = (n: number) => new Date(Date.parse(T0) + n * 3_600_000);
const clock = new FakeClock(new Date(T0));
const marker = 'L3SYNTH';

/** TEST-ONLY synthetic policy: invented numbers, not a product decision (PA-B01…B03). */
function syntheticPolicy(
  overrides: Partial<ProductAnalyticsCollectionPolicy> = {},
): ProductAnalyticsCollectionPolicy {
  return {
    policyRevision: 'synthetic-l3-policy-1',
    purposeId: 'product_usage_measurement',
    marketId: 'LV',
    legalBasisRef: 'synthetic-test-only-basis',
    consentRequired: true,
    eventNames: ['details_opened', 'favorite_added', 'create_publish_finished'],
    rawRetentionHours: 48,
    aggregateRetentionHours: 72,
    acceptanceWindowHours: 24,
    queueMaxAgeHours: 24,
    effectiveFromUtc: '2026-10-01T00:00:00.000Z',
    expiresAtUtc: '2026-12-01T00:00:00.000Z',
    source: 'synthetic-test-only',
    ...overrides,
  };
}

let policy: ProductAnalyticsCollectionPolicy | null = syntheticPolicy();
/** Server-side consent truth of the test; keyed by userId. */
const consent = new Map<string, ProductAnalyticsConsentState>();
const service = new FirestoreProductAnalyticsService(
  db,
  clock,
  { effective: () => policy },
  { state: (userId) => Promise.resolve(consent.get(userId) ?? 'unknown') },
);

const corpus = JSON.parse(
  readFileSync(
    path.resolve(
      process.cwd(),
      '../../../packages/api_contracts/schema/product_analytics/v1/fixtures/product_analytics_corpus.v1.json',
    ),
    'utf8',
  ),
) as {
  validEvents: Record<string, unknown>[];
  invalidEvents: {
    case: string;
    patch?: Record<string, unknown>;
    fields?: Record<string, unknown>;
    rawFields?: string;
    eventName?: string;
  }[];
  invalidBatches: { case: string; batch?: Record<string, unknown>; repeatValidEvents?: number }[];
};

const flagKeys = Object.values(productAnalyticsFlagIds).map((flagId) =>
  featureFlagKey('local', 'LV', flagId),
);
const pointersBefore = new Map<string, Record<string, unknown> | undefined>();
/** Identity, security and DSR records the sessions and erasure write. */
const touched = [
  ...Object.values(cols),
  identity.accounts,
  identity.sessions,
  identity.accessSnapshots,
  identity.providerLinks,
  'securityRateLimitCounters',
  'securityRateLimitAttempts',
  'privacyRequests',
  'privacyDomainTasks',
  'privacyTaskProgress',
  operationsCollections.authority,
  operationsCollections.audit,
];

async function clear(names: Iterable<string>): Promise<void> {
  for (const name of names) {
    for (;;) {
      const page = await db.collection(name).limit(300).get();
      if (page.empty) break;
      const batch = db.batch();
      for (const doc of page.docs) batch.delete(doc.ref);
      await batch.commit();
    }
  }
}

async function setFlags(enabled: boolean, only?: string): Promise<void> {
  for (const flagId of Object.values(productAnalyticsFlagIds))
    if (only === undefined || only === flagId) await setLocalFlag(db, flagId, enabled);
}

async function restoreFlags(): Promise<void> {
  const revisions = await db
    .collection(featureFlagRevisionCollection)
    .where('capabilityId', 'in', Object.values(productAnalyticsFlagIds))
    .get();
  for (const doc of revisions.docs) await doc.ref.delete();
  for (const key of flagKeys) {
    const prior = pointersBefore.get(key);
    const ref = db.collection(featureFlagPointerCollection).doc(key);
    if (prior === undefined) await ref.delete();
    else await ref.set(prior);
  }
}

before(async () => {
  for (const key of flagKeys)
    pointersBefore.set(
      key,
      (await db.collection(featureFlagPointerCollection).doc(key).get()).data(),
    );
  await clear(touched);
});
beforeEach(async () => {
  await clear(Object.values(cols));
  clock.set(new Date(T0));
  policy = syntheticPolicy();
  consent.clear();
  await setFlags(true);
});
after(async () => {
  await clear(touched);
  await restoreFlags();
  for (const name of touched)
    assert.equal((await db.collection(name).limit(1).get()).size, 0, name);
  for (const key of flagKeys) {
    const pointer = (await db.collection(featureFlagPointerCollection).doc(key).get()).data();
    assert.deepEqual(pointer, pointersBefore.get(key));
  }
});

let installation = 0;
async function sender(): Promise<{ userId: string; hint: BookingAccessHint }> {
  installation += 1;
  const firebaseUid = `l3-uid-${String(installation)}-${randomUUID().slice(0, 8)}`;
  const installationId = `l3-install-${String(installation)}`;
  const session = await establishEmulatorIdentitySession({
    firestore: db,
    firebaseUid,
    installationId,
    attemptRequestId: randomUUID(),
    now: clock.now(),
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

async function consentingSender() {
  const s = await sender();
  consent.set(s.userId, 'granted');
  return s;
}

function event(
  eventName: 'details_opened' | 'favorite_added' | 'create_publish_finished',
  fields: Record<string, unknown>,
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    eventId: randomUUID(),
    eventName,
    eventVersion: 1,
    occurredAtUtc: HOUR,
    policyRevision: 'synthetic-l3-policy-1',
    fields,
    ...overrides,
  };
}

const batch = (...events: Record<string, unknown>[]) => ({ schemaVersion: 1, events });

function dispositions(result: ProductAnalyticsIngestResult): string[] {
  assert.equal(result.kind, 'processed', JSON.stringify(result));
  return result.kind === 'processed' ? result.results.map((item) => item.disposition) : [];
}

async function stored(): Promise<Record<string, unknown>[]> {
  return (await db.collection(cols.events).get()).docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  }));
}

async function analyticsDump(): Promise<string> {
  const parts: string[] = [];
  for (const name of Object.values(cols))
    for (const doc of (await db.collection(name).get()).docs)
      parts.push(doc.id, JSON.stringify(doc.data()));
  return parts.join('\n');
}

/** Captures everything written to the console while `body` runs. */
async function captureConsole<T>(body: () => Promise<T>): Promise<{ value: T; output: string }> {
  const chunks: string[] = [];
  const methods = ['log', 'info', 'warn', 'error', 'debug'] as const;
  const original = methods.map((name) => console[name].bind(console));
  const write = process.stdout.write.bind(process.stdout);
  const writeErr = process.stderr.write.bind(process.stderr);
  for (const name of methods)
    console[name] = (...args: unknown[]) => void chunks.push(args.map(String).join(' '));
  process.stdout.write = (chunk: unknown) => (chunks.push(String(chunk)), true);
  process.stderr.write = (chunk: unknown) => (chunks.push(String(chunk)), true);
  try {
    return { value: await body(), output: chunks.join('\n') };
  } finally {
    methods.forEach((name, index) => (console[name] = original[index]!));
    process.stdout.write = write;
    process.stderr.write = writeErr;
  }
}

async function reader(
  actionList: readonly string[] | null,
  expiresAtUtc = '2026-11-25T00:00:00.000Z',
) {
  const s = await sender();
  if (actionList !== null)
    await grantProductAnalyticsAccess(db, {
      userId: s.userId,
      actions: actionList as never,
      grantedAtUtc: T0,
      expiresAtUtc,
    });
  return { userId: s.userId, sessionId: s.hint.sessionId } satisfies ProductAnalyticsReader;
}

async function collectionCounts(): Promise<Map<string, number>> {
  const counts = new Map<string, number>();
  for (const ref of await db.listCollections())
    counts.set(ref.id, (await ref.count().get()).data().count);
  return counts;
}

// ------------------------------------------------------------- 1, 9: the path

void test('L3-T-FLOW: producer batch → validation → raw zone → daily aggregate → audited read', async () => {
  const s = await consentingSender();
  const staff = await reader([actions.aggregateRead]);
  const before = await collectionCounts();
  const result = await service.ingest(
    s.hint,
    batch(
      event('details_opened', { object_kind: 'route' }),
      event('details_opened', { object_kind: 'route' }),
      event('favorite_added', { object_kind: 'place', entry_surface: 'map' }),
      event('create_publish_finished', { create_type: 'event', outcome: 'denied' }),
    ),
  );
  assert.deepEqual(dispositions(result), ['accepted', 'accepted', 'accepted', 'accepted']);
  // Stored: day bucket and allowlisted fields only; nothing about the sender.
  for (const record of await stored()) {
    assert.deepEqual(Object.keys(record).sort(), [
      'environmentId',
      'eventName',
      'eventVersion',
      'expiresAtUtc',
      'fields',
      'id',
      'marketId',
      'occurredDayUtc',
      'policyRevision',
      'registryRevision',
      'schemaVersion',
    ]);
    assert.equal(record.occurredDayUtc, DAY);
    assert.equal(record.expiresAtUtc, '2026-10-27T00:00:00.000Z');
    const text = JSON.stringify(record);
    const { firebaseUid, sessionId, sessionHandle, installationId } = s.hint;
    for (const secret of [firebaseUid, sessionId, sessionHandle, installationId, s.userId])
      assert.ok(!text.includes(secret));
  }
  const built = await service.rebuildDailyAggregate(DAY);
  assert.equal(built.kind, 'built');
  assert.equal(built.kind === 'built' && built.sourceEvents, 4);
  const read = await service.readDailyAggregates(staff, DAY, DAY);
  assert.equal(read.kind, 'succeeded');
  assert.deepEqual(read.kind === 'succeeded' && read.days[0]!.rows, [
    {
      eventName: 'create_publish_finished',
      eventVersion: 1,
      fields: { create_type: 'event', outcome: 'denied' },
      count: 1,
    },
    { eventName: 'details_opened', eventVersion: 1, fields: { object_kind: 'route' }, count: 2 },
    {
      eventName: 'favorite_added',
      eventVersion: 1,
      fields: { entry_surface: 'map', object_kind: 'place' },
      count: 1,
    },
  ]);
  // Only the L3 collections changed; no other domain's records were written.
  const afterCounts = await collectionCounts();
  for (const [name, count] of afterCounts)
    if (!name.startsWith('productAnalytics'))
      assert.equal(count, before.get(name) ?? 0, `foreign collection changed: ${name}`);
});

// ------------------------------------------------------- 2: rejection, no trace

void test('L3-T-REJECT: forbidden, unknown and wrong-version input never reaches storage or logs', async () => {
  const s = await consentingSender();
  const base = corpus.validEvents[0]!;
  const byName = (name: string) => corpus.validEvents.find((item) => item.eventName === name)!;
  const invalid = corpus.invalidEvents.map((item) => {
    const start = { ...(item.eventName === undefined ? base : byName(item.eventName)) };
    if (item.patch !== undefined) Object.assign(start, item.patch);
    if (item.fields !== undefined) start.fields = item.fields;
    if (item.rawFields !== undefined) start.fields = JSON.parse(item.rawFields) as unknown;
    // Each invalid event gets its own well-formed ID unless the case is the ID itself.
    if (!item.case.startsWith('event_id')) start.eventId = randomUUID();
    return start;
  });
  const { value, output } = await captureConsole(async () => {
    const results: ProductAnalyticsIngestResult[] = [];
    for (let index = 0; index < invalid.length; index += 19) {
      const valid = event('details_opened', { object_kind: 'place' });
      results.push(await service.ingest(s.hint, batch(valid, ...invalid.slice(index, index + 19))));
    }
    for (const item of corpus.invalidBatches) {
      const raw =
        item.repeatValidEvents !== undefined
          ? batch(
              ...Array.from({ length: item.repeatValidEvents }, () =>
                event('details_opened', { object_kind: 'route' }),
              ),
            )
          : item.case === 'batch_empty' || !Array.isArray(item.batch!.events)
            ? item.batch!
            : { ...item.batch!, events: [event('details_opened', { object_kind: 'route' })] };
      results.push(await service.ingest(s.hint, raw));
    }
    // A batch over the byte limit is refused whole, before any event is read.
    const padded = Array.from({ length: 20 }, () =>
      event(
        'details_opened',
        { object_kind: 'route' },
        { policyRevision: `${marker}`.padEnd(400, 'x') },
      ),
    );
    results.push(await service.ingest(s.hint, batch(...padded)));
    return results;
  });
  const eventResults = value.slice(0, Math.ceil(invalid.length / 19));
  for (const result of eventResults) {
    const items = dispositions(result);
    assert.equal(items[0], 'accepted');
    assert.ok(
      items.slice(1).every((item) => item === 'rejected_schema'),
      JSON.stringify(items),
    );
  }
  // A malformed eventId is never echoed back.
  const echoed = eventResults.flatMap((result) =>
    result.kind === 'processed' ? result.results.map((item) => item.eventId) : [],
  );
  for (const id of echoed) assert.ok(id === null || /^[0-9a-f-]{36}$/u.test(id));
  for (const result of value.slice(eventResults.length))
    assert.deepEqual(result, { kind: 'refused', code: 'batch_invalid' });
  assert.equal((await stored()).length, eventResults.length);
  const dump = await analyticsDump();
  assert.ok(!dump.includes(marker), 'synthetic marker reached storage');
  assert.ok(!dump.includes('polluted'));
  assert.ok(!output.includes(marker), 'synthetic marker reached a log');
  assert.equal(Object.prototype.hasOwnProperty.call({}, 'polluted'), false);
});

// ---------------------------------------- 3: disable, opt-out, consent, policy

void test('L3-T-CONSENT: no policy, disabled flag, absent or withdrawn consent store nothing', async () => {
  const s = await sender();
  const sample = () => batch(event('details_opened', { object_kind: 'route' }));
  // The production default: no accepted policy and no consent source.
  const production = new FirestoreProductAnalyticsService(db, clock);
  assert.deepEqual(await production.ingest(s.hint, sample()), {
    kind: 'refused',
    code: 'policy_unavailable',
  });
  // An inconsistent or foreign policy is no policy.
  for (const broken of [
    syntheticPolicy({ acceptanceWindowHours: 48 }),
    syntheticPolicy({ queueMaxAgeHours: 30 }),
    syntheticPolicy({ source: 'production' as never }),
    syntheticPolicy({ expiresAtUtc: T0 }),
    syntheticPolicy({ legalBasisRef: '' }),
  ]) {
    policy = broken;
    assert.deepEqual(await service.ingest(s.hint, sample()), {
      kind: 'refused',
      code: 'policy_unavailable',
    });
  }
  policy = syntheticPolicy();
  // Consent is read from the server port; nothing was granted yet.
  assert.deepEqual(await service.ingest(s.hint, sample()), {
    kind: 'refused',
    code: 'consent_absent',
  });
  consent.set(s.userId, 'granted');
  const retry = sample();
  assert.deepEqual(dispositions(await service.ingest(s.hint, retry)), ['accepted']);
  // Opt-out between a lost response and its retry: the retry is refused, the
  // stored event is not duplicated and nothing new is stored.
  consent.set(s.userId, 'withdrawn');
  assert.deepEqual(await service.ingest(s.hint, retry), {
    kind: 'refused',
    code: 'consent_absent',
  });
  assert.deepEqual(await service.ingest(s.hint, sample()), {
    kind: 'refused',
    code: 'consent_absent',
  });
  assert.equal((await stored()).length, 1);
  // Disabling collection refuses before anything is read for the batch.
  consent.set(s.userId, 'granted');
  await setFlags(false, productAnalyticsFlagIds.collection);
  assert.deepEqual(await service.ingest(s.hint, sample()), {
    kind: 'refused',
    code: 'collection_disabled',
  });
  await setFlags(true, productAnalyticsFlagIds.collection);
  // An event collected under another policy revision, or not in the policy.
  policy = syntheticPolicy({
    policyRevision: 'synthetic-l3-policy-2',
    eventNames: ['favorite_added'],
  });
  assert.deepEqual(
    dispositions(
      await service.ingest(
        s.hint,
        batch(
          event('favorite_added', { object_kind: 'route', entry_surface: 'details' }),
          event(
            'favorite_added',
            { object_kind: 'route', entry_surface: 'details' },
            { policyRevision: 'synthetic-l3-policy-2' },
          ),
          event(
            'details_opened',
            { object_kind: 'route' },
            { policyRevision: 'synthetic-l3-policy-2' },
          ),
        ),
      ),
    ),
    ['rejected_policy', 'accepted', 'rejected_policy'],
  );
  // A policy that does not require consent still needs a current Session.
  policy = syntheticPolicy({ consentRequired: false });
  assert.deepEqual(await service.ingest({ ...s.hint, sessionHandle: 'A'.repeat(43) }, sample()), {
    kind: 'refused',
    code: 'unauthenticated',
  });
  assert.equal((await stored()).length, 2);
});

void test('L3-T-LATE: events outside the acceptance window or from the future are not stored', async () => {
  const s = await consentingSender();
  assert.deepEqual(
    dispositions(
      await service.ingest(
        s.hint,
        batch(
          event(
            'details_opened',
            { object_kind: 'route' },
            { occurredAtUtc: '2026-10-25T13:00:00.000Z' },
          ),
          event(
            'details_opened',
            { object_kind: 'route' },
            { occurredAtUtc: '2026-10-24T11:00:00.000Z' },
          ),
          event(
            'details_opened',
            { object_kind: 'route' },
            { occurredAtUtc: '2026-10-24T12:00:00.000Z' },
          ),
        ),
      ),
    ),
    ['rejected_late', 'rejected_late', 'accepted'],
  );
});

void test('L3-T-DSR: after erasure or restriction a replayed buffer is refused and rebuild is unchanged', async () => {
  const repository = new FirestorePrivacyOrchestrationRepository(db);
  const privacy = new PrivacyOrchestrationService(repository, repository, repository);
  const runner = new PrivacyDomainTaskRunner(db, repository, privacy, {
    leaseOwner: 'runner:l3',
    clock,
  });
  for (const type of ['erasure', 'restriction'] as const) {
    await clear(Object.values(cols));
    const s = await consentingSender();
    const buffered = batch(
      event('details_opened', { object_kind: 'place' }),
      event('favorite_added', { object_kind: 'place', entry_surface: 'details' }),
    );
    assert.deepEqual(dispositions(await service.ingest(s.hint, buffered)), [
      'accepted',
      'accepted',
    ]);
    const first = await service.rebuildDailyAggregate(DAY);
    const requestId = randomUUID();
    assert.ok(
      (
        await privacy.submit({
          requestId,
          subjectId: s.userId,
          requestType: type,
          idempotencyKey: `l3-${requestId}`,
          semanticHash: `sha256:${createHash('sha256').update(requestId).digest('hex')}`,
          requiredDomainIds: ['library'],
          occurredAtUtc: T0,
        })
      ).ok,
    );
    assert.ok((await privacy.verify(requestId, 1, T0)).ok);
    assert.ok(
      (
        await privacy.dispatch(
          requestId,
          2,
          [{ domainId: 'library', marketId: 'LV', targetRevision: 1 }],
          T0,
        )
      ).ok,
    );
    await runner.runTask({
      requestId,
      taskId: privacyDomainTaskId(requestId, 'library', 'LV', 1),
      nowUtc: T0,
    });
    const account = (await db.collection(identity.accounts).doc(s.userId).get()).data();
    assert.equal(account?.status, 'restricted');
    // The client still holds the batch (lost response, restart) and replays it,
    // plus something new: nothing is stored and the counts stay.
    for (const replay of [buffered, batch(event('details_opened', { object_kind: 'event' }))])
      assert.deepEqual(await service.ingest(s.hint, replay), {
        kind: 'refused',
        code: 'unauthenticated',
      });
    assert.equal((await stored()).length, 2);
    assert.deepEqual(await service.rebuildDailyAggregate(DAY), first);
  }
});

// --------------------------------------------- 5: lost response and duplicates

void test('L3-T-DEDUPE: a lost response, a retry and in-batch repeats count once; changed payload conflicts', async () => {
  const s = await consentingSender();
  const original = event('favorite_added', { object_kind: 'rental', entry_surface: 'other' });
  const sent = batch(original, event('details_opened', { object_kind: 'rental' }));
  assert.deepEqual(dispositions(await service.ingest(s.hint, sent)), ['accepted', 'accepted']);
  // The response was lost: the client retries the very same batch twice.
  for (let attempt = 0; attempt < 2; attempt += 1)
    assert.deepEqual(dispositions(await service.ingest(s.hint, sent)), ['duplicate', 'duplicate']);
  const changed = { ...original, fields: { object_kind: 'rental', entry_surface: 'map' } };
  const repeat = event('details_opened', { object_kind: 'scenario' });
  assert.deepEqual(dispositions(await service.ingest(s.hint, batch(changed, repeat, repeat))), [
    'conflict',
    'accepted',
    'duplicate',
  ]);
  const first = await service.rebuildDailyAggregate(DAY);
  const second = await service.rebuildDailyAggregate(DAY);
  assert.deepEqual(first, second);
  assert.equal(first.kind === 'built' && first.sourceEvents, 3);
  const aggregate = (await db.collection(cols.dailyAggregates).doc(DAY).get()).data()!;
  assert.deepEqual(
    (aggregate.rows as { count: number }[]).map((row) => row.count),
    [1, 1, 1],
  );
});

// ----------------------------------------------- 7: capability, raw, export

void test('L3-T-ACCESS: foreign or missing capability, raw read and export are refused and audited', async () => {
  const s = await consentingSender();
  await service.ingest(s.hint, batch(event('details_opened', { object_kind: 'route' })));
  await service.rebuildDailyAggregate(DAY);
  const none = await reader(null);
  const wrongAction = await reader([actions.export]);
  const expired = await reader([actions.aggregateRead], '2026-10-25T11:00:00.000Z');
  const full = await reader([actions.aggregateRead, actions.rawRead, actions.export]);
  for (const denied of [
    none,
    wrongAction,
    expired,
    { userId: s.userId, sessionId: s.hint.sessionId },
  ])
    assert.deepEqual(await service.readDailyAggregates(denied, DAY, DAY), {
      kind: 'refused',
      code: 'access_denied',
    });
  // A revoked Session denies the same grant.
  await db.collection(identity.sessions).doc(full.sessionId).update({ status: 'revoked' });
  assert.deepEqual(await service.readDailyAggregates(full, DAY, DAY), {
    kind: 'refused',
    code: 'access_denied',
  });
  const staff = await reader([actions.aggregateRead, actions.rawRead, actions.export]);
  for (const action of [actions.rawRead, actions.export] as const)
    assert.deepEqual(await service.requestRestricted(staff, action), {
      kind: 'refused',
      code: 'policy_unavailable',
    });
  assert.deepEqual(await service.readDailyAggregates(staff, '2026-09-01', DAY), {
    kind: 'refused',
    code: 'request_invalid',
  });
  const read = await service.readDailyAggregates(staff, DAY, DAY);
  assert.equal(read.kind, 'succeeded');
  // The answer is aggregate rows and a fingerprint, never event IDs or raw records.
  assert.deepEqual(Object.keys(read.kind === 'succeeded' ? read.days[0]! : {}).sort(), [
    'dayUtc',
    'fingerprint',
    'rows',
  ]);
  const ids = (await stored()).map((record) => String(record.id));
  for (const id of ids) assert.ok(!JSON.stringify(read).includes(id));
  const audit = (await db.collection(cols.accessAudit).get()).docs.map((doc) => doc.data());
  const summary = audit
    .map((entry) => `${String(entry.action)}:${String(entry.outcome)}:${String(entry.reason)}`)
    .sort();
  assert.deepEqual(summary, [
    'aggregate.read:allow:granted',
    'aggregate.read:deny:access_denied',
    'aggregate.read:deny:access_denied',
    'aggregate.read:deny:access_denied',
    'aggregate.read:deny:access_denied',
    'aggregate.read:deny:access_denied',
    'export:deny:policy_unavailable',
    'raw.read:deny:policy_unavailable',
  ]);
  for (const entry of audit) assert.ok(!JSON.stringify(entry).includes('route'));
});

// ---------------------------------------------- 8: retention and rebuild

void test('L3-T-RETENTION: expiry removes raw events and aggregates; rebuild never restores them', async () => {
  const s = await consentingSender();
  await service.ingest(
    s.hint,
    batch(
      event('details_opened', { object_kind: 'route' }),
      event('details_opened', { object_kind: 'event' }),
    ),
  );
  const built = await service.rebuildDailyAggregate(DAY);
  assert.equal(built.kind, 'built');
  // Retention runs even with collection and aggregation switched off.
  await setFlags(false);
  clock.set(hours(35)); // 2026-10-26T23:00Z: nothing has expired yet.
  assert.deepEqual(await service.expire(), { events: 0, aggregates: 0 });
  clock.set(hours(36)); // 2026-10-27T00:00Z: raw retention of the day ends.
  assert.deepEqual(await service.expire(), { events: 2, aggregates: 0 });
  await setFlags(true);
  assert.deepEqual(await service.rebuildDailyAggregate(DAY), {
    kind: 'refused',
    code: 'window_expired',
  });
  const kept = (await db.collection(cols.dailyAggregates).doc(DAY).get()).data();
  assert.equal(kept?.fingerprint, built.kind === 'built' ? built.fingerprint : null);
  const staff = await reader([actions.aggregateRead]);
  clock.set(hours(60)); // 2026-10-28T00:00Z: aggregate retention ends.
  // Not yet swept, but past its expiry: never served.
  assert.deepEqual(await service.readDailyAggregates(staff, DAY, DAY), {
    kind: 'succeeded',
    days: [],
  });
  assert.deepEqual(await service.expire(), { events: 0, aggregates: 1 });
  assert.deepEqual(await service.rebuildDailyAggregate(DAY), {
    kind: 'refused',
    code: 'window_expired',
  });
  assert.equal((await db.collection(cols.dailyAggregates).limit(1).get()).size, 0);
  // A replay of the old events after expiry is late and stays deleted.
  const later = await consentingSender();
  assert.deepEqual(
    dispositions(
      await service.ingest(later.hint, batch(event('details_opened', { object_kind: 'route' }))),
    ),
    ['rejected_late'],
  );
  assert.equal((await stored()).length, 0);
});

// --------------------------------------------- 10: independent controls

void test('L3-T-ISOLATION: analytics off leaves security controls and the operations console working', async () => {
  await setFlags(false);
  const s = await consentingSender();
  assert.deepEqual(
    await service.ingest(s.hint, batch(event('details_opened', { object_kind: 'route' }))),
    { kind: 'refused', code: 'collection_disabled' },
  );
  // The abuse limiter (security control) still decides and records attempts.
  const before = (await db.collection('securityRateLimitAttempts').count().get()).data().count;
  const decision = await new FirestoreAbuseRateLimiter(db).consume({
    operation: 'identity.session.issue',
    attemptRequestId: randomUUID(),
    accountId: s.userId,
    installationId: s.hint.installationId,
    environmentId: 'local',
    marketId: 'LV',
    now: clock.now(),
    correlationId: `l3-${randomUUID()}`,
  });
  assert.equal(decision.allowed, true);
  assert.ok((await db.collection('securityRateLimitAttempts').count().get()).data().count > before);
  // The L2 console still authorizes and audits an operator action.
  await grantOperationsAuthority(db, {
    userId: s.userId,
    scopes: [{ familyId: 'TF-01', actions: ['ops.inspect'] }],
    grantedAtUtc: T0,
    expiresAtUtc: '2026-11-25T00:00:00.000Z',
  });
  const operations = createEmulatorOperationsConsole(db, { clock });
  const inspected = await operations.inspect(
    { userId: s.userId, sessionId: s.hint.sessionId },
    'TF-01',
    'l3-missing-task',
  );
  assert.deepEqual(inspected, { kind: 'rejected', code: 'not_found' });
  const audit = await db
    .collection(operationsCollections.audit)
    .where('actorId', '==', s.userId)
    .get();
  assert.ok(audit.size >= 1);
  assert.equal((await stored()).length, 0);
});
