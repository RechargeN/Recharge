import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';

import type { PublisherEligibilityV1 } from '../../src/contracts/identity_v1.js';
import { ContentPublicationService } from '../../src/modules/content/application/content_publication_service.js';
import type {
  ContentActor,
  DelegatedEligibilityRequest,
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

  /**
   * Stand-in for the BCK-06 delegated check: no Session, but the Publisher
   * itself must be an active, verified Creator or a verified, active Page in
   * the right market whose owner is still eligible.
   */
  async evaluateDelegated(request: DelegatedEligibilityRequest): Promise<PublisherEligibilityV1> {
    const result = (
      eligible: boolean,
      reason: PublisherEligibilityV1['reason'],
    ): PublisherEligibilityV1 => ({
      schemaVersion: 1,
      publisherRef: request.publisherRef,
      eligible,
      reason,
      authorityRevision: 1,
      evaluatedAtUtc: request.nowUtc as PublisherEligibilityV1['evaluatedAtUtc'],
    });
    return this.identity.transact(async (tx) => {
      let ownerId: string = request.publisherRef.id;
      if (request.publisherRef.type === 'page') {
        const page = await tx.page(request.publisherRef.id);
        if (page === null) return result(false, 'publisher_not_accessible');
        if (page.status !== 'active' || page.verificationStatus !== 'verified')
          return result(false, 'publisher_not_accessible');
        if (page.marketId !== request.marketId) return result(false, 'publisher_not_accessible');
        ownerId = page.ownerUserId;
      }
      const account = await tx.account(ownerId);
      if (account?.status !== 'active') return result(false, 'account_inactive');
      const verification = await tx.verificationForUser(ownerId);
      if (verification?.status !== 'verified' || !account.systemRoles.includes('Creator'))
        return result(false, 'creator_verification_required');
      return result(true, 'eligible');
    });
  }

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
      verifyDisposition: () => Promise.resolve({ verified: false } as const),
      profileFor: () =>
        Promise.resolve({
          available: true,
          profileId: 'place.default',
          requiresPrePublicationModeration: false,
          policyRevision: 'pol-1',
          policyDecisionId: 'pd-1',
        } as const),
    },
    media: {
      check: () =>
        Promise.resolve({
          ready: true,
          mediaRevision: 'media-1',
          attachments: [],
          confirmations: [],
        } as const),
    },
    clock: new FakeClock(new Date('2026-09-29T10:00:00.000Z')),
    ids: {
      newId: () => {
        counter += 1;
        return parseEntityId(`01HZZZZZZZZZZZZZZZZZZZ${String(counter).padStart(4, '0')}`);
      },
    },
    enabledTypes: new Set(['place'] as const),
    delegatedModules: new Map([
      [
        'event-ingestion',
        { operations: new Set(['syncSource']), typeIds: new Set<'place'>(['place']) },
      ],
    ]),
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

// ---------------------------------------------------------------------------
// 2.3 lifecycle authority: taking content down or rolling back re-checks the
// current Publisher authority, and a client can never issue moderation.
// ---------------------------------------------------------------------------

const withdraw = (contentId: string, expectedPointerRevision: number) => ({
  schemaVersion: 1,
  commandType: 'withdrawPublication',
  idempotencyKey: key('withdraw'),
  payload: { contentId, expectedPointerRevision, mode: 'withdraw' },
});
const rollback = (
  contentId: string,
  publishedRevisionId: string,
  expectedPointerRevision: number,
) => ({
  schemaVersion: 1,
  commandType: 'activatePublishedRevision',
  idempotencyKey: key('activate'),
  payload: { contentId, publishedRevisionId, expectedPointerRevision },
});

async function publishedPersonally(context: Awaited<ReturnType<typeof bootstrap>>) {
  const draft = await ok<{ draftId: string; contentId: string }>(
    context.service.execute(actor1, create({ type: 'user', id: u1 })),
  );
  const submission = await ok<{ submissionId: string }>(
    context.service.execute(actor1, submit(draft.draftId, 1)),
  );
  const revision = await ok<{ publishedRevisionId: string }>(
    context.service.execute(actor1, publish(submission.submissionId, 0)),
  );
  return { draft, revision };
}

void test("another verified Creator cannot withdraw or roll back someone else's publication", async () => {
  const context = await bootstrap();
  const { authority, service, repository } = context;
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
  await authority.sessions.issue({
    userId: u2,
    sessionId: session2b,
    issuedAtUtc: '2026-09-29T09:59:46.000Z',
    firebaseUid: u2,
    installationId: 'install-2b',
    snapshotExpiresAtUtc: '2026-09-29T10:04:00.000Z',
  });
  const stranger: ContentActor = { userId: u2, sessionId: session2b };
  const { draft, revision } = await publishedPersonally(context);
  assert.deepEqual(
    await service.execute(stranger, withdraw(draft.contentId, 1)),
    denial('publisher_not_eligible'),
  );
  assert.deepEqual(
    await service.execute(stranger, rollback(draft.contentId, revision.publishedRevisionId, 1)),
    denial('publisher_not_eligible'),
  );
  const pointer = repository.snapshot().pointers[0];
  assert.equal(pointer?.revision, 1);
  assert.equal(pointer?.visibility, 'visible');
});

void test('withdrawing a Page publication needs an active membership of that Page', async () => {
  const context = await bootstrap();
  const { service, repository } = context;
  const draft = await ok<{ draftId: string; contentId: string }>(
    service.execute(actor1, create({ type: 'page', id: page1 })),
  );
  const submission = await ok<{ submissionId: string }>(
    service.execute(actor1, submit(draft.draftId, 1)),
  );
  await ok(service.execute(actor1, publish(submission.submissionId, 0)));
  assert.deepEqual(
    await service.execute(actor2, withdraw(draft.contentId, 1)),
    denial('membership_inactive'),
  );
  assert.equal(repository.snapshot().pointers[0]?.visibility, 'visible');
  await ok(service.execute(actor1, withdraw(draft.contentId, 1)));
  assert.equal(repository.snapshot().pointers[0]?.visibility, 'withdrawn');
});

void test('lost Creator authority blocks owner takedown and rollback; moderation is the takedown path', async () => {
  const context = await bootstrap();
  const { authority, service, repository } = context;
  const { draft, revision } = await publishedPersonally(context);
  await authority.creatorVerification.decide({
    reviewerId: 'reviewer',
    userId: u1,
    status: 'revoked',
    nowUtc: '2026-09-29T09:59:50.000Z',
  });
  assert.deepEqual(
    await service.execute(actor1, withdraw(draft.contentId, 1)),
    denial('publisher_not_eligible'),
  );
  assert.deepEqual(
    await service.execute(actor1, rollback(draft.contentId, revision.publishedRevisionId, 1)),
    denial('publisher_not_eligible'),
  );
  assert.equal(repository.snapshot().pointers[0]?.revision, 1);
});

void test('a signed-in actor cannot issue a moderation disposition even with a well-formed one', async () => {
  const context = await bootstrap();
  const { service, repository } = context;
  const { draft, revision } = await publishedPersonally(context);
  const forged = {
    schemaVersion: 1,
    commandType: 'applyModerationDisposition',
    idempotencyKey: key('forged'),
    payload: {
      instructionId: 'ins-forged',
      decisionId: 'dec-forged',
      policyRevision: 'pol-1',
      disposition: 'restore',
      restoresDecisionId: 'dec-anything',
      target: { contentId: draft.contentId, publishedRevisionId: revision.publishedRevisionId },
      reasonCategory: 'appeal_upheld',
      effectiveAtUtc: '2026-09-29T09:00:00.000Z',
      attestation: 'valid-but-forged-by-client',
    },
  };
  assert.deepEqual(await service.execute(actor1, forged), denial('capability_denied'));
  // The system path independently refuses what its trusted issuer did not sign.
  assert.deepEqual(await service.applyModerationDisposition(forged), denial('capability_denied'));
  assert.equal(repository.snapshot().pointers[0]?.revision, 1);
});

// ---------------------------------------------------------------------------
// 2.4 acceptance: delegated import authority and staff impersonation
// ---------------------------------------------------------------------------

const importer = { moduleId: 'event-ingestion', operation: 'syncSource' };
const importOrigin = {
  kind: 'delegatedImport',
  delegatedActorRef: 'module:event-ingestion/syncSource',
  externalBindingRef: 'src-1|uid-42|',
  sourceId: 'src-1',
  sourceRevision: '3',
  acquiredAtUtc: '2026-09-29T09:00:00.000Z',
  correctionRemovalPolicyRef: 'removal-policy-1',
};
const importCreate = (
  publisherRef: { type: 'user' | 'page'; id: string },
  marketId = 'LV',
  externalBindingRef = 'src-1|uid-42|',
) => ({
  schemaVersion: 1,
  commandType: 'createDraft',
  idempotencyKey: key('import'),
  payload: {
    typeId: 'place',
    publisherRef,
    marketId,
    body: placeBody,
    origin: { ...importOrigin, externalBindingRef },
  },
});

async function verifiedStranger(
  context: Awaited<ReturnType<typeof bootstrap>>,
): Promise<ContentActor> {
  const { authority } = context;
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
  await authority.sessions.issue({
    userId: u2,
    sessionId: session2b,
    issuedAtUtc: '2026-09-29T09:59:46.000Z',
    firebaseUid: u2,
    installationId: 'install-2b',
    snapshotExpiresAtUtc: '2026-09-29T10:04:00.000Z',
  });
  return { userId: u2, sessionId: session2b };
}

void test('staff review cannot submit or publish while impersonating the owning Page', async () => {
  const context = await bootstrap();
  const { service, repository } = context;
  const staff = await verifiedStranger(context);
  const draft = await ok<{ draftId: string; contentId: string }>(
    service.execute(actor1, create({ type: 'page', id: page1 })),
  );
  const submission = await ok<{ submissionId: string }>(
    service.execute(actor1, submit(draft.draftId, 1)),
  );
  // A verified Creator with staff-like reach but no membership of the Page.
  assert.deepEqual(
    await service.execute(staff, submit(draft.draftId, 1)),
    denial('membership_inactive'),
  );
  assert.deepEqual(
    await service.execute(staff, publish(submission.submissionId, 0)),
    denial('membership_inactive'),
  );
  assert.deepEqual(
    await service.execute(staff, create({ type: 'page', id: page1 })),
    denial('membership_inactive'),
  );
  assert.equal(repository.snapshot().revisions.length, 0);
});

void test('a delegated import for a Page still needs the Page, its owner and its market to be eligible', async () => {
  const context = await bootstrap();
  const { authority, service, repository } = context;
  const accepted = await service.executeDelegated(
    importer,
    importCreate({ type: 'page', id: page1 }),
  );
  assert.equal(accepted.kind, 'succeeded');
  // No Session is involved, yet a cross-market Page is refused.
  assert.deepEqual(
    await service.executeDelegated(
      importer,
      importCreate({ type: 'page', id: pageEE }, 'LV', 'src-1|uid-2|'),
    ),
    denial('publisher_not_eligible'),
  );
  // An owner that never completed Creator verification cannot be imported for.
  assert.deepEqual(
    await service.executeDelegated(
      importer,
      importCreate({ type: 'user', id: u2 }, 'LV', 'src-1|uid-3|'),
    ),
    denial('creator_verification_required'),
  );
  // Unknown Pages do not exist for the importer.
  assert.deepEqual(
    await service.executeDelegated(
      importer,
      importCreate({ type: 'page', id: id('ZZ') }, 'LV', 'src-1|uid-4|'),
    ),
    denial('publisher_not_eligible'),
  );
  // Losing the Page's authority stops later imports immediately.
  await authority.pages.decidePage({
    reviewerId: 'reviewer',
    pageId: page1,
    decision: 'suspended',
    nowUtc: '2026-09-29T09:59:50.000Z',
  });
  assert.deepEqual(
    await service.executeDelegated(
      importer,
      importCreate({ type: 'page', id: page1 }, 'LV', 'src-1|uid-5|'),
    ),
    denial('publisher_not_eligible'),
  );
  assert.equal(repository.snapshot().drafts.length, 1);
});

void test('revoked Creator verification of the Page owner blocks a delegated submit', async () => {
  const context = await bootstrap();
  const { authority, service } = context;
  const created = await service.executeDelegated(
    importer,
    importCreate({ type: 'page', id: page1 }),
  );
  assert.equal(created.kind, 'succeeded');
  const draftId = (created as { data: { draftId: string } }).data.draftId;
  await authority.creatorVerification.decide({
    reviewerId: 'reviewer',
    userId: u1,
    status: 'revoked',
    nowUtc: '2026-09-29T09:59:50.000Z',
  });
  assert.deepEqual(
    await service.executeDelegated(importer, {
      schemaVersion: 1,
      commandType: 'submitForPublication',
      idempotencyKey: key('import-submit'),
      payload: { draftId, expectedDraftRevision: 1, changeClass: 'new' },
    }),
    denial('creator_verification_required'),
  );
});

/** True when `text` (source of `file`) imports something inside the Content module. */
function importsContentModule(file: string, text: string, contentDir: string): boolean {
  return [...text.matchAll(/from\s+['"]([^'"]+)['"]/gu)].some((match) => {
    const specifier = match[1] ?? '';
    return (
      specifier.startsWith('.') &&
      path.resolve(path.dirname(file), specifier).startsWith(contentDir)
    );
  });
}

void test('delegated import never reaches Content storage except through the Content service', () => {
  const root = path.resolve(process.cwd(), 'src');
  const contentDir = path.join(root, 'modules', 'content');
  // Positive control: the detector really flags a sibling-module import.
  const sibling = path.join(root, 'modules', 'other', 'application', 'x.ts');
  assert.equal(
    importsContentModule(
      sibling,
      "import x from '../../content/domain/repositories.js';",
      contentDir,
    ),
    true,
  );
  assert.equal(
    importsContentModule(sibling, "import x from '../../reference_data/domain/y.js';", contentDir),
    false,
  );
  const offenders = sourceFiles(root)
    .filter((file) => !file.startsWith(contentDir + path.sep))
    // Shared wire contracts (types and schemas only) are the intended seam.
    .filter((file) => !file.includes(`${path.sep}contracts${path.sep}`))
    .filter((file) => importsContentModule(file, readFileSync(file, 'utf8'), contentDir));
  // C1–E2: exact reviewed consumers; unknown modules still cannot reach Content.
  // Persistence symbols are additionally checked by verify-content-persistence-layout.
  const approved = [
    'content_effects_entry.ts',
    'content_entry.ts',
    // D2: the composition root of Content's reaction to late Media restriction.
    'media_effects_entry.ts',
    'modules/catalog/domain/catalog_item.ts',
    'modules/catalog/infrastructure/content_catalog_source.ts',
    'modules/catalog/infrastructure/emulator_catalog_composition.ts',
    'modules/catalog/infrastructure/firestore_catalog_repository.ts',
    'modules/media/infrastructure/emulator_media_composition.ts',
    'modules/media/infrastructure/firestore_media_repository.ts',
    'modules/moderation/infrastructure/content_moderation_adapter.ts',
    'modules/moderation/infrastructure/emulator_moderation_composition.ts',
    'modules/moderation/infrastructure/emulator_staff_authority.ts',
    'modules/moderation/infrastructure/firestore_moderation_repository.ts',
    'modules/moderation/infrastructure/moderation_decision_verifier.ts',
  ];
  assert.deepEqual(
    offenders.map((file) => path.relative(root, file).replaceAll('\\', '/')).sort(),
    approved.sort(),
  );
  assert.equal(approved.includes('modules/other/application/x.ts'), false);
  assert.equal(approved.includes('modules/catalog/domain/other.ts'), false);
  const symbols: Readonly<Record<string, readonly string[]>> = {
    'content_effects_entry.ts': ['createEmulatorEventBookingHandoff'],
    'content_entry.ts': [
      'ContentPublicationService',
      'ContentActor',
      'toContentWireResult',
      'ContentResultType',
      'createEmulatorContentService',
      'EmulatorSyntheticReferenceData',
      'FirestoreContentRepository',
      'IdentityPublisherEligibility',
      // D3.1 §2.1: the authoring list accepts only types with an available validator.
      'isContentTypeAvailable',
      'resolveContentType',
      // D3.2 §2.4: Emulator rules that refuse what the composition cannot resolve.
      'emulatorCompositionRules',
      // D3.3 §2 Q4: activation the Emulator composition does not offer.
      'emulatorActivationClosedTypes',
      // D3.4 §2.3: Collection membership asked from the Catalog-owned evaluator.
      'CatalogCollectionMembership',
    ],
    'media_effects_entry.ts': [
      'ContentMediaAvailability',
      'SweepReport',
      'ContentPublicationFeed',
      'FirestoreContentRepository',
    ],
    'modules/catalog/domain/catalog_item.ts': ['bookingRefsFor'],
    'modules/catalog/infrastructure/content_catalog_source.ts': [
      'ReferenceDataPort',
      'resolveContentType',
      'ContentPublicationFeed',
      // D9 (901bf0d): the source re-verifies the published body hash.
      'canonicalJson',
      'sha256Hex',
    ],
    'modules/catalog/infrastructure/emulator_catalog_composition.ts': [
      'ContentPublicationFeed',
      'FirestoreContentRepository',
      'EmulatorSyntheticReferenceData',
    ],
    'modules/catalog/infrastructure/firestore_catalog_repository.ts': [
      'assertContentEmulatorContext',
    ],
    'modules/media/infrastructure/emulator_media_composition.ts': [
      'ContentMediaScope',
      'FirestoreContentRepository',
      'IdentityPublisherEligibility',
    ],
    'modules/media/infrastructure/firestore_media_repository.ts': ['assertContentEmulatorContext'],
    'modules/moderation/infrastructure/content_moderation_adapter.ts': [
      'ContentPublicationService',
      'contentCollections',
      'FirestoreContentRepository',
    ],
    'modules/moderation/infrastructure/emulator_moderation_composition.ts': [
      'ContentPublicationService',
      'FirestoreContentRepository',
    ],
    'modules/moderation/infrastructure/emulator_staff_authority.ts': [
      'assertContentEmulatorContext',
    ],
    'modules/moderation/infrastructure/firestore_moderation_repository.ts': [
      'assertContentEmulatorContext',
    ],
    'modules/moderation/infrastructure/moderation_decision_verifier.ts': [
      'ModerationDispositionPort',
      'ModerationProfileResolution',
      'VerifiedDisposition',
    ],
  };
  const allowedSymbol = (relative: string, symbol: string) =>
    symbols[relative]?.includes(symbol) === true;
  for (const file of offenders) {
    const relative = path.relative(root, file).replaceAll('\\', '/');
    for (const match of readFileSync(file, 'utf8').matchAll(
      /import\s+(?:type\s+)?\{([^}]*)\}\s+from\s+['"]([^'"]+)['"]/gu,
    )) {
      if (!path.resolve(path.dirname(file), match[2]!).startsWith(contentDir + path.sep)) continue;
      for (const part of match[1]!.split(',')) {
        const symbol = part.replace(/\btype\b/u, '').trim();
        if (symbol.length > 0) assert.ok(allowedSymbol(relative, symbol), `${relative}: ${symbol}`);
      }
    }
  }
  assert.equal(allowedSymbol('modules/other/application/x.ts', 'ContentPublicationService'), false);
  assert.equal(
    allowedSymbol(
      'modules/catalog/infrastructure/firestore_catalog_repository.ts',
      'FirestoreContentRepository',
    ),
    false,
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
  // BCK07-PERSIST-01: only the Emulator-only Firestore adapter and its composition
  // may name the cloud SDK (types only); everything else stays SDK-free.
  const emulatorOnly = new Set([
    path.join('infrastructure', 'firestore_content_repository.ts'),
    path.join('infrastructure', 'emulator_content_composition.ts'),
    path.join('infrastructure', 'content_publication_feed.ts'),
    path.join('infrastructure', 'firestore_event_booking_handoff_repository.ts'),
  ]);
  for (const file of files) {
    const text = readFileSync(file, 'utf8');
    const relative = path.relative(path.join(root, 'modules', 'content'), file);
    // E2 handoff reads the exact Booking collections, never its lifecycle services.
    const inspected =
      relative === path.join('infrastructure', 'firestore_event_booking_handoff_repository.ts')
        ? text
            .replace(
              "import { eventBookingDeliveryCollections } from '../../../booking/event_projection_delivery.js';",
              '',
            )
            .replace("import { bookingCollections } from '../../../booking/transactions.js';", '')
        : text;
    for (const pattern of forbidden.slice(emulatorOnly.has(relative) ? 1 : 0))
      assert.doesNotMatch(inspected, pattern, path.relative(root, file));
  }
  const sdkImporters = files
    .filter((file) => /from ['"]firebase-admin/u.test(readFileSync(file, 'utf8')))
    .map((file) => path.relative(path.join(root, 'modules', 'content'), file))
    .sort();
  assert.deepEqual(sdkImporters, [...emulatorOnly].sort());
  const entry = readFileSync(path.join(root, 'index.ts'), 'utf8');
  assert.doesNotMatch(entry, /from ['"]\.\/modules\/content\//u);
  assert.deepEqual(
    [...entry.matchAll(/export const (\w+)\s*=/gu)]
      .map((match) => match[1]!)
      .filter((name) => /content/iu.test(name))
      .sort(),
    ['consumeContentEffectV1', 'contentCommandV1', 'contentQueryV1'],
  );
  // Negative control: neither a new SDK importer nor a new export is approved.
  assert.equal(emulatorOnly.has(path.join('domain', 'foreign.ts')), false);
  assert.match("import { getFirestore } from 'firebase-admin/firestore';", forbidden[0]!);
});

// ---------------------------------------------------------------------------
// BCK07-LOCAL-01 local acceptance traceability (BCK-07 §34.4 and AC-76 .. AC-97).
// Each requirement names the tests that are its evidence. The matrix fails if a
// named test disappears or is renamed, so acceptance cannot silently erode.
// ---------------------------------------------------------------------------

const testRoot = path.resolve(process.cwd(), 'test');
const files = {
  contract: 'contract/content_fixture_parity.test.ts',
  domain: 'unit/content/content_domain.test.ts',
  common: 'unit/content/type_rules_common.test.ts',
  unavailable: 'unit/content/type_rules_unavailable.test.ts',
  service: 'integration/content_publication_service.test.ts',
  security: 'integration/content_publication_security.test.ts',
  parity: 'integration/content_repository_parity.test.ts',
  scenarios: 'support/content_repository_scenarios.ts',
  guard: 'emulator/content_emulator_guard.test.ts',
  firestore: 'emulator/content_firestore_repository.test.ts',
  concurrency: 'emulator/content_concurrency.test.ts',
  recovery: 'emulator/content_recovery.test.ts',
  readiness: 'integration/media_content_readiness.test.ts',
  rules: 'emulator/content_rules_default_deny.test.ts',
} as const;

const acceptanceMatrix: ReadonlyArray<
  readonly [requirement: string, evidence: ReadonlyArray<readonly [keyof typeof files, string]>]
> = [
  [
    'schema/TypeScript parity and forward rejection',
    [['contract', 'content schemas accept canonical fixtures']],
  ],
  [
    'all ten registry entries, explicit and fail closed',
    [
      ['domain', 'registry has exactly the ten accepted types'],
      ['unavailable', 'is registered but unavailable'],
      ['service', 'all ten types are explicit'],
    ],
  ],
  [
    'unknown or newer type/schema rejection',
    [
      ['service', 'unauthenticated, newer schema and malformed commands'],
      ['service', 'a stored draft from a newer type schema major is never coerced'],
    ],
  ],
  [
    'lifecycle: submit, moderation disposition, publish',
    [
      ['service', 'Place flows draft -> submit -> publish'],
      ['service', 'a moderated submission cannot publish until BCK-22 approves'],
      ['service', 'request_revision returns the draft to its author'],
      ['service', 'reject closes only that submission'],
    ],
  ],
  [
    'lifecycle: withdraw, archive, hide (restrict) and restore',
    [
      ['service', 'owner withdraw and archive take content down'],
      ['service', 'restrict hides content publicly'],
      ['service', 'owner and moderation holds are independent'],
    ],
  ],
  [
    'idempotency conflict',
    [['service', 'semantic idempotency replays equal commands and rejects a changed payload']],
  ],
  ['stale revision', [['service', 'stale draft revisions are rejected']]],
  [
    'cross-user denial',
    [
      [
        'security',
        "another verified Creator cannot read, edit, submit or publish someone else's content",
      ],
    ],
  ],
  [
    'cross-page denial',
    [['security', 'Page publishing requires an active membership of that exact Page']],
  ],
  ['cross-market denial', [['security', 'cross-market use of a Page is denied']]],
  [
    'revoked PublisherRef authority',
    [
      ['security', 'revoked Creator verification blocks publish'],
      ['security', 'a suspended Page can no longer publish'],
      ['security', 'a revoked Session loses Content authority immediately'],
    ],
  ],
  [
    'immutable revision enforcement',
    [
      ['domain', 'published revision is immutable'],
      ['service', 'a second revision supersedes the first without touching immutable history'],
      ['service', 'the repository refuses to overwrite a published revision'],
    ],
  ],
  [
    'pointer contention',
    [['service', 'concurrent duplicate publishes create exactly one revision']],
  ],
  ['atomic rollback of a failed publish', [['service', 'a failed publish rolls back completely']]],
  [
    'compatible rollback',
    [
      ['service', 'compatible rollback re-selects an earlier immutable revision'],
      ['service', 'rollback fails closed when media, market or the type are no longer valid'],
    ],
  ],
  [
    'AC-92 delegated import uses only Content commands',
    [
      ['service', 'a delegated caller must be an approved module and operation for a granted type'],
      [
        'security',
        'delegated import never reaches Content storage except through the Content service',
      ],
    ],
  ],
  [
    'AC-93 ownerImport provenance is exact and not fabricated',
    [
      ['service', 'a delegated import creates a bound draft with exact ownerImport provenance'],
      [
        'service',
        'an imported draft is published by its Publisher and the revision freezes the provenance',
      ],
    ],
  ],
  [
    'AC-94 imported content passes the same validation, moderation and eligibility',
    [
      [
        'service',
        'an imported submission passes the same validation and moderation as manual content',
      ],
      [
        'security',
        'a delegated import for a Page still needs the Page, its owner and its market to be eligible',
      ],
      ['security', 'revoked Creator verification of the Page owner blocks a delegated submit'],
    ],
  ],
  [
    'AC-95 staff cannot impersonate the owning Page',
    [
      ['security', 'staff review cannot submit or publish while impersonating the owning Page'],
      ['service', 'a signed-in user can never claim an import origin'],
    ],
  ],
  [
    'AC-96 non-session actor idempotency',
    [
      ['service', 'non-session actor idempotency is stable across retry and restart'],
      ['service', 'one external source record binds to at most one draft'],
    ],
  ],
  [
    'import binding lookup and change class',
    [
      ['service', 'a module only sees and touches drafts it bound itself'],
      ['service', 'lookup by binding also returns the publication and current revision'],
      ['service', 'the change class must match whether anything is already published'],
    ],
  ],
  [
    'AC-97 / AC-76 no endpoint, worker, Firebase import or cloud context',
    [
      ['security', 'Content stays framework-neutral'],
      ['common', 'issue collector is unique and bounded'],
    ],
  ],
  // BCK07-PERSIST-01 (Emulator evidence lives in the named Emulator tests).
  [
    'AC-101 Emulator-only enforced technically, including direct construction',
    [
      ['guard', 'the repository constructor accepts only the demo-recharge loopback Emulator'],
      ['guard', 'a missing or non-loopback endpoint is refused, with no cloud fallback'],
      ['guard', 'any project other than the exact demo project is refused'],
      ['guard', 'cloud credentials and endpoint overrides are refused'],
      ['guard', 'the composition needs its default-off flag'],
    ],
  ],
  [
    'AC-102 buffered transactions: overlay, retry with a fresh buffer, checks before writes, rollback',
    [
      ['scenarios', 'a read after a staged write sees it, for single documents and lists'],
      ['scenarios', 'two staged changes to one document leave the last one'],
      ['scenarios', 'a refused or failed transaction stores nothing at all'],
      ['firestore', 'a retried transaction runs the callback again with a new, empty buffer'],
      ['firestore', 'contending transactions leave one winner and roll the losers back completely'],
    ],
  ],
  [
    'AC-103 bounded history and document size, identical on both adapters',
    [
      ['scenarios', 'history and document size are bounded with a typed refusal'],
      ['parity', 'registerContentScenarios'],
      ['firestore', 'registerContentScenarios'],
    ],
  ],
  [
    'AC-104 recovery verifies, replays stored effects and never invents history',
    [
      ['recovery', 'intact stored records verify clean and stored effects replay in order'],
      ['recovery', 'a lost historical effect is reported as corruption and never invented'],
      ['recovery', 'a tampered revision body or a missing current revision is reported'],
    ],
  ],
  [
    'AC-105 every Content collection denies all clients; one writer; concurrency and uniqueness',
    [
      ['rules', 'unauthenticated clients can neither read nor write any Content collection'],
      [
        'rules',
        'authenticated clients, including a same-id user document, remain denied everywhere',
      ],
      ['rules', 'a document written by the server stays unreadable and unchangeable for clients'],
      [
        'concurrency',
        'concurrent imports of one external source record leave exactly one bound draft',
      ],
      ['security', 'Content stays framework-neutral'],
    ],
  ],
  [
    'AC-106 a replay never outlives the caller authority',
    [['service', 'a stored result is not a standing permission']],
  ],
  [
    'AC-107 no cross-module wait under a repository transaction',
    [['readiness', 'Content and Media never wait for each other while holding a transaction']],
  ],
  [
    'AC-108 effects are paged and verified without a silent cap; the client endpoint is verified',
    [
      ['scenarios', 'stored effects are read in stable pages, ties included'],
      [
        'scenarios',
        'integrity verification finds the current effect however long the effect history is',
      ],
      ['guard', 'the client itself must target the Emulator, whatever the environment claims'],
    ],
  ],
  [
    'AC-109 a completed command replays without a Media call and an unreachable Media is typed',
    [['service', 'a completed command replays without asking Media again']],
  ],
];

void test('local acceptance matrix: every requirement is backed by a named, existing test', () => {
  const sources = new Map<string, string>();
  for (const [name, relative] of Object.entries(files))
    sources.set(name, readFileSync(path.join(testRoot, relative), 'utf8'));
  const missing: string[] = [];
  for (const [requirement, evidence] of acceptanceMatrix) {
    if (evidence.length === 0) missing.push(`${requirement}: no evidence listed`);
    for (const [file, title] of evidence)
      if (!sources.get(file)?.includes(title))
        missing.push(`${requirement}: "${title}" not in ${file}`);
  }
  assert.deepEqual(missing, []);
  // The matrix itself stays complete: every named requirement group is present.
  assert.ok(acceptanceMatrix.length >= 30);
});
