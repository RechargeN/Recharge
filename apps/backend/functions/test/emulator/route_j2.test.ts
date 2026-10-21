// J2 / RTE-PUB-01 (docs/product/route/ROUTE_J2_PUBLICATION_BCK11_AMENDMENT.md):
// Route as a Create type through the real BCK-11 Route service, Content, C2
// moderation (with RP-06 publisher trust) and the local Catalog on the
// Emulator. No Scenario handoff, RouteMode or Quick Plan effect exists; the
// suite owns and removes every fixture it creates.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { after, before, test } from 'node:test';

import { createEmulatorCatalogComposition } from '../../src/modules/catalog/infrastructure/emulator_catalog_composition.js';
import { canonicalJson, sha256Hex } from '../../src/modules/content/domain/published_revision.js';
import { moderationCollections } from '../../src/modules/moderation/infrastructure/firestore_moderation_repository.js';
import { quickPlanCollections } from '../../src/modules/quick_plan/quick_plan_contract.js';
import { FirestoreRouteService } from '../../src/modules/route/firestore_route_service.js';
import {
  routeCollections,
  routeFlag,
  routePublicationFlag,
} from '../../src/modules/route/route_contract.js';
import { contentFlagIds } from '../../src/shared/feature_flags.js';
import { emulatorFirestore } from '../support/booking_emulator.js';
import { cleanupContentEmulatorState } from '../support/content_emulator_cleanup.js';
import { createPlaceWorld, expectData } from '../support/content_place_world.js';
import { setLocalFlag } from '../support/notifications_world.js';
import {
  j2PrivateMarkers,
  line,
  routeContentBody,
  routeOf,
  waypoint,
  zigzag,
} from '../support/route_j2_fixtures.js';
import { i3Identity } from '../support/scenario_i3_world.js';

type Json = Record<string, unknown>;
type Hint = {
  firebaseUid: string;
  installationId: string;
  sessionId: string;
  sessionHandle: string;
};
interface Actor {
  readonly userId: string;
  readonly hint: Hint;
}

const db = emulatorFirestore();
const routes = new FirestoreRouteService(db, { now: () => new Date() });
const catalog = createEmulatorCatalogComposition(db, {
  environment: { ...process.env, RECHARGE_TEST_ROUTE_CATALOG: 'true' },
});
const disabledCatalog = createEmulatorCatalogComposition(db, {
  environment: { ...process.env, RECHARGE_TEST_ROUTE_CATALOG: 'false' },
});
const flags = [
  routeFlag,
  routePublicationFlag,
  contentFlagIds.routeAuthoring,
  'identity.session.establish',
];
const extra = [...Object.values(routeCollections), ...Object.values(quickPlanCollections)];
// Built after the cleanup in `before`: the cleanup removes Identity records too.
let world: ReturnType<typeof createPlaceWorld>;
let owner: Actor, stranger: Actor, pageId: string;
let unrelatedDigest: string;

/** Scenario and Quick Plan must never change because of a Route publication. */
async function unrelated() {
  const values = [];
  for (const name of [
    ...Object.values(quickPlanCollections),
    'scenarios',
    'scenarioRevisions',
    'scenarioShares',
  ]) {
    const docs = await db.collection(name).get();
    values.push([name, docs.docs.map((d) => [d.id, d.data()]).sort()]);
  }
  return sha256Hex(canonicalJson(values));
}

before(async () => {
  await cleanupContentEmulatorState(db, extra);
  for (const flag of flags) await setLocalFlag(db, flag, true);
  world = createPlaceWorld(db, 'j2', {
    enabledTypes: new Set(['event', 'place', 'route'] as const),
  });
  const actors = await world.actors;
  pageId = actors.pageId;
  owner = {
    userId: actors.creator.actor.userId,
    hint: {
      firebaseUid: actors.creator.firebaseUid,
      installationId: actors.creator.installationId,
      sessionId: actors.creator.actor.sessionId,
      sessionHandle: actors.creator.sessionHandle,
    },
  };
  stranger = await i3Identity(db, 'j2-stranger-' + randomUUID(), new Date());
  unrelatedDigest = await unrelated();
});
after(async () => {
  try {
    assert.equal(await unrelated(), unrelatedDigest, 'J2 must not touch Scenario or Quick Plan');
  } finally {
    for (const flag of flags) await setLocalFlag(db, flag, false);
    await cleanupContentEmulatorState(db, extra);
    for (const name of [...extra, moderationCollections.publisherTrust])
      assert.equal((await db.collection(name).limit(1).get()).empty, true, name);
    process.stdout.write(
      'J2 cleanup verified: Route, revisions, Content, Media, Moderation, trust, Catalog fixtures and flags removed.\n',
    );
  }
});

const ok = (result: Json, label: string): Json => {
  assert.equal(result.kind, 'succeeded', `${label}: ${JSON.stringify(result)}`);
  return result;
};
const refused = (result: Json, code: string, label: string) =>
  assert.equal(result.code, code, `${label}: ${JSON.stringify(result)}`);
const leaks = (value: unknown) => {
  const json = JSON.stringify(value);
  for (const marker of [...j2PrivateMarkers, 'anchorId', 'turningAnchorId', 'startMeters'])
    assert.equal(json.includes(marker), false, `leak: ${marker}`);
};
const ulid = () => '0' + randomUUID().replaceAll('-', '').slice(0, 25).toUpperCase();

function routeCommand(
  actor: Actor,
  routeId: string,
  commandType: string,
  expectedRevision: number,
  fields: Json = {},
): Json {
  return {
    schemaVersion: 1,
    requestId: randomUUID(),
    ownerContext: actor.userId,
    idempotencyKey: randomUUID(),
    commandType,
    routeId,
    expectedRevision,
    ...fields,
  };
}
const command = async (
  actor: Actor,
  routeId: string,
  type: string,
  revision: number,
  fields?: Json,
) =>
  (await routes.command(actor.hint, routeCommand(actor, routeId, type, revision, fields))) as Json;

/** A stored owner Route (J1 `save`), optionally with a trim (J1 `setPrivacyTrim`). */
async function storedRoute(
  dto: Json = routeOf([zigzag(300)]),
  trim?: { startMeters: number; endMeters: number },
  actor = owner,
) {
  const routeId = ulid();
  ok(await command(actor, routeId, 'save', 0, { route: dto }), 'save');
  let revision = 1;
  if (trim) {
    ok(await command(actor, routeId, 'setPrivacyTrim', 1, { privacyTrim: trim }), 'trim');
    revision = 2;
  }
  return { routeId, revision };
}

/** Content draft pinned to a fresh distribution of the Route. */
async function contentDraft(
  routeId: string,
  revision: number,
  publisherRef: Json = { type: 'user', id: owner.userId },
) {
  const pinned = ok(await command(owner, routeId, 'distribute', revision), 'distribute');
  const body = routeContentBody({
    routeId,
    routeRevisionId: String(pinned.routeRevisionId),
    contentHash: String(pinned.contentHash),
    distribution: pinned.distribution as Json,
  });
  const draft = expectData<{ draftId: string; contentId: string; revision: number }>(
    await world.execute({
      commandType: 'createDraft',
      payload: { typeId: 'route', publisherRef, marketId: 'LV', body },
    }),
    'createDraft route',
  );
  return { ...draft, pinned, body };
}
type Submission = {
  submissionId: string;
  state: string;
  moderation: { profileId: string; policyDecisionId?: string };
};
const submit = async (draft: { draftId: string; revision: number }) =>
  expectData<Submission>(await world.submit(draft.draftId, draft.revision), 'submit route');
async function publish(contentId: string, submissionId: string) {
  const pointer = await world.pointer(contentId).catch(() => null);
  return expectData<{ publishedRevisionId: string }>(
    await world.publishApproved(submissionId, pointer?.revision ?? 0),
    'publish route',
  );
}
async function approve(contentId: string, submissionId: string) {
  return expectData<{ decision: { decisionId: string } }>(
    await world.decide('approve', { contentId, submissionId }),
    'approve route',
  );
}
async function deliver() {
  const set = await catalog.sets.ensureActive();
  await catalog.projector.deliverFromContent(set.setId);
}
const query = { schemaVersion: 1, marketId: 'LV', typeIds: ['route'] };
async function feed() {
  await deliver();
  const page = await catalog.query.feed({ query });
  assert.equal(page.kind, 'succeeded', JSON.stringify(page));
  if (page.kind !== 'succeeded') throw new Error('feed');
  return page;
}
const trust = async (publisherRef: Json) =>
  (
    await db
      .collection(moderationCollections.publisherTrust)
      .doc(`route:${String(publisherRef.type)}:${String(publisherRef.id)}`)
      .get()
  ).data();

void test('1. first Route goes through manual review; Catalog shows start, summary and preview only', async () => {
  const dto = routeOf([zigzag(1500)]) as unknown as Json;
  (dto.waypoints as Json[]).push(waypoint(zigzag(1500)[700]!));
  const { routeId, revision } = await storedRoute(dto, { startMeters: 150, endMeters: 150 });
  const draft = await contentDraft(routeId, revision);
  assert.equal(draft.contentId, routeId, 'one publication per Route: contentId = routeId');
  const submission = await submit(draft);
  assert.equal(submission.state, 'under_review');
  assert.equal(submission.moderation.profileId, 'emulator.operator-review');
  refused(
    await world.publishApproved(submission.submissionId, 0),
    'moderation_required',
    'publish before review',
  );
  // RP-06: a Route rejection names its reason class; any other code is refused.
  refused(
    await world.decide('reject', {
      contentId: routeId,
      submissionId: submission.submissionId,
    }),
    'invalid_contract',
    'reject without reason class',
  );
  refused(
    await world.decide(
      'approve',
      { contentId: routeId, submissionId: submission.submissionId },
      { reasonCode: 'route.prohibited_content' },
    ),
    'invalid_contract',
    'approve with a reason class',
  );
  await approve(routeId, submission.submissionId);
  await publish(routeId, submission.submissionId);

  const page = await feed();
  const card = page.items.find((item) => item.ref.contentId === routeId) as Json | undefined;
  assert.ok(card, 'listed');
  assert.equal('track' in card, false, 'the card has no full track');
  assert.deepEqual(card.preview, (draft.pinned.distribution as Json).preview);
  const start = (draft.pinned.distribution as Json).start as Json;
  assert.deepEqual(card.point, {
    latitude: Number(start.latE7) / 1e7,
    longitude: Number(start.lonE7) / 1e7,
  });
  // The public start is the trimmed one, never the stored first point.
  assert.notDeepEqual(card.point, { latitude: 56.9496, longitude: 24.1052 });
  leaks(page);
  const map = await catalog.query.map({ query });
  assert.equal(map.kind, 'succeeded');
  if (map.kind === 'succeeded') {
    const leaf = map.leaves.find((l) => l.ref.contentId === routeId);
    assert.deepEqual(leaf?.preview, card.preview);
    leaks(map);
  }
  const details = await catalog.query.details({ contentId: routeId });
  assert.equal(details.kind, 'succeeded');
  if (details.kind === 'succeeded') {
    assert.equal(details.state, 'listed');
    const item = details.item as unknown as Json;
    assert.deepEqual((item.track as Json).segments, (draft.pinned.distribution as Json).segments);
    leaks(details);
  }
  // A stranger reads exactly the published revision, without private data.
  const exact = (await world.composition.content.query(
    { userId: stranger.userId, sessionId: stranger.hint.sessionId } as never,
    { schemaVersion: 1, queryType: 'getPublishedRevision', payload: { contentId: routeId } },
  )) as Json;
  ok(exact, 'stranger exact read');
  leaks(exact);
  assert.equal((await trust({ type: 'user', id: owner.userId }))?.state, 'trusted');
});

void test('2. RP-06: after a clean approval the next Route of that publisher is auto-approved', async () => {
  const { routeId, revision } = await storedRoute();
  const draft = await contentDraft(routeId, revision);
  const submission = await submit(draft);
  assert.equal(submission.state, 'approved_for_publication');
  assert.equal(submission.moderation.profileId, 'route.trusted-publisher');
  const record = await trust({ type: 'user', id: owner.userId });
  assert.equal(submission.moderation.policyDecisionId, record?.decisionId, 'audited decision');
  await publish(routeId, submission.submissionId);
  assert.ok((await feed()).items.some((item) => item.ref.contentId === routeId));
  // The author's own withdrawal changes nothing about trust.
  const pointer = await world.pointer(routeId);
  expectData(await world.withdraw(routeId, pointer.revision), 'author withdraw');
  assert.equal((await trust({ type: 'user', id: owner.userId }))?.state, 'trusted');
  // A Page is a separate publisher (RP-04): its first Route is reviewed manually.
  const pageRoute = await storedRoute();
  const pageDraft = await contentDraft(pageRoute.routeId, pageRoute.revision, {
    type: 'page',
    id: pageId,
  });
  const pageSubmission = await submit(pageDraft);
  assert.equal(pageSubmission.state, 'under_review');
  await approve(pageRoute.routeId, pageSubmission.submissionId);
  await publish(pageRoute.routeId, pageSubmission.submissionId);
  assert.equal((await trust({ type: 'page', id: pageId }))?.state, 'trusted');
});

void test('3. RP-06: only a staff-confirmed violation withdraws trust; a clean review restores it', async () => {
  const listed = await storedRoute();
  const listedDraft = await contentDraft(listed.routeId, listed.revision);
  const listedSubmission = await submit(listedDraft);
  assert.equal(listedSubmission.state, 'approved_for_publication');
  await publish(listed.routeId, listedSubmission.submissionId);
  // Staff restrict after review, with its reason class: trust is lost.
  expectData(
    await world.decide(
      'restrict',
      { contentId: listed.routeId },
      { reasonCode: 'route.unsafe_or_private_location' },
    ),
    'staff restrict',
  );
  assert.equal((await trust({ type: 'user', id: owner.userId }))?.state, 'untrusted');
  assert.equal(
    (await feed()).items.some((item) => item.ref.contentId === listed.routeId),
    false,
    'restricted Route leaves the Catalog',
  );
  // The next Route is reviewed by hand again; a rejection keeps it untrusted.
  const next = await storedRoute();
  const nextDraft = await contentDraft(next.routeId, next.revision);
  const rejected = await submit(nextDraft);
  assert.equal(rejected.state, 'under_review');
  expectData(
    await world.decide(
      'reject',
      { contentId: next.routeId, submissionId: rejected.submissionId },
      { reasonCode: 'route.misleading_difficulty_or_conditions' },
    ),
    'staff reject',
  );
  assert.equal((await trust({ type: 'user', id: owner.userId }))?.state, 'untrusted');
  // The author resubmits; a clean approval earns trust back.
  const resubmitted = await submit({ draftId: nextDraft.draftId, revision: nextDraft.revision });
  assert.equal(resubmitted.state, 'under_review');
  await approve(next.routeId, resubmitted.submissionId);
  assert.equal((await trust({ type: 'user', id: owner.userId }))?.state, 'trusted');
  const after = await storedRoute();
  assert.equal(
    (await submit(await contentDraft(after.routeId, after.revision))).state,
    'approved_for_publication',
  );
  // The Page publisher keeps its own trust throughout.
  assert.equal((await trust({ type: 'page', id: pageId }))?.state, 'trusted');
});

void test('4. RP-02: recorded GPS needs 200 m hidden at both ends before it can be distributed', async () => {
  const dto = routeOf([line(900)], { kinds: ['recordedGps'] }) as unknown as Json;
  (dto.waypoints as Json[]).push(waypoint(line(1, 2)[0]!));
  const { routeId } = await storedRoute(dto);
  refused(await command(owner, routeId, 'distribute', 1), 'privacy_trim_required', 'untrimmed');
  ok(
    await command(owner, routeId, 'setPrivacyTrim', 1, {
      privacyTrim: { startMeters: 200, endMeters: 199 },
    }),
    'short trim',
  );
  refused(await command(owner, routeId, 'distribute', 2), 'privacy_trim_required', 'one end');
  ok(
    await command(owner, routeId, 'setPrivacyTrim', 2, {
      privacyTrim: { startMeters: 200, endMeters: 200 },
    }),
    'trim',
  );
  const pinned = ok(await command(owner, routeId, 'distribute', 3), 'distribute');
  const distribution = pinned.distribution as Json;
  assert.equal((distribution.waypoints as Json[]).length, 0, 'waypoint at the hidden start');
  assert.notEqual((distribution.start as Json).lonE7, line(1)[0]![1]);
  leaks(distribution);
  // The receipt is compact: the replay reads the snapshot again.
  const receipts = await db
    .collection(routeCollections.receipts)
    .where('ownerId', '==', owner.userId)
    .get();
  for (const receipt of receipts.docs) assert.equal('distribution' in receipt.data().result, false);
});

void test('5. RP-01: snapshots are immutable, pinned by CAS and hash, and owned by the author', async () => {
  const { routeId } = await storedRoute();
  refused(await command(owner, routeId, 'distribute', 2), 'revision_conflict', 'stale');
  const first = ok(await command(owner, routeId, 'distribute', 1), 'first');
  const again = ok(await command(owner, routeId, 'distribute', 1), 'same revision');
  assert.equal(again.routeRevisionId, first.routeRevisionId, 'one snapshot per revision');
  // A later J1 save does not change the snapshot and does not bump it.
  ok(
    await command(owner, routeId, 'save', 1, {
      route: routeOf([zigzag(200)], { title: 'Edited later' }),
    }),
    'save after distribute',
  );
  const stored = (
    await db.collection(routeCollections.revisions).doc(String(first.routeRevisionId)).get()
  ).data()!;
  assert.equal(stored.contentHash, first.contentHash);
  assert.deepEqual(stored.distribution, first.distribution);
  // A stranger cannot reserve or publish someone else's Route.
  const body = routeContentBody({
    routeId,
    routeRevisionId: String(first.routeRevisionId),
    contentHash: String(first.contentHash),
    distribution: first.distribution as Json,
  });
  const foreign = (await world.composition.content.execute(
    { userId: stranger.userId, sessionId: stranger.hint.sessionId } as never,
    {
      schemaVersion: 1,
      idempotencyKey: randomUUID(),
      commandType: 'createDraft',
      payload: {
        typeId: 'route',
        publisherRef: { type: 'user', id: stranger.userId },
        marketId: 'LV',
        body,
      },
    },
  )) as Json;
  assert.equal(foreign.kind, 'rejected');
  // A draft is work in progress; a tampered distribution never passes submit.
  const tampered = structuredClone(body);
  (tampered.route.distribution.summary as Json).distanceMeters = 1;
  const draft = expectData<{ draftId: string; contentId: string; revision: number }>(
    await world.execute({
      commandType: 'createDraft',
      payload: {
        typeId: 'route',
        publisherRef: { type: 'user', id: owner.userId },
        marketId: 'LV',
        body: tampered,
      },
    }),
    'author draft',
  );
  assert.equal(draft.contentId, routeId, 'the author reserves the id');
  const bad = (await world.submit(draft.draftId, draft.revision)) as Json;
  assert.equal(bad.code, 'validation_failed', JSON.stringify(bad));
  assert.ok(JSON.stringify(bad).includes('route.distribution_hash'), JSON.stringify(bad));
  refused(
    await world.execute({
      commandType: 'createDraft',
      payload: {
        typeId: 'route',
        publisherRef: { type: 'user', id: owner.userId },
        marketId: 'LV',
        body,
      },
    }),
    'revision_conflict',
    'second draft for the same Route',
  );
  // The snapshot of revision 1 is published exactly as it was pinned.
  const fixed = expectData<{ revision: number }>(
    await world.update(draft.draftId, draft.revision, body),
    'restore body',
  );
  const submission = await submit({ draftId: draft.draftId, revision: fixed.revision });
  await publish(routeId, submission.submissionId);
  const exact = (await world.composition.content.query(
    { userId: stranger.userId, sessionId: stranger.hint.sessionId } as never,
    { schemaVersion: 1, queryType: 'getPublishedRevision', payload: { contentId: routeId } },
  )) as unknown as { data: { body: { title: string } } };
  assert.equal(exact.data.body.title, 'Riga riverside walk', 'not the later edited title');
});

void test('6. RP-11: delete waits for withdrawal, then erases the snapshots and blocks reactivation', async () => {
  const { routeId, revision } = await storedRoute();
  const draft = await contentDraft(routeId, revision);
  const submission = await submit(draft);
  // A pending submission blocks deletion too.
  refused(await command(owner, routeId, 'delete', revision), 'publication_active', 'pending');
  const published = await publish(routeId, submission.submissionId);
  refused(await command(owner, routeId, 'delete', revision), 'publication_active', 'published');
  const pointer = await world.pointer(routeId);
  expectData(await world.withdraw(routeId, pointer.revision), 'withdraw');
  ok(await command(owner, routeId, 'delete', revision), 'delete after withdraw');
  const snapshot = (
    await db.collection(routeCollections.revisions).doc(String(draft.pinned.routeRevisionId)).get()
  ).data()!;
  assert.equal(snapshot.status, 'erased');
  assert.equal(snapshot.distribution, null);
  assert.equal(snapshot.contentHash, draft.pinned.contentHash, 'hash stays');
  // The withdrawn revision cannot come back: its Route source is gone.
  const after = await world.pointer(routeId);
  const activated = (await world.activate(
    routeId,
    published.publishedRevisionId,
    after.revision,
  )) as Json;
  assert.equal(activated.kind, 'rejected', JSON.stringify(activated));
  refused(await command(owner, routeId, 'distribute', revision + 1), 'deleted', 'tombstone');
});

void test('7. flags: publication and the Catalog family are default-off and fail closed', async () => {
  const { routeId } = await storedRoute();
  await setLocalFlag(db, routePublicationFlag, false);
  try {
    refused(await command(owner, routeId, 'distribute', 1), 'feature_disabled', 'flag off');
  } finally {
    await setLocalFlag(db, routePublicationFlag, true);
  }
  // Nothing was recorded while the flag was off: the same command now succeeds.
  ok(await command(owner, routeId, 'distribute', 1), 'flag on');
  await deliver();
  const disabled = await disabledCatalog.query.feed({ query });
  assert.equal(disabled.kind, 'unsupported');
  // No RouteMode or Scenario handoff exists in the snapshot.
  const docs = await db.collection(routeCollections.revisions).get();
  for (const doc of docs.docs) {
    const json = JSON.stringify(doc.data());
    for (const word of ['RouteMode', 'scenario', 'quickPlan', 'stops'])
      assert.equal(json.includes(word), false, word);
  }
});
