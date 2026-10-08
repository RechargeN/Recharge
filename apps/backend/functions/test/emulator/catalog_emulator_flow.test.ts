import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { after, test } from 'node:test';
import { getStorage } from 'firebase-admin/storage';

import { eventAuthoringComposition } from '../../src/content_entry.js';
import type { ContentCatalogSource } from '../../src/modules/catalog/application/ports.js';
import type { FeedPage } from '../../src/modules/catalog/application/catalog_query_service.js';
import { createEmulatorCatalogComposition } from '../../src/modules/catalog/infrastructure/emulator_catalog_composition.js';
import { catalogCollections } from '../../src/modules/catalog/infrastructure/firestore_catalog_repository.js';
import { contentCollections } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { IdentityPublisherAuthority } from '../../src/modules/identity_publisher/application/identity_publisher_authority.js';
import { FirestoreIdentityAuthorityRepository } from '../../src/modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import { LocalPageCreationPolicy } from '../../src/modules/identity_publisher/infrastructure/local_page_creation_policy.js';
import { LocalVerificationDecisionAdapter } from '../../src/modules/identity_publisher/infrastructure/local_verification_decision_adapter.js';
import { SyntheticProviderIdentityVerifier } from '../../src/modules/identity_publisher/infrastructure/synthetic_provider_identity_verifier.js';
import { createEmulatorMediaComposition } from '../../src/modules/media/infrastructure/emulator_media_composition.js';
import { mediaCollections } from '../../src/modules/media/infrastructure/firestore_media_repository.js';
import { EmulatorStaffAuthority } from '../../src/modules/moderation/infrastructure/emulator_staff_authority.js';
import { moderationCollections } from '../../src/modules/moderation/infrastructure/firestore_moderation_repository.js';
import type { EntityId } from '../../src/shared/ids.js';
import { standEventBody } from '../stand/stand_content.js';
import { emulatorFirestore } from '../support/booking_emulator.js';

const firestore = emulatorFirestore();
const media = createEmulatorMediaComposition({
  firestore,
  bucket: getStorage().bucket('demo-recharge.appspot.com') as never,
});
const content = eventAuthoringComposition(firestore, { media });
const run = randomUUID().slice(0, 8);
const subcategory = `sub-${run}`;
const png = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  'base64',
);
const sha256 = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');

/** The Catalog's own clock; Content keeps the real one. */
const clock = { fixedMs: null as number | null, now: () => new Date(clock.fixedMs ?? Date.now()) };
const catalog = createEmulatorCatalogComposition(firestore, { clock });
const base = { schemaVersion: 1, marketId: 'LV', subcategoryIds: [subcategory] };

after(async () => {
  for (const name of [
    ...Object.values(catalogCollections),
    ...Object.values(contentCollections),
    ...Object.values(mediaCollections),
    ...Object.values(moderationCollections),
  ]) {
    const snapshot = await firestore.collection(name).get();
    for (const document of snapshot.docs) await document.ref.delete();
  }
});

let sequence = 0;
const key = (label: string) => `e1-${label}-${run}-${(sequence += 1)}`;

const world = (async () => {
  const repository = new FirestoreIdentityAuthorityRepository(firestore);
  const nowUtc = new Date().toISOString();
  const reviewer = randomUUID();
  const authority = new IdentityPublisherAuthority({
    repository,
    providerVerifier: new SyntheticProviderIdentityVerifier(),
    verificationDecisions: new LocalVerificationDecisionAdapter(new Set([reviewer])),
    pagePolicy: new LocalPageCreationPolicy(true, 2),
  });
  const creator = randomUUID();
  const staff = randomUUID();
  for (const [label, id] of [
    ['reviewer', reviewer],
    ['creator', creator],
    ['staff', staff],
  ] as const)
    await authority.accounts.ensureAccount({
      proof: {
        provider: 'google',
        providerTenant: 'demo-recharge-emulator',
        proof: `local-test:google:e1-${run}-${label}`,
      },
      proposedUserId: id,
      proposedIdentityId: randomUUID(),
      nowUtc,
      accountCreationEnabled: true,
    });
  await authority.creatorVerification.submit({
    userId: creator,
    verificationId: randomUUID(),
    evidenceRefIds: [randomUUID()],
    nowUtc,
  });
  await authority.creatorVerification.decide({
    reviewerId: reviewer,
    userId: creator,
    status: 'verified',
    nowUtc,
  });
  const pageId = randomUUID();
  await authority.pages.create({
    userId: creator,
    pageId,
    membershipId: randomUUID(),
    marketId: 'LV',
    nowUtc,
  });
  await authority.pages.decidePage({ reviewerId: reviewer, pageId, decision: 'verified', nowUtc });
  await new EmulatorStaffAuthority(firestore, repository).grant(staff, nowUtc);
  const session = async (userId: string) => {
    const sessionId = randomUUID();
    await authority.sessions.issue({
      userId,
      sessionId,
      firebaseUid: `e1-${run}-${userId}`,
      installationId: `e1-${run}-installation-${userId}`,
      issuedAtUtc: nowUtc,
      snapshotExpiresAtUtc: new Date(Date.now() + 3_600_000).toISOString(),
    });
    return { userId: userId as EntityId, sessionId: sessionId as EntityId };
  };
  return { pageId, creator: await session(creator), staff: await session(staff) };
})();

function eventBody(
  cover: string,
  options: { title: string; date: string; online?: boolean; unlisted?: boolean },
) {
  const body = standEventBody(cover, randomUUID()) as Record<string, unknown>;
  const schedule = { ...(body.schedule as Record<string, unknown>), localStartDate: options.date };
  const slot = {
    ...(body.eventSlots as Record<string, unknown>[])[0],
    localDate: options.date,
    startAtUtc: `${options.date}T15:00:00.000Z`,
    endAtUtc: `${options.date}T17:00:00.000Z`,
  };
  return {
    ...body,
    title: options.title,
    subcategoryId: subcategory,
    schedule,
    eventSlots: [slot],
    visibility: options.unlisted === true ? 'unlisted' : 'public',
    ...(options.online === true
      ? {
          format: 'online',
          onlineAccessMode: 'publicLink',
          publicOnlineUrl: 'https://example.com/live',
          location: { marketCityId: 'riga', countryCode: 'LV' },
        }
      : {}),
  };
}

function succeeded<T>(result: { kind: string; data?: unknown }, label: string): T {
  assert.equal(result.kind, 'succeeded', `${label}: ${JSON.stringify(result)}`);
  return (result as { data: T }).data;
}

/** A real Content publication: draft, Media cover, submit, staff approval, owner publish. */
async function publish(options: {
  title: string;
  date: string;
  online?: boolean;
  unlisted?: boolean;
}) {
  const { creator, staff, pageId } = await world;
  const publisherRef = { type: 'page', id: pageId } as const;
  const draft = succeeded<{ draftId: string; contentId: string; revision: number }>(
    await content.content.execute(creator, {
      schemaVersion: 1,
      commandType: 'createDraft',
      idempotencyKey: key('draft'),
      payload: {
        typeId: 'event',
        publisherRef,
        marketId: 'LV',
        body: eventBody(randomUUID(), options),
      },
    }),
    'createDraft',
  );
  const upload = succeeded<{ uploadSessionId: string; assetId: string }>(
    await media.service.execute(creator, {
      schemaVersion: 1,
      commandType: 'createUploadSession',
      idempotencyKey: key('session'),
      payload: {
        family: 'image',
        marketId: 'LV',
        visibilityClass: 'publicDerived',
        declaredMediaType: 'image/png',
        declaredByteLength: png.length,
        publisherRef,
        entityIntent: { domain: 'content', entityId: draft.contentId, purpose: 'contentMedia' },
      },
    }),
    'upload',
  );
  const asset = await media.repository.transact((tx) => tx.asset(upload.assetId));
  assert.ok(asset);
  await media.objectStore.put(asset.objectKeyHandle, png);
  const confirmed = succeeded<{
    revision: number;
    sourceGenerationRef: { providerGeneration: string };
  }>(
    await media.service.execute(creator, {
      schemaVersion: 1,
      commandType: 'confirmUpload',
      idempotencyKey: key('confirm'),
      payload: {
        uploadSessionId: upload.uploadSessionId,
        expectedSha256: sha256(png),
        expectedByteLength: png.length,
      },
    }),
    'confirm',
  );
  succeeded(
    await media.service.execute(creator, {
      schemaVersion: 1,
      commandType: 'finalizeAsset',
      idempotencyKey: key('finalize'),
      payload: {
        assetId: upload.assetId,
        expectedAssetRevision: confirmed.revision,
        sourceProviderGeneration: confirmed.sourceGenerationRef.providerGeneration,
        expectedSha256: sha256(png),
        expectedByteLength: png.length,
      },
    }),
    'finalize',
  );
  const bound = succeeded<{ revision: number }>(
    await content.content.execute(creator, {
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: key('bind'),
      payload: {
        draftId: draft.draftId,
        expectedRevision: draft.revision,
        body: eventBody(upload.assetId, options),
      },
    }),
    'bind',
  );
  const submission = succeeded<{ submissionId: string }>(
    await content.content.execute(creator, {
      schemaVersion: 1,
      commandType: 'submitForPublication',
      idempotencyKey: key('submit'),
      payload: { draftId: draft.draftId, expectedDraftRevision: bound.revision },
    }),
    'submit',
  );
  const approved = await content.moderation.service.decide(staff, {
    schemaVersion: 1,
    action: 'approve',
    idempotencyKey: key('approve'),
    reason: 'e1 emulator approval',
    target: { contentId: draft.contentId, submissionId: submission.submissionId },
  });
  assert.equal(approved.kind, 'succeeded', JSON.stringify(approved));
  succeeded(
    await content.content.execute(creator, {
      schemaVersion: 1,
      commandType: 'publishApprovedRevision',
      idempotencyKey: key('publish'),
      payload: { submissionId: submission.submissionId, expectedPointerRevision: 0 },
    }),
    'publish',
  );
  return draft.contentId;
}

async function ownerWithdraw(contentId: string) {
  const { creator } = await world;
  const pointer = await content.contentRepository.transact((tx) => tx.pointer(contentId));
  assert.ok(pointer);
  succeeded(
    await content.content.execute(creator, {
      schemaVersion: 1,
      commandType: 'withdrawPublication',
      idempotencyKey: key('withdraw'),
      payload: { contentId, expectedPointerRevision: pointer.revision, mode: 'withdraw' },
    }),
    'withdraw',
  );
}

async function feed(
  query: Record<string, unknown> = {},
  token?: string,
  cursor?: string,
): Promise<FeedPage> {
  const result = await catalog.query.feed({
    query: { ...base, ...query },
    ...(token === undefined ? {} : { snapshotToken: token }),
    ...(cursor === undefined ? {} : { cursor }),
  });
  assert.equal(result.kind, 'succeeded', JSON.stringify(result));
  return result;
}

const titles = (page: FeedPage) => page.items.map((item) => item.title);
const ids: Record<string, string> = {};

void test(
  'delivery projects published Events; hidden ones never reach Feed, Map or Search',
  { timeout: 240_000 },
  async () => {
    ids.a = await publish({ title: 'Clay A', date: '2035-10-05' });
    ids.b = await publish({ title: 'Clay B online', date: '2035-10-06', online: true });
    ids.c = await publish({ title: 'Clay C unlisted', date: '2035-10-07', unlisted: true });
    const active = await catalog.sets.ensureActive();
    const delivered = await catalog.projector.deliverFromContent(active.setId);
    assert.equal(delivered.stoppedAt, null);
    assert.equal(delivered.synced, true);
    assert.ok(delivered.applied >= 3);

    const page = await feed();
    assert.deepEqual(titles(page), ['Clay A', 'Clay B online'], 'unlisted is never listed');
    assert.equal(page.freshness.availability, 'not_connected');
    assert.deepEqual(page.items[0]?.availability.status, 'not_connected');
    const map = await catalog.query.map({ query: base, snapshotToken: page.snapshotToken });
    assert.equal(map.kind, 'succeeded');
    if (map.kind !== 'succeeded') return;
    assert.deepEqual(
      map.leaves.map((leaf) => leaf.ref.contentId),
      [ids.a],
    );
    assert.equal(map.notMappable, 1);
    assert.equal(map.snapshot.projectionSetRevision, page.snapshot.projectionSetRevision);
    const search = await catalog.query.search({ query: { ...base, literalText: 'online' } });
    assert.equal(search.kind, 'succeeded');
    if (search.kind === 'succeeded') assert.deepEqual(titles(search), ['Clay B online']);
    const unlisted = await catalog.query.details({ contentId: ids.c });
    assert.deepEqual(unlisted.kind === 'succeeded' ? [unlisted.state, unlisted.reason] : unlisted, [
      'excluded',
      'unlisted',
    ]);

    // A repeated delivery finds nothing new; a repeated fact is deduped.
    const again = await catalog.projector.deliverFromContent(active.setId);
    assert.equal(again.processed, 0);
    const [published] = await catalog.source.effectsForContent(ids.a, null, 10);
    assert.ok(published);
    assert.deepEqual(await catalog.projector.consumeContentFact(active.setId, published), {
      outcome: 'deduped',
    });
  },
);

void test('old or reordered facts never resurrect a hidden Event; other types stay disabled', async () => {
  const active = await catalog.sets.ensureActive();
  const [published] = await catalog.source.effectsForContent(ids.a!, null, 10);
  assert.ok(published);
  await ownerWithdraw(ids.a!);
  await catalog.projector.deliverFromContent(active.setId);
  assert.deepEqual(titles(await feed()), ['Clay B online']);
  // The same fact again, and an older revision under another id: nothing changes.
  assert.deepEqual(await catalog.projector.consumeContentFact(active.setId, published), {
    outcome: 'deduped',
  });
  const replay = await catalog.projector.consumeContentFact(active.setId, {
    ...published,
    effectId: `${published.effectId}:replayed`,
  });
  assert.equal(replay.outcome, 'stale');
  assert.deepEqual(titles(await feed()), ['Clay B online']);

  // Reordered delivery into an isolated set: the newer hide arrives first.
  const setId = `reorder-${run}`;
  await catalog.repository.transact((tx) =>
    tx.putSet({
      setId,
      status: 'building',
      origin: 'rebuild',
      revision: 0,
      createdAtUtc: new Date().toISOString(),
      activatedAtUtc: null,
      lastSourceSyncAtUtc: null,
      deliveryCheckpoint: null,
    }),
  );
  const facts = await catalog.source.effectsForContent(ids.a!, null, 10);
  assert.equal(facts.length, 2);
  const [first, second] = facts;
  assert.equal((await catalog.projector.consumeContentFact(setId, second)).outcome, 'applied');
  assert.equal((await catalog.projector.consumeContentFact(setId, first)).outcome, 'stale');
  const versions = await catalog.repository.versionsForContent(setId, ids.a!);
  const current = versions.find((version) => version.validToRevision === null);
  assert.deepEqual([current?.state, current?.reason], ['excluded', 'withdrawn']);

  const place = await catalog.projector.consumeContentFact(setId, {
    ...published,
    effectId: `place-${run}`,
    contentId: randomUUID(),
    typeId: 'place',
    visibility: 'visible',
  });
  assert.deepEqual(place, {
    outcome: 'applied',
    projection: 'excluded',
    reason: 'type_disabled',
    catalogRevision: 2,
  });
});

void test(
  'a lost delivery is found by reconciliation and recovered; a missing source fact is reported',
  { timeout: 240_000 },
  async () => {
    const active = await catalog.sets.ensureActive();
    ids.d = await publish({ title: 'Clay D', date: '2035-10-08' });
    // Delivery that loses every fact of D.
    const lossy = createEmulatorCatalogComposition(firestore, {
      clock,
      source: (source): ContentCatalogSource => ({
        ...source,
        effectsAfter: async (afterCheckpoint, limit) =>
          (await source.effectsAfter(afterCheckpoint, limit)).filter(
            (fact) => fact.contentId !== ids.d,
          ),
        effectsForContent: (...args) => source.effectsForContent(...args),
        latestEffect: () => source.latestEffect(),
        pointersPage: (...args) => source.pointersPage(...args),
        publishedRevision: (id) => source.publishedRevision(id),
        typeVisibilityPolicy: (typeId) => source.typeVisibilityPolicy(typeId),
      }),
    });
    await lossy.projector.deliverFromContent(active.setId);
    assert.equal(titles(await feed()).includes('Clay D'), false);

    const report = await catalog.reconciler.reconcile(active.setId);
    assert.ok(
      report.findings.some((finding) => finding.code === 'gap' && finding.contentId === ids.d),
    );
    assert.ok(report.recovered >= 1);
    assert.equal(report.complete, true, JSON.stringify(report.findings));
    assert.ok(titles(await feed()).includes('Clay D'));

    // A fact Content itself lost is reported, never invented, and the set is not marked synced.
    ids.e = await publish({ title: 'Clay E', date: '2035-10-09' });
    const [lost] = await catalog.source.effectsForContent(ids.e, null, 10);
    assert.ok(lost);
    const lostRef = firestore.collection(contentCollections.effects).doc(lost.effectId);
    const stored = (await lostRef.get()).data();
    await lostRef.delete();
    const before = await catalog.sets.active();
    const broken = await catalog.reconciler.reconcile(active.setId);
    assert.ok(
      broken.findings.some(
        (finding) => finding.code === 'source_effect_missing' && finding.contentId === ids.e,
      ),
    );
    assert.equal(broken.complete, false);
    assert.equal((await catalog.sets.active())?.lastSourceSyncAtUtc, before?.lastSourceSyncAtUtc);
    assert.equal(titles(await feed()).includes('Clay E'), false);
    // Restoring the source fact lets the next reconciliation recover it.
    await lostRef.create(stored!);
    const repaired = await catalog.reconciler.reconcile(active.setId);
    assert.equal(repaired.complete, true, JSON.stringify(repaired.findings));
    assert.ok(titles(await feed()).includes('Clay E'));
  },
);

void test(
  'the checkpoint moves only after a fact was processed',
  { timeout: 240_000 },
  async () => {
    const active = await catalog.sets.ensureActive();
    ids.f = await publish({ title: 'Clay F', date: '2035-10-10' });
    const [factF] = await catalog.source.effectsForContent(ids.f, null, 10);
    assert.ok(factF);
    let failures = 1;
    const flaky = createEmulatorCatalogComposition(firestore, {
      clock,
      source: (source): ContentCatalogSource => ({
        effectsAfter: (...args) => source.effectsAfter(...args),
        effectsForContent: (...args) => source.effectsForContent(...args),
        latestEffect: () => source.latestEffect(),
        pointersPage: (...args) => source.pointersPage(...args),
        typeVisibilityPolicy: (typeId) => source.typeVisibilityPolicy(typeId),
        publishedRevision: (id) => {
          if (id === factF.publishedRevisionId && failures > 0) {
            failures -= 1;
            return Promise.reject(new Error('source read failed'));
          }
          return source.publishedRevision(id);
        },
      }),
    });
    const stopped = await flaky.projector.deliverFromContent(active.setId);
    assert.deepEqual(stopped.stoppedAt, { effectId: factF.effectId, code: 'source_unavailable' });
    assert.equal(stopped.synced, false);
    assert.notEqual(stopped.checkpoint?.effectId, factF.effectId, 'not past the failed fact');
    assert.equal(titles(await feed()).includes('Clay F'), false);
    const resumed = await catalog.projector.deliverFromContent(active.setId);
    assert.equal(resumed.stoppedAt, null);
    assert.ok(resumed.applied >= 1);
    assert.ok(titles(await feed()).includes('Clay F'));
  },
);

void test(
  'pagination keeps its snapshot and order while facts arrive; tombstones still win',
  { timeout: 300_000 },
  async () => {
    const active = await catalog.sets.ensureActive();
    for (const [name, date] of [
      ['g1', '2035-10-11'],
      ['g2', '2035-10-12'],
      ['g3', '2035-10-13'],
      ['g4', '2035-10-14'],
    ] as const)
      ids[name] = await publish({ title: `Clay ${name.toUpperCase()}`, date });
    await catalog.projector.deliverFromContent(active.setId);
    const first = await feed({ pageSize: 2 });
    const snapshotTitles = [
      'Clay B online',
      'Clay D',
      'Clay E',
      'Clay F',
      'Clay G1',
      'Clay G2',
      'Clay G3',
      'Clay G4',
    ];
    assert.equal(first.totalEligible, snapshotTitles.length);
    assert.deepEqual(titles(first), snapshotTitles.slice(0, 2));

    // A new Event that would sort first, and a hide of one not yet shown.
    ids.h = await publish({ title: 'Clay H', date: '2035-10-04' });
    await ownerWithdraw(ids.g4!);
    await catalog.projector.deliverFromContent(active.setId);

    const seen = [...titles(first)];
    let cursor = first.nextCursor;
    while (cursor !== null) {
      const next = await feed({ pageSize: 2 }, first.snapshotToken, cursor);
      assert.equal(next.snapshotToken, first.snapshotToken);
      seen.push(...titles(next));
      cursor = next.nextCursor;
    }
    assert.deepEqual(
      seen,
      snapshotTitles.filter((title) => title !== 'Clay G4'),
      'no duplicate, no skip, no new item, tombstone wins',
    );
    assert.equal(new Set(seen).size, seen.length);
    // A new applied query takes a new snapshot that includes H first.
    assert.equal(titles(await feed())[0], 'Clay H');

    // Cursor errors are typed.
    const tampered = await catalog.query.feed({
      query: { ...base, pageSize: 2 },
      snapshotToken: first.snapshotToken,
      cursor: `${first.nextCursor}x`,
    });
    assert.deepEqual(tampered, { kind: 'invalid', code: 'cursor_invalid' });
    const otherToken = (await feed({ pageSize: 2 })).snapshotToken;
    const mismatch = await catalog.query.feed({
      query: { ...base, pageSize: 2 },
      snapshotToken: otherToken,
      cursor: first.nextCursor!,
    });
    assert.deepEqual(mismatch, { kind: 'invalid', code: 'cursor_snapshot_mismatch' });
    clock.fixedMs = Date.now() + 601_000;
    try {
      const expired = await catalog.query.feed({
        query: { ...base, pageSize: 2 },
        snapshotToken: first.snapshotToken,
        cursor: first.nextCursor!,
      });
      assert.deepEqual(expired, { kind: 'stale', code: 'cursor_expired' });
    } finally {
      clock.fixedMs = null;
    }
  },
);

void test(
  'rebuild is isolated, activation is atomic and rollback keeps tombstones',
  { timeout: 300_000 },
  async () => {
    const active = await catalog.sets.ensureActive();
    await catalog.projector.deliverFromContent(active.setId);
    const before = await feed();
    const membership = before.items.map((item) => item.ref.contentId);
    const rebuilt = await catalog.sets.rebuild();
    assert.equal(rebuilt.report.complete, true, JSON.stringify(rebuilt.report.findings));
    // Not queryable before activation.
    assert.equal((await feed()).snapshot.projectionSetId, active.setId);
    assert.deepEqual(await catalog.sets.activate(rebuilt.setId, 'someone-else'), {
      ok: false,
      code: 'active_moved',
    });
    const activated = await catalog.sets.activate(rebuilt.setId, active.setId);
    assert.deepEqual(activated, { ok: true, setId: rebuilt.setId, previousSetId: active.setId });
    const stale = await catalog.query.feed({ query: base, snapshotToken: before.snapshotToken });
    assert.deepEqual(stale, { kind: 'stale', code: 'snapshot_superseded' });
    const after = await feed();
    assert.equal(after.snapshot.projectionSetId, rebuilt.setId);
    assert.deepEqual(
      after.items.map((item) => item.ref.contentId),
      membership,
      'the rebuilt set serves the same membership',
    );
    assert.equal(titles(after).includes('Clay A'), false);

    const rolledBack = await catalog.sets.rollback(rebuilt.setId);
    assert.deepEqual(rolledBack, { ok: true, setId: active.setId, previousSetId: rebuilt.setId });
    const back = await feed();
    assert.equal(back.snapshot.projectionSetId, active.setId);
    assert.deepEqual(
      back.items.map((item) => item.ref.contentId),
      membership,
    );
    assert.equal(titles(back).includes('Clay A'), false, 'the withdrawn Event stays hidden');
  },
);

void test(
  'freshness follows the projection age and the approved time rules hold',
  { timeout: 120_000 },
  async () => {
    const active = await catalog.sets.ensureActive();
    const syncedAt = Date.now();
    clock.fixedMs = syncedAt;
    try {
      await catalog.projector.deliverFromContent(active.setId);
      clock.fixedMs = syncedAt + 900_000;
      assert.equal((await feed()).freshness.projection, 'fresh');
      clock.fixedMs = syncedAt + 901_000;
      const late = await feed();
      assert.equal(late.freshness.projection, 'stale');
      assert.equal(late.freshness.overall, 'stale', 'expired data is never shown as fresh');

      // At 2035-10-11 16:00Z G1 is running: it comes first; earlier Events have ended.
      clock.fixedMs = Date.parse('2035-10-11T16:00:00.000Z');
      const running = await feed();
      assert.equal(running.items[0]?.title, 'Clay G1');
      assert.equal(running.items[0]?.occurrence.state, 'running');
      for (const ended of ['Clay B online', 'Clay D', 'Clay E', 'Clay F', 'Clay H'])
        assert.equal(titles(running).includes(ended), false, `${ended} has ended`);
    } finally {
      clock.fixedMs = null;
    }
  },
);
