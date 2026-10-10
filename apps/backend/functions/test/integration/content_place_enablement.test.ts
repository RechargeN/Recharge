// D3.1 §2.2 (PLACE_D3_1_PUBLICATION_AMENDMENT.md): the Content service with
// in-memory ports under the Emulator authoring sets. Types without a validator
// are refused as unsupported even when listed; Activity, Rental and Collection
// stay disabled under every Emulator set; once Place is switched off, the
// commands that create or change publishable content are refused while the
// owner's hide and reads keep working.
import assert from 'node:assert/strict';
import test from 'node:test';

import type { ContentTypeId } from '../../src/contracts/content_v1.js';
import type { PublisherEligibilityV1 } from '../../src/contracts/identity_v1.js';
import {
  ContentPublicationService,
  type ContentIdGenerator,
} from '../../src/modules/content/application/content_publication_service.js';
import type {
  ContentActor,
  PublisherEligibilityPort,
  PublisherEligibilityRequest,
} from '../../src/modules/content/application/ports/publisher_eligibility_port.js';
import type { MediaReadinessPort } from '../../src/modules/content/application/ports/media_readiness_port.js';
import type { ModerationDispositionPort } from '../../src/modules/content/application/ports/moderation_disposition_port.js';
import { InMemoryContentRepository } from '../../src/modules/content/infrastructure/in_memory_content_repository.js';
import { EmulatorSyntheticReferenceData } from '../../src/modules/content/infrastructure/emulator_reference_data.js';
import { parseEntityId, type EntityId } from '../../src/shared/ids.js';
import { standPlaceBody } from '../stand/stand_content_place.js';
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
  #next = 5000;
  newId(): EntityId {
    this.#next += 1;
    return ulid(this.#next);
  }
}

const userA = ulid(1);
const actorA: ContentActor = { userId: userA, sessionId: ulid(2) };

class AllowAll implements PublisherEligibilityPort {
  evaluate(request: PublisherEligibilityRequest): Promise<PublisherEligibilityV1> {
    return Promise.resolve({
      schemaVersion: 1,
      publisherRef: request.publisherRef,
      eligible: true,
      reason: 'eligible',
      authorityRevision: 1,
      evaluatedAtUtc: request.nowUtc as PublisherEligibilityV1['evaluatedAtUtc'],
    });
  }
  evaluateDelegated(): Promise<PublisherEligibilityV1> {
    return Promise.reject(new Error('not used'));
  }
}

/** No pre-publication review: a submission is approved by policy at once. */
class NoReview implements ModerationDispositionPort {
  verifyDisposition() {
    return Promise.resolve({ verified: false } as const);
  }
  profileFor() {
    return Promise.resolve({
      available: true,
      profileId: 'place.default',
      requiresPrePublicationModeration: false,
      policyRevision: 'pol-1',
      policyDecisionId: 'pd-1',
    } as const);
  }
}

/** Media ready, without attachments, as the existing Content service tests fake it. */
class ReadyMedia implements MediaReadinessPort {
  check() {
    return Promise.resolve({
      ready: true,
      mediaRevision: 'media-1',
      attachments: [],
      confirmations: [],
    } as const);
  }
}

function service(repository: InMemoryContentRepository, enabled: readonly ContentTypeId[]) {
  return new ContentPublicationService({
    repository,
    eligibility: new AllowAll(),
    // The Emulator reference data, with its D3.1 Place taxonomy.
    referenceData: new EmulatorSyntheticReferenceData(),
    moderation: new NoReview(),
    media: new ReadyMedia(),
    clock: new FakeClock(new Date('2026-10-10T10:00:00.000Z')),
    ids: new SequentialIds(),
    enabledTypes: new Set(enabled),
  });
}

let counter = 0;
const key = (label: string) => `d31-${label}-${(counter += 1)}`;
const placeBody = standPlaceBody({
  submittedByUserId: userA,
  coverMediaId: 'asset-cover',
  galleryMediaIds: ['asset-gallery-1'],
});

const create = (typeId: string, body: unknown = {}) => ({
  schemaVersion: 1,
  commandType: 'createDraft',
  idempotencyKey: key(`create-${typeId}`),
  payload: { typeId, publisherRef: { type: 'user', id: userA }, marketId: 'LV', body },
});

async function succeeded<T>(promise: Promise<{ kind: string; data?: unknown; code?: string }>) {
  const result = await promise;
  assert.equal(result.kind, 'succeeded', `${result.kind}:${String(result.code)}`);
  return result.data as T;
}

async function refusedWith(
  promise: Promise<{ kind: string; code?: string }>,
  code: string,
  label: string,
): Promise<void> {
  const result = await promise;
  assert.equal(result.kind, 'rejected', `${label}: ${JSON.stringify(result)}`);
  assert.equal(result.code, code, label);
}

const emulatorSets: readonly (readonly ContentTypeId[])[] = [
  [],
  ['event'],
  ['place'],
  ['event', 'place'],
];

void test('types without a validator are refused as unsupported even when listed', async () => {
  const unvalidated = ['route', 'session', 'scenario', 'find_people', 'class_workshop'] as const;
  const content = service(new InMemoryContentRepository(), [...unvalidated, 'place']);
  for (const typeId of unvalidated)
    await refusedWith(content.execute(actorA, create(typeId)), 'content_type_unsupported', typeId);
});

void test('Activity, Rental and Collection stay disabled under every Emulator authoring set', async () => {
  for (const enabled of emulatorSets) {
    const content = service(new InMemoryContentRepository(), enabled);
    for (const typeId of ['activity', 'rental', 'collection'])
      await refusedWith(
        content.execute(actorA, create(typeId)),
        'type_disabled',
        `${typeId} with ${JSON.stringify(enabled)}`,
      );
  }
});

void test('Place authoring needs its own type in the set', async () => {
  for (const enabled of emulatorSets) {
    const result = await service(new InMemoryContentRepository(), enabled).execute(
      actorA,
      create('place'),
    );
    if (enabled.includes('place')) assert.equal(result.kind, 'succeeded', JSON.stringify(enabled));
    else assert.equal((result as { code?: string }).code, 'type_disabled', JSON.stringify(enabled));
  }
});

void test('with Place switched off, authoring is refused and the owner can still hide and read', async () => {
  const repository = new InMemoryContentRepository();
  const on = service(repository, ['event', 'place']);
  // Published Place, plus a second approved submission waiting to be published.
  const draft = await succeeded<{ draftId: EntityId; contentId: EntityId }>(
    on.execute(actorA, create('place')),
  );
  const bound = await succeeded<{ revision: number }>(
    on.execute(actorA, {
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: key('bind'),
      payload: { draftId: draft.draftId, expectedRevision: 1, body: placeBody },
    }),
  );
  const first = await succeeded<{ submissionId: EntityId }>(
    on.execute(actorA, {
      schemaVersion: 1,
      commandType: 'submitForPublication',
      idempotencyKey: key('submit'),
      payload: { draftId: draft.draftId, expectedDraftRevision: bound.revision },
    }),
  );
  const published = await succeeded<{ publishedRevisionId: EntityId }>(
    on.execute(actorA, {
      schemaVersion: 1,
      commandType: 'publishApprovedRevision',
      idempotencyKey: key('publish'),
      payload: { submissionId: first.submissionId, expectedPointerRevision: 0 },
    }),
  );
  const revised = await succeeded<{ revision: number }>(
    on.execute(actorA, {
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: key('revise'),
      payload: {
        draftId: draft.draftId,
        expectedRevision: bound.revision,
        body: { ...placeBody, title: 'Kronvalda park pond and fountain' },
      },
    }),
  );
  const second = await succeeded<{ submissionId: EntityId }>(
    on.execute(actorA, {
      schemaVersion: 1,
      commandType: 'submitForPublication',
      idempotencyKey: key('resubmit'),
      payload: { draftId: draft.draftId, expectedDraftRevision: revised.revision },
    }),
  );

  // Matrix row "Event on / Place off" (§2.2).
  const off = service(repository, ['event']);
  await refusedWith(off.execute(actorA, create('place')), 'type_disabled', 'create');
  await refusedWith(
    off.execute(actorA, {
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: key('update-off'),
      payload: { draftId: draft.draftId, expectedRevision: revised.revision, body: placeBody },
    }),
    'type_disabled',
    'update',
  );
  await refusedWith(
    off.execute(actorA, {
      schemaVersion: 1,
      commandType: 'submitForPublication',
      idempotencyKey: key('submit-off'),
      payload: { draftId: draft.draftId, expectedDraftRevision: revised.revision },
    }),
    'type_disabled',
    'submit',
  );
  await refusedWith(
    off.execute(actorA, {
      schemaVersion: 1,
      commandType: 'publishApprovedRevision',
      idempotencyKey: key('publish-off'),
      payload: { submissionId: second.submissionId, expectedPointerRevision: 1 },
    }),
    'type_disabled',
    'publish',
  );
  await refusedWith(
    off.execute(actorA, {
      schemaVersion: 1,
      commandType: 'activatePublishedRevision',
      idempotencyKey: key('activate-off'),
      payload: {
        contentId: draft.contentId,
        publishedRevisionId: published.publishedRevisionId,
        expectedPointerRevision: 1,
      },
    }),
    'type_disabled',
    'activate',
  );
  // Owner reads stay available.
  await succeeded(
    off.query(actorA, {
      schemaVersion: 1,
      queryType: 'getDraft',
      payload: { draftId: draft.draftId },
    }),
  );
  await succeeded(
    off.query(actorA, {
      schemaVersion: 1,
      queryType: 'getPublishedRevision',
      payload: { contentId: draft.contentId },
    }),
  );
  // The owner's hide stays available, and the read shows its result.
  await succeeded(
    off.execute(actorA, {
      schemaVersion: 1,
      commandType: 'withdrawPublication',
      idempotencyKey: key('withdraw-off'),
      payload: { contentId: draft.contentId, expectedPointerRevision: 1, mode: 'withdraw' },
    }),
  );
  const status = await succeeded<{ pointer: { visibility: string } }>(
    off.query(actorA, {
      schemaVersion: 1,
      queryType: 'getPublicationStatus',
      payload: { contentId: draft.contentId },
    }),
  );
  assert.equal(status.pointer.visibility, 'withdrawn');
});
