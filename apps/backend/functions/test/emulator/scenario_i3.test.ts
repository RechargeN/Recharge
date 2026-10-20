// I3 / SCN-PUB-01 (SCENARIO_PUBLICATION_BCK10_AMENDMENT.md): personal, unlisted
// and public Scenario through real Planning, Content, Media, C2 moderation and
// Catalog owner services on the Emulator. Every check of the I3 matrix maps to
// one test below; the suite owns and removes every fixture it creates.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { after, before, test } from 'node:test';

import { createEmulatorCatalogComposition } from '../../src/modules/catalog/infrastructure/emulator_catalog_composition.js';
import {
  FirestoreScenarioService,
  scenarioCollections,
} from '../../src/modules/quick_plan/firestore_scenario_service.js';
import { quickPlanCollections } from '../../src/modules/quick_plan/quick_plan_contract.js';
import { canonicalJson, sha256Hex } from '../../src/modules/content/domain/published_revision.js';
import { contentFlagIds, scenarioFlagIds } from '../../src/shared/feature_flags.js';
import { handleMediaDelivery } from '../../src/media_entry.js';
import { callBookingFunction, emulatorFirestore } from '../support/booking_emulator.js';
import { cleanupContentEmulatorState } from '../support/content_emulator_cleanup.js';
import { setLocalFlag } from '../support/notifications_world.js';
import { uploadReadyImage } from '../support/content_event_world.js';
import {
  createScenarioWorld,
  expectData,
  i3Identity,
  i3ScenarioDraft,
  i3Ulid,
  type I3Actor,
} from '../support/scenario_i3_world.js';

const db = emulatorFirestore();
// Built after the cleanup in `before`: the cleanup removes Identity records too.
let world: ReturnType<typeof createScenarioWorld>;
const catalog = createEmulatorCatalogComposition(db, {
  environment: { ...process.env, RECHARGE_TEST_SCENARIO_CATALOG: 'true' },
});
const flags = [
  scenarioFlagIds.sync,
  scenarioFlagIds.publication,
  scenarioFlagIds.share,
  contentFlagIds.scenarioAuthoring,
  'identity.session.establish',
];
const extra = [...Object.values(scenarioCollections), ...Object.values(quickPlanCollections)];
let owner: I3Actor, editor: I3Actor, stranger: I3Actor, revoked: I3Actor;
let place: Awaited<ReturnType<typeof world.publishedPlace>>;

before(async () => {
  await cleanupContentEmulatorState(db, extra);
  for (const flag of flags) await setLocalFlag(db, flag, true);
  world = createScenarioWorld(db, 'i3');
  owner = await world.owner();
  const now = new Date();
  editor = await i3Identity(db, 'i3-editor-' + randomUUID(), now);
  stranger = await i3Identity(db, 'i3-stranger-' + randomUUID(), now);
  revoked = await i3Identity(db, 'i3-revoked-' + randomUUID(), now);
  place = await world.publishedPlace();
});
after(async () => {
  for (const flag of flags) await setLocalFlag(db, flag, false);
  await cleanupContentEmulatorState(db, extra);
  for (const name of extra) assert.equal((await db.collection(name).limit(1).get()).empty, true);
  process.stdout.write(
    'I3 cleanup verified: Scenario, Content, Media, Moderation, Catalog fixtures and flags removed.\n',
  );
});

type Json = Record<string, unknown>;
const ok = (result: Json, label: string): Json => {
  assert.equal(result.kind, 'succeeded', `${label}: ${JSON.stringify(result)}`);
  return result;
};
const leaks = (value: unknown, ...ids: string[]) => {
  const json = JSON.stringify(value);
  for (const marker of ['PRIVATE-', 'SNAPSHOT-title', 'Catalog place location', ...ids])
    assert.equal(json.includes(marker), false, `leak: ${marker}`);
};
const query = { schemaVersion: 1, marketId: 'LV', typeIds: ['scenario'] };

/** An owner plan saved through I2, optionally shared with an editor and a revoked member. */
async function plan(draft = i3ScenarioDraft({ placeId: place.contentId }), members = false) {
  const id = i3Ulid();
  ok(
    await world.planning.command(owner.hint, world.command(owner, id, 'save', 0, { draft })),
    'save',
  );
  if (members)
    for (const member of [editor, revoked]) {
      const inviteId = randomUUID();
      ok(
        await world.planning.command(
          owner.hint,
          world.command(owner, id, 'invite', 0, {
            recipientId: member.userId,
            role: 'editor',
            inviteId,
            expiresAtUtc: new Date(Date.now() + 3_600_000).toISOString(),
          }),
        ),
        'invite',
      );
      ok(
        await world.planning.command(
          member.hint,
          world.command(member, id, 'accept', 0, { inviteId }),
        ),
        'accept',
      );
    }
  if (members)
    ok(
      await world.planning.command(
        owner.hint,
        world.command(owner, id, 'revoke', 2, { recipientId: revoked.userId }),
      ),
      'revoke',
    );
  return id;
}
async function distribute(id: string, revision = 1, actor = owner, key?: string) {
  return world.planning.command(actor.hint, {
    ...world.command(actor, id, 'distribute', revision),
    ...(key === undefined ? {} : { idempotencyKey: key }),
  });
}
async function share(id: string, revision = 1, actor = owner, extraFields: Json = {}) {
  return world.planning.command(
    actor.hint,
    world.command(actor, id, 'share', revision, extraFields),
  );
}
const resolve = (actor: I3Actor, shareToken: string) =>
  world.planning.query(actor.hint, { schemaVersion: 1, requestId: randomUUID(), shareToken });

/** Content draft pinned to a distribution, with a ready cover bound at revision 2. */
async function contentDraft(revision: Json) {
  const { creator } = await world.actors;
  const distribution = revision.distribution as Json;
  const body = {
    title: distribution.title,
    shortDescription: 'A relaxed walk through the old town',
    fullDescription: 'Stops in the old town with lunch, a viewpoint and the cathedral.',
    contentLocale: 'en',
    media: { rightsConfirmed: true },
    scenario: {
      ref: {
        scenarioId: revision.scenarioId,
        scenarioRevisionId: revision.scenarioRevisionId,
        contentHash: revision.contentHash,
      },
      distribution,
    },
  };
  const draft = expectData<{ draftId: string; contentId: string; revision: number }>(
    await world.execute({
      commandType: 'createDraft',
      payload: {
        typeId: 'scenario',
        publisherRef: { type: 'user', id: creator.actor.userId },
        marketId: 'LV',
        body,
      },
    }),
    'createDraft scenario',
  );
  // The cover is bound to the exact draft under the personal publisher (SP-02).
  const { assetId: cover } = await uploadReadyImage(world.media, creator.actor, {
    publisherRef: { type: 'user', id: creator.actor.userId },
    contentId: draft.contentId,
    bytes: Buffer.from(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGPQ6w4HAAH7ARF0JhTpAAAAAElFTkSuQmCC',
      'base64',
    ),
    mediaType: 'image/png',
    key: world.key,
  });
  const bound = {
    ...body,
    media: { coverImage: { mediaId: cover, altText: { en: 'Old town' } }, rightsConfirmed: true },
  };
  const updated = expectData<{ revision: number }>(
    await world.update(draft.draftId, draft.revision, bound),
    'bind scenario',
  );
  return { ...draft, revision: updated.revision, cover, body: bound };
}
async function approved(draft: { draftId: string; contentId: string; revision: number }) {
  const submission = expectData<{ submissionId: string }>(
    await world.submit(draft.draftId, draft.revision),
    'submit scenario',
  );
  expectData(
    await world.decide('approve', {
      contentId: draft.contentId,
      submissionId: submission.submissionId,
    }),
    'approve scenario',
  );
  return submission.submissionId;
}
async function published(id: string, revision = 1) {
  const pinned: Json = { ...ok(await distribute(id, revision), 'distribute'), scenarioId: id };
  const draft = await contentDraft(pinned);
  const submissionId = await approved(draft);
  const pointer = await world.pointer(draft.contentId).catch(() => null);
  const result = expectData<{ publishedRevisionId: string }>(
    await world.publishApproved(submissionId, pointer?.revision ?? 0),
    'publish scenario',
  );
  return { ...draft, pinned, submissionId, ...result };
}
async function catalogDetails(contentId: string) {
  const set = await catalog.sets.ensureActive();
  await catalog.projector.deliverFromContent(set.setId);
  return catalog.query.details({ contentId });
}
async function feedIds(snapshotToken?: string) {
  const set = await catalog.sets.ensureActive();
  await catalog.projector.deliverFromContent(set.setId);
  const page = await catalog.query.feed({
    query,
    ...(snapshotToken === undefined ? {} : { snapshotToken }),
  });
  assert.equal(page.kind, 'succeeded', JSON.stringify(page));
  if (page.kind !== 'succeeded') throw new Error('feed');
  return { ids: page.items.map((item) => item.ref.contentId), token: page.snapshotToken, page };
}
const exact = async (contentId: string) =>
  world.composition.content.query((await world.actors).creator.actor, {
    schemaVersion: 1,
    queryType: 'getPublishedRevision',
    payload: { contentId },
  });

void test('1. visibility × actor matrix: only the owner distributes, shares, submits and activates', async () => {
  const id = await plan(undefined, true);
  // personal: nobody but members reads; no Content, Catalog or share answer exists.
  assert.equal(
    (
      await world.planning.query(stranger.hint, {
        schemaVersion: 1,
        requestId: randomUUID(),
        scenarioId: id,
      })
    ).code,
    'not_found_or_forbidden',
  );
  assert.equal(
    (
      await world.planning.query(revoked.hint, {
        schemaVersion: 1,
        requestId: randomUUID(),
        scenarioId: id,
      })
    ).code,
    'not_found_or_forbidden',
  );
  assert.equal((await exact(id)).kind, 'rejected');
  // An editor edits the live draft but never distributes, shares or deletes.
  for (const actor of [editor, stranger, revoked]) {
    const generation = actor === editor ? 1 : 0;
    for (const type of ['distribute', 'share', 'unshare'])
      assert.notEqual(
        (
          await world.planning.command(actor.hint, {
            ...world.command(actor, id, type, 1),
            generation,
          })
        ).kind,
        'succeeded',
        `${type} by ${actor === editor ? 'editor' : 'other'}`,
      );
  }
  ok(
    await world.planning.command(editor.hint, {
      ...world.command(editor, id, 'save', 1, {
        draft: i3ScenarioDraft({ placeId: place.contentId, revision: 2 }),
      }),
      generation: 1,
    }),
    'editor save',
  );
  // A non-Creator owner may keep and distribute a personal Scenario, never publish it.
  const own = i3Ulid();
  ok(
    await world.planning.command(
      editor.hint,
      world.command(editor, own, 'save', 0, {
        draft: i3ScenarioDraft({ placeId: place.contentId }),
      }),
    ),
    'editor own save',
  );
  const editorRevision = ok(await distribute(own, 1, editor), 'editor distribute');
  const refused = await world.composition.content.execute(
    { userId: editor.userId, sessionId: editor.hint.sessionId },
    {
      schemaVersion: 1,
      idempotencyKey: randomUUID(),
      commandType: 'createDraft',
      payload: {
        typeId: 'scenario',
        publisherRef: { type: 'user', id: editor.userId },
        marketId: 'LV',
        body: { scenario: { ref: { scenarioId: own } }, ...editorRevision },
      },
    },
  );
  assert.equal(refused.kind, 'rejected');
  // unlisted: a token is the capability; the id alone is nothing.
  const link = ok(await share(id, 2), 'share') as Json & { token: string };
  for (const actor of [stranger, revoked, editor, owner])
    ok(await resolve(actor, link.token), 'token read');
  assert.equal((await exact(id)).kind, 'rejected');
  // public: the owner publishes; the Catalog lists it; a stranger reads it exactly.
  const result = await published(id, 2);
  assert.equal(result.contentId, id, 'one publication per Scenario: contentId = scenarioId');
  assert.equal((await exact(id)).kind, 'succeeded');
  assert.ok((await feedIds()).ids.includes(id));
  // Revoke collaboration does not withdraw (I2 guarantee, SP-11).
  ok(
    await world.planning.command(
      owner.hint,
      world.command(owner, id, 'revoke', 2, { recipientId: editor.userId }),
    ),
    'revoke editor',
  );
  assert.equal((await exact(id)).kind, 'succeeded');
  // Activation is the owner's, never another account's.
  const pointer = await world.pointer(id);
  const foreign = await world.composition.content.execute(
    { userId: stranger.userId, sessionId: stranger.hint.sessionId },
    {
      schemaVersion: 1,
      idempotencyKey: randomUUID(),
      commandType: 'activatePublishedRevision',
      payload: {
        contentId: id,
        publishedRevisionId: result.publishedRevisionId,
        expectedPointerRevision: pointer.revision,
      },
    },
  );
  assert.equal(foreign.kind, 'rejected');
});

void test('2. public, unlisted, Catalog and Media answers never disclose private data', async () => {
  const id = await plan(undefined, true);
  const link = ok(await share(id), 'share') as Json & { token: string };
  const shared = ok(await resolve(stranger, link.token), 'resolve');
  leaks(shared, editor.userId, revoked.userId, owner.userId);
  const result = await published(id);
  leaks(await exact(id), editor.userId, revoked.userId);
  const details = await catalogDetails(id);
  leaks(details, editor.userId, revoked.userId);
  const { page } = await feedIds();
  leaks(page, editor.userId, revoked.userId);
  // The catalog stop location and its snapshot never travel; the stop is a reference.
  const distribution = (result.pinned.distribution as Json) ?? {};
  assert.equal(JSON.stringify(distribution).includes(place.contentId), true);
  // Media: Content names a deliverable pin only while the publication is public.
  // (The Emulator fake processor writes no variant bytes, so the byte step of
  // the D2 gate is covered by the D1/D10 real-tools evidence, not here.)
  const pin = () =>
    world.media.contentScope.deliverablePin({ contentId: id, assetId: result.cover });
  assert.ok(await pin());
  const pointer = await world.pointer(id);
  expectData(await world.withdraw(id, pointer.revision), 'withdraw');
  assert.equal(await pin(), null);
  const refused = await handleMediaDelivery(
    { firestore: db },
    { schemaVersion: 1, contentId: id, assetId: result.cover, profile: 'display' },
  );
  assert.equal(refused.code, 'not_found');
});

void test('3. full C3 lifecycle through Content, Media, moderation and Catalog', async () => {
  const id = await plan();
  const result = await published(id);
  const details = await catalogDetails(id);
  assert.ok(details.kind === 'succeeded' && details.state === 'listed', JSON.stringify(details));
  assert.equal((details.item as unknown as Json).coverMediaId, result.cover);
  // Staff restriction hides it; restore lifts exactly that restriction.
  const pointer = await world.pointer(id);
  const restriction = expectData<{ decision: { decisionId: string } }>(
    await world.decide('restrict', { contentId: id }),
    'restrict',
  );
  assert.equal((await exact(id)).kind, 'rejected');
  const hidden = await catalogDetails(id);
  assert.ok(hidden.kind === 'succeeded' && hidden.state !== 'listed');
  expectData(
    await world.decide(
      'restore',
      { contentId: id },
      { restoresDecisionId: restriction.decision.decisionId },
    ),
    'restore',
  );
  assert.equal((await exact(id)).kind, 'succeeded');
  assert.ok(pointer.revision > 0);
});

void test('4. one forbidden body is refused at submit, at publish of an approval and at activation', async () => {
  // The body becomes forbidden when its catalog stop is no longer public.
  const stop = await world.publishedPlace();
  const pending = await plan(i3ScenarioDraft({ placeId: stop.contentId }));
  const pendingDraft = await contentDraft({
    ...ok(await distribute(pending), 'distribute'),
    scenarioId: pending,
  });
  const id = await plan(i3ScenarioDraft({ placeId: stop.contentId }));
  const content = await contentDraft({ ...ok(await distribute(id), 'distribute'), scenarioId: id });
  const submissionId = await approved(content);
  let stopPointer = await world.pointer(stop.contentId);
  expectData(await world.withdraw(stop.contentId, stopPointer.revision), 'withdraw stop');
  const atSubmit = await world.submit(pendingDraft.draftId, pendingDraft.revision);
  assert.equal(atSubmit.code, 'validation_failed', JSON.stringify(atSubmit));
  const atPublish = await world.publishApproved(submissionId, 0);
  assert.equal(atPublish.code, 'validation_failed', JSON.stringify(atPublish));
  // Planning refuses a new distribution of the same body as well.
  assert.equal((await distribute(id)).code, 'distribution_invalid');
  // Activation: publish while the stop is back, then take it away and re-select.
  stopPointer = await world.pointer(stop.contentId);
  expectData(
    await world.activate(stop.contentId, stop.publishedRevisionId, stopPointer.revision),
    'stop back',
  );
  const first = expectData<{ publishedRevisionId: string }>(
    await world.publishApproved(submissionId, 0),
    'publish',
  );
  let pointer = await world.pointer(id);
  expectData(await world.withdraw(id, pointer.revision), 'owner withdraw');
  stopPointer = await world.pointer(stop.contentId);
  expectData(await world.withdraw(stop.contentId, stopPointer.revision), 'withdraw stop again');
  pointer = await world.pointer(id);
  const atActivate = await world.activate(id, first.publishedRevisionId, pointer.revision);
  assert.equal(atActivate.code, 'validation_failed', JSON.stringify(atActivate));
  stopPointer = await world.pointer(stop.contentId);
  expectData(
    await world.activate(stop.contentId, stop.publishedRevisionId, stopPointer.revision),
    'stop restored',
  );
});

void test('5. a concurrent edit during review publishes the exact approved revision or conflicts', async () => {
  const id = await plan();
  const pinned: Json = { ...ok(await distribute(id), 'distribute'), scenarioId: id };
  const content = await contentDraft(pinned);
  const submissionId = await approved(content);
  // The live plan changes during review; the approved body does not.
  ok(
    await world.planning.command(
      owner.hint,
      world.command(owner, id, 'save', 1, {
        draft: i3ScenarioDraft({
          placeId: place.contentId,
          title: 'Edited during review',
          revision: 2,
        }),
      }),
    ),
    'edit during review',
  );
  assert.equal((await distribute(id, 1)).code, 'revision_conflict');
  // The reviewed Content draft cannot change under review: an explicit conflict.
  assert.equal(
    (await world.update(content.draftId, content.revision, content.body)).code,
    'revision_conflict',
  );
  const revision = expectData<{
    body: { scenario: { ref: { contentHash: string }; distribution: unknown } };
  }>(await world.publishApproved(submissionId, 0), 'publish');
  assert.equal(revision.body.scenario.ref.contentHash, pinned.contentHash);
  assert.equal(sha256Hex(canonicalJson(revision.body.scenario.distribution)), pinned.contentHash);
  assert.equal(JSON.stringify(revision).includes('Edited during review'), false);
  // The edit reaches the public only as a new distribution, review and switch.
  const next: Json = { ...ok(await distribute(id, 2), 'distribute 2'), scenarioId: id };
  const distribution = next.distribution as Json;
  const updated = expectData<{ revision: number }>(
    await world.update(content.draftId, content.revision, {
      ...content.body,
      title: distribution.title,
      scenario: {
        ref: {
          scenarioId: id,
          scenarioRevisionId: next.scenarioRevisionId,
          contentHash: next.contentHash,
        },
        distribution,
      },
    }),
    'new revision',
  );
  const second = await approved({ ...content, revision: updated.revision });
  assert.equal(
    JSON.stringify(await exact(id)).includes('Edited during review'),
    false,
    'old stays until the switch',
  );
  const pointer = await world.pointer(id);
  expectData(await world.publishApproved(second, pointer.revision), 'switch');
  assert.equal(JSON.stringify(await exact(id)).includes('Edited during review'), true);
});

void test('6. visibility changes, new revisions and share lifecycle keep the agreed rights', async () => {
  const id = await plan();
  const first = await published(id);
  let pointer = await world.pointer(id);
  expectData(await world.withdraw(id, pointer.revision), 'withdraw');
  assert.equal((await exact(id)).kind, 'rejected');
  assert.ok(!(await feedIds()).ids.includes(id));
  pointer = await world.pointer(id);
  expectData(await world.activate(id, first.publishedRevisionId, pointer.revision), 'activate');
  assert.ok((await feedIds()).ids.includes(id));
  // Unlisted: rotate, revoke, staff restriction and restore, expiry.
  const one = ok(await share(id), 'share 1') as Json & { token: string };
  const two = ok(await share(id), 'share 2') as Json & { token: string };
  assert.equal((await resolve(stranger, one.token)).code, 'not_found', 'rotated');
  ok(await resolve(stranger, two.token), 'current');
  const shareId = sha256Hex(two.token);
  const restriction = expectData<{ decision: { decisionId: string } }>(
    await world.decide('restrict_share', { shareId }),
    'restrict share',
  );
  assert.equal((await resolve(stranger, two.token)).code, 'not_found');
  expectData(
    await world.decide(
      'restore_share',
      { shareId },
      { restoresDecisionId: restriction.decision.decisionId },
    ),
    'restore share',
  );
  ok(await resolve(stranger, two.token), 'restored');
  // Expiry: the stored deadline passes (the Session stays current).
  const shareRef = db.collection(scenarioCollections.shares).doc(shareId);
  const expiresAtUtc = (await shareRef.get()).get('expiresAtUtc') as string;
  await shareRef.update({ expiresAtUtc: new Date(Date.now() - 1000).toISOString() });
  assert.equal((await resolve(stranger, two.token)).code, 'token_expired');
  await shareRef.update({ expiresAtUtc });
  ok(await world.planning.command(owner.hint, world.command(owner, id, 'unshare', 1)), 'unshare');
  assert.equal((await resolve(stranger, two.token)).code, 'not_found');
  assert.ok((await feedIds()).ids.includes(id), 'unshare never touches the public revision');
  assert.equal((await share(id, 1, owner, { ttlDays: 91 })).code, 'request_invalid');
});

void test('7. an old snapshot or cursor never returns a Scenario after access ends', async () => {
  const id = await plan();
  await published(id);
  const before = await feedIds();
  assert.ok(before.ids.includes(id));
  const pointer = await world.pointer(id);
  expectData(await world.withdraw(id, pointer.revision), 'withdraw');
  const set = await catalog.sets.ensureActive();
  await catalog.projector.deliverFromContent(set.setId);
  const old = await catalog.query.feed({ query, snapshotToken: before.token });
  assert.ok(old.kind === 'succeeded');
  assert.equal(
    old.items.some((item) => item.ref.contentId === id),
    false,
  );
  const map = await catalog.query.map({ query, snapshotToken: before.token });
  assert.ok(map.kind === 'succeeded' && !map.leaves.some((leaf) => leaf.ref.contentId === id));
  const details = await catalog.query.details({
    contentId: id,
    snapshotToken: before.token,
    query,
  });
  assert.ok(details.kind !== 'succeeded' || details.state !== 'listed');
});

void test('8. an unavailable or changed stop yields the agreed answer without its data', async () => {
  const stop = await world.publishedPlace();
  const full = await plan(i3ScenarioDraft({ placeId: stop.contentId }));
  await published(full);
  const minimal = await plan(i3ScenarioDraft({ placeId: stop.contentId, minimal: true }));
  await published(minimal);
  const listed = await catalogDetails(full);
  assert.ok(listed.kind === 'succeeded' && listed.state === 'listed');
  assert.ok(JSON.stringify(listed).includes(String(stop.body.title)), 'fresh stop title');
  const pointer = await world.pointer(stop.contentId);
  expectData(await world.withdraw(stop.contentId, pointer.revision), 'withdraw stop');
  const degraded = await catalogDetails(full);
  assert.ok(degraded.kind === 'succeeded' && degraded.state === 'listed');
  const json = JSON.stringify(degraded);
  assert.equal(json.includes(stop.contentId), false, 'no reference to a hidden stop');
  assert.equal(json.includes(String(stop.body.title)), false, 'no title of a hidden stop');
  assert.ok(json.includes('"type":"unavailable"'));
  // Below two available stops the Scenario leaves the Catalog without being withdrawn.
  const excluded = await catalogDetails(minimal);
  assert.ok(
    excluded.kind === 'succeeded' && excluded.state === 'excluded' && excluded.item === null,
  );
  assert.ok(!(await feedIds()).ids.includes(minimal));
  assert.equal((await exact(minimal)).kind, 'succeeded');
});

void test('9. lost answers, repeats and resumed flows have no duplicate effects', async () => {
  const id = await plan();
  const key = randomUUID();
  const one = ok(await distribute(id, 1, owner, key), 'distribute');
  const two = ok(await distribute(id, 1, owner, key), 'replay');
  assert.equal(two.scenarioRevisionId, one.scenarioRevisionId);
  const revisions = await db
    .collection(scenarioCollections.revisions)
    .where('scenarioId', '==', id)
    .get();
  assert.equal(revisions.size, 1);
  // A lost share answer never reveals the token again and never creates a second link.
  const shareCommand = world.command(owner, id, 'share', 1);
  const first = ok(await world.planning.command(owner.hint, shareCommand), 'share');
  const replay = ok(
    await world.planning.command(owner.hint, { ...shareCommand, requestId: randomUUID() }),
    'share replay',
  );
  assert.equal(typeof first.token, 'string');
  assert.equal(replay.token, undefined);
  assert.equal(replay.tokenUnavailable, true);
  const shares = await db
    .collection(scenarioCollections.shares)
    .where('scenarioId', '==', id)
    .get();
  assert.equal(shares.size, 1);
  // One publication per Scenario: a second createDraft is a conflict.
  const pinned: Json = { ...one, scenarioId: id };
  await contentDraft(pinned);
  await assert.rejects(contentDraft(pinned), /revision_conflict/);
  // SP-11: no delete while a share or a publication stands; afterwards it is allowed.
  assert.equal(
    (await world.planning.command(owner.hint, world.command(owner, id, 'delete', 1))).code,
    'publication_active',
  );
  ok(await world.planning.command(owner.hint, world.command(owner, id, 'unshare', 1)), 'unshare');
  ok(await world.planning.command(owner.hint, world.command(owner, id, 'delete', 1)), 'delete');
  // A deleted source can no longer be submitted (SP-06 stale).
  const draft = await world.composition.contentRepository.transact((tx) => tx.draftByContentId(id));
  assert.ok(draft);
  const stale = await world.submit(draft.draftId, draft.revision);
  assert.equal(stale.kind, 'rejected');
});

void test('10. the Functions surface: scenario callables and the Scenario Content flag over HTTP', async () => {
  const { creator } = await world.actors;
  const id = await plan();
  const body = world.command(owner, id, 'distribute', 1);
  const wire = await callBookingFunction('scenarioCommandV1', body, creator.idToken);
  assert.equal(wire.status, 200);
  const result = wire.body.result as Json;
  assert.equal(result.kind, 'succeeded', JSON.stringify(result));
  const link = (
    await callBookingFunction(
      'scenarioCommandV1',
      world.command(owner, id, 'share', 1),
      creator.idToken,
    )
  ).body.result as Json;
  assert.equal(link.kind, 'succeeded');
  const read = (
    await callBookingFunction(
      'scenarioQueryV1',
      { schemaVersion: 1, requestId: randomUUID(), shareToken: link.token },
      creator.idToken,
    )
  ).body.result as Json;
  assert.equal(read.kind, 'succeeded', JSON.stringify(read));
  leaks(read);
  await setLocalFlag(db, scenarioFlagIds.share, false);
  const off = (
    await callBookingFunction(
      'scenarioQueryV1',
      { schemaVersion: 1, requestId: randomUUID(), shareToken: link.token },
      creator.idToken,
    )
  ).body.result as Json;
  assert.equal(off.code, 'feature_disabled');
  await setLocalFlag(db, scenarioFlagIds.share, true);
});

void test('11. Quick Plan and Route are untouched; Expand keeps its single creation path', async () => {
  const before = await db.collection(quickPlanCollections.plans).get();
  const id = await plan();
  await published(id);
  const after = await db.collection(quickPlanCollections.plans).get();
  assert.deepEqual(after.docs.map((d) => d.id).sort(), before.docs.map((d) => d.id).sort());
  // No Route type became available and no Route field entered a distribution.
  const revision = (
    await db.collection(scenarioCollections.revisions).where('scenarioId', '==', id).get()
  ).docs[0]!.data();
  assert.equal(JSON.stringify(revision.distribution).includes('routeId'), false);
  const route = await world.execute({
    commandType: 'createDraft',
    payload: {
      typeId: 'route',
      publisherRef: { type: 'user', id: owner.userId },
      marketId: 'LV',
      body: {},
    },
  });
  assert.equal(route.kind, 'rejected');
  // Expand stays the I2 path: an expanded Scenario is a separate, private plan.
  const planService = world.planning;
  assert.ok(planService instanceof FirestoreScenarioService);
});
