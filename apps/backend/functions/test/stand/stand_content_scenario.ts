import { createHash, randomUUID } from 'node:crypto';
import type { Firestore } from 'firebase-admin/firestore';

import { eventAuthoringComposition, scenarioStopsFor } from '../../src/content_entry.js';
import { SessionAuthorityService } from '../../src/modules/identity_publisher/application/session_authority_service.js';
import { FirestoreIdentityAuthorityRepository } from '../../src/modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import {
  contentCollections,
  FirestoreContentRepository,
} from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { createEmulatorCatalogComposition } from '../../src/modules/catalog/infrastructure/emulator_catalog_composition.js';
import { FirestoreScenarioService } from '../../src/modules/quick_plan/firestore_scenario_service.js';
import { contentFlagIds, scenarioFlagIds } from '../../src/shared/feature_flags.js';
import { systemServerClock } from '../../src/shared/server_clock.js';
import {
  readStandManifest,
  StandSeedInterrupted,
  writeStandManifest,
} from './stand_content_event.js';
import { uploadStandImage } from './stand_content_session.js';
import { enableStandFlag } from './stand_flags.js';
import { actorFor, mediaFor } from './stand_media.js';
import type { ContentActor } from '../../src/modules/content/application/ports/publisher_eligibility_port.js';
import { standUsers } from './stand_plan.js';

/**
 * I3 stand Scenario (SCN-PUB-01): one fixed personal Scenario of the stand
 * Creator saved through I2, pinned by Planning `distribute`, bound to its one
 * Content draft with a cover through Media, submitted, approved through C2 and
 * published by the owner, then shared unlisted. Every command repeats the same
 * key and payload on every run, so a resumed seed equals a clean one.
 *
 * Planning authorizes a Session handle, which the stand never stores; the seed
 * issues its own Session for one fixed installation through the Session owner
 * service. Its records are excluded from the stand digest as per-run by design.
 */
export interface StandContentScenarioManifest {
  readonly publisherUserId: string;
  readonly scenarioId: string;
  readonly contentId: string;
  readonly draftId: string;
  readonly scenarioRevisionId: string;
  readonly submissionId: string;
  readonly publishedRevisionId: string;
  readonly coverAssetId: string;
  readonly approveDecisionId: string;
  readonly shareId: string | null;
  readonly completedAtUtc: string;
}

export const standScenarioSeedInstallation = 'stand-installation-scenario-seed';

export const standSeedScenario = Object.freeze({
  scenarioId: '06S7SCENAR10SEED000000000K',
  approveReason: 'stand seed: the seeded Scenario is approved for publication',
  cover: Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGPQ6w4HAAH7ARF0JhTpAAAAAElFTkSuQmCC',
    'base64',
  ),
  keys: Object.freeze({
    save: 'stand-seed-scenario-save',
    distribute: 'stand-seed-scenario-distribute',
    draft: 'stand-seed-scenario-draft',
    cover: 'stand-seed-scenario-cover',
    bind: 'stand-seed-scenario-bind',
    submit: 'stand-seed-scenario-submit',
    approve: 'stand-seed-scenario-approve',
    publish: 'stand-seed-scenario-publish',
    share: 'stand-seed-scenario-share',
  }),
});

export const standSeedScenarioSteps = [
  'save',
  'distribute',
  'draft',
  'cover',
  'bind',
  'submit',
  'approve',
  'publish',
  'share',
] as const;
type Step = (typeof standSeedScenarioSteps)[number];

const id = (n: number) => `00000000-0000-4000-8000-0000000003${String(n).padStart(2, '0')}`;

/** Two own public places and a time block in Riga; fixed ids, no catalog stop. */
export function standScenarioDraft(title = 'Riga old town (stand)'): Record<string, unknown> {
  const [day, a, b, c, l1, l2] = [id(1), id(2), id(3), id(4), id(5), id(6)];
  const item = (
    itemId: string,
    kind: string,
    source: Record<string, unknown>,
    loc: string | null,
  ) => ({
    id: itemId,
    dayId: day,
    startLocationId: loc,
    endLocationId: loc,
    kind,
    source,
    sourceStatus: 'ready',
    schedule: {
      mode: 'flexible',
      planned: {
        type: 'template',
        startDayIndex: 0,
        preferredStart: { hour: 10, minute: 0 },
        windowStart: null,
        windowEnd: null,
        windowEndDayOffset: 0,
        endDayIndex: null,
        preferredEnd: null,
        startTimezoneId: null,
        endTimezoneId: null,
      },
      calculated: null,
    },
    durationMinutes: 60,
    cost: { components: [] },
    orderLocked: false,
    timeLocked: false,
    role: 'mandatory',
    alternativeGroupId: null,
    selected: false,
    publicNote: '',
  });
  const location = (locationId: string, title: string, latitude: number, longitude: number) => ({
    id: locationId,
    point: { latitude, longitude },
    title,
    address: null,
    marketId: 'LV',
    regionId: null,
    timezoneId: 'Europe/Riga',
    disclosure: 'public',
    sourceObjectId: null,
    sourceObjectType: null,
  });
  return {
    title,
    scenario: {
      schemaVersion: 2,
      updatesEnabled: true,
      revision: 1,
      format: 'day',
      dateMode: 'template',
      defaultTimezoneId: 'Europe/Riga',
      displayCurrencyCode: 'EUR',
      party: { peopleCount: 2, kind: 'couple' },
      constraints: {},
      days: [
        {
          id: day,
          title: 'Old town',
          dayIndex: 0,
          timezoneId: 'Europe/Riga',
          localDate: null,
          startLocationId: null,
          endLocationId: null,
          preferredStartTime: null,
          preferredEndTime: null,
          itemIds: [a, b, c],
        },
      ],
      locations: [
        location(l1, 'Town Hall Square', 56.9474, 24.1063),
        location(l2, 'Dome cathedral', 56.949, 24.104),
      ],
      items: [
        item(a, 'visit', { type: 'custom_location', locationId: l1 }, l1),
        item(b, 'visit', { type: 'custom_location', locationId: l2 }, l2),
        item(
          c,
          'time_block',
          { type: 'time_block', title: 'Coffee break', categoryId: null },
          null,
        ),
      ],
      unscheduledItemIds: [],
      legs: [],
      totals: {},
      origin: null,
      capabilities: { publicPublish: false, unlistedShare: false, liveLogistics: false },
    },
  };
}

function expectSucceeded<T>(label: string, result: Readonly<Record<string, unknown>>): T {
  if (result.kind !== 'succeeded')
    throw new Error(`stand_seed_scenario_${label}_refused:${JSON.stringify(result)}`);
  return (result.data ?? result) as T;
}

/**
 * The Creator's Content Session: the latest live one that is not the seed's own
 * Planning Session, so Content and Media records never name a per-run Session.
 */
async function contentActor(firestore: Firestore): Promise<ContentActor> {
  const base = await actorFor(firestore, 'creator');
  const sessions = await new FirestoreIdentityAuthorityRepository(firestore).transact((tx) =>
    tx.sessionsForUser(base.userId),
  );
  const live = sessions
    .filter(
      (session) =>
        session.status === 'active' && session.installationId !== standScenarioSeedInstallation,
    )
    .sort((left, right) => (left.issuedAtUtc < right.issuedAtUtc ? 1 : -1))[0];
  if (live === undefined) throw new Error('no live Content Session for the stand Creator');
  return { userId: base.userId, sessionId: live.sessionId };
}

/** A Planning Session of the stand Creator for the fixed seed installation. */
async function planningHint(firestore: Firestore, userId: string) {
  const creator = standUsers.find((user) => user.label === 'creator')!;
  const now = new Date();
  const sessionId = randomUUID();
  const issued = await new SessionAuthorityService(
    new FirestoreIdentityAuthorityRepository(firestore),
  ).issue({
    userId,
    sessionId,
    firebaseUid: creator.firebaseUid,
    installationId: standScenarioSeedInstallation,
    issuedAtUtc: now.toISOString(),
    snapshotExpiresAtUtc: new Date(now.getTime() + 3_600_000).toISOString(),
  });
  return {
    firebaseUid: creator.firebaseUid,
    installationId: standScenarioSeedInstallation,
    sessionId: issued.session.sessionId,
    sessionHandle: issued.sessionHandle,
  };
}

export async function seedContentScenario(
  firestore: Firestore,
  options: { readonly interruptAfter?: string | undefined } = {},
): Promise<{ readonly reused: boolean; readonly manifest: StandContentScenarioManifest }> {
  const existing = (await readStandManifest(firestore))?.contentScenario;
  if (existing !== undefined) return { reused: true, manifest: existing };
  const nowUtc = new Date().toISOString();
  for (const flag of [
    scenarioFlagIds.sync,
    scenarioFlagIds.publication,
    scenarioFlagIds.share,
    contentFlagIds.scenarioAuthoring,
  ])
    await enableStandFlag(firestore, flag, nowUtc);
  const checkpoint = (step: Step) => {
    if (options.interruptAfter === step)
      throw new StandSeedInterrupted(`stand scenario seed interrupted after ${step} (test hook)`);
  };
  const { scenarioId, keys } = standSeedScenario;
  const media = mediaFor(firestore);
  const composition = eventAuthoringComposition(firestore, {
    media,
    enabledTypes: new Set(['scenario'] as const),
  });
  const creator = await contentActor(firestore);
  const hint = await planningHint(firestore, creator.userId);
  const planning = new FirestoreScenarioService(
    firestore,
    systemServerClock,
    scenarioStopsFor(firestore),
  );
  const command = (
    commandType: string,
    idempotencyKey: string,
    extra: Record<string, unknown> = {},
  ) => ({
    schemaVersion: 1,
    requestId: randomUUID(),
    actorContext: creator.userId,
    idempotencyKey,
    commandType,
    scenarioId,
    expectedRevision: commandType === 'save' ? 0 : 1,
    generation: 0,
    ...extra,
  });

  expectSucceeded(
    'save',
    await planning.command(hint, command('save', keys.save, { draft: standScenarioDraft() })),
  );
  checkpoint('save');
  const pinned = expectSucceeded<{
    scenarioRevisionId: string;
    contentHash: string;
    distribution: Record<string, unknown>;
  }>('distribute', await planning.command(hint, command('distribute', keys.distribute)));
  checkpoint('distribute');
  const body = (coverMediaId?: string) => ({
    title: pinned.distribution.title,
    shortDescription: 'A short walk through the Riga old town',
    fullDescription: 'Two old town places and a coffee break, as a reusable template.',
    contentLocale: 'en',
    media:
      coverMediaId === undefined
        ? { rightsConfirmed: false }
        : {
            coverImage: { mediaId: coverMediaId, altText: { en: 'Old town' } },
            rightsConfirmed: true,
          },
    scenario: {
      ref: {
        scenarioId,
        scenarioRevisionId: pinned.scenarioRevisionId,
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
        typeId: 'scenario',
        publisherRef: { type: 'user', id: creator.userId },
        marketId: 'LV',
        body: body(),
      },
    }),
  );
  checkpoint('draft');
  const coverAssetId = await uploadStandImage(media, creator, {
    key: keys.cover,
    bytes: standSeedScenario.cover,
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
      reason: standSeedScenario.approveReason,
      target: { contentId: draft.contentId, submissionId: submission.submissionId },
    }),
  );
  if (approved.receipt.outcome === 'refused')
    throw new Error(`stand_seed_scenario_approve_refused:${JSON.stringify(approved.receipt)}`);
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
  // The token is shown once; a resumed seed that lost it records no share id.
  const share = expectSucceeded<{ token?: string }>(
    'share',
    await planning.command(hint, command('share', keys.share)),
  );
  checkpoint('share');
  const manifest: StandContentScenarioManifest = {
    publisherUserId: creator.userId,
    scenarioId,
    contentId: draft.contentId,
    draftId: draft.draftId,
    scenarioRevisionId: pinned.scenarioRevisionId,
    submissionId: submission.submissionId,
    publishedRevisionId: published.publishedRevisionId,
    coverAssetId,
    approveDecisionId: approved.decision.decisionId,
    shareId:
      typeof share.token === 'string'
        ? createHash('sha256').update(share.token, 'utf8').digest('hex')
        : null,
    completedAtUtc: new Date().toISOString(),
  };
  await writeStandManifest(firestore, { contentScenario: manifest });
  return { reused: false, manifest };
}

async function required(firestore: Firestore): Promise<StandContentScenarioManifest> {
  const scenario = (await readStandManifest(firestore))?.contentScenario;
  if (scenario === undefined) throw new Error('stand Scenario is not seeded');
  return scenario;
}

export async function standScenarioStatus(firestore: Firestore) {
  const scenario = await required(firestore);
  const pointer = (
    await firestore.collection(contentCollections.pointers).doc(scenario.contentId).get()
  ).data();
  return { manifest: scenario, pointer: pointer ?? null };
}

/**
 * `scenario verify`: one publication per Scenario at the seeded revision, the
 * body pinned to the seeded Planning revision, and the Catalog Scenario family
 * listing it when the stand runs with the local family switch.
 */
export async function verifyStandScenario(firestore: Firestore): Promise<readonly string[]> {
  const scenario = await required(firestore);
  const problems: string[] = [];
  if (scenario.contentId !== scenario.scenarioId) problems.push('contentId is not the scenarioId');
  const pointer = (
    await firestore.collection(contentCollections.pointers).doc(scenario.contentId).get()
  ).data();
  if (pointer?.currentPublishedRevisionId !== scenario.publishedRevisionId)
    problems.push('pointer does not show the seeded revision');
  if (pointer?.visibility !== 'visible') problems.push('Scenario is not visible');
  const revision = await new FirestoreContentRepository(firestore).transact((tx) =>
    tx.publishedRevision(scenario.publishedRevisionId),
  );
  const ref = (
    revision?.body as { scenario?: { ref?: { scenarioRevisionId?: string } } } | undefined
  )?.scenario?.ref;
  if (ref?.scenarioRevisionId !== scenario.scenarioRevisionId)
    problems.push('published body is not pinned to the seeded Planning revision');
  if (JSON.stringify(revision).includes('PRIVATE')) problems.push('private data in the revision');
  const catalog = createEmulatorCatalogComposition(firestore);
  const active = await catalog.sets.ensureActive();
  await catalog.projector.deliverFromContent(active.setId);
  const details = await catalog.query.details({ contentId: scenario.contentId });
  const expected = process.env.RECHARGE_TEST_SCENARIO_CATALOG === 'true' ? 'listed' : 'excluded';
  if (details.kind !== 'succeeded' && expected === 'listed')
    problems.push(`Catalog details refused: ${JSON.stringify(details)}`);
  if (details.kind === 'succeeded' && details.state !== expected)
    problems.push(`Catalog state is ${details.state}, expected ${expected}`);
  return problems;
}
