// D3.7 (T3) Find People on the Emulator through the real callables, Firestore,
// C2 moderation, BCK-06 consent, the Catalog and K2: default-off flags, the
// private/public matrix, revoke/hide/expiry/block/sanction against current,
// old-snapshot, cursor and exact-ID reads, lost answers and the retention
// erasure. Synthetic data only; every fixture is removed afterwards.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { after, before, test } from 'node:test';
import type { DocumentData } from 'firebase-admin/firestore';

import { deliverContentEffects, catalogEffectConsumer } from '../../src/content_effects_entry.js';
import { purgeFindPeopleRetention } from '../../src/content_entry.js';
import { createEmulatorCatalogComposition } from '../../src/modules/catalog/infrastructure/emulator_catalog_composition.js';
import { withoutFindPeopleExactLocation } from '../../src/modules/content/domain/type_rules/find_people_rules.js';
import { contentCollections } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { findPeopleIdentityCollections } from '../../src/modules/identity_publisher/infrastructure/find_people_privacy_authority.js';
import { createK1 } from '../../src/moderation_entry.js';
import { FirestoreSafetyService } from '../../src/modules/trust_safety/firestore_safety_service.js';
import {
  safetyCollections as sc,
  safetyPolicyRevision,
} from '../../src/modules/trust_safety/safety_policy.js';
import { catalogFlagIds, contentFlagIds, identityFlagIds } from '../../src/shared/feature_flags.js';
import { publicCellCentre } from '../../src/shared/find_people_policy.js';
import { emulatorFirestore } from '../support/booking_emulator.js';
import type { PublishingActor } from '../support/content_event_world.js';
import {
  createFindPeopleWorld,
  findPeopleBody,
  flagFixture,
  type Answer,
  type SignedActor,
} from '../support/content_find_people_world.js';
import { FakeClock } from '../support/fake_clock.js';

const firestore = emulatorFirestore();
const world = createFindPeopleWorld(firestore, 'd37-fp');
const flags = flagFixture(firestore, [
  contentFlagIds.findPeopleAuthoring,
  identityFlagIds.findPeopleConsent,
  catalogFlagIds.findPeople,
  catalogFlagIds.discoverRead,
  catalogFlagIds.delivery,
  contentFlagIds.eventAuthoring,
  contentFlagIds.sessionAuthoring,
  'trustSafety.runtime',
  'moderation.staff',
]);
const clock = { now: () => new Date() };
const k1 = createK1(firestore, clock);
const k2 = new FirestoreSafetyService(firestore, clock, k1.workflows);
const savedAuthority = new Map<string, DocumentData | undefined>();

// Values only the private source holds; none may appear in a public answer or record.
const secrets = ['56.95182', '24.08571', 'riverside steps', 'Ķīpsalas iela', 'blue bench'];
const assertNoSecrets = (value: unknown, label: string) => {
  const text = JSON.stringify(value);
  for (const secret of secrets) assert.equal(text.includes(secret), false, `${label}: ${secret}`);
};

let creator: SignedActor;
let adult: SignedActor;
let unattested: SignedActor;
let minor: SignedActor;
let staff: PublishingActor;
let pageId: string;

const hint = (p: PublishingActor) => ({
  firebaseUid: p.firebaseUid,
  sessionId: p.actor.sessionId,
  sessionHandle: p.sessionHandle,
  installationId: p.installationId,
});
function data<T>(answer: Answer, label: string): T {
  assert.equal(answer.kind, 'succeeded', `${label}: ${JSON.stringify(answer)}`);
  return answer.data as T;
}
const fpQuery = { schemaVersion: 1, marketId: 'LV', typeIds: ['find_people'] };

before(async () => {
  await flags.save();
  for (const id of ['owner', 'abusePolicy'])
    savedAuthority.set(id, (await firestore.collection(sc.authority).doc(id).get()).data());
  const actors = await world.actors;
  creator = actors.creator;
  staff = actors.staff;
  pageId = actors.pageId;
  adult = await world.viewer('adult');
  unattested = await world.viewer('unattested');
  minor = await world.viewer('minor');
  await world.attest(adult.actor.userId, 'adult_18_plus');
  await world.attest(minor.actor.userId, 'minor');
});

after(async () => {
  await world.cleanup();
  for (const [id, value] of savedAuthority) {
    const ref = firestore.collection(sc.authority).doc(id);
    if (value === undefined) await ref.delete();
    else await ref.set(value);
  }
  await flags.restore();
});

/** Draft, full body, consent, submit, staff approval and owner publish. */
async function published(
  change: (body: Record<string, unknown>) => void = () => undefined,
  publisherRef: { type: 'user' | 'page'; id: string } = { type: 'user', id: creator.actor.userId },
) {
  const draft = data<{ draftId: string; contentId: string; revision: number }>(
    await world.content(creator, 'createDraft', {
      typeId: 'find_people',
      marketId: 'LV',
      publisherRef,
      body: {},
    }),
    'create',
  );
  const bound = data<{ revision: number }>(
    await world.content(creator, 'updateDraft', {
      draftId: draft.draftId,
      expectedRevision: draft.revision,
      body: await findPeopleBody(creator.actor.userId, change),
    }),
    'update',
  );
  data(await world.consent(creator, 'grantFindPeopleConsent', draft.contentId, 0), 'consent');
  const submission = data<{ submissionId: string }>(
    await world.content(creator, 'submitForPublication', {
      draftId: draft.draftId,
      expectedDraftRevision: bound.revision,
    }),
    'submit',
  );
  data(
    await world.decide('approve', {
      contentId: draft.contentId,
      submissionId: submission.submissionId,
    }),
    'approve',
  );
  const revision = data<{ publishedRevisionId: string; body: Record<string, unknown> }>(
    await world.content(creator, 'publishApprovedRevision', {
      submissionId: submission.submissionId,
      expectedPointerRevision: 0,
    }),
    'publish',
  );
  return { ...draft, revision: bound.revision, ...revision };
}

async function deliver() {
  const outcomes = await deliverContentEffects(firestore, {
    flags: { isEnabled: (id) => Promise.resolve(id === catalogFlagIds.delivery) },
    consumers: [catalogEffectConsumer()],
  });
  assert.deepEqual(outcomes, [{ consumer: 'catalog', status: 'completed' }]);
}

const listed = (answer: Answer) =>
  data<{ items: { ref: { contentId: string } }[] }>(answer, 'feed').items.map(
    (item) => item.ref.contentId,
  );
const detailsItem = async (viewer: SignedActor, contentId: string, extra = {}) =>
  data<{ item: unknown }>(
    await world.discover(viewer, 'details', { contentId, ...extra }),
    'details',
  ).item;

void test('flags off: no authoring, no consent grant, no Catalog type; other types stay off', async () => {
  for (const id of [
    contentFlagIds.findPeopleAuthoring,
    identityFlagIds.findPeopleConsent,
    catalogFlagIds.findPeople,
    contentFlagIds.eventAuthoring,
    contentFlagIds.sessionAuthoring,
  ])
    await flags.set(id, false);
  await flags.set(catalogFlagIds.discoverRead, true);
  await world.attest(creator.actor.userId, 'adult_18_plus');
  const create = {
    typeId: 'find_people',
    marketId: 'LV',
    publisherRef: { type: 'user', id: creator.actor.userId },
    body: {},
  };
  assert.equal((await world.content(creator, 'createDraft', create)).code, 'type_disabled');
  assert.equal(
    (await world.consent(creator, 'grantFindPeopleConsent', randomUUID(), 0)).code,
    'feature_disabled',
  );
  assert.equal(
    (await world.discover(adult, 'feed', { query: fpQuery })).code,
    'type_disabled:find_people',
  );
  await flags.set(contentFlagIds.findPeopleAuthoring, true);
  // Its flag enables only Find People.
  assert.equal(
    (await world.content(creator, 'createDraft', { ...create, typeId: 'event' })).code,
    'type_disabled',
  );
});

void test('age authority: no attestation or a minor refuses; client claims are not authority', async () => {
  await flags.set(contentFlagIds.findPeopleAuthoring, true);
  await flags.set(identityFlagIds.findPeopleConsent, true);
  const create = (actor: SignedActor) =>
    world.content(actor, 'createDraft', {
      typeId: 'find_people',
      marketId: 'LV',
      publisherRef: { type: 'user', id: creator.actor.userId },
      body: { findPeople: { birthDate: '1990-01-01', ageVerified: true } },
    });
  await world.attest(creator.actor.userId, null);
  assert.equal((await create(creator)).code, 'age_eligibility_required');
  await world.attest(creator.actor.userId, 'minor');
  assert.equal((await create(creator)).code, 'age_eligibility_required');
  await world.attest(creator.actor.userId, 'adult_18_plus');
  const draft = data<{ draftId: string; contentId: string; revision: number }>(
    await create(creator),
    'create',
  );
  // A body that claims an age is the author's private draft, but never validates.
  data(await world.consent(creator, 'grantFindPeopleConsent', draft.contentId, 0), 'consent');
  const refused = await world.content(creator, 'submitForPublication', {
    draftId: draft.draftId,
    expectedDraftRevision: draft.revision,
  });
  assert.equal(refused.code, 'validation_failed');
  assert.ok(JSON.stringify(refused).includes('find_people.client_age_forbidden'));
  // A minor cannot consent either.
  await world.attest(creator.actor.userId, 'minor');
  assert.equal(
    (await world.consent(creator, 'grantFindPeopleConsent', randomUUID(), 0)).code,
    'not_found',
  );
  await world.attest(creator.actor.userId, 'adult_18_plus');
});

let first: Awaited<ReturnType<typeof published>>;
let second: Awaited<ReturnType<typeof published>>;

void test('C3 + consent: lost answers replay, only the author reads the source, publish is public', async () => {
  await flags.set(contentFlagIds.findPeopleAuthoring, true);
  await flags.set(identityFlagIds.findPeopleConsent, true);
  // Projection follows its flag at delivery time: on before the first publication.
  await flags.set(catalogFlagIds.findPeople, true);
  await flags.set(catalogFlagIds.delivery, true);
  const createKey = world.key('fixed-create');
  const createPayload = {
    typeId: 'find_people',
    marketId: 'LV',
    publisherRef: { type: 'user', id: creator.actor.userId },
    body: {},
  };
  const created = data<{ draftId: string; contentId: string; revision: number }>(
    await world.content(creator, 'createDraft', createPayload, createKey),
    'create',
  );
  // The answer was "lost": the same command returns the same draft.
  assert.deepEqual(
    data(await world.content(creator, 'createDraft', createPayload, createKey), 'replay'),
    created,
  );
  const bound = data<{ revision: number }>(
    await world.content(creator, 'updateDraft', {
      draftId: created.draftId,
      expectedRevision: created.revision,
      body: await findPeopleBody(creator.actor.userId),
    }),
    'update',
  );
  const submit = () =>
    world.content(creator, 'submitForPublication', {
      draftId: created.draftId,
      expectedDraftRevision: bound.revision,
    });
  assert.equal((await submit()).code, 'privacy_consent_required');
  // Only the author of exactly this draft can consent, as an adult.
  assert.equal(
    (await world.consent(adult, 'grantFindPeopleConsent', created.contentId, 0)).code,
    'not_found',
  );
  const grantKey = world.key('grant');
  const granted = data<{ consent: { state: string; expiresAtUtc: string; grantedAtUtc: string } }>(
    await world.consent(creator, 'grantFindPeopleConsent', created.contentId, 0, grantKey),
    'grant',
  );
  assert.equal(granted.consent.state, 'active');
  assert.equal(
    Date.parse(granted.consent.expiresAtUtc) - Date.parse(granted.consent.grantedAtUtc),
    30 * 86_400_000,
  );
  assert.deepEqual(
    data(
      await world.consent(creator, 'grantFindPeopleConsent', created.contentId, 0, grantKey),
      'grant replay',
    ),
    granted,
  );
  const submission = data<{ submissionId: string }>(await submit(), 'submit');
  data(
    await world.decide('approve', {
      contentId: created.contentId,
      submissionId: submission.submissionId,
    }),
    'approve',
  );
  const publishKey = world.key('publish');
  const publish = () =>
    world.content(
      creator,
      'publishApprovedRevision',
      { submissionId: submission.submissionId, expectedPointerRevision: 0 },
      publishKey,
    );
  const revision = data<{ publishedRevisionId: string; body: Record<string, unknown> }>(
    await publish(),
    'publish',
  );
  assert.deepEqual(data(await publish(), 'publish replay'), revision);
  assertNoSecrets(revision.body, 'published revision');
  const exact = (await findPeopleBody(creator.actor.userId)) as unknown as {
    findPeople: { meeting: { exact: { latitude: number; longitude: number } } };
  };
  const centre = publicCellCentre(
    exact.findPeople.meeting.exact.latitude,
    exact.findPeople.meeting.exact.longitude,
  );
  const location = (
    revision.body.findPeople as { meeting: { publicLocation: Record<string, number> } }
  ).meeting.publicLocation;
  assert.equal(location.latitude, centre.latitude);
  assert.equal(location.longitude, centre.longitude);
  // Private source: the author only (not another account, not staff).
  const own = data<{ body: unknown }>(
    await world.contentQuery(creator, 'getDraft', { draftId: created.draftId }),
    'own draft',
  );
  assert.ok(JSON.stringify(own.body).includes('56.95182'));
  for (const other of [adult, unattested]) {
    const answer = await world.contentQuery(other, 'getDraft', { draftId: created.draftId });
    assert.equal(answer.kind, 'rejected');
    assertNoSecrets(answer, 'foreign getDraft');
  }
  // Exact-ID public read: adults pass the fresh gate, others do not.
  const read = (viewer: SignedActor) =>
    world.contentQuery(viewer, 'getPublishedRevision', { contentId: created.contentId });
  assertNoSecrets(data(await read(adult), 'adult exact read'), 'adult exact read');
  assert.equal((await read(unattested)).code, 'not_found');
  assert.equal((await read(minor)).code, 'not_found');
  first = { ...created, revision: bound.revision, ...revision };
});

void test('Catalog/MapObject: only the cell centre, adults only, private data in no stored record', async () => {
  await flags.set(catalogFlagIds.findPeople, true);
  await flags.set(catalogFlagIds.delivery, true);
  await flags.set(catalogFlagIds.discoverRead, true);
  second = await published((body) => {
    const slot = (body.findPeople as { schedule: { slot: Record<string, string> } }).schedule.slot;
    slot.id = randomUUID();
    slot.startAtUtc = '2027-05-16T06:00:00.000Z';
    slot.endAtUtc = '2027-05-16T07:30:00.000Z';
    (body as { title: string }).title = 'Second morning run by the Daugava';
  });
  await deliver();
  const feed = data<{ items: Record<string, unknown>[]; snapshotToken: string }>(
    await world.discover(adult, 'feed', { query: fpQuery }),
    'feed',
  );
  const card = feed.items.find(
    (item) => (item.ref as { contentId: string }).contentId === first.contentId,
  );
  assert.ok(card, JSON.stringify(feed));
  assertNoSecrets(feed, 'feed');
  const centre = (first.body.findPeople as { meeting: { publicLocation: Record<string, number> } })
    .meeting.publicLocation;
  assert.deepEqual(card.point, { latitude: centre.latitude, longitude: centre.longitude });
  assert.equal(card.publicGeoPrecisionMeters, 1000);
  const map = data<{ leaves: { ref: { contentId: string }; point: unknown }[] }>(
    await world.discover(adult, 'map', { query: fpQuery, snapshotToken: feed.snapshotToken }),
    'map',
  );
  const leaf = map.leaves.find((item) => item.ref.contentId === first.contentId);
  assert.deepEqual(leaf?.point, { latitude: centre.latitude, longitude: centre.longitude });
  assertNoSecrets(map, 'map');
  const item = await detailsItem(adult, first.contentId);
  assert.ok(item);
  assertNoSecrets(item, 'details');
  // Viewers without a current adult attestation get nothing.
  for (const viewer of [unattested, minor]) {
    assert.deepEqual(listed(await world.discover(viewer, 'feed', { query: fpQuery })), []);
    assert.equal(await detailsItem(viewer, first.contentId), null);
  }
  // Stored public records hold no private value; only the draft and its own answers do.
  const allowedHolders = new Set<string>([
    contentCollections.drafts,
    contentCollections.idempotency,
  ]);
  for (const collection of await firestore.listCollections()) {
    if (allowedHolders.has(collection.id)) continue;
    for (const doc of (await collection.get()).docs) {
      const text = JSON.stringify(doc.data());
      if (!text.includes(first.contentId) && !text.includes(second.contentId)) continue;
      assertNoSecrets(doc.data(), `${collection.id}/${doc.id}`);
    }
  }
});

void test('revoke, hide, block, mute and sanction remove it from current, old snapshot, cursor and exact-ID', async () => {
  const query = { ...fpQuery, pageSize: 1 };
  const page1 = data<{
    items: { ref: { contentId: string } }[];
    snapshotToken: string;
    nextCursor: string;
  }>(await world.discover(adult, 'feed', { query }), 'page1');
  assert.deepEqual(
    page1.items.map((item) => item.ref.contentId),
    [first.contentId],
  );
  assert.ok(page1.nextCursor);
  const token = page1.snapshotToken;
  const page2 = () =>
    world.discover(adult, 'feed', { query, snapshotToken: token, cursor: page1.nextCursor });
  const oldSnapshot = () => world.discover(adult, 'feed', { query, snapshotToken: token });
  const exactRead = (contentId: string) =>
    world.contentQuery(adult, 'getPublishedRevision', { contentId });
  assert.deepEqual(listed(await page2()), [second.contentId]);

  // Consent revoke of the second request.
  data(await world.consent(creator, 'revokeFindPeopleConsent', second.contentId, 1), 'revoke');
  assert.deepEqual(listed(await page2()), []);
  assert.deepEqual(listed(await oldSnapshot()), [first.contentId]);
  assert.equal(await detailsItem(adult, second.contentId, { snapshotToken: token, query }), null);
  assert.equal((await exactRead(second.contentId)).code, 'not_found');
  assert.equal(
    (await world.contentQuery(creator, 'getPublishedRevision', { contentId: second.contentId }))
      .code,
    'not_found',
  );
  data(
    await world.contentQuery(creator, 'getDraft', { draftId: second.draftId }),
    'own private draft',
  );
  const map = data<{ leaves: { ref: { contentId: string } }[] }>(
    await world.discover(adult, 'map', { query: fpQuery, snapshotToken: token }),
    'map',
  );
  assert.equal(
    map.leaves.some((leaf) => leaf.ref.contentId === second.contentId),
    false,
  );
  // Activation cannot bring it back without consent.
  const status = data<{ pointer: { revision: number } }>(
    await world.contentQuery(creator, 'getPublicationStatus', { contentId: first.contentId }),
    'status',
  );

  // Owner hide of the first: removed from the old snapshot before any delivery.
  data(
    await world.content(creator, 'withdrawPublication', {
      contentId: first.contentId,
      expectedPointerRevision: status.pointer.revision,
      mode: 'withdraw',
    }),
    'hide',
  );
  assert.deepEqual(listed(await oldSnapshot()), []);
  assert.equal((await exactRead(first.contentId)).code, 'not_found');
  const reactivate = data<{ revision: number }>(
    await world.content(creator, 'activatePublishedRevision', {
      contentId: first.contentId,
      publishedRevisionId: first.publishedRevisionId,
      expectedPointerRevision: status.pointer.revision + 1,
    }),
    'activate',
  );
  assert.ok(reactivate.revision > status.pointer.revision);
  await deliver();
  assert.deepEqual(listed(await world.discover(adult, 'feed', { query: fpQuery })), [
    first.contentId,
  ]);

  // K2: block either way, and the viewer's mute, hide it everywhere for this viewer.
  await flags.set('trustSafety.runtime', true);
  await firestore
    .collection(sc.authority)
    .doc('abusePolicy')
    .set({ policyRevision: safetyPolicyRevision, maxPerMinute: 30 });
  const relation = (kind: 'block' | 'mute', active: boolean, expectedRevision: number) =>
    k2.relation(hint(adult), {
      schemaVersion: 1,
      requestId: randomUUID(),
      targetUserId: creator.actor.userId,
      kind,
      active,
      expectedRevision,
      idempotencyKey: randomUUID(),
    });
  for (const kind of ['block', 'mute'] as const) {
    assert.equal((await relation(kind, true, 0)).kind, 'succeeded');
    assert.deepEqual(listed(await world.discover(adult, 'feed', { query: fpQuery })), []);
    assert.equal(await detailsItem(adult, first.contentId), null);
    assert.equal((await exactRead(first.contentId)).code, 'not_found');
    assert.equal((await relation(kind, false, 1)).kind, 'succeeded');
    assert.deepEqual(listed(await world.discover(adult, 'feed', { query: fpQuery })), [
      first.contentId,
    ]);
  }

  // C2 moderation restrict of this exact object, then restore.
  const restricted = data<{ decision: { decisionId: string } }>(
    await world.decide('restrict', { contentId: first.contentId }),
    'restrict',
  );
  assert.deepEqual(listed(await world.discover(adult, 'feed', { query: fpQuery })), []);
  assert.equal((await exactRead(first.contentId)).code, 'not_found');
  data(
    await world.decide(
      'restore',
      { contentId: first.contentId },
      { restoresDecisionId: restricted.decision.decisionId },
    ),
    'restore',
  );
  await deliver();
  assert.deepEqual(listed(await world.discover(adult, 'feed', { query: fpQuery })), [
    first.contentId,
  ]);

  // T&S sanction of the author through the K2 owner path (user scope; K2
  // contentHide does not list find_people, see D3.7 §11).
  await flags.set('moderation.staff', true);
  const expiry = new Date(Date.now() + 3_600_000).toISOString();
  await firestore.collection(sc.authority).doc('owner').set({ userId: staff.actor.userId });
  await k1.staff.grantScoped(
    staff.actor.userId,
    [{ marketId: 'LV', typeId: 'user', actions: ['sanction'] }],
    expiry,
    new Date().toISOString(),
  );
  const sanctionId = randomUUID();
  const issued = await k2.issue(staff.actor, {
    sanctionId,
    subjectUserId: creator.actor.userId,
    family: 'temporarySuspend',
    durationDays: 7,
    reasonCode: 'safety',
    reason: 'Synthetic D3.7 restriction',
    idempotencyKey: randomUUID(),
  });
  assert.equal(issued.kind, 'succeeded', JSON.stringify(issued));
  assert.equal((await k2.reconcile(sanctionId)).kind, 'succeeded');
  assert.deepEqual(listed(await world.discover(adult, 'feed', { query: fpQuery })), []);
  assert.equal((await exactRead(first.contentId)).code, 'not_found');
  await k2.change(staff.actor, {
    sanctionId,
    expectedRevision: 1,
    operation: 'revoke',
    reason: 'Synthetic',
    idempotencyKey: randomUUID(),
  });
  await k2.reconcile(sanctionId);
  assert.deepEqual(listed(await world.discover(adult, 'feed', { query: fpQuery })), [
    first.contentId,
  ]);
});

void test('expiry: consent window and meeting end close the object for every new read', async () => {
  const at = (iso: string) =>
    createEmulatorCatalogComposition(firestore, {
      clock: new FakeClock(new Date(iso)),
      viewerId: adult.actor.userId,
      findPeopleEnabled: true,
    });
  const ids = async (iso: string) => {
    const feed = await at(iso).query.feed({ query: fpQuery });
    assert.equal(feed.kind, 'succeeded', JSON.stringify(feed));
    return feed.kind === 'succeeded' ? feed.items.map((item) => item.ref.contentId) : [];
  };
  assert.deepEqual(await ids(new Date().toISOString()), [first.contentId]);
  // 31 days after the grant the consent expired, long before the meeting.
  assert.deepEqual(await ids(new Date(Date.now() + 31 * 86_400_000).toISOString()), []);
  const details = await at('2027-05-15T08:00:00.000Z').query.details({
    contentId: first.contentId,
  });
  assert.ok(details.kind === 'succeeded' && details.item === null);
});

void test('retention: exact meeting data is erased 30 days after revoke, from draft and stored answers', async () => {
  const consent = (
    await firestore
      .collection(findPeopleIdentityCollections.consents)
      .doc(`${second.contentId}:${creator.actor.userId}`)
      .get()
  ).data() as { revokedAtUtc: string };
  const revokedAt = Date.parse(consent.revokedAtUtc);
  const early = await purgeFindPeopleRetention(
    firestore,
    new Date(revokedAt + 29 * 86_400_000).toISOString(),
  );
  assert.equal(early.purgedDraftIds.includes(second.draftId), false);
  const report = await purgeFindPeopleRetention(
    firestore,
    new Date(revokedAt + 31 * 86_400_000).toISOString(),
  );
  assert.ok(report.purgedDraftIds.includes(second.draftId), JSON.stringify(report));
  // The first item was hidden then reactivated earlier: that cannot reset
  // its already established retention deadline.
  assert.equal(report.purgedDraftIds.includes(first.draftId), true);
  assert.ok(report.redactedAnswers >= 1);
  const own = data<{ body: unknown; revision: number }>(
    await world.contentQuery(creator, 'getDraft', { draftId: second.draftId }),
    'purged draft',
  );
  assertNoSecrets(own.body, 'purged draft');
  assert.equal(JSON.stringify(own.body).includes('"exact"'), false);
  for (const doc of (await firestore.collection(contentCollections.idempotency).get()).docs) {
    const text = String(doc.get('outcomeJson') ?? '');
    if (text.includes(second.draftId)) assertNoSecrets(text, 'stored answer');
  }
  const audit = await firestore
    .collection(contentCollections.audit)
    .where('subjectId', '==', second.draftId)
    .get();
  assert.ok(
    audit.docs.some((doc) => doc.get('action') === 'content.find_people.private_location_purged'),
  );
  // A purged draft cannot be published again without a new exact point.
  data(await world.consent(creator, 'grantFindPeopleConsent', second.contentId, 2), 'regrant');
  const resubmit = await world.content(creator, 'submitForPublication', {
    draftId: second.draftId,
    expectedDraftRevision: own.revision,
  });
  assert.equal(resubmit.code, 'validation_failed');
});

void test('Page publisher: the author publishes for their Page; staff cannot read the source', async () => {
  const page = await published(() => undefined, { type: 'page', id: pageId });
  assertNoSecrets(page.body, 'page revision');
  const staffSigned = (await world.actors).staff;
  const foreign = await world.contentQuery(staffSigned, 'getDraft', { draftId: page.draftId });
  assert.equal(foreign.kind, 'rejected');
  assertNoSecrets(foreign, 'staff getDraft');
});

void test('retention: historical exact answers survive no-exact draft until boundary, then replay is redacted', async () => {
  const initial = data<{ draftId: string; contentId: string; revision: number }>(
    await world.content(creator, 'createDraft', {
      typeId: 'find_people',
      marketId: 'LV',
      publisherRef: { type: 'user', id: creator.actor.userId },
      body: {},
    }),
    'historical create',
  );
  const body = await findPeopleBody(creator.actor.userId);
  const payload = { draftId: initial.draftId, expectedRevision: initial.revision, body };
  const key = randomUUID();
  const exact = data<{ revision: number }>(
    await world.content(creator, 'updateDraft', payload, key),
    'exact update',
  );
  data(
    await world.content(creator, 'updateDraft', {
      draftId: initial.draftId,
      expectedRevision: exact.revision,
      body: withoutFindPeopleExactLocation(body),
    }),
    'remove current exact',
  );
  const ended = '2026-01-01T00:00:00.000Z';
  const consentRef = firestore
    .collection(findPeopleIdentityCollections.consents)
    .doc(`${initial.contentId}:${creator.actor.userId}`);
  await consentRef.set({
    contentId: initial.contentId,
    revokedAtUtc: ended,
    expiresAtUtc: '2027-01-01T00:00:00.000Z',
  });
  const draftRef = firestore.collection(contentCollections.drafts).doc(initial.draftId);
  const before = (await draftRef.get()).data();
  const answers = async () =>
    (
      await firestore
        .collection(contentCollections.idempotency)
        .where('actorUserId', '==', creator.actor.userId)
        .get()
    ).docs.filter((d) => String(d.get('outcomeJson')).includes(initial.draftId));
  await purgeFindPeopleRetention(firestore, '2026-01-30T23:59:59.999Z');
  assert.ok((await answers()).some((d) => String(d.get('outcomeJson')).includes('"exact"')));
  // Two purgers race with an unrelated draft update. No stale replacement of
  // the current body/revision, and no duplicate purge audit on retry.
  const reports = await Promise.all([
    purgeFindPeopleRetention(firestore, '2026-01-31T00:00:00.000Z'),
    purgeFindPeopleRetention(firestore, '2026-01-31T00:00:00.000Z'),
    draftRef.update({ retentionRaceMarker: true }),
  ]);
  assert.ok(reports.slice(0, 2).some((r) => r && 'redactedAnswers' in r && r.redactedAnswers > 0));
  for (const d of await answers())
    assertNoSecrets(d.get('outcomeJson'), 'historical stored answer');
  const replay = data<{ body: unknown }>(
    await world.content(creator, 'updateDraft', payload, key),
    'old command replay',
  );
  assertNoSecrets(replay.body, 'historical replay');
  assert.equal(JSON.stringify(replay.body).includes('"exact"'), false);
  const after = (await draftRef.get()).data();
  assert.equal(after?.revision, before?.revision);
  assert.equal(after?.bodyJson, before?.bodyJson);
  assert.equal(after?.retentionRaceMarker, true);
  const audits = await firestore
    .collection(contentCollections.audit)
    .where('subjectId', '==', initial.draftId)
    .get();
  assert.equal(
    audits.docs.filter((d) => d.get('action') === 'content.find_people.private_location_purged')
      .length,
    1,
  );
  assert.equal(
    (await purgeFindPeopleRetention(firestore, '2026-02-01T00:00:00.000Z')).redactedAnswers,
    0,
  );
});

void test('retention: owner terminal event survives later pointer changes and legacy records get no fresh period', async () => {
  const item = await published();
  const ended = '2026-02-01T00:00:00.000Z';
  const pointerRef = firestore.collection(contentCollections.pointers).doc(item.contentId);
  const auditRef = firestore.collection(contentCollections.audit).doc(randomUUID());
  await auditRef.set({
    action: 'content.publication.withdraw',
    subjectId: item.contentId,
    occurredAtUtc: ended,
  });
  await pointerRef.update({ ownerHold: 'withdrawn', updatedAtUtc: '2026-03-01T00:00:00.000Z' });
  await purgeFindPeopleRetention(firestore, '2026-03-02T23:59:59.999Z');
  const draftRef = firestore.collection(contentCollections.drafts).doc(item.draftId);
  assert.ok(String((await draftRef.get()).get('bodyJson')).includes('"exact"'));
  await Promise.all([
    purgeFindPeopleRetention(firestore, '2026-03-03T00:00:00.000Z'),
    pointerRef.update({
      updatedAtUtc: '2026-03-20T00:00:00.000Z',
      moderationHold: { kind: 'restricted', decisionId: 'late' },
    }),
  ]);
  assertNoSecrets((await draftRef.get()).get('bodyJson'), 'stable event deadline');
  assert.equal(
    (await purgeFindPeopleRetention(firestore, '2026-03-03T00:00:00.000Z')).purgedDraftIds.includes(
      item.draftId,
    ),
    false,
  );
  // Existing hidden record with no surviving owner event: creation is the
  // conservative anchor, never the mutable pointer or repair time.
  const legacy = await published();
  const legacyRef = firestore.collection(contentCollections.drafts).doc(legacy.draftId);
  await legacyRef.update({ createdAtUtc: ended });
  await firestore
    .collection(contentCollections.pointers)
    .doc(legacy.contentId)
    .update({ ownerHold: 'withdrawn', updatedAtUtc: '2026-05-01T00:00:00.000Z' });
  await purgeFindPeopleRetention(firestore, '2026-03-03T00:00:00.000Z');
  assertNoSecrets((await legacyRef.get()).get('bodyJson'), 'legacy no extension');
});
