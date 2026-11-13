// D3.4 §2.2, §2.3 (COLLECTION_D3_4_PUBLICATION_AMENDMENT.md): the Content
// service with in-memory ports under the Emulator authoring sets. Collection
// needs its own type in the set; Rental stays disabled; once Collection is
// switched off the commands that create or change publishable content are
// refused while the owner's hide and reads keep working. Membership is asked
// from a Catalog-owned port, freshly, for the exact body at submit, publish and
// activation: a withheld item needs the author's acknowledgement, an unknown or
// forbidden reference and an outage are refused, and a refusal changes nothing.
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
import type {
  PublishedObjectMembershipPort,
  PublishedObjectMembershipStatus,
} from '../../src/modules/content/application/ports/published_object_membership_port.js';
import { collectionRuleConfig } from '../../src/modules/content/domain/type_rules/collection_rules.js';
import { emulatorCompositionRules } from '../../src/modules/content/infrastructure/emulator_activity_dependencies.js';
import { InMemoryContentRepository } from '../../src/modules/content/infrastructure/in_memory_content_repository.js';
import { EmulatorSyntheticReferenceData } from '../../src/modules/content/infrastructure/emulator_reference_data.js';
import { parseEntityId, type EntityId } from '../../src/shared/ids.js';
import {
  standCollectionBody,
  type StandCollectionItemInput,
} from '../stand/stand_content_collection.js';
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
  #next = 9000;
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
      profileId: 'collection.default',
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
      mediaRevision: 'media-1',
      attachments: [],
      confirmations: [],
    } as const);
  }
}

/** Catalog stand-in: one status per object id (default `ready`), every question recorded. */
class FakeMembership implements PublishedObjectMembershipPort {
  readonly statuses = new Map<string, PublishedObjectMembershipStatus | Error>();
  readonly asked: { objectType: string; objectId: string; marketId: string }[] = [];
  statusOf(input: {
    readonly objectType: string;
    readonly objectId: string;
    readonly marketId: string;
  }): Promise<PublishedObjectMembershipStatus> {
    this.asked.push({ ...input });
    const status = this.statuses.get(input.objectId) ?? 'ready';
    return status instanceof Error ? Promise.reject(status) : Promise.resolve(status);
  }
}

function service(
  repository: InMemoryContentRepository,
  enabled: readonly ContentTypeId[],
  membership?: PublishedObjectMembershipPort,
) {
  return new ContentPublicationService({
    repository,
    eligibility: new AllowAll(),
    referenceData: new EmulatorSyntheticReferenceData(),
    moderation: new NoReview(),
    media: new ReadyMedia(),
    clock: new FakeClock(new Date('2026-10-12T10:00:00.000Z')),
    ids: new SequentialIds(),
    enabledTypes: new Set(enabled),
    // As composed by the Emulator authoring path (content_entry.ts).
    compositionRules: emulatorCompositionRules,
    ...(membership === undefined ? {} : { publishedObjectMembership: membership }),
  });
}

let counter = 0;
const key = (label: string) => `d34-${label}-${(counter += 1)}`;
const members = [ulid(101), ulid(102), ulid(103)] as const;
const itemIds = [ulid(201), ulid(202), ulid(203)] as const;

function items(objectTypes: readonly string[] = ['place', 'place', 'place']) {
  return members.map((objectId, index): StandCollectionItemInput => ({
    itemId: itemIds[index]!,
    objectId,
    objectType: objectTypes[index] ?? 'place',
    title: `Stop ${index + 1}`,
    order: index,
  }));
}

/** A complete Collection body whose review belongs to draft revision 2 (create, then bind). */
function collectionBody(
  options: {
    readonly acknowledged?: readonly string[];
    readonly objectTypes?: readonly string[];
    readonly reviewedRevision?: number;
  } = {},
) {
  return standCollectionBody({
    coverMediaId: 'asset-cover',
    items: items(options.objectTypes),
    reviewedRevision: options.reviewedRevision ?? 2,
    ...(options.acknowledged === undefined ? {} : { acknowledged: options.acknowledged }),
  });
}

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

const publish = (submissionId: EntityId, pointerRevision: number) => ({
  schemaVersion: 1,
  commandType: 'publishApprovedRevision',
  idempotencyKey: key('publish'),
  payload: { submissionId, expectedPointerRevision: pointerRevision },
});

const activate = (contentId: EntityId, publishedRevisionId: EntityId, pointerRevision: number) => ({
  schemaVersion: 1,
  commandType: 'activatePublishedRevision',
  idempotencyKey: key('activate'),
  payload: { contentId, publishedRevisionId, expectedPointerRevision: pointerRevision },
});

const withdraw = (contentId: EntityId, pointerRevision: number) => ({
  schemaVersion: 1,
  commandType: 'withdrawPublication',
  idempotencyKey: key('withdraw'),
  payload: { contentId, expectedPointerRevision: pointerRevision, mode: 'withdraw' },
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

/** A Collection draft with the full body saved at revision 2. */
async function boundDraft(content: ContentPublicationService, body: Record<string, unknown>) {
  const draft = await succeeded<{ draftId: EntityId; contentId: EntityId }>(
    content.execute(actorA, create('collection')),
  );
  const bound = await succeeded<{ revision: number }>(
    content.execute(actorA, {
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: key('bind'),
      payload: { draftId: draft.draftId, expectedRevision: 1, body },
    }),
  );
  assert.equal(bound.revision, 2);
  return { ...draft, revision: bound.revision };
}

/** What a refused command must leave untouched: pointer, revisions and effects. */
function stateOf(repository: InMemoryContentRepository, contentId: EntityId) {
  const snapshot = repository.snapshot();
  return {
    pointer: snapshot.pointers.find((item) => item.contentId === contentId) ?? null,
    revisions: snapshot.revisions.filter((item) => item.contentId === contentId),
    submissions: snapshot.submissions.filter((item) => item.contentId === contentId),
    effects: snapshot.effects,
  };
}

const stableKey = (index: number) => `place:${members[index]}`;

const emulatorSets: readonly (readonly ContentTypeId[])[] = [
  [],
  ['event'],
  ['place'],
  ['activity'],
  ['collection'],
  ['event', 'place', 'activity'],
  ['place', 'collection'],
  ['event', 'place', 'activity', 'collection'],
];

void test('Collection authoring needs its own type in the set; Rental stays disabled', async () => {
  for (const enabled of emulatorSets) {
    const content = service(new InMemoryContentRepository(), enabled, new FakeMembership());
    const result = await content.execute(actorA, create('collection'));
    if (enabled.includes('collection'))
      assert.equal(result.kind, 'succeeded', JSON.stringify(enabled));
    else assert.equal((result as { code?: string }).code, 'type_disabled', JSON.stringify(enabled));
    await refusedWith(
      content.execute(actorA, create('rental')),
      'type_disabled',
      `rental with ${JSON.stringify(enabled)}`,
    );
  }
});

void test('without the Catalog membership port a complete Collection fails closed', async () => {
  const body = collectionBody();
  const without = service(new InMemoryContentRepository(), ['collection']);
  const draft = await boundDraft(without, body);
  await refusedWith(
    without.execute(actorA, submit(draft.draftId, draft.revision)),
    'validation_failed',
    'no membership authority',
  );
  // Control: the same body passes when Catalog answers that every item is ready.
  const membership = new FakeMembership();
  const content = service(new InMemoryContentRepository(), ['collection'], membership);
  const ready = await boundDraft(content, body);
  await succeeded(content.execute(actorA, submit(ready.draftId, ready.revision)));
  assert.deepEqual(
    membership.asked,
    members.map((objectId) => ({ objectType: 'place', objectId, marketId: 'LV' })),
  );
});

void test('every allowed item type is asked by its own type; none is decided by Content', async () => {
  const membership = new FakeMembership();
  const content = service(new InMemoryContentRepository(), ['collection'], membership);
  const objectTypes = ['rental', 'bookableSession', 'route'];
  const draft = await boundDraft(content, collectionBody({ objectTypes }));
  await succeeded(content.execute(actorA, submit(draft.draftId, draft.revision)));
  assert.deepEqual(
    membership.asked.map((item) => item.objectType),
    objectTypes,
  );
  // The answer is Catalog's alone: the same types with no publication are refused.
  for (const objectId of members) membership.statuses.set(objectId, 'unknown');
  const unknown = await boundDraft(content, collectionBody({ objectTypes }));
  await refusedWith(
    content.execute(actorA, submit(unknown.draftId, unknown.revision)),
    'validation_failed',
    'types without publications',
  );
});

void test('a withheld item needs exactly the author’s acknowledgement', async () => {
  const membership = new FakeMembership();
  membership.statuses.set(members[1], 'withheld');
  const content = service(new InMemoryContentRepository(), ['collection'], membership);
  const cases: ReadonlyArray<readonly [string, readonly string[], 'succeeded' | 'refused']> = [
    ['not acknowledged', [], 'refused'],
    ['a ready item acknowledged instead', [stableKey(0)], 'refused'],
    ['too much acknowledged', [stableKey(0), stableKey(1)], 'refused'],
    ['exactly the withheld item', [stableKey(1)], 'succeeded'],
  ];
  for (const [label, acknowledged, outcome] of cases) {
    const draft = await boundDraft(content, collectionBody({ acknowledged }));
    const result = content.execute(actorA, submit(draft.draftId, draft.revision));
    if (outcome === 'succeeded') await succeeded(result);
    else await refusedWith(result, 'validation_failed', label);
  }
  // A review of another draft revision is stale even when its keys match.
  const stale = await boundDraft(
    content,
    collectionBody({ acknowledged: [stableKey(1)], reviewedRevision: 1 }),
  );
  await refusedWith(
    content.execute(actorA, submit(stale.draftId, stale.revision)),
    'validation_failed',
    'stale review',
  );
});

void test('unknown and forbidden references and a Catalog outage are refused, even when acknowledged', async () => {
  for (const status of ['unknown', 'forbidden', 'unavailable', new Error('down')] as const) {
    const membership = new FakeMembership();
    membership.statuses.set(members[2], status);
    const content = service(new InMemoryContentRepository(), ['collection'], membership);
    const draft = await boundDraft(content, collectionBody({ acknowledged: [stableKey(2)] }));
    await refusedWith(
      content.execute(actorA, submit(draft.draftId, draft.revision)),
      'validation_failed',
      String(status),
    );
  }
});

void test('publish asks Catalog again: a change after approval refuses and changes nothing', async () => {
  for (const status of ['unknown', 'forbidden', 'unavailable', 'withheld'] as const) {
    const repository = new InMemoryContentRepository();
    const membership = new FakeMembership();
    const content = service(repository, ['collection'], membership);
    const draft = await boundDraft(content, collectionBody());
    const submission = await succeeded<{ submissionId: EntityId }>(
      content.execute(actorA, submit(draft.draftId, draft.revision)),
    );
    // After approval the referenced object changes; the review acknowledged nothing.
    membership.statuses.set(members[0], status);
    const before = stateOf(repository, draft.contentId);
    await refusedWith(
      content.execute(actorA, publish(submission.submissionId, 0)),
      'validation_failed',
      `publish after ${status}`,
    );
    assert.deepEqual(stateOf(repository, draft.contentId), before, status);
    // Restored, the same approved submission publishes.
    membership.statuses.delete(members[0]);
    await succeeded(content.execute(actorA, publish(submission.submissionId, 0)));
  }
});

void test('activation tolerates natural decay but refuses hard references and an outage', async () => {
  const repository = new InMemoryContentRepository();
  const membership = new FakeMembership();
  const content = service(repository, ['collection'], membership);
  const draft = await boundDraft(content, collectionBody());
  const submission = await succeeded<{ submissionId: EntityId }>(
    content.execute(actorA, submit(draft.draftId, draft.revision)),
  );
  const published = await succeeded<{ publishedRevisionId: EntityId }>(
    content.execute(actorA, publish(submission.submissionId, 0)),
  );
  await succeeded(content.execute(actorA, withdraw(draft.contentId, 1)));

  for (const status of ['unknown', 'forbidden', 'unavailable'] as const) {
    membership.statuses.set(members[1], status);
    const before = stateOf(repository, draft.contentId);
    await refusedWith(
      content.execute(actorA, activate(draft.contentId, published.publishedRevisionId, 2)),
      'validation_failed',
      `activate with ${status}`,
    );
    assert.deepEqual(stateOf(repository, draft.contentId), before, status);
  }
  // An item hidden by its owner since publication does not block (CLG §3.10),
  // although the revision's review acknowledged nothing.
  membership.statuses.set(members[1], 'withheld');
  const asked = membership.asked.length;
  const pointer = await succeeded<{ visibility: string; currentPublishedRevisionId: string }>(
    content.execute(actorA, activate(draft.contentId, published.publishedRevisionId, 2)),
  );
  assert.equal(pointer.visibility, 'visible');
  assert.equal(pointer.currentPublishedRevisionId, published.publishedRevisionId);
  assert.equal(membership.asked.length, asked + members.length);
});

void test('with Collection switched off, authoring is refused and the owner can still hide and read', async () => {
  const repository = new InMemoryContentRepository();
  const membership = new FakeMembership();
  const on = service(repository, ['event', 'collection'], membership);
  const draft = await boundDraft(on, collectionBody());
  const first = await succeeded<{ submissionId: EntityId }>(
    on.execute(actorA, submit(draft.draftId, draft.revision)),
  );
  const published = await succeeded<{ publishedRevisionId: EntityId }>(
    on.execute(actorA, publish(first.submissionId, 0)),
  );
  const revised = await succeeded<{ revision: number }>(
    on.execute(actorA, {
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: key('revise'),
      payload: {
        draftId: draft.draftId,
        expectedRevision: draft.revision,
        body: collectionBody({ reviewedRevision: 3 }),
      },
    }),
  );
  const second = await succeeded<{ submissionId: EntityId }>(
    on.execute(actorA, submit(draft.draftId, revised.revision)),
  );

  const off = service(repository, ['event'], membership);
  const asked = membership.asked.length;
  await refusedWith(off.execute(actorA, create('collection')), 'type_disabled', 'create');
  await refusedWith(
    off.execute(actorA, {
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: key('update-off'),
      payload: { draftId: draft.draftId, expectedRevision: revised.revision, body: {} },
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
    off.execute(actorA, publish(second.submissionId, 1)),
    'type_disabled',
    'publish',
  );
  await refusedWith(
    off.execute(actorA, activate(draft.contentId, published.publishedRevisionId, 1)),
    'type_disabled',
    'activate',
  );
  // Refused before any membership question.
  assert.equal(membership.asked.length, asked);
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
  await succeeded(off.execute(actorA, withdraw(draft.contentId, 1)));
  const status = await succeeded<{ pointer: { visibility: string } }>(
    off.query(actorA, {
      schemaVersion: 1,
      queryType: 'getPublicationStatus',
      payload: { contentId: draft.contentId },
    }),
  );
  assert.equal(status.pointer.visibility, 'withdrawn');
});

void test('membership is asked only for Collection, once per distinct reference, never for an oversized list', async () => {
  const membership = new FakeMembership();
  const content = service(new InMemoryContentRepository(), ['place', 'collection'], membership);
  // A Place is never a membership question.
  const place = await succeeded<{ draftId: EntityId }>(content.execute(actorA, create('place')));
  const bound = await succeeded<{ revision: number }>(
    content.execute(actorA, {
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: key('place-bind'),
      payload: {
        draftId: place.draftId,
        expectedRevision: 1,
        body: standPlaceBody({
          submittedByUserId: userA,
          coverMediaId: 'asset-place-cover',
          galleryMediaIds: [],
        }),
      },
    }),
  );
  await succeeded(content.execute(actorA, submit(place.draftId, bound.revision)));
  assert.equal(membership.asked.length, 0);

  // A duplicated reference is asked once (the validator refuses the duplicate).
  const body = collectionBody();
  const duplicated = {
    ...body,
    items: [
      ...(body.items as unknown[]),
      { ...(body.items as Record<string, unknown>[])[0], id: ulid(299), order: 3 },
    ],
  };
  const draft = await boundDraft(content, duplicated);
  await refusedWith(
    content.execute(actorA, submit(draft.draftId, draft.revision)),
    'validation_failed',
    'duplicate item',
  );
  assert.equal(membership.asked.length, members.length);

  // Over the validator's ceiling the body never reaches storage (the 64 KiB
  // Content body bound is lower), so no oversized list is ever resolved.
  const many = Array.from({ length: collectionRuleConfig.maxItems + 1 }, (_, index) => ({
    id: ulid(10_000 + index),
    ref: { objectId: ulid(20_000 + index), objectType: 'place' },
    snapshot: { title: `Stop ${index}` },
    sourceStatus: 'ready',
    order: index,
  }));
  const oversized = await succeeded<{ draftId: EntityId }>(
    content.execute(actorA, create('collection')),
  );
  await refusedWith(
    content.execute(actorA, {
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: key('oversized'),
      payload: { draftId: oversized.draftId, expectedRevision: 1, body: { ...body, items: many } },
    }),
    'validation_failed',
    'oversized body',
  );
  assert.equal(membership.asked.length, members.length);
});
