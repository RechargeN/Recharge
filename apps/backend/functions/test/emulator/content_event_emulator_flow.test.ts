import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { after, test } from 'node:test';
import { getStorage } from 'firebase-admin/storage';

import { eventAuthoringComposition } from '../../src/content_entry.js';
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
import {
  featureFlagKey,
  featureFlagPointerCollection,
  featureFlagRevisionCollection,
} from '../../src/platform/config/feature_flag_repository.js';
import { featureFlagRevisionDocumentId } from '../../src/platform/config/firestore_feature_flag_gate.js';
import { contentFlagIds } from '../../src/shared/feature_flags.js';
import type { EntityId } from '../../src/shared/ids.js';
import { standEventBody } from '../stand/stand_content.js';
import {
  callBookingFunction,
  createFirebaseActor,
  emulatorFirestore,
  registerSessionContext,
} from '../support/booking_emulator.js';

const firestore = emulatorFirestore();
const media = createEmulatorMediaComposition({
  firestore,
  bucket: getStorage().bucket('demo-recharge.appspot.com') as never,
});
const composition = eventAuthoringComposition(firestore, { media });
const run = randomUUID().slice(0, 8);
const png = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  'base64',
);
const sha256 = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');
const flagKey = featureFlagKey('local', 'LV', contentFlagIds.eventAuthoring);

async function setContentFlag(enabled: boolean): Promise<void> {
  const batch = firestore.batch();
  batch.set(
    firestore
      .collection(featureFlagRevisionCollection)
      .doc(featureFlagRevisionDocumentId(flagKey, 1)),
    {
      schemaVersion: 1,
      revision: 1,
      environmentId: 'local',
      marketId: 'LV',
      capabilityId: contentFlagIds.eventAuthoring,
      enabled,
      createdAtUtc: '2026-10-06T00:00:00.000Z',
    },
  );
  batch.set(firestore.collection(featureFlagPointerCollection).doc(flagKey), {
    key: flagKey,
    activeRevision: 1,
    pointerRevision: 1,
  });
  await batch.commit();
}

after(async () => {
  // Leave the shared Emulator tidy for the next test file.
  for (const name of [
    ...Object.values(contentCollections),
    ...Object.values(mediaCollections),
    ...Object.values(moderationCollections),
  ]) {
    const snapshot = await firestore.collection(name).get();
    for (const document of snapshot.docs) await document.ref.delete();
  }
  await firestore
    .collection(featureFlagRevisionCollection)
    .doc(featureFlagRevisionDocumentId(flagKey, 1))
    .delete();
  await firestore.collection(featureFlagPointerCollection).doc(flagKey).delete();
});

let worlds = 0;

/** Identity world through the owner services, with real Session handles for the callables. */
async function bootstrap() {
  const world = (worlds += 1);
  const repository = new FirestoreIdentityAuthorityRepository(firestore);
  const nowUtc = new Date().toISOString();
  const reviewer = randomUUID();
  const authority = new IdentityPublisherAuthority({
    repository,
    providerVerifier: new SyntheticProviderIdentityVerifier(),
    verificationDecisions: new LocalVerificationDecisionAdapter(new Set([reviewer])),
    pagePolicy: new LocalPageCreationPolicy(true, 2),
  });
  const account = async (label: string, userId: string) => {
    await authority.accounts.ensureAccount({
      proof: {
        provider: 'google',
        providerTenant: 'demo-recharge-emulator',
        proof: `local-test:google:c3-${run}-${world}-${label}`,
      },
      proposedUserId: userId,
      proposedIdentityId: randomUUID(),
      nowUtc,
      accountCreationEnabled: true,
    });
  };
  const creator = randomUUID();
  const viewer = randomUUID();
  const staff = randomUUID();
  for (const [label, id] of [
    ['reviewer', reviewer],
    ['creator', creator],
    ['viewer', viewer],
    ['staff', staff],
  ] as const)
    await account(label, id);
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
  const signedIn = async (userId: string, label: string) => {
    const firebaseUid = `c3-${run}-${world}-${label}`;
    const installationId = `c3-${run}-${world}-${label}-installation`;
    const sessionId = randomUUID();
    const issued = await authority.sessions.issue({
      userId,
      sessionId,
      firebaseUid,
      installationId,
      issuedAtUtc: nowUtc,
      snapshotExpiresAtUtc: new Date(Date.now() + 3_600_000).toISOString(),
    });
    const idToken = await createFirebaseActor(firebaseUid);
    registerSessionContext(idToken, {
      sessionId,
      sessionHandle: issued.sessionHandle,
      installationId,
    });
    return {
      idToken,
      actor: { userId: userId as EntityId, sessionId: sessionId as EntityId },
    };
  };
  return {
    pageId,
    creator: await signedIn(creator, 'creator'),
    viewer: await signedIn(viewer, 'viewer'),
    staff: await signedIn(staff, 'staff'),
  };
}

let sequence = 0;
const key = (label: string) => `c3-${label}-${run}-${(sequence += 1)}`;

async function command(idToken: string | undefined, body: Record<string, unknown>) {
  const response = await callBookingFunction(
    'contentCommandV1',
    { schemaVersion: 1, idempotencyKey: key(String(body.commandType)), ...body },
    idToken,
  );
  return response.body.result as Record<string, unknown>;
}

async function query(idToken: string, queryType: string, payload: Record<string, unknown>) {
  const response = await callBookingFunction(
    'contentQueryV1',
    { schemaVersion: 1, queryType, payload },
    idToken,
  );
  return response.body.result as Record<string, unknown>;
}

function data(result: Record<string, unknown>): Record<string, unknown> {
  assert.equal(result.kind, 'succeeded', JSON.stringify(result));
  return result.data as Record<string, unknown>;
}

type World = Awaited<ReturnType<typeof bootstrap>>;

async function uploadCover(world: World, contentId: string): Promise<string> {
  const actor = world.creator.actor;
  const created = await media.service.execute(actor, {
    schemaVersion: 1,
    commandType: 'createUploadSession',
    idempotencyKey: key('cover-session'),
    payload: {
      family: 'image',
      marketId: 'LV',
      visibilityClass: 'publicDerived',
      declaredMediaType: 'image/png',
      declaredByteLength: png.length,
      publisherRef: { type: 'page', id: world.pageId },
      entityIntent: { domain: 'content', entityId: contentId, purpose: 'contentMedia' },
    },
  });
  assert.equal(created.kind, 'succeeded', JSON.stringify(created));
  const upload = (created as { data: { uploadSessionId: string; assetId: string } }).data;
  const asset = await media.repository.transact((tx) => tx.asset(upload.assetId));
  assert.ok(asset);
  await media.objectStore.put(asset.objectKeyHandle, png);
  const confirmed = await media.service.execute(actor, {
    schemaVersion: 1,
    commandType: 'confirmUpload',
    idempotencyKey: key('cover-confirm'),
    payload: {
      uploadSessionId: upload.uploadSessionId,
      expectedSha256: sha256(png),
      expectedByteLength: png.length,
    },
  });
  assert.equal(confirmed.kind, 'succeeded', JSON.stringify(confirmed));
  const uploaded = (
    confirmed as { data: { revision: number; sourceGenerationRef: { providerGeneration: string } } }
  ).data;
  const finalized = await media.service.execute(actor, {
    schemaVersion: 1,
    commandType: 'finalizeAsset',
    idempotencyKey: key('cover-finalize'),
    payload: {
      assetId: upload.assetId,
      expectedAssetRevision: uploaded.revision,
      sourceProviderGeneration: uploaded.sourceGenerationRef.providerGeneration,
      expectedSha256: sha256(png),
      expectedByteLength: png.length,
    },
  });
  assert.equal(finalized.kind, 'succeeded', JSON.stringify(finalized));
  return upload.assetId;
}

async function approve(world: World, contentId: string, submissionId: string) {
  const decided = await composition.moderation.service.decide(world.staff.actor, {
    schemaVersion: 1,
    action: 'approve',
    idempotencyKey: key('approve'),
    reason: 'c3 emulator test approval',
    target: { contentId, submissionId },
  });
  assert.equal(decided.kind, 'succeeded', JSON.stringify(decided));
  assert.equal(
    decided.kind === 'succeeded' && decided.data.receipt.outcome,
    'applied',
    JSON.stringify(decided),
  );
}

/** Creator draft with a ready cover, submitted for review, all through the callables. */
async function submittedEvent(world: World, title = 'Ceramics evening') {
  const draft = data(
    await command(world.creator.idToken, {
      commandType: 'createDraft',
      payload: {
        typeId: 'event',
        publisherRef: { type: 'page', id: world.pageId },
        marketId: 'LV',
        body: { ...standEventBody(randomUUID()), title },
      },
    }),
  );
  const contentId = String(draft.contentId);
  const draftId = String(draft.draftId);
  const assetId = await uploadCover(world, contentId);
  const bound = data(
    await command(world.creator.idToken, {
      commandType: 'updateDraft',
      payload: {
        draftId,
        expectedRevision: draft.revision,
        body: { ...standEventBody(assetId), title },
      },
    }),
  );
  const submission = data(
    await command(world.creator.idToken, {
      commandType: 'submitForPublication',
      payload: { draftId, expectedDraftRevision: bound.revision },
    }),
  );
  return { contentId, draftId, assetId, submissionId: String(submission.submissionId), submission };
}

async function pointerOf(idToken: string, contentId: string) {
  const status = data(await query(idToken, 'getPublicationStatus', { contentId }));
  return status.pointer as Record<string, unknown>;
}

void test('the Content callables stay closed until the Emulator flag is on', async () => {
  const world = await bootstrap();
  const create = {
    commandType: 'createDraft',
    payload: {
      typeId: 'event',
      publisherRef: { type: 'page', id: world.pageId },
      marketId: 'LV',
      body: standEventBody(randomUUID()),
    },
  };
  await setContentFlag(false);
  assert.deepEqual(await command(world.creator.idToken, create), {
    schemaVersion: 1,
    kind: 'rejected',
    code: 'type_disabled',
  });
  await setContentFlag(true);
  assert.equal((await command(undefined, create)).code, 'unauthenticated');
  assert.equal((await command(world.creator.idToken, create)).kind, 'succeeded');
  // A user who is not a verified Creator member of the Page cannot author for it.
  const foreign = await command(world.viewer.idToken, create);
  assert.equal(foreign.kind, 'rejected', JSON.stringify(foreign));
  // Moderation dispositions and import lookups are never reachable from the client.
  const disposition = await command(world.creator.idToken, {
    commandType: 'applyModerationDisposition',
    payload: {},
  });
  assert.equal(disposition.code, 'capability_denied');
  const lookup = await query(world.creator.idToken, 'findByExternalBinding', {
    externalBindingRef: 'x',
  });
  assert.equal(lookup.code, 'capability_denied');
});

void test(
  'review comes first; revisions are immutable and the pointer rolls back',
  { timeout: 240_000 },
  async () => {
    await setContentFlag(true);
    const world = await bootstrap();
    const first = await submittedEvent(world);
    assert.equal(first.submission.state, 'under_review');
    const early = await command(world.creator.idToken, {
      commandType: 'publishApprovedRevision',
      payload: { submissionId: first.submissionId, expectedPointerRevision: 0 },
    });
    assert.equal(early.code, 'moderation_required');

    await approve(world, first.contentId, first.submissionId);
    const revision1 = data(
      await command(world.creator.idToken, {
        commandType: 'publishApprovedRevision',
        payload: { submissionId: first.submissionId, expectedPointerRevision: 0 },
      }),
    );
    const revision1Id = String(revision1.publishedRevisionId);
    const stored1 = (
      await firestore.collection(contentCollections.publishedRevisions).doc(revision1Id).get()
    ).data();
    assert.ok(stored1);

    // A second edition goes through the same review before it is published.
    const draft = data(await query(world.creator.idToken, 'getDraft', { draftId: first.draftId }));
    const edited = data(
      await command(world.creator.idToken, {
        commandType: 'updateDraft',
        payload: {
          draftId: first.draftId,
          expectedRevision: draft.revision,
          body: { ...standEventBody(first.assetId), title: 'Ceramics evening, second edition' },
        },
      }),
    );
    const second = data(
      await command(world.creator.idToken, {
        commandType: 'submitForPublication',
        payload: { draftId: first.draftId, expectedDraftRevision: edited.revision },
      }),
    );
    await approve(world, first.contentId, String(second.submissionId));
    const before = await pointerOf(world.creator.idToken, first.contentId);
    const revision2 = data(
      await command(world.creator.idToken, {
        commandType: 'publishApprovedRevision',
        payload: {
          submissionId: second.submissionId,
          expectedPointerRevision: before.revision,
        },
      }),
    );
    const revision2Id = String(revision2.publishedRevisionId);
    const published = await pointerOf(world.creator.idToken, first.contentId);
    assert.equal(published.currentPublishedRevisionId, revision2Id);
    assert.equal(published.previousPublishedRevisionId, revision1Id);
    const shown = data(
      await query(world.viewer.idToken, 'getPublishedRevision', { contentId: first.contentId }),
    );
    assert.equal((shown.body as Record<string, unknown>).title, 'Ceramics evening, second edition');

    // Rollback selects the earlier immutable revision; it never edits history.
    const rolledBack = data(
      await command(world.creator.idToken, {
        commandType: 'activatePublishedRevision',
        payload: {
          contentId: first.contentId,
          publishedRevisionId: revision1Id,
          expectedPointerRevision: published.revision,
        },
      }),
    );
    assert.equal(rolledBack.currentPublishedRevisionId, revision1Id);
    assert.equal(rolledBack.previousPublishedRevisionId, revision2Id);
    const again = (
      await firestore.collection(contentCollections.publishedRevisions).doc(revision1Id).get()
    ).data();
    assert.deepEqual(again, stored1, 'a published revision never changes');
    const current = data(
      await query(world.viewer.idToken, 'getPublishedRevision', { contentId: first.contentId }),
    );
    assert.equal((current.body as Record<string, unknown>).title, 'Ceramics evening');
  },
);

void test(
  'hide: the owner withdraws, moderation restricts, neither lifts the other',
  { timeout: 240_000 },
  async () => {
    await setContentFlag(true);
    const world = await bootstrap();
    const event = await submittedEvent(world);
    await approve(world, event.contentId, event.submissionId);
    const revision = data(
      await command(world.creator.idToken, {
        commandType: 'publishApprovedRevision',
        payload: { submissionId: event.submissionId, expectedPointerRevision: 0 },
      }),
    );
    const revisionId = String(revision.publishedRevisionId);

    const visible = await pointerOf(world.creator.idToken, event.contentId);
    const hidden = data(
      await command(world.creator.idToken, {
        commandType: 'withdrawPublication',
        payload: {
          contentId: event.contentId,
          expectedPointerRevision: visible.revision,
          mode: 'withdraw',
        },
      }),
    );
    assert.equal(hidden.visibility, 'withdrawn');
    const notServed = await query(world.viewer.idToken, 'getPublishedRevision', {
      contentId: event.contentId,
    });
    assert.equal(notServed.code, 'not_found');
    // Only the owner of the Page may hide it.
    const foreignHide = await command(world.viewer.idToken, {
      commandType: 'withdrawPublication',
      payload: {
        contentId: event.contentId,
        expectedPointerRevision: hidden.revision,
        mode: 'withdraw',
      },
    });
    assert.equal(foreignHide.kind, 'rejected');

    // The owner shows it again by re-selecting the revision.
    const shown = data(
      await command(world.creator.idToken, {
        commandType: 'activatePublishedRevision',
        payload: {
          contentId: event.contentId,
          publishedRevisionId: revisionId,
          expectedPointerRevision: hidden.revision,
        },
      }),
    );
    assert.equal(shown.visibility, 'visible');

    // A moderation restriction cannot be bypassed by the owner.
    const restricted = await composition.moderation.service.decide(world.staff.actor, {
      schemaVersion: 1,
      action: 'restrict',
      idempotencyKey: key('restrict'),
      reason: 'c3 emulator test restriction',
      target: { contentId: event.contentId },
    });
    assert.equal(restricted.kind, 'succeeded', JSON.stringify(restricted));
    const held = await pointerOf(world.creator.idToken, event.contentId);
    assert.equal(held.visibility, 'restricted');
    const bypass = await command(world.creator.idToken, {
      commandType: 'activatePublishedRevision',
      payload: {
        contentId: event.contentId,
        publishedRevisionId: revisionId,
        expectedPointerRevision: held.revision,
      },
    });
    assert.equal(bypass.kind, 'rejected', JSON.stringify(bypass));
  },
);

void test('publishing an Event through Content does not make it bookable', async () => {
  await setContentFlag(true);
  const world = await bootstrap();
  const event = await submittedEvent(world);
  await approve(world, event.contentId, event.submissionId);
  data(
    await command(world.creator.idToken, {
      commandType: 'publishApprovedRevision',
      payload: { submissionId: event.submissionId, expectedPointerRevision: 0 },
    }),
  );
  const projections = await firestore
    .collection('bookingEventProjections')
    .where('eventId', '==', event.contentId)
    .get();
  assert.equal(projections.size, 0, 'no silent Content -> Booking bridge exists');
});
