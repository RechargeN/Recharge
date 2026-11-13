// D3.7 (T3) Content service behaviour for Find People on the in-memory
// repository: default-off flag, author-only private source, synthetic 18+ and
// BCK-06 consent gates, the server-built public projection and full C3 without
// a bypass on publish or activate. Firestore, callables and Catalog: see
// test/emulator/content_find_people_emulator_flow.test.ts.
import assert from 'node:assert/strict';
import test from 'node:test';

import { readContentJson } from '../../src/contracts/content_schema_registry.js';
import type { ContentBody, ContentTypeId } from '../../src/contracts/content_v1.js';
import type { PublisherEligibilityV1 } from '../../src/contracts/identity_v1.js';
import {
  ContentPublicationService,
  type ContentIdGenerator,
} from '../../src/modules/content/application/content_publication_service.js';
import type {
  FindPeopleConsentState,
  FindPeoplePrivacyPort,
} from '../../src/modules/content/application/ports/find_people_privacy_port.js';
import type { MediaReadinessPort } from '../../src/modules/content/application/ports/media_readiness_port.js';
import type { ModerationDispositionPort } from '../../src/modules/content/application/ports/moderation_disposition_port.js';
import type {
  ContentActor,
  PublisherEligibilityRequest,
} from '../../src/modules/content/application/ports/publisher_eligibility_port.js';
import { EmulatorSyntheticReferenceData } from '../../src/modules/content/infrastructure/emulator_reference_data.js';
import { InMemoryContentRepository } from '../../src/modules/content/infrastructure/in_memory_content_repository.js';
import { parseEntityId, type EntityId } from '../../src/shared/ids.js';
import { FakeClock } from '../support/fake_clock.js';

const crockford = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
function ulid(counter: number): EntityId {
  let rest = counter;
  let suffix = '';
  for (let index = 0; index < 8; index += 1) {
    suffix = crockford[rest % 32] + suffix;
    rest = Math.floor(rest / 32);
  }
  return parseEntityId(`01HZZZZZZZZZZZZZZZ${suffix}`);
}

class SequentialIds implements ContentIdGenerator {
  #next = 9000;
  newId(): EntityId {
    this.#next += 1;
    return ulid(this.#next);
  }
}

const userA = parseEntityId('11111111-1111-4111-8111-111111111111');
const userB = parseEntityId('22222222-2222-4222-8222-222222222222');
const pageP = parseEntityId('33333333-3333-4333-8333-333333333333');
const actorA: ContentActor = { userId: userA, sessionId: ulid(2) };
const actorB: ContentActor = { userId: userB, sessionId: ulid(3) };

class NoReview implements ModerationDispositionPort {
  verifyDisposition() {
    return Promise.resolve({ verified: false } as const);
  }
  profileFor() {
    return Promise.resolve({
      available: true,
      profileId: 'find_people.default',
      requiresPrePublicationModeration: false,
      policyRevision: 'pol-1',
      policyDecisionId: 'pd-1',
    } as const);
  }
}

class ReadyMedia implements MediaReadinessPort {
  check() {
    return Promise.resolve({
      ready: true,
      mediaRevision: 'media-0',
      attachments: [],
      confirmations: [],
    } as const);
  }
}

/** Synthetic owner answers; every call is recorded so tests can prove fail-closed paths. */
class FakePrivacy implements FindPeoplePrivacyPort {
  readonly adults = new Set<string>([userA, userB]);
  readonly consents = new Map<string, FindPeopleConsentState['state']>();
  publicGate = true;
  readonly reads: string[] = [];
  isAdult(input: { readonly userId: string }) {
    return Promise.resolve(this.adults.has(input.userId));
  }
  consent(input: { readonly contentId: string; readonly userId: string }) {
    const state = this.consents.get(`${input.contentId}:${input.userId}`) ?? 'missing';
    return Promise.resolve(
      (state === 'active'
        ? { state, consentRevision: 1, expiresAtUtc: '2027-06-01T00:00:00.000Z' }
        : { state }) as FindPeopleConsentState,
    );
  }
  publicReadAllowed(input: { readonly viewerUserId: string }) {
    this.reads.push(input.viewerUserId);
    return Promise.resolve(this.publicGate);
  }
}

let seq = 0;
const key = () => `fp-test-${++seq}`;
async function validBody(): Promise<ContentBody> {
  const fixture = (await readContentJson('fixtures/find_people_create_compat.json')) as {
    cases: { name: string; body: ContentBody }[];
  };
  return structuredClone(fixture.cases.find((item) => item.name === 'valid')!.body);
}

function world(options: { readonly privacy?: FindPeoplePrivacyPort | null } = {}) {
  const repository = new InMemoryContentRepository();
  const clock = new FakeClock(new Date('2026-10-19T10:00:00.000Z'));
  const privacy = new FakePrivacy();
  const service = (types: readonly ContentTypeId[] = ['find_people']) =>
    new ContentPublicationService({
      repository,
      eligibility: {
        evaluate: (r: PublisherEligibilityRequest) =>
          Promise.resolve({
            schemaVersion: 1,
            publisherRef: r.publisherRef,
            eligible: true,
            reason: 'eligible',
            authorityRevision: 1,
            evaluatedAtUtc: r.nowUtc as PublisherEligibilityV1['evaluatedAtUtc'],
          }),
        evaluateDelegated: (r) =>
          Promise.resolve({
            schemaVersion: 1,
            publisherRef: r.publisherRef,
            eligible: true,
            reason: 'eligible',
            authorityRevision: 1,
            evaluatedAtUtc: r.nowUtc as PublisherEligibilityV1['evaluatedAtUtc'],
          }),
      },
      referenceData: new EmulatorSyntheticReferenceData(),
      moderation: new NoReview(),
      media: new ReadyMedia(),
      clock,
      ids: new SequentialIds(),
      enabledTypes: new Set(types),
      // A module granted Find People must still be refused (§7).
      delegatedModules: new Map([
        [
          'importer',
          {
            operations: new Set(['createDraft']),
            typeIds: new Set<ContentTypeId>(['find_people']),
          },
        ],
      ]),
      ...(options.privacy === null ? {} : { findPeoplePrivacy: options.privacy ?? privacy }),
    });
  return { repository, clock, privacy, service };
}

type Result = { kind: string; code?: string; data?: unknown };
async function ok<T>(value: Promise<Result>): Promise<T> {
  const result = await value;
  assert.equal(result.kind, 'succeeded', JSON.stringify(result));
  return result.data as T;
}
async function refused(value: Promise<Result>, code: string): Promise<Result> {
  const result = await value;
  assert.equal(result.kind, 'rejected', JSON.stringify(result));
  assert.equal(result.code, code);
  return result;
}
const command = (commandType: string, payload: unknown, idempotencyKey = key()) => ({
  schemaVersion: 1,
  commandType,
  payload,
  idempotencyKey,
});
const createCommand = (
  publisher: { type: 'user' | 'page'; id: EntityId } = { type: 'user', id: userA },
) =>
  command('createDraft', {
    typeId: 'find_people',
    marketId: 'LV',
    publisherRef: publisher,
    body: {},
  });

async function prepared(
  service: ContentPublicationService,
  body: ContentBody,
  publisher?: { type: 'user' | 'page'; id: EntityId },
) {
  const draft = await ok<{ draftId: EntityId; contentId: EntityId; revision: number }>(
    service.execute(actorA, createCommand(publisher)),
  );
  const updated = await ok<{ revision: number }>(
    service.execute(
      actorA,
      command('updateDraft', { draftId: draft.draftId, expectedRevision: draft.revision, body }),
    ),
  );
  return { ...draft, revision: updated.revision };
}

void test('default off, no age authority or no port: refused before anything is stored', async () => {
  const w = world();
  await refused(w.service([]).execute(actorA, createCommand()), 'type_disabled');
  await refused(w.service(['session']).execute(actorA, createCommand()), 'type_disabled');
  w.privacy.adults.delete(userA);
  await refused(w.service().execute(actorA, createCommand()), 'age_eligibility_required');
  const missing = world({ privacy: null });
  await refused(missing.service().execute(actorA, createCommand()), 'age_eligibility_required');
  assert.equal(w.repository.snapshot().drafts.length, 0);
  assert.equal(missing.repository.snapshot().drafts.length, 0);
  // A delegated module never authors Find People, even when granted the type.
  const delegated = await w.service().executeDelegated(
    { moduleId: 'importer', operation: 'createDraft' },
    command('createDraft', {
      typeId: 'find_people',
      marketId: 'LV',
      publisherRef: { type: 'user', id: userA },
      body: {},
      origin: {
        kind: 'delegatedImport',
        delegatedActorRef: 'module:importer/createDraft',
        externalBindingRef: 'src|1|',
        sourceId: 'src',
        sourceRevision: '1',
        acquiredAtUtc: '2026-10-19T09:00:00.000Z',
        correctionRemovalPolicyRef: 'removal-1',
      },
    }),
  );
  assert.equal(delegated.kind, 'rejected');
  assert.equal(w.repository.snapshot().drafts.length, 0);
});

void test('the private source belongs to its author only, also inside a Page', async () => {
  const w = world();
  const content = w.service();
  const draft = await prepared(content, await validBody(), { type: 'page', id: pageP });
  // Another member of the same Page (eligible by Identity) cannot read or change it.
  await refused(
    content.query(actorB, {
      schemaVersion: 1,
      queryType: 'getDraft',
      payload: { draftId: draft.draftId },
    }),
    'capability_denied',
  );
  await refused(
    content.query(actorB, {
      schemaVersion: 1,
      queryType: 'getPublicationStatus',
      payload: { contentId: draft.contentId },
    }),
    'capability_denied',
  );
  await refused(
    content.execute(
      actorB,
      command('updateDraft', {
        draftId: draft.draftId,
        expectedRevision: draft.revision,
        body: {},
      }),
    ),
    'capability_denied',
  );
  await refused(
    content.execute(
      actorB,
      command('submitForPublication', {
        draftId: draft.draftId,
        expectedDraftRevision: draft.revision,
      }),
    ),
    'capability_denied',
  );
  const own = await ok<{ body: ContentBody }>(
    content.query(actorA, {
      schemaVersion: 1,
      queryType: 'getDraft',
      payload: { draftId: draft.draftId },
    }),
  );
  assert.ok(JSON.stringify(own.body).includes('"exact"'));
});

void test('C3 with consent: public projection only, no bypass on publish or activate', async () => {
  const w = world();
  const content = w.service();
  const body = await validBody();
  const draft = await prepared(content, body);
  const submit = () =>
    command('submitForPublication', {
      draftId: draft.draftId,
      expectedDraftRevision: draft.revision,
    });
  // No consent yet: refused without a submission.
  await refused(content.execute(actorA, submit()), 'privacy_consent_required');
  w.privacy.consents.set(`${draft.contentId}:${userA}`, 'active');
  const submission = await ok<{ submissionId: EntityId }>(content.execute(actorA, submit()));
  const publish = command('publishApprovedRevision', {
    submissionId: submission.submissionId,
    expectedPointerRevision: 0,
  });
  // Consent revoked between submit and publish: publish re-checks and refuses.
  w.privacy.consents.set(`${draft.contentId}:${userA}`, 'revoked');
  await refused(content.execute(actorA, publish), 'privacy_consent_required');
  w.privacy.consents.set(`${draft.contentId}:${userA}`, 'active');
  // Age attestation revoked: refused as well.
  w.privacy.adults.delete(userA);
  await refused(
    content.execute(actorA, { ...publish, idempotencyKey: key() }),
    'age_eligibility_required',
  );
  w.privacy.adults.add(userA);
  const revision = await ok<{
    publishedRevisionId: EntityId;
    body: ContentBody;
    bodyHash: string;
  }>(content.execute(actorA, publish));
  // Lost answer: the replay returns the same revision, nothing is duplicated.
  assert.deepEqual(await content.execute(actorA, publish), { kind: 'succeeded', data: revision });
  assert.equal(w.repository.snapshot().revisions.length, 1);
  const text = JSON.stringify(revision.body);
  for (const secret of [
    '56.95182',
    '24.08571',
    'Ķīpsala riverside steps',
    'Ķīpsalas iela 6',
    'blue bench',
    '"exact"',
    'confirmations',
  ])
    assert.equal(text.includes(secret), false, secret);
  assert.ok(text.includes('"publicLocation"'));
  // Exact-ID public reads apply the same fresh gate to the author and other viewers.
  const read = (actor: ContentActor) =>
    content.query(actor, {
      schemaVersion: 1,
      queryType: 'getPublishedRevision',
      payload: { contentId: draft.contentId },
    });
  w.privacy.publicGate = false;
  await refused(read(actorA), 'not_found');
  // Private source access remains available to its author after public refusal.
  await ok(
    content.query(actorA, {
      schemaVersion: 1,
      queryType: 'getDraft',
      payload: { draftId: draft.draftId },
    }),
  );
  await refused(read(actorB), 'not_found');
  w.privacy.publicGate = true;
  assert.deepEqual((await ok<{ body: ContentBody }>(read(actorB))).body, revision.body);
  assert.deepEqual(w.privacy.reads, [userA, userB, userB]);
  // Disabled type: exact-ID reads stop too.
  await refused(
    w.service(['session']).query(actorB, {
      schemaVersion: 1,
      queryType: 'getPublishedRevision',
      payload: { contentId: draft.contentId },
    }),
    'not_found',
  );
  // Owner hide works without consent and without the age authority.
  w.privacy.consents.set(`${draft.contentId}:${userA}`, 'revoked');
  w.privacy.adults.delete(userA);
  await ok(
    content.execute(
      actorA,
      command('withdrawPublication', {
        contentId: draft.contentId,
        expectedPointerRevision: 1,
        mode: 'withdraw',
      }),
    ),
  );
  await refused(read(actorB), 'not_found');
  w.privacy.adults.add(userA);
  const activate = () =>
    command('activatePublishedRevision', {
      contentId: draft.contentId,
      publishedRevisionId: revision.publishedRevisionId,
      expectedPointerRevision: 2,
    });
  // Activate cannot bring it back without consent.
  await refused(content.execute(actorA, activate()), 'privacy_consent_required');
  w.privacy.consents.set(`${draft.contentId}:${userA}`, 'active');
  // Another eligible member cannot activate the author's request.
  await refused(content.execute(actorB, activate()), 'capability_denied');
  // After the meeting ended, the immutable public body is refused on activate.
  w.clock.set(new Date('2027-05-15T08:00:00.000Z'));
  const ended = await refused(content.execute(actorA, activate()), 'validation_failed');
  assert.ok(JSON.stringify(ended).includes('find_people.meeting_ended'));
  w.clock.set(new Date('2026-10-19T11:00:00.000Z'));
  await ok(content.execute(actorA, activate()));
  assert.equal(w.repository.snapshot().pointers[0]?.visibility, 'visible');
});

void test('the same forbidden input is refused on submit, approved publish and activate', async () => {
  const w = world();
  const content = w.service();
  const draft = await prepared(content, await validBody());
  w.privacy.consents.set(`${draft.contentId}:${userA}`, 'active');
  const submission = await ok<{ submissionId: EntityId }>(
    content.execute(
      actorA,
      command('submitForPublication', {
        draftId: draft.draftId,
        expectedDraftRevision: draft.revision,
      }),
    ),
  );
  // Time passes beyond the meeting end before the approved publish.
  w.clock.set(new Date('2027-05-15T08:00:00.000Z'));
  const atPublish = await refused(
    content.execute(
      actorA,
      command('publishApprovedRevision', {
        submissionId: submission.submissionId,
        expectedPointerRevision: 0,
      }),
    ),
    'validation_failed',
  );
  assert.ok(JSON.stringify(atPublish).includes('find_people.meeting_ended'));
  // A body with a client public point never reaches a submission.
  w.clock.set(new Date('2026-10-19T10:00:00.000Z'));
  const smuggled = await validBody();
  (smuggled.findPeople as { meeting: Record<string, unknown> }).meeting.publicGeo = {
    latitude: 56.95,
    longitude: 24.08,
  };
  const second = await prepared(content, smuggled);
  w.privacy.consents.set(`${second.contentId}:${userA}`, 'active');
  const atSubmit = await refused(
    content.execute(
      actorA,
      command('submitForPublication', {
        draftId: second.draftId,
        expectedDraftRevision: second.revision,
      }),
    ),
    'validation_failed',
  );
  assert.ok(JSON.stringify(atSubmit).includes('find_people.public_geo_forbidden'));
  const snapshot = w.repository.snapshot();
  assert.equal(snapshot.revisions.length, 0);
  assert.equal(snapshot.submissions.length, 1);
});

void test('other Create types are untouched by the Find People gates', async () => {
  const w = world({ privacy: null });
  const created = await w.service(['session']).execute(
    actorA,
    command('createDraft', {
      typeId: 'session',
      marketId: 'LV',
      publisherRef: { type: 'user', id: userA },
      body: {},
    }),
  );
  assert.equal(created.kind, 'succeeded');
});
