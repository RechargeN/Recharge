// D3.3 (RENTAL_D3_3_PUBLICATION_AMENDMENT.md §3): the Rental / Equipment
// lifecycle on the Firestore and Storage Emulators through the real Content,
// Media and C2 moderation services, the TEST-ONLY Rental policy over the
// pinned BCK-20 revision, the required cover and Media readiness, the closed
// Rental activation (Q4), and the effects on Catalog (excluded as a disabled
// type), Discover (refused), Booking (nothing) and D2 (a restricted photo).
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { contentMediaAvailability } from '../../src/media_effects_entry.js';
import { createEmulatorCatalogComposition } from '../../src/modules/catalog/infrastructure/emulator_catalog_composition.js';
import { catalogCollections } from '../../src/modules/catalog/infrastructure/firestore_catalog_repository.js';
import { contentCollections } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { createEmulatorEventBookingHandoff } from '../../src/modules/content/infrastructure/firestore_event_booking_handoff_repository.js';
import { emulatorFirestore } from '../support/booking_emulator.js';
import {
  standRentalAnchorUtc,
  standRentalBody,
  standSeedRental,
} from '../stand/stand_content_rental.js';
import { createRentalWorld, expectData } from '../support/content_rental_world.js';

const firestore = emulatorFirestore();
const world = createRentalWorld(firestore, 'd33-flow');

const code = (result: { kind: string; code?: string }) =>
  result.kind === 'succeeded' ? 'succeeded' : `${result.kind}:${String(result.code)}`;

void test('a Rental goes draft, cover and gallery, submit, approval and publish; a repeated create is the same draft', async () => {
  const { pageId } = await world.actors;
  const create = {
    commandType: 'createDraft',
    idempotencyKey: world.key('create-replay'),
    payload: {
      typeId: 'rental',
      publisherRef: { type: 'page', id: pageId },
      marketId: 'LV',
      body: {},
    },
  };
  const first = expectData<{ draftId: string; contentId: string }>(
    await world.execute(create),
    'create',
  );
  assert.deepEqual(
    expectData<{ draftId: string; contentId: string }>(await world.execute(create), 'replay'),
    first,
  );

  const published = await world.publishedRental();
  const pointer = await world.pointer(published.contentId);
  assert.equal(pointer.visibility, 'visible');
  assert.equal(pointer.currentPublishedRevisionId, published.publishedRevisionId);
  const revision = await world.composition.contentRepository.transact((tx) =>
    tx.publishedRevision(published.publishedRevisionId),
  );
  assert.ok(revision);
  assert.equal(revision.typeId, 'rental');
  assert.deepEqual(
    revision.mediaAttachments.map((item) => item.assetId).sort(),
    [published.cover, ...published.gallery].sort(),
  );
  assert.deepEqual(revision.body, published.body);
});

void test('the cover stays required, and every photo must be ready', async () => {
  const noCover = await world.boundRental((body) => ({ ...body, mediaRefs: [] }));
  assert.equal(
    code(await world.submit(noCover.draftId, noCover.revision)),
    'rejected:validation_failed',
  );

  const { creator, pageId } = await world.actors;
  const draft = await world.emptyDraft();
  const cover = await world.upload(draft.contentId, standSeedRental.images.cover);
  // An upload session without bytes: the asset is reserved, not ready.
  const reserved = expectData<{ assetId: string }>(
    await world.media.service.execute(creator.actor, {
      schemaVersion: 1,
      commandType: 'createUploadSession',
      idempotencyKey: world.key('reserved'),
      payload: {
        family: 'image',
        marketId: 'LV',
        visibilityClass: 'publicDerived',
        declaredMediaType: 'image/png',
        declaredByteLength: 70,
        publisherRef: { type: 'page', id: pageId },
        entityIntent: { domain: 'content', entityId: draft.contentId, purpose: 'contentMedia' },
      },
    }),
    'reserve',
  );
  const bound = expectData<{ revision: number }>(
    await world.update(
      draft.draftId,
      draft.revision,
      standRentalBody({
        actorUserId: creator.actor.userId,
        mediaRefs: [cover, reserved.assetId],
        anchorUtc: standRentalAnchorUtc(),
      }),
    ),
    'bind',
  );
  assert.equal(code(await world.submit(draft.draftId, bound.revision)), 'rejected:media_not_ready');
});

void test('a pair without policy, outside the whitelist or unknown to BCK-20 fails closed', async () => {
  for (const change of [
    { categoryId: 'sport', subcategoryId: 'yoga' },
    { categoryId: 'art_culture_museums', subcategoryId: 'museum' },
    { subcategoryId: 'not_a_subcategory' },
  ]) {
    const rental = await world.boundRental((body) => ({ ...body, ...change }));
    assert.equal(
      code(await world.submit(rental.draftId, rental.revision)),
      'rejected:validation_failed',
      JSON.stringify(change),
    );
  }
});

void test('a rejected revision cannot be published', async () => {
  const rental = await world.boundRental();
  const submission = expectData<{ submissionId: string }>(
    await world.submit(rental.draftId, rental.revision),
    'submit',
  );
  expectData(
    await world.decide('reject', {
      contentId: rental.contentId,
      submissionId: submission.submissionId,
    }),
    'reject',
  );
  assert.equal((await world.publishApproved(submission.submissionId, 0)).kind, 'rejected');
  assert.equal(
    await world.composition.contentRepository.transact((tx) => tx.pointer(rental.contentId)),
    null,
  );
});

void test('owner hide works; re-activation stays closed (Q4) with the pointer unchanged; a new revision publishes', async () => {
  const rental = await world.publishedRental();
  assert.equal(code(await world.withdraw(rental.contentId, 1)), 'succeeded');
  const hidden = await world.pointer(rental.contentId);
  assert.equal(hidden.visibility, 'withdrawn');
  assert.equal(
    code(await world.activate(rental.contentId, rental.publishedRevisionId, hidden.revision)),
    'rejected:type_disabled',
  );
  assert.deepEqual(await world.pointer(rental.contentId), hidden);

  // A new revision goes through the whole path and becomes visible again.
  const revised = expectData<{ revision: number }>(
    await world.update(rental.draftId, rental.revision, {
      ...rental.body,
      title: 'Kipsala sea kayak and canoe rental',
    }),
    'revise',
  );
  const submission = expectData<{ submissionId: string }>(
    await world.submit(rental.draftId, revised.revision),
    'resubmit',
  );
  expectData(
    await world.decide('approve', {
      contentId: rental.contentId,
      submissionId: submission.submissionId,
    }),
    'reapprove',
  );
  const republished = expectData<{ publishedRevisionId: string }>(
    await world.publishApproved(submission.submissionId, hidden.revision),
    'republish',
  );
  const switched = await world.pointer(rental.contentId);
  assert.equal(switched.currentPublishedRevisionId, republished.publishedRevisionId);
  assert.equal(switched.visibility, 'visible');

  // Staff restriction takes the Rental down.
  expectData(await world.decide('restrict', { contentId: rental.contentId }), 'restrict');
  assert.equal((await world.pointer(rental.contentId)).visibility, 'restricted');
});

void test('effects: Catalog excludes the Rental as a disabled type, Discover refuses it, Booking ignores it', async () => {
  const rental = await world.publishedRental();
  const catalog = createEmulatorCatalogComposition(firestore);
  const active = await catalog.sets.ensureActive();
  await catalog.projector.deliverFromContent(active.setId);
  const versions = (
    await firestore
      .collection(catalogCollections.versions)
      .where('contentId', '==', rental.contentId)
      .get()
  ).docs.map((doc) => doc.data() as { setId: string; state: string; reason: string });
  const delivered = versions.filter((item) => item.setId === active.setId);
  assert.ok(delivered.length > 0, 'Catalog recorded the Rental');
  for (const item of delivered)
    assert.deepEqual([item.state, item.reason], ['excluded', 'type_disabled']);

  const discover = (await catalog.query.feed({
    query: { schemaVersion: 1, marketId: 'LV', typeIds: ['rental'] },
  })) as { kind: string; code?: string };
  assert.equal(discover.code, 'type_disabled:rental', JSON.stringify(discover));

  const { handoff, repository } = createEmulatorEventBookingHandoff(firestore);
  await handoff.deliver();
  const effects = await firestore
    .collection(contentCollections.effects)
    .where('contentId', '==', rental.contentId)
    .get();
  assert.ok(!effects.empty);
  for (const effect of effects.docs) {
    const receipt = await repository.transact((tx) => tx.receipt(String(effect.data().effectId)));
    assert.equal(receipt?.outcome, 'ignored');
    assert.deepEqual(receipt?.outboxIds, []);
  }
  assert.equal(await repository.transact((tx) => tx.state(rental.contentId)), null);
});

void test('D2: a restricted photo is refused and suppressed; with activation closed it stays suppressed after the lift', async () => {
  const rental = await world.publishedRental();
  const photo = rental.gallery[0] as string;
  const pinOf = () =>
    world.media.contentScope.deliverablePin({ contentId: rental.contentId, assetId: photo });
  assert.ok(await pinOf(), 'the published Rental pins its gallery photo');

  const restricted = expectData<{ decision: { decisionId: string } }>(
    await world.decide('restrict_media', { assetId: photo }),
    'restrict_media',
  );
  const wire = await world.media.delivery.deliver({
    contentId: rental.contentId,
    assetId: photo,
    profile: 'display',
  });
  assert.equal(code(wire), 'rejected:not_found');

  const availability = contentMediaAvailability(firestore);
  assert.equal(await availability.reconcileContent(rental.contentId), 'suppressed');
  const suppressed = await world.pointer(rental.contentId);
  assert.deepEqual(
    (suppressed.mediaSuppression ?? []).map((item) => item.assetId),
    [photo],
  );
  assert.equal(suppressed.visibility, 'visible');
  assert.equal(await pinOf(), null);

  // Lifting the restriction does not lift the suppression (D2), and the
  // publisher's activation that would is closed for Rental (Q4).
  expectData(
    await world.decide(
      'restore_media',
      { assetId: photo },
      { restoresDecisionId: restricted.decision.decisionId },
    ),
    'restore_media',
  );
  const pointer = await world.pointer(rental.contentId);
  assert.equal(
    code(await world.activate(rental.contentId, rental.publishedRevisionId, pointer.revision)),
    'rejected:type_disabled',
  );
  assert.equal(await pinOf(), null);
});

/** The draft's current revision, as the owner services stored it. */
async function draftRevision(draftId: string): Promise<number> {
  const draft = await world.composition.contentRepository.transact((tx) => tx.draft(draftId));
  assert.ok(draft);
  return draft.revision;
}

/** Saves [body] as a new revision, submits, approves and publishes it. */
async function republish(rental: { draftId: string; contentId: string }, body: unknown) {
  const saved = expectData<{ revision: number }>(
    await world.update(rental.draftId, await draftRevision(rental.draftId), body),
    'revise',
  );
  const submission = await world.submit(rental.draftId, saved.revision);
  if (submission.kind !== 'succeeded') return submission;
  const { submissionId } = submission.data as { submissionId: string };
  expectData(
    await world.decide('approve', { contentId: rental.contentId, submissionId }),
    'approve',
  );
  const pointer = await world.pointer(rental.contentId);
  return world.publishApproved(submissionId, pointer.revision);
}

void test('D2 recovery: after the lift, a new revision reusing the same photo is deliverable again', async () => {
  const rental = await world.publishedRental();
  const photo = rental.gallery[0] as string;
  const pinOf = () =>
    world.media.contentScope.deliverablePin({ contentId: rental.contentId, assetId: photo });
  const restricted = expectData<{ decision: { decisionId: string } }>(
    await world.decide('restrict_media', { assetId: photo }),
    'restrict_media',
  );
  assert.equal(
    await contentMediaAvailability(firestore).reconcileContent(rental.contentId),
    'suppressed',
  );
  expectData(
    await world.decide(
      'restore_media',
      { assetId: photo },
      { restoresDecisionId: restricted.decision.decisionId },
    ),
    'restore_media',
  );
  assert.equal(await pinOf(), null, 'the lift alone does not restore delivery');

  // The same media ids, a changed title: a full new review and publication.
  const published = await republish(rental, { ...rental.body, title: 'Kipsala kayaks (2)' });
  assert.equal(code(published), 'succeeded');
  const pointer = await world.pointer(rental.contentId);
  assert.equal(pointer.mediaSuppression, undefined);
  assert.equal(pointer.visibility, 'visible');
  const revision = await world.composition.contentRepository.transact((tx) =>
    tx.publishedRevision(pointer.currentPublishedRevisionId as string),
  );
  assert.deepEqual(revision?.body.mediaRefs, rental.body.mediaRefs, 'the same media are reused');
  assert.ok(await pinOf(), 'the reused photo is deliverable again');
});

void test('D2 recovery: while the restriction holds, a revision reusing the photo is refused; one without it publishes', async () => {
  const rental = await world.publishedRental();
  const photo = rental.gallery[0] as string;
  expectData(await world.decide('restrict_media', { assetId: photo }), 'restrict_media');
  assert.equal(
    await contentMediaAvailability(firestore).reconcileContent(rental.contentId),
    'suppressed',
  );
  const before = await world.pointer(rental.contentId);

  const reused = await republish(rental, { ...rental.body, title: 'Kipsala kayaks (3)' });
  assert.equal(code(reused), 'rejected:media_not_ready');
  assert.deepEqual(await world.pointer(rental.contentId), before);

  // Submit refused: the draft stays editable. Without the restricted photo the
  // new revision publishes and the suppression is gone with the old revision.
  const remaining = (rental.body.mediaRefs as string[]).filter((id) => id !== photo);
  const without = await republish(rental, {
    ...rental.body,
    title: 'Kipsala kayaks (4)',
    mediaRefs: remaining,
  });
  assert.equal(code(without), 'succeeded');
  const pointer = await world.pointer(rental.contentId);
  assert.equal(pointer.mediaSuppression, undefined);
  assert.equal(pointer.visibility, 'visible');
  for (const assetId of remaining)
    assert.ok(
      await world.media.contentScope.deliverablePin({ contentId: rental.contentId, assetId }),
      assetId,
    );
  assert.equal(
    await world.media.contentScope.deliverablePin({ contentId: rental.contentId, assetId: photo }),
    null,
  );
});
