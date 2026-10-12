import type { LinkedPlaceEligibilityPort } from '../../src/modules/content/application/ports/linked_place_eligibility_port.js';
// D3.2 §2.2, §2.4 (ACTIVITY_D3_2_PUBLICATION_AMENDMENT.md): the Content
// service with in-memory ports under the Emulator authoring sets. Activity
// needs its own type in the set; Rental and Collection stay disabled under
// every Emulator set; once Activity is switched off, the commands that create
// or change publishable content are refused while the owner's hide and reads
// keep working; and with the Emulator composition rules a linked Place is
// refused at submit, because the composition cannot resolve it.
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
import { emulatorCompositionRules } from '../../src/modules/content/infrastructure/emulator_activity_dependencies.js';
import { InMemoryContentRepository } from '../../src/modules/content/infrastructure/in_memory_content_repository.js';
import { EmulatorSyntheticReferenceData } from '../../src/modules/content/infrastructure/emulator_reference_data.js';
import { parseEntityId, type EntityId } from '../../src/shared/ids.js';
import { standActivityBody } from '../stand/stand_content_activity.js';
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
  #next = 6000;
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
      profileId: 'activity.default',
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

function service(
  repository: InMemoryContentRepository,
  enabled: readonly ContentTypeId[],
  options: {
    readonly compositionRules?: boolean;
    readonly linkedPlaceEligibility?: LinkedPlaceEligibilityPort;
    readonly enforceLinkedPlaceEligibility?: boolean;
  } = {},
) {
  return new ContentPublicationService({
    repository,
    eligibility: new AllowAll(),
    // The Emulator reference data, with its D3.2 Activity taxonomy.
    referenceData: new EmulatorSyntheticReferenceData(),
    moderation: new NoReview(),
    media: new ReadyMedia(),
    clock: new FakeClock(new Date('2026-10-11T10:00:00.000Z')),
    ids: new SequentialIds(),
    enabledTypes: new Set(enabled),
    ...(options.linkedPlaceEligibility
      ? {
          linkedPlaceEligibility: options.linkedPlaceEligibility,
          enforceLinkedPlaceEligibility: true,
        }
      : {}),
    ...(options.enforceLinkedPlaceEligibility ? { enforceLinkedPlaceEligibility: true } : {}),
    // As composed by the Emulator authoring path (content_entry.ts).
    ...(options.compositionRules === false ? {} : { compositionRules: emulatorCompositionRules }),
  });
}

let counter = 0;
const key = (label: string) => `d32-${label}-${(counter += 1)}`;
const activityBody = standActivityBody({
  coverMediaId: 'asset-cover',
  galleryMediaIds: ['asset-gallery-1'],
});

const create = (typeId: string, body: unknown = {}) => ({
  schemaVersion: 1,
  commandType: 'createDraft',
  idempotencyKey: key(`create-${typeId}`),
  payload: { typeId, publisherRef: { type: 'user', id: userA }, marketId: 'LV', body },
});

const submit = (draftId: EntityId, revision: number) => ({
  schemaVersion: 1,
  commandType: 'submitForPublication',
  idempotencyKey: key('submit'),
  payload: { draftId, expectedDraftRevision: revision },
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

/** An Activity draft with the full body saved; returns its ids and revision. */
async function boundDraft(content: ContentPublicationService, body: Record<string, unknown>) {
  const draft = await succeeded<{ draftId: EntityId; contentId: EntityId }>(
    content.execute(actorA, create('activity')),
  );
  const bound = await succeeded<{ revision: number }>(
    content.execute(actorA, {
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: key('bind'),
      payload: { draftId: draft.draftId, expectedRevision: 1, body },
    }),
  );
  return { ...draft, revision: bound.revision };
}

const emulatorSets: readonly (readonly ContentTypeId[])[] = [
  [],
  ['event'],
  ['place'],
  ['activity'],
  ['event', 'place'],
  ['event', 'activity'],
  ['place', 'activity'],
  ['event', 'place', 'activity'],
];

void test('Rental and Collection stay disabled under every Emulator authoring set', async () => {
  for (const enabled of emulatorSets) {
    const content = service(new InMemoryContentRepository(), enabled);
    for (const typeId of ['rental', 'collection'])
      await refusedWith(
        content.execute(actorA, create(typeId)),
        'type_disabled',
        `${typeId} with ${JSON.stringify(enabled)}`,
      );
  }
});

void test('types without a validator are refused as unsupported even next to Activity', async () => {
  const unvalidated = ['route', 'session', 'scenario', 'find_people', 'class_workshop'] as const;
  const content = service(new InMemoryContentRepository(), [...unvalidated, 'activity']);
  for (const typeId of unvalidated)
    await refusedWith(content.execute(actorA, create(typeId)), 'content_type_unsupported', typeId);
});

void test('Activity authoring needs its own type in the set', async () => {
  for (const enabled of emulatorSets) {
    const result = await service(new InMemoryContentRepository(), enabled).execute(
      actorA,
      create('activity'),
    );
    if (enabled.includes('activity'))
      assert.equal(result.kind, 'succeeded', JSON.stringify(enabled));
    else assert.equal((result as { code?: string }).code, 'type_disabled', JSON.stringify(enabled));
  }
});

void test('the Emulator taxonomy refuses an inapplicable or unknown subcategory and a missing criterion', async () => {
  const content = service(new InMemoryContentRepository(), ['activity']);
  const refused: ReadonlyArray<readonly [string, Record<string, unknown>]> = [
    [
      'inapplicable',
      { ...activityBody, categoryId: 'wellness_recharge', subcategoryId: 'sauna', criteria: {} },
    ],
    ['criterion', { ...activityBody, criteria: {} }],
    ['unknown pair', { ...activityBody, categoryId: 'nope', subcategoryId: 'nope' }],
  ];
  for (const [label, body] of refused) {
    const draft = await boundDraft(content, body);
    await refusedWith(
      content.execute(actorA, submit(draft.draftId, draft.revision)),
      'validation_failed',
      label,
    );
  }
  const valid = await boundDraft(content, activityBody);
  await succeeded(content.execute(actorA, submit(valid.draftId, valid.revision)));
});

void test('a linked Place fails closed at submit under the Emulator composition rules', async () => {
  const linked = {
    ...activityBody,
    location: {
      ...(activityBody.location as Record<string, unknown>),
      linkedPlaceId: ulid(4242),
    },
  };
  // The unchanged validator alone accepts it (a permanent id) ...
  const plain = service(new InMemoryContentRepository(), ['activity'], {
    compositionRules: false,
  });
  const accepted = await boundDraft(plain, linked);
  await succeeded(plain.execute(actorA, submit(accepted.draftId, accepted.revision)));
  // ... the Emulator composition cannot resolve the Place, so it refuses.
  const content = service(new InMemoryContentRepository(), ['activity']);
  const draft = await boundDraft(content, linked);
  await refusedWith(
    content.execute(actorA, submit(draft.draftId, draft.revision)),
    'validation_failed',
    'linked Place',
  );
  // Removing the link is the way forward; nothing else changes.
  const unlinked = await succeeded<{ revision: number }>(
    content.execute(actorA, {
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: key('unlink'),
      payload: { draftId: draft.draftId, expectedRevision: draft.revision, body: activityBody },
    }),
  );
  await succeeded(content.execute(actorA, submit(draft.draftId, unlinked.revision)));
});

void test('with Activity switched off, authoring is refused and the owner can still hide and read', async () => {
  const repository = new InMemoryContentRepository();
  const on = service(repository, ['event', 'activity']);
  // Published Activity, plus a second approved submission waiting to be published.
  const draft = await boundDraft(on, activityBody);
  const first = await succeeded<{ submissionId: EntityId }>(
    on.execute(actorA, submit(draft.draftId, draft.revision)),
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
        expectedRevision: draft.revision,
        body: { ...activityBody, title: 'Ķemeri bog boardwalk long loop' },
      },
    }),
  );
  const second = await succeeded<{ submissionId: EntityId }>(
    on.execute(actorA, submit(draft.draftId, revised.revision)),
  );

  // Matrix row "Event on / Activity off" (§2.2).
  const off = service(repository, ['event']);
  await refusedWith(off.execute(actorA, create('activity')), 'type_disabled', 'create');
  await refusedWith(
    off.execute(actorA, {
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: key('update-off'),
      payload: { draftId: draft.draftId, expectedRevision: revised.revision, body: activityBody },
    }),
    'type_disabled',
    'update',
  );
  await refusedWith(
    off.execute(actorA, submit(draft.draftId, revised.revision)),
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

const linkedBody = {
  ...activityBody,
  location: {
    ...(activityBody.location as Record<string, unknown>),
    linkedPlaceId: ulid(4343),
  },
};

/** What a refused command must leave untouched: pointer, revisions and effects. */
function stateOf(repository: InMemoryContentRepository, contentId: EntityId) {
  const snapshot = repository.snapshot();
  return {
    pointer: snapshot.pointers.find((item) => item.contentId === contentId) ?? null,
    revisions: snapshot.revisions.filter((item) => item.contentId === contentId),
    effects: snapshot.effects,
  };
}

/** Publishes a linked-Place Activity with a service that has no composition rule. */
async function publishedWithoutRule(repository: InMemoryContentRepository) {
  const plain = service(repository, ['activity'], { compositionRules: false });
  const draft = await boundDraft(plain, linkedBody);
  const submission = await succeeded<{ submissionId: EntityId }>(
    plain.execute(actorA, submit(draft.draftId, draft.revision)),
  );
  const published = await succeeded<{ publishedRevisionId: EntityId }>(
    plain.execute(actorA, {
      schemaVersion: 1,
      commandType: 'publishApprovedRevision',
      idempotencyKey: key('publish-linked'),
      payload: { submissionId: submission.submissionId, expectedPointerRevision: 0 },
    }),
  );
  return { plain, draft, linkedRevisionId: published.publishedRevisionId };
}

const activate = (contentId: EntityId, publishedRevisionId: EntityId, pointerRevision: number) => ({
  schemaVersion: 1,
  commandType: 'activatePublishedRevision',
  idempotencyKey: key('activate'),
  payload: { contentId, publishedRevisionId, expectedPointerRevision: pointerRevision },
});

void test('activate checks the target immutable revision: a linked-Place revision replaced by a newer one stays inactive', async () => {
  const repository = new InMemoryContentRepository();
  const { plain, draft, linkedRevisionId } = await publishedWithoutRule(repository);
  // A newer, unlinked revision becomes current; the draft no longer has the link.
  const revised = await succeeded<{ revision: number }>(
    plain.execute(actorA, {
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: key('unlink'),
      payload: { draftId: draft.draftId, expectedRevision: draft.revision, body: activityBody },
    }),
  );
  const second = await succeeded<{ submissionId: EntityId }>(
    plain.execute(actorA, submit(draft.draftId, revised.revision)),
  );
  await succeeded(
    plain.execute(actorA, {
      schemaVersion: 1,
      commandType: 'publishApprovedRevision',
      idempotencyKey: key('publish-unlinked'),
      payload: { submissionId: second.submissionId, expectedPointerRevision: 1 },
    }),
  );

  // Activity enabled and the rule composed: the old linked revision is refused,
  // although the current draft (the body a draft-based check would see) is valid.
  const ruled = service(repository, ['activity']);
  const before = stateOf(repository, draft.contentId);
  assert.equal(before.pointer?.revision, 2);
  await refusedWith(
    ruled.execute(actorA, activate(draft.contentId, linkedRevisionId, 2)),
    'validation_failed',
    'activate linked revision',
  );
  assert.deepEqual(stateOf(repository, draft.contentId), before);

  // Control: without the rule the same activation goes through.
  await succeeded(plain.execute(actorA, activate(draft.contentId, linkedRevisionId, 2)));
  assert.equal(
    stateOf(repository, draft.contentId).pointer?.currentPublishedRevisionId,
    linkedRevisionId,
  );
});

void test('activate checks the target immutable revision: an owner-hidden linked-Place revision is not shown again', async () => {
  const repository = new InMemoryContentRepository();
  const { plain, draft, linkedRevisionId } = await publishedWithoutRule(repository);
  await succeeded(
    plain.execute(actorA, {
      schemaVersion: 1,
      commandType: 'withdrawPublication',
      idempotencyKey: key('withdraw'),
      payload: { contentId: draft.contentId, expectedPointerRevision: 1, mode: 'withdraw' },
    }),
  );
  const ruled = service(repository, ['activity']);
  const before = stateOf(repository, draft.contentId);
  assert.equal(before.pointer?.visibility, 'withdrawn');
  await refusedWith(
    ruled.execute(actorA, activate(draft.contentId, linkedRevisionId, 2)),
    'validation_failed',
    'activate hidden linked revision',
  );
  assert.deepEqual(stateOf(repository, draft.contentId), before);
});

void test('publish of a linked-Place submission approved before the rule is refused', async () => {
  const repository = new InMemoryContentRepository();
  const plain = service(repository, ['activity'], { compositionRules: false });
  const draft = await boundDraft(plain, linkedBody);
  // Approved by policy at submit, while no rule was composed.
  const submission = await succeeded<{ submissionId: EntityId }>(
    plain.execute(actorA, submit(draft.draftId, draft.revision)),
  );
  const publish = () => ({
    schemaVersion: 1,
    commandType: 'publishApprovedRevision',
    idempotencyKey: key('publish-approved'),
    payload: { submissionId: submission.submissionId, expectedPointerRevision: 0 },
  });
  const ruled = service(repository, ['activity']);
  const before = stateOf(repository, draft.contentId);
  assert.equal(before.pointer, null);
  await refusedWith(ruled.execute(actorA, publish()), 'validation_failed', 'publish');
  assert.deepEqual(stateOf(repository, draft.contentId), before);
  // Control: without the rule the same approved submission publishes.
  await succeeded(plain.execute(actorA, publish()));
  assert.equal(stateOf(repository, draft.contentId).pointer?.visibility, 'visible');
});

void test('D3.9 exact target linked Place is checked freshly at submit, publish and activation; positive and refusal preserve lifecycle invariants', async () => {
  const repository = new InMemoryContentRepository();
  let status: 'eligible' | 'unknown' | 'forbidden' | 'unavailable' = 'eligible';
  const seen: string[] = [];
  const guarded = service(repository, ['activity'], {
    compositionRules: false,
    linkedPlaceEligibility: {
      check: (input) => {
        seen.push(input.placeId);
        return Promise.resolve({ status });
      },
    },
  });
  const draft = await boundDraft(guarded, linkedBody);
  const missing = service(repository, ['activity'], {
    compositionRules: false,
    enforceLinkedPlaceEligibility: true,
  });
  status = 'unknown';
  const beforeSubmit = stateOf(repository, draft.contentId);
  await refusedWith(
    missing.execute(actorA, submit(draft.draftId, draft.revision)),
    'validation_failed',
    'missing Catalog dependency on submit',
  );
  assert.deepEqual(stateOf(repository, draft.contentId), beforeSubmit);
  await refusedWith(
    guarded.execute(actorA, submit(draft.draftId, draft.revision)),
    'validation_failed',
    'unknown linked Place',
  );
  assert.deepEqual(stateOf(repository, draft.contentId), beforeSubmit);
  status = 'eligible';
  const submitted = await succeeded<{ submissionId: EntityId }>(
    guarded.execute(actorA, submit(draft.draftId, draft.revision)),
  );
  const publish = () => ({
    schemaVersion: 1,
    commandType: 'publishApprovedRevision',
    idempotencyKey: key('d39-publish'),
    payload: { submissionId: submitted.submissionId, expectedPointerRevision: 0 },
  });
  status = 'forbidden';
  const beforePublish = stateOf(repository, draft.contentId);
  await refusedWith(
    missing.execute(actorA, publish()),
    'validation_failed',
    'missing Catalog dependency on publish',
  );
  assert.deepEqual(stateOf(repository, draft.contentId), beforePublish);
  await refusedWith(
    guarded.execute(actorA, publish()),
    'validation_failed',
    'Place hidden after approval',
  );
  assert.deepEqual(stateOf(repository, draft.contentId), beforePublish);
  status = 'eligible';
  const published = await succeeded<{ publishedRevisionId: EntityId }>(
    guarded.execute(actorA, publish()),
  );
  await succeeded(
    guarded.execute(actorA, {
      schemaVersion: 1,
      commandType: 'withdrawPublication',
      idempotencyKey: key('d39-hide'),
      payload: { contentId: draft.contentId, expectedPointerRevision: 1, mode: 'withdraw' },
    }),
  );
  status = 'unavailable';
  const beforeActivate = stateOf(repository, draft.contentId);
  await refusedWith(
    missing.execute(actorA, activate(draft.contentId, published.publishedRevisionId, 2)),
    'validation_failed',
    'missing Catalog dependency on activate',
  );
  assert.deepEqual(stateOf(repository, draft.contentId), beforeActivate);
  await refusedWith(
    guarded.execute(actorA, activate(draft.contentId, published.publishedRevisionId, 2)),
    'validation_failed',
    'Catalog outage',
  );
  assert.deepEqual(stateOf(repository, draft.contentId), beforeActivate);
  status = 'forbidden';
  await refusedWith(
    guarded.execute(actorA, activate(draft.contentId, published.publishedRevisionId, 2)),
    'validation_failed',
    'old linked target forbidden',
  );
  assert.deepEqual(stateOf(repository, draft.contentId), beforeActivate);
  status = 'eligible';
  await succeeded(
    guarded.execute(actorA, activate(draft.contentId, published.publishedRevisionId, 2)),
  );
  assert.ok(
    seen.length >= 7 &&
      seen.every(
        (id) => id === String((linkedBody.location as Record<string, unknown>).linkedPlaceId),
      ),
  );
});
