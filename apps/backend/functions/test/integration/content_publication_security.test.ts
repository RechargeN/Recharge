import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';

import type { PublisherEligibilityV1 } from '../../src/contracts/identity_v1.js';
import { ContentPublicationService } from '../../src/modules/content/application/content_publication_service.js';
import type {
  ContentActor,
  PublisherEligibilityPort,
  PublisherEligibilityRequest,
} from '../../src/modules/content/application/ports/publisher_eligibility_port.js';
import { InMemoryContentRepository } from '../../src/modules/content/infrastructure/in_memory_content_repository.js';
import {
  createLocalIdentityPublisherAuthority,
  type IdentityPublisherAuthority,
} from '../../src/modules/identity_publisher/application/identity_publisher_authority.js';
import type { InMemoryIdentityAuthorityRepository } from '../../src/modules/identity_publisher/infrastructure/in_memory_identity_authority_repository.js';
import { IdentityFailure } from '../../src/modules/identity_publisher/domain/failures.js';
import { parseEntityId, type EntityId } from '../../src/shared/ids.js';
import { FakeClock } from '../support/fake_clock.js';

const id = (suffix: string): EntityId => parseEntityId(`018FQ2Z8Q9N4M7K2T6V3W1X5${suffix}`);
const u1 = id('YA');
const u2 = id('YB');
const session1 = id('YC');
const session2 = id('YD');
const session2b = id('YN');
const page1 = id('YE');
const pageEE = id('YF');
const membership1 = id('YG');
const membership2 = id('YH');
const verification1 = id('YJ');
const verification2 = id('YK');
const evidence = id('YM');

/** Server-current eligibility built on the real BCK-06 local authority. */
class IdentityBackedEligibility implements PublisherEligibilityPort {
  constructor(
    private readonly authority: IdentityPublisherAuthority,
    private readonly identity: InMemoryIdentityAuthorityRepository,
  ) {}

  async evaluate(request: PublisherEligibilityRequest): Promise<PublisherEligibilityV1> {
    const denied = (reason: PublisherEligibilityV1['reason']): PublisherEligibilityV1 => ({
      schemaVersion: 1,
      publisherRef: request.publisherRef,
      eligible: false,
      reason,
      authorityRevision: 0,
      evaluatedAtUtc: request.nowUtc as PublisherEligibilityV1['evaluatedAtUtc'],
    });
    if (request.publisherRef.type === 'page') {
      const page = await this.identity.transact((tx) => tx.page(request.publisherRef.id));
      // A Page belongs to exactly one market; cross-market use is denied.
      if (page !== null && page.marketId !== request.marketId)
        return denied('publisher_not_accessible');
    }
    let snapshot;
    try {
      snapshot = await this.authority.access.create({
        userId: request.actor.userId,
        sessionId: request.actor.sessionId,
        ...(request.publisherRef.type === 'page' ? { pageId: request.publisherRef.id } : {}),
        capabilityPolicyRevision: 1,
        evaluatedAtUtc: request.nowUtc,
        expiresAtUtc: new Date(Date.parse(request.nowUtc) + 5 * 60 * 1000).toISOString(),
      });
    } catch (error) {
      if (error instanceof IdentityFailure)
        return denied(
          error.code === 'membership_inactive' ? 'membership_inactive' : 'account_inactive',
        );
      throw error;
    }
    return this.authority.publishers.evaluate({
      snapshot,
      requestedPublisher: request.publisherRef,
      requiredCapability: request.requiredCapability,
      nowUtc: request.nowUtc,
    });
  }
}

const placeBody = {
  title: 'Vermanes garden greenhouse',
  placeKind: 'managedVenue',
  relationshipToPlace: 'owner',
  shortDescription: 'Historic glass greenhouse in the city centre',
  contentLocale: 'en',
  categoryId: 'art_culture_museums',
  subcategoryId: 'museum',
  location: {
    marketCityId: 'riga',
    countryCode: 'LV',
    city: 'Riga',
    formattedAddress: 'Elizabetes iela 1, Riga',
    point: { latitude: 56.9496, longitude: 24.1052 },
    timezoneId: 'Europe/Riga',
    accuracy: 'rooftop',
    pinConfirmed: true,
  },
  hours: {
    mode: 'regular',
    weeklyPeriods: [
      { id: 'period-1', dayOfWeek: 1, openMinute: 600, closeMinute: 1140, closesNextDay: false },
    ],
    seasons: [],
    exceptions: [],
  },
  operationalStatus: { status: 'operating' },
  pricing: { entryType: 'paid', entryPriceFrom: 700, currencyCode: 'EUR' },
  media: { coverImage: { mediaId: 'media-cover' }, gallery: [] },
  provenance: {
    sourceType: 'ownerSubmission',
    submittedByUserId: u1,
    relationshipClaim: 'owner',
    createdAtUtc: '2026-09-29T09:00:00.000Z',
    lastConfirmedAtUtc: '2026-09-29T09:00:00.000Z',
  },
};

const referenceLookups = {
  supportsLocale: (locale: string) => ['en', 'ru', 'lv'].includes(locale),
  subcategoryApplies: () => true,
  requiredCriteria: () => [] as readonly string[],
  pointInServiceArea: (latitude: number, longitude: number) =>
    latitude > 56 && latitude < 58 && longitude > 23 && longitude < 25.5,
};
const marketContext = { currencyCode: 'EUR', timezoneId: 'Europe/Riga' } as const;

async function bootstrap() {
  const { authority, repository: identity } = createLocalIdentityPublisherAuthority({
    reviewerIds: new Set(['reviewer']),
    pageCreationEnabled: true,
    maximumOwnedPages: 3,
  });
  for (const [index, userId] of [u1, u2].entries()) {
    await authority.accounts.ensureAccount({
      proof: {
        provider: 'google',
        providerTenant: 'consumer',
        proof: `local-test:google:content-${index}`,
      },
      proposedUserId: userId,
      proposedIdentityId: id(index === 0 ? 'ZA' : 'ZB'),
      nowUtc: '2026-09-29T09:58:00.000Z',
      accountCreationEnabled: true,
    });
  }
  await authority.creatorVerification.submit({
    userId: u1,
    verificationId: verification1,
    evidenceRefIds: [evidence],
    nowUtc: '2026-09-29T09:59:10.000Z',
  });
  await authority.creatorVerification.decide({
    reviewerId: 'reviewer',
    userId: u1,
    status: 'verified',
    nowUtc: '2026-09-29T09:59:20.000Z',
  });
  await authority.pages.create({
    userId: u1,
    pageId: page1,
    membershipId: membership1,
    marketId: 'LV',
    nowUtc: '2026-09-29T09:59:30.000Z',
  });
  await authority.pages.create({
    userId: u1,
    pageId: pageEE,
    membershipId: membership2,
    marketId: 'EE',
    nowUtc: '2026-09-29T09:59:31.000Z',
  });
  for (const pageId of [page1, pageEE])
    await authority.pages.decidePage({
      reviewerId: 'reviewer',
      pageId,
      decision: 'verified',
      nowUtc: '2026-09-29T09:59:40.000Z',
    });

  for (const [userId, sessionId, installationId] of [
    [u1, session1, 'install-1'],
    [u2, session2, 'install-2'],
  ] as const)
    await authority.sessions.issue({
      userId,
      sessionId,
      issuedAtUtc: '2026-09-29T09:59:45.000Z',
      firebaseUid: userId,
      installationId,
      snapshotExpiresAtUtc: '2026-09-29T10:04:00.000Z',
    });
  let counter = 5000;
  const repository = new InMemoryContentRepository();
  const service = new ContentPublicationService({
    repository,
    eligibility: new IdentityBackedEligibility(authority, identity),
    referenceData: {
      resolve: () =>
        Promise.resolve({
          ok: true,
          revisions: {
            marketConfigRevisionId: 'mc-1',
            taxonomyRevisionId: 'tx-1',
            localizationRevisionId: 'loc-1',
          },
          market: marketContext,
          lookups: referenceLookups,
        } as const),
    },
    moderation: {
      profileFor: () =>
        Promise.resolve({
          available: true,
          profileId: 'place.default',
          requiresPrePublicationModeration: false,
          policyRevision: 'pol-1',
          policyDecisionId: 'pd-1',
        } as const),
    },
    media: { check: () => Promise.resolve({ ready: true, mediaRevision: 'media-1' } as const) },
    clock: new FakeClock(new Date('2026-09-29T10:00:00.000Z')),
    ids: {
      newId: () => {
        counter += 1;
        return parseEntityId(`01HZZZZZZZZZZZZZZZZZZZ${String(counter).padStart(4, '0')}`);
      },
    },
    enabledTypes: new Set(['place'] as const),
  });
  return { authority, service, repository };
}

const actor1: ContentActor = { userId: u1, sessionId: session1 };
const actor2: ContentActor = { userId: u2, sessionId: session2 };
let keyCounter = 0;
const key = (label: string) => `${label}-${String((keyCounter += 1)).padStart(6, '0')}`;

const create = (publisherRef: { type: 'user' | 'page'; id: string }, marketId = 'LV') => ({
  schemaVersion: 1,
  commandType: 'createDraft',
  idempotencyKey: key('create'),
  payload: { typeId: 'place', publisherRef, marketId, body: placeBody },
});
const update = (draftId: string, expectedRevision: number) => ({
  schemaVersion: 1,
  commandType: 'updateDraft',
  idempotencyKey: key('update'),
  payload: { draftId, expectedRevision, body: { ...placeBody, title: 'Changed' } },
});
const submit = (draftId: string, expectedDraftRevision: number) => ({
  schemaVersion: 1,
  commandType: 'submitForPublication',
  idempotencyKey: key('submit'),
  payload: { draftId, expectedDraftRevision },
});
const publish = (submissionId: string, expectedPointerRevision: number) => ({
  schemaVersion: 1,
  commandType: 'publishApprovedRevision',
  idempotencyKey: key('publish'),
  payload: { submissionId, expectedPointerRevision },
});

async function ok<T>(
  promise: Promise<{ kind: string; data?: unknown; code?: string }>,
): Promise<T> {
  const result = await promise;
  assert.equal(result.kind, 'succeeded', `unexpected ${result.kind}:${String(result.code)}`);
  return result.data as T;
}
const denial = (code: string) => ({ kind: 'rejected', code });

void test('a verified Creator publishes personally through real server-current eligibility', async () => {
  const { service, repository } = await bootstrap();
  const draft = await ok<{ draftId: string }>(
    service.execute(actor1, create({ type: 'user', id: u1 })),
  );
  const submission = await ok<{ submissionId: string }>(
    service.execute(actor1, submit(draft.draftId, 1)),
  );
  await ok(service.execute(actor1, publish(submission.submissionId, 0)));
  assert.equal(repository.snapshot().revisions.length, 1);
});

void test('a User without Creator verification cannot create, and nothing is written', async () => {
  const { service, repository } = await bootstrap();
  assert.deepEqual(
    await service.execute(actor2, create({ type: 'user', id: u2 })),
    denial('creator_verification_required'),
  );
  assert.equal(repository.snapshot().drafts.length, 0);
});

void test("another verified Creator cannot read, edit, submit or publish someone else's content", async () => {
  const { authority, service, repository } = await bootstrap();
  await authority.creatorVerification.submit({
    userId: u2,
    verificationId: verification2,
    evidenceRefIds: [evidence],
    nowUtc: '2026-09-29T09:59:11.000Z',
  });
  await authority.creatorVerification.decide({
    reviewerId: 'reviewer',
    userId: u2,
    status: 'verified',
    nowUtc: '2026-09-29T09:59:21.000Z',
  });
  // Verification bumps authority; a fresh Session carries the new revision.
  await authority.sessions.issue({
    userId: u2,
    sessionId: session2b,
    issuedAtUtc: '2026-09-29T09:59:46.000Z',
    firebaseUid: u2,
    installationId: 'install-2b',
    snapshotExpiresAtUtc: '2026-09-29T10:04:00.000Z',
  });
  const verifiedActor2: ContentActor = { userId: u2, sessionId: session2b };
  const draft = await ok<{ draftId: string; contentId: string }>(
    service.execute(actor1, create({ type: 'user', id: u1 })),
  );
  const submission = await ok<{ submissionId: string }>(
    service.execute(actor1, submit(draft.draftId, 1)),
  );
  // user2 is a real verified Creator but not the owner of user1's publisher.
  assert.deepEqual(
    await service.execute(verifiedActor2, update(draft.draftId, 1)),
    denial('publisher_not_eligible'),
  );
  assert.deepEqual(
    await service.execute(verifiedActor2, submit(draft.draftId, 1)),
    denial('publisher_not_eligible'),
  );
  assert.deepEqual(
    await service.execute(verifiedActor2, publish(submission.submissionId, 0)),
    denial('publisher_not_eligible'),
  );
  assert.deepEqual(
    await service.query(verifiedActor2, {
      schemaVersion: 1,
      queryType: 'getDraft',
      payload: { draftId: draft.draftId },
    }),
    denial('publisher_not_eligible'),
  );
  assert.deepEqual(
    await service.execute(verifiedActor2, create({ type: 'user', id: u1 })),
    denial('publisher_not_eligible'),
  );
  assert.equal(repository.snapshot().revisions.length, 0);
});

void test('Page publishing requires an active membership of that exact Page', async () => {
  const { service, repository } = await bootstrap();
  const draft = await ok<{ draftId: string }>(
    service.execute(actor1, create({ type: 'page', id: page1 })),
  );
  assert.equal(repository.snapshot().drafts.length, 1);
  // user2 has no membership on the Page.
  assert.deepEqual(
    await service.execute(actor2, update(draft.draftId, 1)),
    denial('membership_inactive'),
  );
  assert.deepEqual(
    await service.execute(actor2, create({ type: 'page', id: page1 })),
    denial('membership_inactive'),
  );
  // The owner can also publish personally, but a page id is not a user id.
  assert.deepEqual(
    await service.execute(actor1, create({ type: 'user', id: page1 })),
    denial('publisher_not_eligible'),
  );
});

void test('cross-market use of a Page is denied', async () => {
  const { service, repository } = await bootstrap();
  assert.deepEqual(
    await service.execute(actor1, create({ type: 'page', id: pageEE }, 'LV')),
    denial('publisher_not_eligible'),
  );
  assert.equal(repository.snapshot().drafts.length, 0);
});

void test('revoked Creator verification blocks publish of an already approved submission', async () => {
  const { authority, service, repository } = await bootstrap();
  const draft = await ok<{ draftId: string }>(
    service.execute(actor1, create({ type: 'user', id: u1 })),
  );
  const submission = await ok<{ submissionId: string }>(
    service.execute(actor1, submit(draft.draftId, 1)),
  );
  await authority.creatorVerification.decide({
    reviewerId: 'reviewer',
    userId: u1,
    status: 'revoked',
    nowUtc: '2026-09-29T09:59:50.000Z',
  });
  // Revocation bumps the account's authority revision, so the old Session is
  // fenced out before the Creator check is even reached: fail closed.
  assert.deepEqual(
    await service.execute(actor1, publish(submission.submissionId, 0)),
    denial('publisher_not_eligible'),
  );
  const snapshot = repository.snapshot();
  assert.equal(snapshot.revisions.length, 0);
  assert.equal(snapshot.pointers.length, 0);
  assert.equal(snapshot.effects.length, 0);
});

void test('a suspended Page can no longer publish', async () => {
  const { authority, service, repository } = await bootstrap();
  const draft = await ok<{ draftId: string }>(
    service.execute(actor1, create({ type: 'page', id: page1 })),
  );
  const submission = await ok<{ submissionId: string }>(
    service.execute(actor1, submit(draft.draftId, 1)),
  );
  await authority.pages.decidePage({
    reviewerId: 'reviewer',
    pageId: page1,
    decision: 'suspended',
    nowUtc: '2026-09-29T09:59:50.000Z',
  });
  assert.deepEqual(
    await service.execute(actor1, publish(submission.submissionId, 0)),
    denial('publisher_not_eligible'),
  );
  assert.equal(repository.snapshot().revisions.length, 0);
});

void test('a revoked Session loses Content authority immediately', async () => {
  const { authority, service } = await bootstrap();
  const draft = await ok<{ draftId: string }>(
    service.execute(actor1, create({ type: 'user', id: u1 })),
  );
  await authority.sessions.revoke({
    actorUserId: u1,
    sessionId: session1,
    nowUtc: '2026-09-29T09:59:55.000Z',
  });
  assert.deepEqual(
    await service.execute(actor1, update(draft.draftId, 1)),
    denial('publisher_not_eligible'),
  );
});

function sourceFiles(directory: string): string[] {
  return readdirSync(directory).flatMap((entry) => {
    const full = path.join(directory, entry);
    return statSync(full).isDirectory() ? sourceFiles(full) : full.endsWith('.ts') ? [full] : [];
  });
}

void test('Content stays framework-neutral: no Firebase, transport, Booking or export wiring', () => {
  const root = path.resolve(process.cwd(), 'src');
  const forbidden = [
    /from ['"](firebase|firebase-admin|firebase-functions|@google-cloud|express)/u,
    /from ['"][./]+\/(booking|notifications|platform)\//u,
    /\bonCall\b|\bonRequest\b|\bonSchedule\b|getFirestore|initializeApp/u,
  ];
  const files = sourceFiles(path.join(root, 'modules', 'content'));
  assert.ok(files.length >= 14);
  for (const file of files) {
    const text = readFileSync(file, 'utf8');
    for (const pattern of forbidden) assert.doesNotMatch(text, pattern, path.relative(root, file));
  }
  // No callable/export registry, Rules or index change was introduced.
  assert.doesNotMatch(readFileSync(path.join(root, 'index.ts'), 'utf8'), /content/iu);
});
