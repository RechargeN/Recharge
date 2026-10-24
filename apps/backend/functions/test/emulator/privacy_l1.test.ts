// L1 (PRIVACY_L1_DSR_RETENTION_HOLD_AMENDMENT.md §11): DSR, retention and
// legal hold over every writer of the registry, on the Firestore and Storage
// Emulator. Synthetic data only; every test removes what it created.
import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { after, before, beforeEach, test } from 'node:test';
import type { Firestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';

import { bookingCollections } from '../../src/booking/transactions.js';
import { createInternalBooking } from '../../src/booking/create_internal_booking.js';
import { privacyDomainTaskId } from '../../src/modules/privacy_orchestration/application/dispatch_privacy_tasks.js';
import {
  PrivacyDomainTaskRunner,
  type PrivacyRunnerOptions,
  type RunOutcome,
} from '../../src/modules/privacy_orchestration/application/privacy_domain_task_runner.js';
import { PrivacyOrchestrationService } from '../../src/modules/privacy_orchestration/application/privacy_orchestration_service.js';
import { PrivacyRequestIntake } from '../../src/modules/privacy_orchestration/application/privacy_request_intake.js';
import { planRetentionDeletionDispatch } from '../../src/modules/privacy_orchestration/application/retention_deletion_dispatch.js';
import { privacyHoldApplies } from '../../src/modules/privacy_orchestration/domain/privacy_legal_hold.js';
import {
  privacyErasureDomainIds,
  privacyWriterRegistry,
} from '../../src/modules/privacy_orchestration/domain/privacy_writer_registry.js';
import {
  FirestorePrivacyLegalHoldService,
  privacyHoldCollections,
} from '../../src/modules/privacy_orchestration/infrastructure/firestore_privacy_legal_hold_service.js';
import {
  FirestorePrivacyOrchestrationRepository,
  privacyOrchestrationCollections,
} from '../../src/modules/privacy_orchestration/infrastructure/firestore_privacy_orchestration_repository.js';
import { privacyProgressCollection } from '../../src/modules/privacy_orchestration/infrastructure/firestore_privacy_subject_sweep.js';
import { createAccount } from '../../src/modules/identity_publisher/domain/account.js';
import { identityAuthorityCollections } from '../../src/modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import { libraryCollections } from '../../src/modules/library/library_contract.js';
import { MediaDeletionService } from '../../src/modules/media/application/media_deletion_service.js';
import type { ObjectStorePort } from '../../src/modules/media/application/ports/object_store_port.js';
import { advance, createReservedAsset } from '../../src/modules/media/domain/media_asset.js';
import type { MediaRetentionPolicy } from '../../src/modules/media/domain/media_retention.js';
import { createEmulatorMediaComposition } from '../../src/modules/media/infrastructure/emulator_media_composition.js';
import { mediaCollections } from '../../src/modules/media/infrastructure/firestore_media_repository.js';
import { FirestoreQuickPlanService } from '../../src/modules/quick_plan/firestore_quick_plan_service.js';
import { FirestoreReviewService } from '../../src/modules/reviews/firestore_review_service.js';
import { reviewCollections } from '../../src/modules/reviews/review_policy.js';
import { RetentionRegistry } from '../../src/security/retention_registry.js';
import type { EntityId } from '../../src/shared/ids.js';
import { parseUtcInstant } from '../../src/shared/utc_instant.js';
import { bookingInvariantProblems } from '../support/booking_invariants.js';
import { emulatorFirestore, seedEvent } from '../support/booking_emulator.js';
import { createCommand, finiteEvent } from '../support/booking_fixtures.js';
import { FakeClock } from '../support/fake_clock.js';
import {
  disableFunctionTriggers,
  enableFunctionTriggers,
} from '../support/functions_emulator_triggers.js';

const db: Firestore = emulatorFirestore();
const bucket = getStorage().bucket('demo-recharge.appspot.com');
const repository = new FirestorePrivacyOrchestrationRepository(db);
const service = new PrivacyOrchestrationService(repository, repository, repository);
const holds = new FirestorePrivacyLegalHoldService(db);

/** Synthetic subjects (Crockford ULIDs). */
const S = '01JZ0000000000000000000SBJ';
const O = '01JZ0000000000000000000THR';
const NOW = '2026-10-24T12:00:00.000Z';
const clock = new FakeClock(new Date(NOW));
const at = (minutes: number) => new Date(Date.parse(NOW) + minutes * 60_000).toISOString();
const holdActor = 'privacy-hold-officer';
/** TEST-ONLY Media retention, as in the D2 gate; not a product policy. */
const testOnlyMediaRetention: MediaRetentionPolicy = {
  revision: 'l1-test-only-media-retention-1',
  orphanGraceSeconds: 60,
  quarantinedRetentionSeconds: 60,
  blockedRetentionSeconds: 60,
  inFlightAttemptLeaseSeconds: 60,
  deletionHoldLeaseSeconds: 30,
  deletionReceiptRetentionSeconds: 600,
};

const writtenCollections = [...new Set(privacyWriterRegistry.map((entry) => entry.collection))];
/**
 * Collections a test touches besides what it seeds: DSR records, Identity,
 * Booking and Media effects, fences and projections written by the owners.
 */
const effectCollections = [
  ...writtenCollections.filter((name) =>
    /^(privacy|identity|booking|eventBooking|media|notification|library|rating)/u.test(name),
  ),
  'quickPlans',
  'scenarios',
  'routes',
  'routeRevisions',
  'safetyRelations',
];
const touched = new Set<string>(effectCollections);
const storageHandles = new Set<string>();

async function clear(names: Iterable<string>): Promise<void> {
  await Promise.all(
    [...names].map(async (name) => {
      for (;;) {
        const page = await db.collection(name).limit(300).get();
        if (page.empty) break;
        const batch = db.batch();
        for (const document of page.docs) batch.delete(document.ref);
        await batch.commit();
      }
    }),
  );
}

/** Between tests only what a test touched; around the file every registry collection. */
async function wipe(full = false): Promise<void> {
  await clear(full ? writtenCollections : touched);
  touched.clear();
  for (const name of effectCollections) touched.add(name);
  const media = createEmulatorMediaComposition({ firestore: db, bucket: bucket as never });
  for (const handle of storageHandles) await media.objectStore.remove(handle);
  storageHandles.clear();
  clock.set(new Date(NOW));
}

before(async () => {
  // Every effect in this file is the owner's own: Functions triggers stay off.
  await disableFunctionTriggers();
  await wipe(true);
});
beforeEach(() => wipe());
after(async () => {
  await wipe(true);
  await enableFunctionTriggers();
});

/** One named L1 scenario; Functions triggers are off for the whole file. */
function l1(name: string, body: () => Promise<void>): void {
  void test(name, body);
}

async function seed(collection: string, id: string, data: Record<string, unknown>) {
  touched.add(collection);
  await db.collection(collection).doc(id).set(data);
}

async function doc(collection: string, id: string) {
  return (await db.collection(collection).doc(id).get()).data();
}

async function account(userId: string): Promise<void> {
  await seed(identityAuthorityCollections.accounts, userId, { ...createAccount(userId, NOW) });
}

/** A verified, dispatched request of the subject over the given domains. */
async function request(
  domains: readonly string[],
  type: 'erasure' | 'access' | 'restriction' = 'erasure',
  subjectId = S,
) {
  const requestId = randomUUID();
  const submitted = await service.submit({
    requestId,
    subjectId,
    requestType: type,
    idempotencyKey: `l1-${requestId}`,
    semanticHash: `sha256:${createHash('sha256').update(requestId).digest('hex')}`,
    requiredDomainIds: domains,
    occurredAtUtc: NOW,
  });
  assert.ok(submitted.ok);
  assert.ok((await service.verify(requestId, 1, NOW)).ok);
  assert.ok(
    (
      await service.dispatch(
        requestId,
        2,
        domains.map((domainId) => ({ domainId, marketId: 'LV', targetRevision: 1 })),
        NOW,
      )
    ).ok,
  );
  return {
    requestId,
    taskId: (domain: string) => privacyDomainTaskId(requestId, domain, 'LV', 1),
  };
}

function runner(options: PrivacyRunnerOptions = {}) {
  return new PrivacyDomainTaskRunner(db, repository, service, {
    leaseOwner: 'runner:l1-a',
    clock,
    ...options,
  });
}

async function task(requestId: string, domain: string) {
  return (await repository.listByRequest(requestId)).find((item) => item.domainId === domain)!;
}

/** Runs one domain until it stops making bounded progress. */
async function drive(
  r: PrivacyDomainTaskRunner,
  requestId: string,
  domain: string,
  nowUtc = NOW,
): Promise<RunOutcome> {
  for (let run = 0; run < 50; run += 1) {
    const outcome = await r.runTask({
      requestId,
      taskId: privacyDomainTaskId(requestId, domain, 'LV', 1),
      nowUtc,
    });
    if (outcome !== 'progress') return outcome;
  }
  throw new Error('privacy task did not settle');
}

async function reconcile(requestId: string) {
  const current = await repository.get(requestId);
  const result = await service.reconcile(requestId, current!.revision, NOW);
  assert.ok(result.ok);
  return result.request;
}

async function placeHold(
  holdId: string,
  scope: { domainId: string; collection: string; recordId: string | null },
) {
  await seed(privacyHoldCollections.authority, holdActor, { active: true });
  const placed = await holds.place({
    actorId: holdActor,
    holdId,
    subjectId: S,
    scope,
    basisRef: 'case-l1-basis-SECRET-0001',
    reviewAtUtc: at(60 * 24 * 30),
    nowUtc: NOW,
  });
  assert.ok(placed.ok, JSON.stringify(placed));
  return placed.hold;
}

function quickPlan(owner: string, planId: string, extra: Record<string, unknown> = {}) {
  return seed('quickPlans', `${owner}:${planId}`, {
    ownerId: owner,
    planId,
    revision: 3,
    status: 'active',
    plan: { id: planId, revision: 3, sourcePrompt: 'private evening near the river', steps: [] },
    updatedAtUtc: NOW,
    ...extra,
  });
}

// ---------------------------------------------------------------- 2: authority

l1(
  'L1-T-AUTH: no authority, foreign subject, repeat and changed payload under one key',
  async () => {
    const intake = new PrivacyRequestIntake(db, service, repository);
    const sessionId = 'l1-session-subject';
    const handle = createHash('sha256').update('l1-handle-subject').digest('base64url');
    const hint = {
      firebaseUid: 'uid-l1-subject',
      sessionId,
      sessionHandle: handle,
      installationId: 'install-l1',
    };
    // Nothing exists yet: no Session, no authority.
    assert.deepEqual(
      await intake.submitForSession(hint, {
        requestId: randomUUID(),
        requestType: 'erasure',
        idempotencyKey: 'l1-intake-key',
        nowUtc: NOW,
      }),
      { ok: false, code: 'access_denied' },
    );
    await seed(identityAuthorityCollections.accounts, S, { ...createAccount(S, NOW) });
    await seed(identityAuthorityCollections.sessions, sessionId, {
      schemaVersion: 1,
      sessionId,
      userId: S,
      status: 'active',
      revision: 1,
      authzRevision: 1,
      firebaseUid: hint.firebaseUid,
      installationId: hint.installationId,
      handleHash: createHash('sha256').update(handle).digest('hex'),
      issuedAtUtc: NOW,
      lastSeenAtUtc: NOW,
      idleExpiresAtUtc: at(60 * 24),
    });
    await seed(identityAuthorityCollections.accessSnapshots, sessionId, {
      schemaVersion: 1,
      userId: S,
      sessionId,
      accountRevision: 1,
      sessionRevision: 1,
      authzRevision: 1,
      capabilityPolicyRevision: 1,
      capabilityIds: [],
      evaluatedAtUtc: NOW,
      expiresAtUtc: at(60),
    });
    // A client-named other subject never widens the scope.
    assert.deepEqual(
      await intake.submitForSession(hint, {
        requestId: randomUUID(),
        requestType: 'erasure',
        idempotencyKey: 'l1-intake-key',
        subjectId: O,
        nowUtc: NOW,
      }),
      { ok: false, code: 'subject_mismatch' },
    );
    assert.equal((await db.collection('privacyRequests').get()).size, 0);
    const first = await intake.submitForSession(hint, {
      requestId: randomUUID(),
      requestType: 'access',
      idempotencyKey: 'l1-intake-key',
      nowUtc: NOW,
    });
    assert.ok(first.ok);
    assert.equal(first.view.status, 'dispatched');
    assert.deepEqual(
      first.view.domains.map((domain) => domain.domainId),
      [...privacyErasureDomainIds].sort(),
    );
    // A retry is a new attempt of the same logical submission: same request.
    const repeat = await intake.submitForSession(hint, {
      requestId: randomUUID(),
      requestType: 'access',
      idempotencyKey: 'l1-intake-key',
      nowUtc: at(1),
    });
    assert.ok(repeat.ok);
    assert.equal(repeat.view.requestId, first.view.requestId);
    assert.equal((await db.collection('privacyRequests').get()).size, 1);
    // The same key with another payload is a conflict, never a second request.
    const changed = await service.submit({
      requestId: randomUUID(),
      subjectId: S,
      requestType: 'access',
      idempotencyKey: 'l1-intake-key',
      semanticHash: `sha256:${'f'.repeat(64)}`,
      requiredDomainIds: ['library'],
      occurredAtUtc: at(2),
    });
    assert.deepEqual(changed, { ok: false, code: 'idempotency_conflict' });
  },
);

// ------------------------------------------------------------ 1: every writer

l1(
  'L1-T-W1 Identity: account restricted and Sessions revoked; teardown blocked (PB-01, PB-03)',
  async () => {
    await account(S);
    await account(O);
    await seed(identityAuthorityCollections.sessions, 's-subject', {
      schemaVersion: 1,
      sessionId: 's-subject',
      userId: S,
      status: 'active',
      revision: 1,
      authzRevision: 1,
      firebaseUid: 'uid-s',
      installationId: 'install-s',
      handleHash: 'h',
      issuedAtUtc: NOW,
      lastSeenAtUtc: NOW,
      idleExpiresAtUtc: at(60),
    });
    await seed(identityAuthorityCollections.sessions, 's-other', {
      schemaVersion: 1,
      sessionId: 's-other',
      userId: O,
      status: 'active',
      revision: 1,
      authzRevision: 1,
      firebaseUid: 'uid-o',
      installationId: 'install-o',
      handleHash: 'h',
      issuedAtUtc: NOW,
      lastSeenAtUtc: NOW,
      idleExpiresAtUtc: at(60),
    });
    await seed(identityAuthorityCollections.pageMemberships, 'page-1:' + S, {
      userId: S,
      pageId: 'page-1',
    });
    await seed('identityAgeAttestations', S, { userId: S, adult: true });
    const r = await request(['identity']);
    assert.equal(await drive(runner(), r.requestId, 'identity'), 'blocked');
    assert.deepEqual((await task(r.requestId, 'identity')).blockedCodes, ['PB-01', 'PB-03']);
    assert.equal((await doc(identityAuthorityCollections.accounts, S))?.status, 'restricted');
    assert.equal(
      (await doc(identityAuthorityCollections.sessions, 's-subject'))?.status,
      'revoked',
    );
    assert.equal((await doc(identityAuthorityCollections.sessions, 's-other'))?.status, 'active');
    assert.equal((await doc(identityAuthorityCollections.accounts, O))?.status, 'active');
    // Blocked is not deletion: the records are still there.
    assert.ok(await doc(identityAuthorityCollections.pageMemberships, 'page-1:' + S));
    assert.ok(await doc('identityAgeAttestations', S));
    assert.equal((await reconcile(r.requestId)).status, 'partially_completed');
  },
);

l1(
  'L1-T-W4 Security: rate-limit and audit records stay without an accepted erasure action (PB-05)',
  async () => {
    await account(S);
    await seed('securityRateLimitAttempts', 'a1', { accountId: S, at: NOW });
    await seed('securityAudit', 'a2', { accountId: S, action: 'refused' });
    const r = await request(['security']);
    assert.equal(await drive(runner(), r.requestId, 'security'), 'blocked');
    assert.deepEqual((await task(r.requestId, 'security')).blockedCodes, ['PB-05']);
    assert.ok(await doc('securityRateLimitAttempts', 'a1'));
  },
);

l1('L1-T-W5 Booking: terminal records pseudonymized, another person untouched', async () => {
  await account(S);
  const booking = (id: string, userId: string) => ({
    schemaVersion: 1,
    id,
    revision: 2,
    userId,
    eventId: 'event-1',
    occurrenceId: 'occurrence-1',
    admissionMode: 'booking',
    confirmationMode: 'instant',
    state: 'cancelled',
    participantUnits: 1,
    reconfirmationState: 'notRequired',
    createdAt: '2026-09-20T00:00:00.000Z',
    updatedAt: '2026-09-21T00:00:00.000Z',
    confirmedAt: '2026-09-20T00:00:00.000Z',
    cancelledAt: '2026-09-21T00:00:00.000Z',
    terminalReason: 'userCancelled',
    retentionClass: 'bookingCore',
    legalHold: false,
  });
  await seed(bookingCollections.bookings, 'b-subject', booking('b-subject', S));
  await seed(bookingCollections.bookings, 'b-other', booking('b-other', O));
  await seed(bookingCollections.audit, 'audit-1', { actorId: S, action: 'cancel' });
  const r = await request(['booking']);
  assert.equal(await drive(runner(), r.requestId, 'booking'), 'succeeded');
  assert.match(String((await doc(bookingCollections.bookings, 'b-subject'))?.userId), /^anon_/u);
  assert.match(String((await doc(bookingCollections.audit, 'audit-1'))?.actorId), /^anon_/u);
  assert.equal((await doc(bookingCollections.bookings, 'b-other'))?.userId, O);
  assert.equal((await reconcile(r.requestId)).status, 'completed');
});

l1(
  'L1-T-BK Booking: a future booking is cancelled through Booking, inventory consistent, no refund',
  async () => {
    await account(S);
    const event = finiteEvent({
      occurrenceStartsAt: '2026-11-02T10:00:00.000Z',
      occurrenceEndsAt: '2026-11-02T12:00:00.000Z',
      registrationWindow: {
        opensAt: '2026-10-01T00:00:00.000Z',
        closesAt: '2026-11-01T00:00:00.000Z',
      },
      cancellationDeadline: '2026-11-01T00:00:00.000Z',
    });
    await seedEvent(event, db);
    const created = await createInternalBooking(
      {
        firestore: db,
        clock: new FakeClock(new Date(NOW)),
        newBookingId: () => '01JZBK0000000000000000SBJ0',
      },
      S,
      createCommand({ requestId: 'l1-bk-request', idempotencyKey: 'l1-bk-key' }),
    );
    assert.equal(created.kind, 'succeeded', JSON.stringify(created));
    const r = await request(['booking']);
    assert.equal(await drive(runner(), r.requestId, 'booking'), 'succeeded');
    const stored = await doc(bookingCollections.bookings, '01JZBK0000000000000000SBJ0');
    assert.equal(stored?.state, 'cancelled');
    assert.equal(stored?.terminalReason, 'privacyErasure');
    assert.match(String(stored?.userId), /^anon_/u);
    // Inventory, active key and usage agree with the cancelled booking.
    assert.deepEqual(await bookingInvariantProblems(db), []);
    const keys = await db.collection(bookingCollections.activeKeys).where('actorId', '==', S).get();
    assert.equal(keys.size, 0);
    // There is no payment runtime: nothing refund- or payment-like was written.
    const names = (await db.listCollections()).map((collection) => collection.id);
    assert.equal(
      names.some((name) => /refund|payment/iu.test(name)),
      false,
    );
  },
);

l1(
  'L1-T-W6/W7 Content: drafts, bindings and publications stay; blocked PB-18, PB-02, PB-05',
  async () => {
    await account(S);
    await seed('contentDrafts', 'draft-1', {
      createdByUserId: S,
      body: { title: 'Private draft' },
    });
    await seed('contentExternalBindings', `local-import:v1:${S}:loc_1`, { createdByUserId: S });
    await seed('contentPublishedRevisions', 'rev-1', { publisherRef: { type: 'user', id: S } });
    await seed('contentIdempotency', 'idem-1', { actorUserId: S });
    const r = await request(['content']);
    assert.equal(await drive(runner(), r.requestId, 'content'), 'blocked');
    assert.deepEqual((await task(r.requestId, 'content')).blockedCodes, [
      'PB-02',
      'PB-05',
      'PB-18',
    ]);
    assert.ok(await doc('contentDrafts', 'draft-1'));
    assert.ok(await doc('contentPublishedRevisions', 'rev-1'));
  },
);

/** A ready asset with source and one variant really stored in the Storage Emulator. */
async function readyAsset(
  owner: string,
  store: ObjectStorePort & { put(h: string, b: Buffer): Promise<void> },
  writer: {
    writeVariant(id: string, b: Buffer, t: string): Promise<{ providerGeneration: string }>;
  },
) {
  const assetId = randomUUID() as EntityId;
  const handle = `objk:${randomUUID()}`;
  const variantId = randomUUID() as EntityId;
  const bytes = Buffer.from('l1-source-bytes');
  await store.put(handle, bytes);
  storageHandles.add(handle);
  const variant = await writer.writeVariant(variantId, Buffer.from('l1-variant'), 'image/webp');
  const now = parseUtcInstant(NOW);
  const reserved = createReservedAsset({
    assetId,
    ownerSubjectId: owner as EntityId,
    marketId: 'LV',
    family: 'image',
    visibilityClass: 'private',
    policyRevision: 'test-only',
    objectKeyHandle: handle,
    nowUtc: now,
  });
  const ready = advance(
    reserved,
    ['uploading', 'uploaded', 'validating', 'processing', 'ready'],
    now,
    {
      variantRefs: [
        {
          variantId,
          profile: 'display',
          format: 'webp',
          providerGeneration: variant.providerGeneration,
          sha256: 'a'.repeat(64),
          byteLength: 10,
          transformProfileRevision: 'test-only',
          sourceProviderGeneration: 'g1',
        },
      ],
    },
  );
  return { assetId, handle, variantId, ready, variantGeneration: variant.providerGeneration };
}

function mediaWorld(
  options: { failRemovals?: { count: number }; retention?: boolean; referenced?: Set<string> } = {},
) {
  const composition = createEmulatorMediaComposition({
    firestore: db,
    bucket: bucket as never,
    clock,
    ...(options.retention === false ? {} : { retention: testOnlyMediaRetention }),
  });
  const store = composition.objectStore;
  const failing: ObjectStorePort = {
    stat: (h) => store.stat(h),
    remove: (h) => {
      if (options.failRemovals && options.failRemovals.count > 0) {
        options.failRemovals.count -= 1;
        return Promise.resolve('failed');
      }
      return store.remove(h);
    },
    removeVariant: (v) => store.removeVariant(v),
  };
  const references = {
    isReferenced: (assetId: string) => Promise.resolve(options.referenced?.has(assetId) ?? false),
  };
  const deletion = new MediaDeletionService({
    repository: composition.repository,
    authority: composition.authority,
    restrictionAuthority: {
      verifyRestriction: () => Promise.resolve({ verified: false } as const),
    },
    references,
    objectStore: failing,
    clock,
    ids: { newId: () => randomUUID() as EntityId },
    ...(options.retention === false ? {} : { retention: testOnlyMediaRetention }),
  });
  return {
    composition,
    store,
    media: { deletion, references, retentionPolicyAvailable: options.retention !== false },
  };
}

l1(
  'L1-T-W8 Media: free assets deleted with source and variant bytes; referenced and policy-less ones stay',
  async () => {
    await account(S);
    const referenced = new Set<string>();
    const world = mediaWorld({ referenced });
    const free = await readyAsset(S, world.store, world.store);
    const attached = await readyAsset(S, world.store, world.store);
    const foreign = await readyAsset(O, world.store, world.store);
    referenced.add(attached.assetId);
    const reserved = createReservedAsset({
      assetId: randomUUID() as EntityId,
      ownerSubjectId: S as EntityId,
      marketId: 'LV',
      family: 'image',
      visibilityClass: 'private',
      policyRevision: 'test-only',
      objectKeyHandle: `objk:${randomUUID()}`,
      nowUtc: parseUtcInstant(NOW),
    });
    for (const asset of [free.ready, attached.ready, foreign.ready, reserved])
      await world.composition.repository.transact((tx) => tx.putAsset(asset, 0));
    const r = await request(['media']);
    assert.equal(await drive(runner({ media: world.media }), r.requestId, 'media'), 'blocked');
    assert.ok((await task(r.requestId, 'media')).blockedCodes?.includes('PB-02'));
    assert.equal((await doc(mediaCollections.assets, free.assetId))?.lifecycle, 'deleted');
    assert.equal((await doc(mediaCollections.assets, reserved.assetId))?.lifecycle, 'deleted');
    // Not just metadata: the source and the derived variant are gone from Storage.
    assert.deepEqual(await world.store.stat(free.handle), { kind: 'absent' });
    assert.equal(
      (await world.store.readVariant(free.variantId, free.variantGeneration, 1024)).kind,
      'absent',
    );
    assert.equal((await doc(mediaCollections.assets, attached.assetId))?.lifecycle, 'ready');
    assert.equal((await world.store.stat(attached.handle)).kind, 'complete');
    assert.equal((await doc(mediaCollections.assets, foreign.assetId))?.lifecycle, 'ready');
    // Without an accepted retention policy a settled asset cannot be held: PB-14.
    const noPolicy = mediaWorld({ retention: false });
    const settled = await readyAsset(S, noPolicy.store, noPolicy.store);
    await noPolicy.composition.repository.transact((tx) => tx.putAsset(settled.ready, 0));
    const second = await request(['media']);
    assert.equal(
      await drive(runner({ media: noPolicy.media }), second.requestId, 'media'),
      'blocked',
    );
    assert.ok((await task(second.requestId, 'media')).blockedCodes?.includes('PB-14'));
    assert.equal((await doc(mediaCollections.assets, settled.assetId))?.lifecycle, 'ready');
  },
);

l1('L1-T-MD Media: an unconfirmed byte removal is retried, never reported as deleted', async () => {
  await account(S);
  const failRemovals = { count: 1 };
  const world = mediaWorld({ failRemovals });
  const asset = await readyAsset(S, world.store, world.store);
  await world.composition.repository.transact((tx) => tx.putAsset(asset.ready, 0));
  const r = await request(['media']);
  const first = await runner({ media: world.media }).runTask({
    requestId: r.requestId,
    taskId: r.taskId('media'),
    nowUtc: NOW,
  });
  assert.equal(first, 'retry_scheduled');
  assert.equal((await doc(mediaCollections.assets, asset.assetId))?.lifecycle, 'deleting');
  assert.equal((await task(r.requestId, 'media')).status, 'dispatched');
  assert.equal((await reconcile(r.requestId)).status, 'dispatched');
  // Media receipts cannot be found by subject: the task ends blocked (PB-14), not done.
  assert.equal(await drive(runner({ media: world.media }), r.requestId, 'media'), 'blocked');
  assert.deepEqual((await task(r.requestId, 'media')).blockedCodes, ['PB-14']);
  assert.equal((await doc(mediaCollections.assets, asset.assetId))?.lifecycle, 'deleted');
  assert.deepEqual(await world.store.stat(asset.handle), { kind: 'absent' });
});

l1(
  'L1-T-W9/W10 Moderation and reports stay; the reporter is never disclosed (PB-09, PB-11)',
  async () => {
    await account(S);
    await seed('trustSafetyReports', 'report-1', {
      reporterUserId: S,
      narrative: 'REPORT-NARRATIVE',
    });
    await seed('moderationDecisions', 'decision-1', { staffUserId: S });
    const r = await request(['moderation']);
    assert.equal(await drive(runner(), r.requestId, 'moderation'), 'blocked');
    assert.deepEqual((await task(r.requestId, 'moderation')).blockedCodes, ['PB-09', 'PB-11']);
    assert.ok(await doc('trustSafetyReports', 'report-1'));
  },
);

l1(
  'L1-T-W12 Notifications: a held domain keeps its records; release and follow-up erase them',
  async () => {
    await account(S);
    await seed('notificationInboxItems', 'inbox-1', { recipientId: S, title: 'x' });
    await seed('notificationPreferences', S, { userId: S, revision: 1 });
    await placeHold('9c1f2b0a-0d0e-4c4e-9a64-0f6e5c0a0001', {
      domainId: 'notifications',
      collection: '*',
      recordId: null,
    });
    const r = await request(['notifications']);
    assert.equal(await drive(runner(), r.requestId, 'notifications'), 'succeeded');
    assert.ok(await doc('notificationInboxItems', 'inbox-1'));
    const retained = await reconcile(r.requestId);
    assert.equal(retained.status, 'completedWithRetention');
    const hold = await doc(privacyHoldCollections.holds, '9c1f2b0a-0d0e-4c4e-9a64-0f6e5c0a0001');
    assert.ok(
      (
        await holds.release({
          actorId: holdActor,
          holdId: '9c1f2b0a-0d0e-4c4e-9a64-0f6e5c0a0001',
          expectedRevision: Number(hold?.revision),
          nowUtc: at(1),
        })
      ).ok,
    );
    const followUpId = randomUUID();
    const followUp = await service.submitLegalHoldReleaseFollowUp({
      originalRequestId: r.requestId,
      requestId: followUpId,
      subjectId: S,
      holdReleaseRevision: 2,
      semanticHash: `sha256:${'e'.repeat(64)}`,
      requiredDomainIds: ['notifications'],
      occurredAtUtc: at(2),
    });
    assert.ok(followUp.ok);
    assert.ok((await service.verify(followUpId, 1, at(2))).ok);
    assert.ok(
      (
        await service.dispatch(
          followUpId,
          2,
          [{ domainId: 'notifications', marketId: 'LV', targetRevision: 1 }],
          at(2),
        )
      ).ok,
    );
    assert.equal(await drive(runner(), followUpId, 'notifications', at(3)), 'succeeded');
    assert.equal(await doc('notificationInboxItems', 'inbox-1'), undefined);
    assert.equal(await doc('notificationPreferences', S), undefined);
  },
);

l1(
  'L1-T-W13 Library: favorites, visits and receipts erased; another owner and the fence stay',
  async () => {
    await account(S);
    for (const [id, owner] of [
      ['entry-s1', S],
      ['entry-s2', S],
      ['entry-o1', O],
    ] as const)
      await seed(libraryCollections.entries, id, {
        ownerId: owner,
        kind: 'favorite',
        objectId: 'x',
      });
    await seed(libraryCollections.receipts, 'receipt-s', { ownerId: S });
    const r = await request(['library']);
    assert.equal(await drive(runner(), r.requestId, 'library'), 'succeeded');
    assert.equal(await doc(libraryCollections.entries, 'entry-s1'), undefined);
    assert.equal(await doc(libraryCollections.receipts, 'receipt-s'), undefined);
    assert.ok(await doc(libraryCollections.entries, 'entry-o1'));
    assert.equal((await doc(libraryCollections.owners, S))?.erased, true);
    assert.equal((await reconcile(r.requestId)).status, 'completed');
  },
);

l1(
  'L1-T-W14 Reviews: published reviews stay (PB-04); a deleted review never returns to the rating',
  async () => {
    await account(S);
    const contentId = '01JZREV0000000000000000SBJ';
    const review = (id: string, authorId: string, rating: number, deleted: boolean) => ({
      schemaVersion: 1,
      reviewId: id,
      authorId,
      contentId,
      typeId: 'place',
      marketId: 'LV',
      revision: 1,
      rating,
      text: deleted ? '' : 'REVIEW-TEXT',
      edited: false,
      deleted,
      moderationHold: null,
      policyRevision: 'p',
      evidence: null,
      createdAtUtc: NOW,
      updatedAtUtc: NOW,
      verified: false,
    });
    await seed(reviewCollections.reviews, 'r-s', review('r-s', S, 5, false));
    await seed(reviewCollections.reviews, 'r-s-deleted', review('r-s-deleted', S, 1, true));
    await seed(reviewCollections.reviews, 'r-o', review('r-o', O, 4, false));
    const r = await request(['reviews']);
    assert.equal(await drive(runner(), r.requestId, 'reviews'), 'blocked');
    assert.deepEqual((await task(r.requestId, 'reviews')).blockedCodes, ['PB-04', 'PB-05']);
    const rebuilt = await new FirestoreReviewService(db, clock).rebuild(contentId);
    assert.equal((rebuilt as { kind: string }).kind, 'succeeded');
    const projection = await doc(reviewCollections.projections, contentId);
    assert.equal(projection?.count, 2);
    assert.deepEqual(projection?.distribution, [0, 0, 0, 1, 1]);
  },
);

l1(
  "L1-T-W15 Trust & Safety: own relations end, another person's relation and sanctions stay",
  async () => {
    await account(S);
    await seed('safetyRelations', 'rel-own', {
      ownerId: S,
      targetUserId: O,
      kind: 'block',
      active: true,
      revision: 1,
      policyRevision: 'p',
      updatedAtUtc: NOW,
    });
    await seed('safetyRelations', 'rel-other', {
      ownerId: O,
      targetUserId: S,
      kind: 'block',
      active: true,
      revision: 1,
      policyRevision: 'p',
      updatedAtUtc: NOW,
    });
    await seed('safetySanctions', 'sanction-1', { subjectUserId: S, family: 'warning' });
    const r = await request(['trust_safety']);
    assert.equal(await drive(runner(), r.requestId, 'trust_safety'), 'blocked');
    const own = await doc('safetyRelations', 'rel-own');
    assert.equal(own?.active, false);
    assert.equal(own?.revision, 2);
    assert.equal((await doc('safetyRelations', 'rel-other'))?.active, true);
    assert.ok(await doc('safetySanctions', 'sanction-1'));
    assert.ok((await task(r.requestId, 'trust_safety')).blockedCodes?.includes('PB-09'));
  },
);

l1('L1-T-W16 Admin/Support: case and read audit stay (PB-10)', async () => {
  await account(S);
  await seed('adminReadAudit', 'read-1', { actorId: S });
  const r = await request(['admin_support']);
  assert.equal(await drive(runner(), r.requestId, 'admin_support'), 'blocked');
  assert.deepEqual((await task(r.requestId, 'admin_support')).blockedCodes, ['PB-10']);
  assert.ok(await doc('adminReadAudit', 'read-1'));
});

l1(
  'L1-T-W17 Quick Plan: own private plan tombstoned; shared plans and invitations stay (PB-12)',
  async () => {
    await account(S);
    await quickPlan(S, 'plan-private');
    await quickPlan(S, 'plan-shared', {
      invitations: { [O]: { inviteeId: O, ownerId: S, status: 'accepted', generation: 1 } },
    });
    await quickPlan(O, 'plan-of-other', {
      invitations: { [S]: { inviteeId: S, ownerId: O, status: 'accepted', generation: 1 } },
    });
    const r = await request(['quick_plan']);
    assert.equal(await drive(runner(), r.requestId, 'quick_plan'), 'blocked');
    assert.deepEqual((await task(r.requestId, 'quick_plan')).blockedCodes, ['PB-12']);
    const tombstone = await doc('quickPlans', `${S}:plan-private`);
    assert.equal(tombstone?.status, 'deleted');
    assert.equal(tombstone?.plan, undefined);
    assert.equal((await doc('quickPlans', `${S}:plan-shared`))?.status, 'active');
    const others = await doc('quickPlans', `${O}:plan-of-other`);
    assert.equal(others?.status, 'active');
    assert.equal(
      (others?.invitations as Record<string, { status: string }>)[S]!.status,
      'accepted',
    );
  },
);

l1('L1-T-W18 Scenario: own private Scenario deleted; shared or published ones stay', async () => {
  await account(S);
  const scenario = (id: string) => ({
    scenarioId: id,
    ownerId: S,
    status: 'active',
    revision: 2,
    updatedAtUtc: NOW,
    draft: { title: 'Weekend', scenario: { revision: 2 } },
  });
  await seed('scenarios', 'scn-private', scenario('scn-private'));
  await seed('scenarios', 'scn-shared', scenario('scn-shared'));
  await seed('scenarioMembers', `scn-shared:${O}`, {
    actorId: O,
    scenarioId: 'scn-shared',
    status: 'active',
  });
  await seed('scenarios', 'scn-public', scenario('scn-public'));
  await seed('contentPublicationPointers', 'scn-public', {
    currentPublishedRevisionId: 'rev-public',
    ownerHold: null,
  });
  const r = await request(['scenario']);
  assert.equal(await drive(runner(), r.requestId, 'scenario'), 'blocked');
  assert.deepEqual((await task(r.requestId, 'scenario')).blockedCodes, ['PB-02', 'PB-12']);
  const deleted = await doc('scenarios', 'scn-private');
  assert.equal(deleted?.status, 'deleted');
  assert.equal(deleted?.draft, null);
  assert.equal((await doc('scenarios', 'scn-shared'))?.status, 'active');
  assert.equal((await doc('scenarios', 'scn-public'))?.status, 'active');
  assert.equal((await doc('scenarioMembers', `scn-shared:${O}`))?.status, 'active');
});

l1(
  'L1-T-W19 Route: own unpublished Route and its snapshots erased; a published Route stays',
  async () => {
    await account(S);
    await seed('routes', `${S}:route-private`, {
      ownerId: S,
      routeId: 'route-private',
      revision: 4,
      status: 'active',
      createdAtUtc: NOW,
      updatedAtUtc: NOW,
      route: { track: 'PRIVATE-GPS-TRACK' },
      distributions: [{ revision: 3, routeRevisionId: 'route-rev-1' }],
    });
    await seed('routeRevisions', 'route-rev-1', {
      ownerId: S,
      status: 'active',
      distribution: { line: 'x' },
    });
    await seed('routes', `${S}:route-public`, {
      ownerId: S,
      routeId: 'route-public',
      revision: 1,
      status: 'active',
      createdAtUtc: NOW,
      updatedAtUtc: NOW,
      route: { track: 'PUBLIC' },
    });
    await seed('contentPublicationPointers', 'route-public', {
      currentPublishedRevisionId: 'rev-route',
      ownerHold: null,
    });
    const r = await request(['route']);
    assert.equal(await drive(runner(), r.requestId, 'route'), 'blocked');
    const erased = await doc('routes', `${S}:route-private`);
    assert.equal(erased?.status, 'deleted');
    assert.equal(erased?.route, undefined);
    assert.equal((await doc('routeRevisions', 'route-rev-1'))?.distribution, null);
    assert.equal((await doc('routes', `${S}:route-public`))?.status, 'active');
    assert.ok((await task(r.requestId, 'route')).blockedCodes?.includes('PB-02'));
  },
);

// ------------------------------------------------ 3: pages, inserts, restart

l1(
  'L1-T-PAGE: several pages, inserts behind the cursor and deletes ahead, restart from checkpoint',
  async () => {
    await account(S);
    for (const id of ['p02', 'p04', 'p06', 'p08', 'p10', 'p12', 'p14']) await quickPlan(S, id);
    const r = await request(['quick_plan']);
    const first = runner({ pageSize: 2, maxPages: 1 });
    assert.equal(
      await first.runTask({ requestId: r.requestId, taskId: r.taskId('quick_plan'), nowUtc: NOW }),
      'progress',
    );
    assert.equal(
      await first.runTask({ requestId: r.requestId, taskId: r.taskId('quick_plan'), nowUtc: NOW }),
      'progress',
    );
    const checkpoint = await doc(privacyProgressCollection, r.taskId('quick_plan'));
    assert.equal(checkpoint?.cursor, `${S}:p08`);
    // Between pages: one plan appears behind the cursor, one ahead disappears.
    await quickPlan(S, 'p01');
    await db.collection('quickPlans').doc(`${S}:p12`).delete();
    // A new runner (a restarted process) resumes from the stored checkpoint.
    assert.equal(
      await drive(
        runner({ leaseOwner: 'runner:l1-b', pageSize: 2, maxPages: 1 }),
        r.requestId,
        'quick_plan',
      ),
      'succeeded',
    );
    const plans = await db.collection('quickPlans').where('ownerId', '==', S).get();
    assert.equal(plans.size, 7);
    assert.equal(
      plans.docs.every((plan) => plan.get('status') === 'deleted'),
      true,
    );
  },
);

// ------------------------------------------------------- 4: crashes and lease

l1(
  'L1-T-CRASH: crash before the effect, after the effect, during verification; no false completion',
  async () => {
    await account(S);
    await quickPlan(S, 'c1');
    await quickPlan(S, 'c2');
    const r = await request(['quick_plan']);
    const taskId = r.taskId('quick_plan');
    // Crash inside the page, before any effect committed.
    await assert.rejects(
      runner({
        fault: (point) => {
          if (point === 'page') throw new Error('privacy_fault:page');
        },
      }).runTask({
        requestId: r.requestId,
        taskId,
        nowUtc: NOW,
      }),
      /privacy_fault:page/u,
    );
    assert.equal((await doc('quickPlans', `${S}:c1`))?.status, 'active');
    // The crashed run still holds its lease: another runner must wait for expiry.
    assert.equal(
      await runner({ leaseOwner: 'runner:l1-b' }).runTask({
        requestId: r.requestId,
        taskId,
        nowUtc: at(1),
      }),
      'lease_held',
    );
    // Crash in the verification pass, after every effect committed.
    await assert.rejects(
      runner({
        leaseOwner: 'runner:l1-b',
        fault: (point) => {
          if (point === 'verify') throw new Error('privacy_fault:verify');
        },
      }).runTask({
        requestId: r.requestId,
        taskId,
        nowUtc: at(10),
      }),
      /privacy_fault:verify/u,
    );
    assert.equal((await doc('quickPlans', `${S}:c1`))?.status, 'deleted');
    assert.equal((await task(r.requestId, 'quick_plan')).status, 'dispatched');
    assert.equal((await reconcile(r.requestId)).status, 'dispatched');
    assert.equal(
      await drive(runner({ leaseOwner: 'runner:l1-c' }), r.requestId, 'quick_plan', at(20)),
      'succeeded',
    );
    assert.equal((await reconcile(r.requestId)).status, 'completed');
    // Media: the effect committed but the checkpoint did not.
    const world = mediaWorld();
    const asset = await readyAsset(S, world.store, world.store);
    await world.composition.repository.transact((tx) => tx.putAsset(asset.ready, 0));
    const m = await request(['media']);
    await assert.rejects(
      runner({
        media: world.media,
        fault: (point) => {
          if (point === 'before_checkpoint') throw new Error('privacy_fault:checkpoint');
        },
      }).runTask({
        requestId: m.requestId,
        taskId: m.taskId('media'),
        nowUtc: NOW,
      }),
      /privacy_fault:checkpoint/u,
    );
    assert.equal((await doc(mediaCollections.assets, asset.assetId))?.lifecycle, 'deleted');
    // The rerun finds the asset already deleted and does not delete twice.
    assert.equal(
      await drive(
        runner({ leaseOwner: 'runner:l1-d', media: world.media }),
        m.requestId,
        'media',
        at(10),
      ),
      'blocked',
    );
    assert.deepEqual((await task(m.requestId, 'media')).blockedCodes, ['PB-14']);
  },
);

// ---------------------------------------------------------------- 5: holds

l1(
  'L1-T-HOLD: authority only; hold before start and during processing; release and follow-up',
  async () => {
    await account(S);
    await seed(privacyHoldCollections.authority, holdActor, { active: true });
    // Without authority nothing is placed.
    assert.deepEqual(
      await holds.place({
        actorId: 'some-client',
        holdId: '5b6c1c10-8c0e-4c8a-9a3e-0d3b7a0c0001',
        subjectId: S,
        scope: { domainId: '*', collection: '*', recordId: null },
        basisRef: 'basis',
        reviewAtUtc: at(60),
        nowUtc: NOW,
      }),
      { ok: false, code: 'authority_denied' },
    );
    for (const id of ['h1', 'h2', 'h3', 'h4']) await quickPlan(S, id);
    // Before the start: one record.
    await placeHold('5b6c1c10-8c0e-4c8a-9a3e-0d3b7a0c0002', {
      domainId: 'quick_plan',
      collection: 'quickPlans',
      recordId: `${S}:h1`,
    });
    const r = await request(['quick_plan']);
    const paced = runner({ pageSize: 1, maxPages: 1 });
    assert.equal(
      await paced.runTask({ requestId: r.requestId, taskId: r.taskId('quick_plan'), nowUtc: NOW }),
      'progress',
    );
    // During processing: a record the sweep has not reached yet.
    const late = await placeHold('5b6c1c10-8c0e-4c8a-9a3e-0d3b7a0c0003', {
      domainId: 'quick_plan',
      collection: 'quickPlans',
      recordId: `${S}:h4`,
    });
    assert.equal(await drive(paced, r.requestId, 'quick_plan'), 'succeeded');
    assert.equal((await task(r.requestId, 'quick_plan')).retainedCount, 2);
    assert.equal((await doc('quickPlans', `${S}:h1`))?.status, 'active');
    assert.equal((await doc('quickPlans', `${S}:h4`))?.status, 'active');
    assert.equal((await doc('quickPlans', `${S}:h2`))?.status, 'deleted');
    assert.equal((await reconcile(r.requestId)).status, 'completedWithRetention');
    // A change of scope is the authority's own revisioned and audited act.
    const changed = await holds.change({
      actorId: holdActor,
      holdId: late.holdId,
      expectedRevision: 1,
      reviewAtUtc: at(60 * 24 * 60),
      nowUtc: at(1),
    });
    assert.ok(changed.ok);
    assert.ok(
      (
        await holds.release({
          actorId: holdActor,
          holdId: late.holdId,
          expectedRevision: 2,
          nowUtc: at(2),
        })
      ).ok,
    );
    const audit = await db
      .collection(privacyHoldCollections.audit)
      .where('holdId', '==', late.holdId)
      .get();
    assert.deepEqual(audit.docs.map((entry) => String(entry.get('action'))).sort(), [
      'changed',
      'placed',
      'released',
    ]);
    // Release resumes processing through one linked follow-up request.
    const followUpId = randomUUID();
    assert.ok(
      (
        await service.submitLegalHoldReleaseFollowUp({
          originalRequestId: r.requestId,
          requestId: followUpId,
          subjectId: S,
          holdReleaseRevision: 3,
          semanticHash: `sha256:${'c'.repeat(64)}`,
          requiredDomainIds: ['quick_plan'],
          occurredAtUtc: at(3),
        })
      ).ok,
    );
    assert.ok((await service.verify(followUpId, 1, at(3))).ok);
    assert.ok(
      (
        await service.dispatch(
          followUpId,
          2,
          [{ domainId: 'quick_plan', marketId: 'LV', targetRevision: 1 }],
          at(3),
        )
      ).ok,
    );
    assert.equal(await drive(runner(), followUpId, 'quick_plan', at(4)), 'succeeded');
    assert.equal((await doc('quickPlans', `${S}:h4`))?.status, 'deleted');
    assert.equal((await doc('quickPlans', `${S}:h1`))?.status, 'active');
  },
);

// ------------------------------------------------------- 7, 8: shared, replay

l1(
  'L1-T-SHARED and L1-T-RESURRECT: Page and shared data stay; no write, replay or rebuild revives erased data',
  async () => {
    await account(S);
    await account(O);
    // A Page S manages: the page and its content are the Page's, not S's.
    await seed(identityAuthorityCollections.managedPages, 'page-x', {
      pageId: 'page-x',
      ownerUserId: O,
    });
    await seed(identityAuthorityCollections.pageMemberships, `page-x:${S}`, {
      pageId: 'page-x',
      userId: S,
    });
    await seed('contentDrafts', 'page-draft', {
      createdByUserId: O,
      publisherRef: { type: 'page', id: 'page-x' },
    });
    await quickPlan(S, 'replayed');
    const r = await request(['quick_plan', 'identity']);
    assert.equal(await drive(runner(), r.requestId, 'quick_plan'), 'succeeded');
    assert.equal(await drive(runner(), r.requestId, 'identity'), 'blocked');
    assert.ok(await doc(identityAuthorityCollections.managedPages, 'page-x'));
    assert.ok(await doc(identityAuthorityCollections.pageMemberships, `page-x:${S}`));
    assert.ok(await doc('contentDrafts', 'page-draft'));
    // A late save with the subject's former Session cannot recreate the plan.
    const late = await new FirestoreQuickPlanService(db, clock).command(
      {
        firebaseUid: 'uid-s',
        sessionId: 'no-longer-valid',
        sessionHandle: 'x',
        installationId: 'i',
      },
      {
        schemaVersion: 1,
        requestId: randomUUID(),
        ownerContext: S,
        idempotencyKey: 'l1-late-save-0001',
        commandType: 'save',
        planId: 'replayed',
        expectedRevision: 4,
        plan: {
          id: 'replayed',
          revision: 4,
          mood: 'calm',
          maxDurationMinutes: 60,
          freeOnly: true,
          walkingOnly: true,
          sourcePrompt: 'again',
          currencyCode: 'EUR',
          steps: [],
        },
      },
    );
    assert.equal(late.kind, 'rejected');
    assert.equal((await doc('quickPlans', `${S}:replayed`))?.status, 'deleted');
    // A replay of the same erasure task does nothing new.
    assert.equal(await drive(runner(), r.requestId, 'quick_plan'), 'succeeded');
    assert.equal((await doc('quickPlans', `${S}:replayed`))?.revision, 4);
  },
);

// --------------------------------------------------------- 9: retention expiry

l1('L1-T-RET: retention expiry dispatches deletion only without an applicable hold', async () => {
  const registry = new RetentionRegistry([
    {
      policyId: 'l1.test-only',
      status: 'accepted',
      durationDays: 30,
      legalHoldSupported: true,
      evidenceRevision: 'test-only',
    },
    { policyId: 'l1.unresolved', status: 'unresolved', legalHoldSupported: true },
  ]);
  const hold = await placeHold('6f1d0b9e-2b2c-4c8e-8f0a-1a2b3c4d0001', {
    domainId: 'library',
    collection: 'libraryEntries',
    recordId: 'held-entry',
  });
  const target = (recordId: string, policyId = 'l1.test-only') => ({
    domainId: 'library',
    recordId,
    policyId,
    createdAtUtc: parseUtcInstant('2026-08-01T00:00:00.000Z'),
    legalHold: privacyHoldApplies(hold, {
      domainId: 'library',
      collection: 'libraryEntries',
      recordId,
    }),
  });
  const plan = planRetentionDeletionDispatch(
    registry,
    [target('held-entry'), target('free-entry'), target('no-policy', 'l1.unresolved')],
    parseUtcInstant(NOW),
  );
  assert.deepEqual(
    plan.map((item) => item.decision.action),
    ['retain_legal_hold', 'dispatch_deletion', 'policy_unavailable'],
  );
});

// --------------------------------------- 10, 11: one account, every writer

l1(
  'L1-T-E2E and L1-T-LEAK: one account through every writer; answers carry no foreign data',
  async () => {
    await account(S);
    await account(O);
    await seed(libraryCollections.entries, 'e2e-entry', {
      ownerId: S,
      kind: 'favorite',
      objectId: 'x',
    });
    await quickPlan(S, 'e2e-plan');
    await seed('safetyRelations', 'e2e-rel', {
      ownerId: S,
      targetUserId: O,
      kind: 'mute',
      active: true,
      revision: 1,
    });
    await seed('trustSafetyReports', 'e2e-report', {
      reporterUserId: O,
      narrative: 'REPORT-NARRATIVE',
      target: { userId: S },
    });
    await seed(reviewCollections.reviews, 'e2e-review', {
      authorId: S,
      text: 'REVIEW-TEXT',
      deleted: false,
    });
    await seed('notificationInboxItems', 'e2e-inbox', { recipientId: S });
    await seed('contentDrafts', 'e2e-draft', { createdByUserId: S });
    const world = mediaWorld();
    const asset = await readyAsset(S, world.store, world.store);
    await world.composition.repository.transact((tx) => tx.putAsset(asset.ready, 0));
    await placeHold('7a2e3f40-1b2c-4d5e-8f60-0a1b2c3d0001', {
      domainId: 'quick_plan',
      collection: 'quickPlans',
      recordId: `${S}:e2e-plan`,
    });
    const domains = [...privacyErasureDomainIds];
    const r = await request(domains);
    const all = runner({ media: world.media });
    const outcomes: Record<string, RunOutcome> = {};
    // Identity last: its teardown is blocked anyway, and it never runs before the others.
    for (const domain of [...domains.filter((d) => d !== 'identity'), 'identity'])
      outcomes[domain] = await drive(all, r.requestId, domain);
    assert.deepEqual(outcomes, {
      admin_support: 'blocked',
      booking: 'succeeded',
      content: 'blocked',
      library: 'succeeded',
      media: 'blocked',
      moderation: 'blocked',
      notifications: 'succeeded',
      quick_plan: 'succeeded',
      reviews: 'blocked',
      route: 'succeeded',
      scenario: 'succeeded',
      security: 'blocked',
      trust_safety: 'blocked',
      identity: 'blocked',
    });
    const request_ = await reconcile(r.requestId);
    // Never completed while any writer is blocked.
    assert.equal(request_.status, 'partially_completed');
    assert.equal(await doc(libraryCollections.entries, 'e2e-entry'), undefined);
    assert.equal(await doc('notificationInboxItems', 'e2e-inbox'), undefined);
    assert.equal((await doc('quickPlans', `${S}:e2e-plan`))?.status, 'active');
    assert.equal((await doc(mediaCollections.assets, asset.assetId))?.lifecycle, 'deleted');
    assert.equal((await doc('safetyRelations', 'e2e-rel'))?.active, false);
    // What the requester and the audit trail can see.
    const intake = new PrivacyRequestIntake(db, service, repository);
    const view = await intake.view(request_);
    const visible = JSON.stringify([
      view,
      (await db.collection(privacyOrchestrationCollections.requests).get()).docs.map((d) =>
        d.data(),
      ),
      (await db.collection(privacyOrchestrationCollections.tasks).get()).docs.map((d) => d.data()),
      (await db.collection(privacyProgressCollection).get()).docs.map((d) => d.data()),
      (await db.collection(privacyHoldCollections.audit).get()).docs.map((d) => d.data()),
    ]);
    for (const secret of [
      O,
      'REPORT-NARRATIVE',
      'REVIEW-TEXT',
      'case-l1-basis-SECRET-0001',
      'private evening',
    ])
      assert.equal(visible.includes(secret), false, secret);
    assert.equal(JSON.stringify(view).includes(S), false);
  },
);
