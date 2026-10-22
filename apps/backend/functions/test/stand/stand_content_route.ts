import { randomUUID } from 'node:crypto';
import type { Firestore } from 'firebase-admin/firestore';

import { eventAuthoringComposition } from '../../src/content_entry.js';
import { SessionAuthorityService } from '../../src/modules/identity_publisher/application/session_authority_service.js';
import { FirestoreIdentityAuthorityRepository } from '../../src/modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import {
  contentCollections,
  FirestoreContentRepository,
} from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { createEmulatorCatalogComposition } from '../../src/modules/catalog/infrastructure/emulator_catalog_composition.js';
import { moderationCollections } from '../../src/modules/moderation/infrastructure/firestore_moderation_repository.js';
import { FirestoreRouteService } from '../../src/modules/route/firestore_route_service.js';
import { routeFlag, routePublicationFlag } from '../../src/modules/route/route_contract.js';
import { encodeElevation, encodePolyline } from '../../src/modules/route/route_geometry.js';
import { contentFlagIds } from '../../src/shared/feature_flags.js';
import { systemServerClock } from '../../src/shared/server_clock.js';
import type { ContentActor } from '../../src/modules/content/application/ports/publisher_eligibility_port.js';
import {
  readStandManifest,
  StandSeedInterrupted,
  writeStandManifest,
} from './stand_content_event.js';
import { uploadStandImage } from './stand_content_session.js';
import { enableStandFlag } from './stand_flags.js';
import { actorFor, mediaFor } from './stand_media.js';
import { standUsers } from './stand_plan.js';

/**
 * J2 stand Route (RTE-PUB-01): one fixed Route of the stand Creator saved
 * through the J1 owner sync, its ends hidden by a privacy trim, pinned by
 * `distribute`, bound to its one Content draft with a cover through Media,
 * submitted, approved through C2 (which earns the Creator's Route trust) and
 * published. Every command repeats the same key and payload on every run, so
 * a resumed seed equals a clean one.
 *
 * The Route service authorizes a Session handle, which the stand never stores;
 * the seed issues its own Session for one fixed installation through the
 * Session owner service. Its records are excluded from the stand digest.
 */
export interface StandContentRouteManifest {
  readonly publisherUserId: string;
  readonly routeId: string;
  readonly contentId: string;
  readonly draftId: string;
  readonly routeRevisionId: string;
  readonly submissionId: string;
  readonly publishedRevisionId: string;
  readonly coverAssetId: string;
  readonly approveDecisionId: string;
  readonly completedAtUtc: string;
}

export const standRouteSeedInstallation = 'stand-installation-route-seed';

export const standSeedRoute = Object.freeze({
  routeId: '06RTE0SEED00000000000000K1',
  title: 'Riga riverside walk (stand)',
  trim: Object.freeze({ startMeters: 200, endMeters: 200 }),
  approveReason: 'stand seed: the seeded Route is approved for publication',
  cover: Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGPQ6w4HAAH7ARF0JhTpAAAAAElFTkSuQmCC',
    'base64',
  ),
  keys: Object.freeze({
    save: 'stand-seed-route-save',
    trim: 'stand-seed-route-trim',
    distribute: 'stand-seed-route-distribute',
    draft: 'stand-seed-route-draft',
    cover: 'stand-seed-route-cover',
    bind: 'stand-seed-route-bind',
    submit: 'stand-seed-route-submit',
    approve: 'stand-seed-route-approve',
    publish: 'stand-seed-route-publish',
  }),
});

export const standSeedRouteSteps = [
  'save',
  'trim',
  'distribute',
  'draft',
  'cover',
  'bind',
  'submit',
  'approve',
  'publish',
] as const;
type Step = (typeof standSeedRouteSteps)[number];

const id = (n: number) => `00000000-0000-4000-8000-0000000004${String(n).padStart(2, '0')}`;

/**
 * A recorded walk along the Daugava, 600 points with elevation, one waypoint
 * next to the private start (dropped by the trim) and one in the middle with a
 * private note that never leaves the owner's Route.
 */
export function standRouteDto(title: string = standSeedRoute.title): Record<string, unknown> {
  const points = Array.from({ length: 600 }, (_, i) => ({
    latE7: 569_480_000 + (i % 9) * 250 - (i % 4) * 120,
    lonE7: 241_000_000 + i * 900,
    eleDm: 70 + (i % 11),
  }));
  const first = points[0]!,
    last = points[points.length - 1]!,
    middle = points[300]!;
  const [from, to, segment, home, bench] = [id(1), id(2), id(3), id(4), id(5)];
  const waypoint = (
    waypointId: string,
    at: { latE7: number; lonE7: number },
    title: string,
    note: string | null,
  ) => ({
    waypointId,
    segmentId: null,
    anchorId: null,
    latE7: at.latE7,
    lonE7: at.lonE7,
    eleDm: null,
    typeId: 'viewpoint',
    trackState: 'offTrackConfirmed',
    title,
    description: null,
    note,
    safetyNote: null,
  });
  return {
    schemaVersion: 1,
    coordinatePolicy: 'wgs84-e7-dm-v1',
    title,
    shape: 'oneWay',
    turningAnchorId: null,
    profile: { id: 'walking', version: 1 },
    anchors: [
      { anchorId: from, latE7: first.latE7, lonE7: first.lonE7 },
      { anchorId: to, latE7: last.latE7, lonE7: last.lonE7 },
    ],
    segments: [
      {
        segmentId: segment,
        order: 0,
        fromAnchorId: from,
        toAnchorId: to,
        sourceKind: 'recordedGps',
        derivation: 'original',
        sourceId: 'stand-recording',
        parentSegmentId: null,
        polyline: encodePolyline(points),
        elevation: encodeElevation(points),
      },
    ],
    waypoints: [
      waypoint(home, first, 'PRIVATE-home', null),
      waypoint(bench, middle, 'River bench', 'PRIVATE-note'),
    ],
  };
}

function expectSucceeded<T>(label: string, result: Readonly<Record<string, unknown>>): T {
  if (result.kind !== 'succeeded')
    throw new Error(`stand_seed_route_${label}_refused:${JSON.stringify(result)}`);
  return (result.data ?? result) as T;
}

/**
 * The Creator's Content Session: the latest live one that is not the seed's own
 * Route Session, so Content and Media records never name a per-run Session.
 */
async function contentActor(firestore: Firestore): Promise<ContentActor> {
  const base = await actorFor(firestore, 'creator');
  const sessions = await new FirestoreIdentityAuthorityRepository(firestore).transact((tx) =>
    tx.sessionsForUser(base.userId),
  );
  const live = sessions
    .filter(
      (session) =>
        session.status === 'active' && session.installationId !== standRouteSeedInstallation,
    )
    .sort((left, right) => (left.issuedAtUtc < right.issuedAtUtc ? 1 : -1))[0];
  if (live === undefined) throw new Error('no live Content Session for the stand Creator');
  return { userId: base.userId, sessionId: live.sessionId };
}

/** A Route Session of the stand Creator for the fixed seed installation. */
async function routeHint(firestore: Firestore, userId: string) {
  const creator = standUsers.find((user) => user.label === 'creator')!;
  const now = new Date();
  const issued = await new SessionAuthorityService(
    new FirestoreIdentityAuthorityRepository(firestore),
  ).issue({
    userId,
    sessionId: randomUUID(),
    firebaseUid: creator.firebaseUid,
    installationId: standRouteSeedInstallation,
    issuedAtUtc: now.toISOString(),
    snapshotExpiresAtUtc: new Date(now.getTime() + 3_600_000).toISOString(),
  });
  return {
    firebaseUid: creator.firebaseUid,
    installationId: standRouteSeedInstallation,
    sessionId: issued.session.sessionId,
    sessionHandle: issued.sessionHandle,
  };
}

export async function seedContentRoute(
  firestore: Firestore,
  options: { readonly interruptAfter?: string | undefined } = {},
): Promise<{ readonly reused: boolean; readonly manifest: StandContentRouteManifest }> {
  const existing = (await readStandManifest(firestore))?.contentRoute;
  if (existing !== undefined) return { reused: true, manifest: existing };
  const nowUtc = new Date().toISOString();
  for (const flag of [routeFlag, routePublicationFlag, contentFlagIds.routeAuthoring])
    await enableStandFlag(firestore, flag, nowUtc);
  const checkpoint = (step: Step) => {
    if (options.interruptAfter === step)
      throw new StandSeedInterrupted(`stand route seed interrupted after ${step} (test hook)`);
  };
  const { routeId, keys } = standSeedRoute;
  const media = mediaFor(firestore);
  const composition = eventAuthoringComposition(firestore, {
    media,
    enabledTypes: new Set(['route'] as const),
  });
  const creator = await contentActor(firestore);
  const hint = await routeHint(firestore, creator.userId);
  const routes = new FirestoreRouteService(firestore, systemServerClock);
  const command = (
    commandType: string,
    idempotencyKey: string,
    expectedRevision: number,
    extra: Record<string, unknown> = {},
  ) =>
    routes.command(hint, {
      schemaVersion: 1,
      requestId: randomUUID(),
      ownerContext: creator.userId,
      idempotencyKey,
      commandType,
      routeId,
      expectedRevision,
      ...extra,
    });

  expectSucceeded('save', await command('save', keys.save, 0, { route: standRouteDto() }));
  checkpoint('save');
  // RP-02: the recorded walk hides 200 m at both ends before it is distributed.
  expectSucceeded(
    'trim',
    await command('setPrivacyTrim', keys.trim, 1, { privacyTrim: standSeedRoute.trim }),
  );
  checkpoint('trim');
  const pinned = expectSucceeded<{
    routeRevisionId: string;
    contentHash: string;
    distribution: Record<string, unknown>;
  }>('distribute', await command('distribute', keys.distribute, 2));
  checkpoint('distribute');
  const body = (coverMediaId?: string) => ({
    title: pinned.distribution.title,
    shortDescription: 'A calm recorded walk along the Daugava',
    fullDescription: 'A recorded riverside walk in Riga; both private ends are hidden.',
    contentLocale: 'en',
    categoryId: 'art_culture_museums',
    subcategoryId: 'art_walk',
    media:
      coverMediaId === undefined
        ? {}
        : {
            coverImage: { mediaId: coverMediaId, altText: { en: 'Riverside' } },
            rightsConfirmed: true,
          },
    route: {
      ref: {
        routeId,
        routeRevisionId: pinned.routeRevisionId,
        contentHash: pinned.contentHash,
      },
      distribution: pinned.distribution,
    },
  });
  const draft = expectSucceeded<{ draftId: string; contentId: string }>(
    'draft',
    await composition.content.execute(creator, {
      schemaVersion: 1,
      commandType: 'createDraft',
      idempotencyKey: keys.draft,
      payload: {
        typeId: 'route',
        publisherRef: { type: 'user', id: creator.userId },
        marketId: 'LV',
        body: body(),
      },
    }),
  );
  checkpoint('draft');
  const coverAssetId = await uploadStandImage(media, creator, {
    key: keys.cover,
    bytes: standSeedRoute.cover,
    publisherUserId: creator.userId,
    contentId: draft.contentId,
  });
  checkpoint('cover');
  expectSucceeded(
    'bind',
    await composition.content.execute(creator, {
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: keys.bind,
      payload: { draftId: draft.draftId, expectedRevision: 1, body: body(coverAssetId) },
    }),
  );
  checkpoint('bind');
  const submission = expectSucceeded<{ submissionId: string; state: string }>(
    'submit',
    await composition.content.execute(creator, {
      schemaVersion: 1,
      commandType: 'submitForPublication',
      idempotencyKey: keys.submit,
      payload: { draftId: draft.draftId, expectedDraftRevision: 2 },
    }),
  );
  if (submission.state !== 'under_review')
    throw new Error(`stand_seed_route_submit_not_reviewed:${submission.state}`);
  checkpoint('submit');
  // RP-06: the first Route of the Creator is reviewed by hand; the approval earns trust.
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
      reason: standSeedRoute.approveReason,
      target: { contentId: draft.contentId, submissionId: submission.submissionId },
    }),
  );
  if (approved.receipt.outcome === 'refused')
    throw new Error(`stand_seed_route_approve_refused:${JSON.stringify(approved.receipt)}`);
  checkpoint('approve');
  const published = expectSucceeded<{ publishedRevisionId: string }>(
    'publish',
    await composition.content.execute(creator, {
      schemaVersion: 1,
      commandType: 'publishApprovedRevision',
      idempotencyKey: keys.publish,
      payload: { submissionId: submission.submissionId, expectedPointerRevision: 0 },
    }),
  );
  checkpoint('publish');
  const manifest: StandContentRouteManifest = {
    publisherUserId: creator.userId,
    routeId,
    contentId: draft.contentId,
    draftId: draft.draftId,
    routeRevisionId: pinned.routeRevisionId,
    submissionId: submission.submissionId,
    publishedRevisionId: published.publishedRevisionId,
    coverAssetId,
    approveDecisionId: approved.decision.decisionId,
    completedAtUtc: new Date().toISOString(),
  };
  await writeStandManifest(firestore, { contentRoute: manifest });
  return { reused: false, manifest };
}

async function required(firestore: Firestore): Promise<StandContentRouteManifest> {
  const route = (await readStandManifest(firestore))?.contentRoute;
  if (route === undefined) throw new Error('stand Route is not seeded');
  return route;
}

export async function standRouteStatus(firestore: Firestore) {
  const route = await required(firestore);
  const pointer = (
    await firestore.collection(contentCollections.pointers).doc(route.contentId).get()
  ).data();
  return { manifest: route, pointer: pointer ?? null };
}

/**
 * `route verify`: one publication per Route at the seeded revision, the body
 * pinned to the seeded snapshot without any private data, the Creator trusted
 * after the reviewed approval, and the Catalog Route family listing it with
 * its preview when the stand runs with the local family switch.
 */
export async function verifyStandRoute(firestore: Firestore): Promise<readonly string[]> {
  const route = await required(firestore);
  const problems: string[] = [];
  if (route.contentId !== route.routeId) problems.push('contentId is not the routeId');
  const pointer = (
    await firestore.collection(contentCollections.pointers).doc(route.contentId).get()
  ).data();
  if (pointer?.currentPublishedRevisionId !== route.publishedRevisionId)
    problems.push('pointer does not show the seeded revision');
  if (pointer?.visibility !== 'visible') problems.push('Route is not visible');
  const revision = await new FirestoreContentRepository(firestore).transact((tx) =>
    tx.publishedRevision(route.publishedRevisionId),
  );
  const ref = (revision?.body as { route?: { ref?: { routeRevisionId?: string } } } | undefined)
    ?.route?.ref;
  if (ref?.routeRevisionId !== route.routeRevisionId)
    problems.push('published body is not pinned to the seeded Route snapshot');
  const text = JSON.stringify(revision);
  for (const marker of ['PRIVATE', 'stand-recording', 'anchorId', 'startMeters'])
    if (text.includes(marker)) problems.push(`private data in the revision: ${marker}`);
  const trust = (
    await firestore
      .collection(moderationCollections.publisherTrust)
      .doc(`route:user:${route.publisherUserId}`)
      .get()
  ).data();
  if (trust?.state !== 'trusted') problems.push('the Creator did not earn Route trust');
  const catalog = createEmulatorCatalogComposition(firestore);
  const active = await catalog.sets.ensureActive();
  await catalog.projector.deliverFromContent(active.setId);
  const details = await catalog.query.details({ contentId: route.contentId });
  const expected = process.env.RECHARGE_TEST_ROUTE_CATALOG === 'true' ? 'listed' : 'excluded';
  if (details.kind !== 'succeeded' && expected === 'listed')
    problems.push(`Catalog details refused: ${JSON.stringify(details)}`);
  if (details.kind === 'succeeded' && details.state !== expected)
    problems.push(`Catalog state is ${details.state}, expected ${expected}`);
  if (details.kind === 'succeeded' && details.state === 'listed') {
    const item = details.item as { preview?: unknown; track?: unknown } | null;
    if (item?.preview === undefined || item.track === undefined)
      problems.push('Catalog Details lack the preview or the trimmed track');
    if (JSON.stringify(details).includes('PRIVATE')) problems.push('private data in the Catalog');
  }
  return problems;
}
