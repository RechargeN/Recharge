import type { Firestore } from 'firebase-admin/firestore';

import { eventAuthoringComposition } from '../../src/content_entry.js';
import { readContentJson } from '../../src/contracts/content_schema_registry.js';
import { createEmulatorCatalogComposition } from '../../src/modules/catalog/infrastructure/emulator_catalog_composition.js';
import { catalogCollections } from '../../src/modules/catalog/infrastructure/firestore_catalog_repository.js';
import {
  contentCollections,
  FirestoreContentRepository,
} from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import {
  FirestoreFindPeopleConsentService,
  findPeopleIdentityCollections,
  readFindPeopleConsent,
} from '../../src/modules/identity_publisher/infrastructure/find_people_privacy_authority.js';
import { catalogFlagIds, contentFlagIds, identityFlagIds } from '../../src/shared/feature_flags.js';
import { findPeoplePolicy, isPublicCellCentre } from '../../src/shared/find_people_policy.js';
import { systemServerClock } from '../../src/shared/server_clock.js';
import {
  readStandManifest,
  StandSeedInterrupted,
  writeStandManifest,
} from './stand_content_event.js';
import { enableStandFlag } from './stand_flags.js';
import { actorFor, mediaFor } from './stand_media.js';

/**
 * D3.7 stand Find People: one fixed request published through Content only —
 * an empty draft, the full private source with the server's author, the
 * author's explicit BCK-06 consent, submit, a staff approval through C2, the
 * owner's publish and the Catalog delivery. The stand creator and viewer get a
 * synthetic server 18+ attestation (FP-OD-04); the stand staff user has none,
 * so it is the unattested viewer of the mobile gate. Every command repeats the
 * same key and payload on every run.
 */
export interface StandContentFindPeopleManifest {
  readonly publisherUserId: string;
  readonly contentId: string;
  readonly draftId: string;
  readonly createdByUserId: string;
  readonly submissionId: string;
  readonly publishedRevisionId: string;
  readonly approveDecisionId: string;
  readonly viewerUserId: string;
  readonly publicLocation: { readonly latitude: number; readonly longitude: number };
  readonly completedAtUtc: string;
}

export const standSeedFindPeople = Object.freeze({
  slotId: 'f3d70000-0000-4000-8000-00000000d307',
  attestedAtUtc: '2026-10-19T00:00:00.000Z',
  approveReason: 'stand seed: the seeded Find People request is approved for publication',
  keys: Object.freeze({
    draft: 'stand-seed-find-people-draft',
    bind: 'stand-seed-find-people-bind',
    consent: 'stand-seed-find-people-consent',
    submit: 'stand-seed-find-people-submit',
    approve: 'stand-seed-find-people-approve',
    publish: 'stand-seed-find-people-publish',
  }),
});

export const standSeedFindPeopleSteps = [
  'draft',
  'bind',
  'consent',
  'submit',
  'approve',
  'publish',
] as const;
export type StandSeedFindPeopleStep = (typeof standSeedFindPeopleSteps)[number];

function expectSucceeded<T>(label: string, result: { kind: string; data?: unknown }): T {
  if (result.kind !== 'succeeded' || result.data === undefined)
    throw new Error(`stand_seed_find_people_${label}_refused:${JSON.stringify(result)}`);
  return result.data as T;
}

/** The shared D3.7 wire fixture body, bound to the server's author. */
export async function standFindPeopleBody(authorUserId: string): Promise<Record<string, unknown>> {
  const fixture = (await readContentJson('fixtures/find_people_create_compat.json')) as {
    cases: { name: string; body: Record<string, unknown> }[];
  };
  const body = structuredClone(fixture.cases.find((item) => item.name === 'valid')!.body) as {
    findPeople: {
      hosts: { responsibleHostUserIds: string[] };
      schedule: { slot: { id: string } };
    };
  };
  body.findPeople.hosts.responsibleHostUserIds = [authorUserId];
  body.findPeople.schedule.slot.id = standSeedFindPeople.slotId;
  return body;
}

/** FP-OD-04: the synthetic server attestation of one stand user (`none` removes it). */
export async function attestStandUser(
  firestore: Firestore,
  label: string,
  band: 'adult' | 'minor' | 'none',
): Promise<string> {
  const { userId } = await actorFor(firestore, label);
  const ref = firestore.collection(findPeopleIdentityCollections.ageAttestations).doc(userId);
  if (band === 'none') await ref.delete();
  else
    await ref.set({
      schemaVersion: 1,
      userId,
      marketId: findPeoplePolicy.marketId,
      ageBand: band === 'adult' ? 'adult_18_plus' : 'minor',
      source: 'synthetic_emulator_fixture',
      policyRevision: findPeoplePolicy.agePolicyRevision,
      attestedAtUtc: standSeedFindPeople.attestedAtUtc,
      revokedAtUtc: null,
    });
  return userId;
}

function findPeopleComposition(firestore: Firestore) {
  return eventAuthoringComposition(firestore, {
    media: mediaFor(firestore),
    enabledTypes: new Set(['find_people'] as const),
  });
}

/** Content → Catalog delivery of the stand (idempotent next to the E2 trigger). */
export async function deliverStandCatalog(firestore: Firestore) {
  const catalog = createEmulatorCatalogComposition(firestore, { findPeopleEnabled: true });
  const active = await catalog.sets.ensureActive();
  const report = await catalog.projector.deliverFromContent(active.setId);
  return { synced: report.synced, stoppedAt: report.stoppedAt };
}

export async function seedContentFindPeople(
  firestore: Firestore,
  options: { readonly interruptAfter?: string | undefined } = {},
): Promise<{ readonly reused: boolean; readonly manifest: StandContentFindPeopleManifest }> {
  const existing = (await readStandManifest(firestore))?.contentFindPeople;
  if (existing !== undefined) return { reused: true, manifest: existing };
  const nowUtc = new Date().toISOString();
  for (const flag of [
    contentFlagIds.findPeopleAuthoring,
    identityFlagIds.findPeopleConsent,
    catalogFlagIds.findPeople,
  ])
    await enableStandFlag(firestore, flag, nowUtc);
  const checkpoint = (step: StandSeedFindPeopleStep) => {
    if (options.interruptAfter === step)
      throw new StandSeedInterrupted(
        `stand find-people seed interrupted after ${step} (test hook)`,
      );
  };
  await attestStandUser(firestore, 'creator', 'adult');
  const viewerUserId = await attestStandUser(firestore, 'viewer', 'adult');
  const composition = findPeopleComposition(firestore);
  const creator = await actorFor(firestore, 'creator');
  const { keys } = standSeedFindPeople;

  const draft = expectSucceeded<{
    draftId: string;
    contentId: string;
    createdByUserId: string;
  }>(
    'draft',
    await composition.content.execute(creator, {
      schemaVersion: 1,
      commandType: 'createDraft',
      idempotencyKey: keys.draft,
      payload: {
        typeId: 'find_people',
        publisherRef: { type: 'user', id: creator.userId },
        marketId: 'LV',
        body: {},
      },
    }),
  );
  checkpoint('draft');
  expectSucceeded(
    'bind',
    await composition.content.execute(creator, {
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: keys.bind,
      payload: {
        draftId: draft.draftId,
        expectedRevision: 1,
        body: await standFindPeopleBody(draft.createdByUserId),
      },
    }),
  );
  checkpoint('bind');
  const consent = await new FirestoreFindPeopleConsentService(
    firestore,
    systemServerClock,
  ).commandAs(creator.userId, {
    schemaVersion: 1,
    commandType: 'grantFindPeopleConsent',
    idempotencyKey: keys.consent,
    payload: { contentId: draft.contentId, expectedRevision: 0 },
  });
  if (consent.kind !== 'succeeded')
    throw new Error(`stand_seed_find_people_consent_refused:${JSON.stringify(consent)}`);
  checkpoint('consent');
  const submission = expectSucceeded<{ submissionId: string }>(
    'submit',
    await composition.content.execute(creator, {
      schemaVersion: 1,
      commandType: 'submitForPublication',
      idempotencyKey: keys.submit,
      payload: { draftId: draft.draftId, expectedDraftRevision: 2 },
    }),
  );
  checkpoint('submit');
  const staff = await actorFor(firestore, 'staff');
  const approved = expectSucceeded<{
    decision: { decisionId: string };
    receipt: { outcome: string };
  }>(
    'approve',
    await composition.moderation.service.decide(staff, {
      schemaVersion: 1,
      action: 'approve',
      idempotencyKey: keys.approve,
      reason: standSeedFindPeople.approveReason,
      target: { contentId: draft.contentId, submissionId: submission.submissionId },
    }),
  );
  if (approved.receipt.outcome === 'refused')
    throw new Error(`stand_seed_find_people_approve_refused:${JSON.stringify(approved.receipt)}`);
  checkpoint('approve');
  const published = expectSucceeded<{
    publishedRevisionId: string;
    body: { findPeople: { meeting: { publicLocation: { latitude: number; longitude: number } } } };
  }>(
    'publish',
    await composition.content.execute(creator, {
      schemaVersion: 1,
      commandType: 'publishApprovedRevision',
      idempotencyKey: keys.publish,
      payload: { submissionId: submission.submissionId, expectedPointerRevision: 0 },
    }),
  );
  checkpoint('publish');
  await deliverStandCatalog(firestore);
  const location = published.body.findPeople.meeting.publicLocation;
  const manifest: StandContentFindPeopleManifest = {
    publisherUserId: creator.userId,
    contentId: draft.contentId,
    draftId: draft.draftId,
    createdByUserId: draft.createdByUserId,
    submissionId: submission.submissionId,
    publishedRevisionId: published.publishedRevisionId,
    approveDecisionId: approved.decision.decisionId,
    viewerUserId,
    publicLocation: { latitude: location.latitude, longitude: location.longitude },
    completedAtUtc: new Date().toISOString(),
  };
  await writeStandManifest(firestore, { contentFindPeople: manifest });
  return { reused: false, manifest };
}

async function required(firestore: Firestore): Promise<StandContentFindPeopleManifest> {
  const manifest = (await readStandManifest(firestore))?.contentFindPeople;
  if (manifest === undefined) throw new Error('stand Find People is not seeded');
  return manifest;
}

export async function standFindPeopleStatus(firestore: Firestore) {
  const manifest = await required(firestore);
  const pointer = (
    await firestore.collection(contentCollections.pointers).doc(manifest.contentId).get()
  ).data();
  return { manifest, pointer: pointer ?? null };
}

/**
 * `find-people verify`: visible pointer on the seeded revision; the published
 * body is the public projection only (cell centre, no exact data); consent
 * active; Catalog lists exactly the cell centre.
 */
export async function verifyStandFindPeople(firestore: Firestore): Promise<readonly string[]> {
  const manifest = await required(firestore);
  const problems: string[] = [];
  const pointer = (
    await firestore.collection(contentCollections.pointers).doc(manifest.contentId).get()
  ).data();
  if (pointer?.currentPublishedRevisionId !== manifest.publishedRevisionId)
    problems.push('pointer does not show the seeded revision');
  if (pointer?.visibility !== 'visible') problems.push('Find People request is not visible');
  const revision = await new FirestoreContentRepository(firestore).transact((tx) =>
    tx.publishedRevision(manifest.publishedRevisionId),
  );
  const text = JSON.stringify(revision?.body ?? {});
  for (const secret of ['56.95182', '24.08571', 'riverside steps', 'Ķīpsalas iela', 'blue bench'])
    if (text.includes(secret)) problems.push(`published body holds private data: ${secret}`);
  const { latitude, longitude } = manifest.publicLocation;
  if (!isPublicCellCentre(latitude, longitude)) problems.push('public point is not a cell centre');
  const consent = await readFindPeopleConsent(firestore, {
    contentId: manifest.contentId,
    userId: manifest.createdByUserId,
    nowUtc: new Date().toISOString(),
  });
  if (consent.state !== 'active') problems.push(`consent is ${consent.state}`);
  await deliverStandCatalog(firestore);
  const versions = await firestore
    .collection(catalogCollections.versions)
    .where('contentId', '==', manifest.contentId)
    .get();
  const listed = versions.docs.filter(
    (doc) => doc.get('state') === 'listed' && doc.get('validToRevision') === null,
  );
  if (listed.length !== 1) problems.push(`Catalog lists ${listed.length} current versions`);
  for (const doc of listed) {
    const point = doc.get('item.point') as { latitude: number; longitude: number } | undefined;
    if (point?.latitude !== latitude || point.longitude !== longitude)
      problems.push('Catalog point is not the public cell centre');
    const item = JSON.stringify(doc.data());
    if (item.includes('56.95182') || item.includes('Ķīpsalas iela'))
      problems.push('Catalog item holds private data');
  }
  return problems;
}

/** Owner-path fixtures of the mobile gate, run in the stand's trusted backend context. */
export async function runFindPeopleFixture(
  firestore: Firestore,
  args: readonly string[],
): Promise<unknown> {
  const [action, first, second] = args;
  if (action === 'attest' && first !== undefined && second !== undefined)
    return {
      userId: await attestStandUser(firestore, first, second as 'adult' | 'minor' | 'none'),
    };
  if (action === 'deliver') return deliverStandCatalog(firestore);
  if (action === 'approve' && first !== undefined) {
    const composition = findPeopleComposition(firestore);
    const submission = await new FirestoreContentRepository(firestore).transact((tx) =>
      tx.submission(first),
    );
    if (submission === null) throw new Error('unknown submission');
    const staff = await actorFor(firestore, 'staff');
    return composition.moderation.service.decide(staff, {
      schemaVersion: 1,
      action: 'approve',
      idempotencyKey: `stand-find-people-approve-${first}`,
      reason: 'stand: D3.7 mobile gate review',
      target: { contentId: submission.contentId, submissionId: first },
    });
  }
  throw new Error(
    'usage: find-people-fixture attest <label> adult|minor|none | deliver | approve <submissionId>',
  );
}
