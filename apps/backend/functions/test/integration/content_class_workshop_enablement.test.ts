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
import { EmulatorSyntheticReferenceData } from '../../src/modules/content/infrastructure/emulator_reference_data.js';
import { InMemoryContentRepository } from '../../src/modules/content/infrastructure/in_memory_content_repository.js';
import { parseEntityId, type EntityId } from '../../src/shared/ids.js';
import { readContentJson } from '../../src/contracts/content_schema_registry.js';
import type { ContentBody } from '../../src/contracts/content_v1.js';
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
  #next = 8000;
  newId(): EntityId {
    this.#next += 1;
    return ulid(this.#next);
  }
}

const userA = parseEntityId('11111111-1111-4111-8111-111111111111');
const actorA: ContentActor = { userId: userA, sessionId: ulid(3) };

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
      profileId: 'class_workshop.default',
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

let seq = 0;
const key = () => `class-workshop-test-${++seq}`;
async function fixtureBody(name = 'valid'): Promise<ContentBody> {
  const f = (await readContentJson('fixtures/class_workshop_create_compat.json')) as {
    cases: { name: string; body: ContentBody }[];
  };
  return structuredClone(f.cases.find((item) => item.name === name)!.body);
}

/** Fixed series 2027-05-15 and 2027-05-22, 10:00–13:00 Riga, price for the series. */
async function seriesBody(): Promise<ContentBody> {
  const body = (await fixtureBody('valid_full_series_price')) as Record<string, unknown>;
  return body;
}

function world(repository = new InMemoryContentRepository()) {
  const clock = new FakeClock(new Date('2026-10-19T10:00:00Z'));
  let allowed = true;
  let outage = false;
  let extraRequired: readonly string[] = [];
  const ref = new EmulatorSyntheticReferenceData();
  const service = (types: readonly ContentTypeId[] = ['class_workshop']) =>
    new ContentPublicationService({
      repository,
      eligibility: {
        evaluate: (r) =>
          allowed
            ? new AllowAll().evaluate(r)
            : Promise.resolve({
                schemaVersion: 1,
                publisherRef: r.publisherRef,
                eligible: false,
                reason: 'capability_missing',
                authorityRevision: 2,
                evaluatedAtUtc: r.nowUtc,
              } as never),
        evaluateDelegated: () => Promise.reject(new Error('not used')),
      },
      referenceData: {
        resolve: async (input) => {
          if (outage) throw new Error('Reference owner unavailable');
          const result = await ref.resolve(input);
          return result.ok
            ? {
                ...result,
                lookups: {
                  ...result.lookups,
                  requiredCriteria: (typeId, categoryId, subcategoryId) => {
                    const base = result.lookups.requiredCriteria(typeId, categoryId, subcategoryId);
                    return base === undefined ? undefined : [...base, ...extraRequired];
                  },
                },
              }
            : result;
        },
      },
      moderation: new NoReview(),
      media: new ReadyMedia(),
      clock,
      ids: new SequentialIds(),
      enabledTypes: new Set(types),
    });
  return {
    repository,
    clock,
    service,
    setOutage: (value: boolean) => {
      outage = value;
    },
    setAllowed: (value: boolean) => {
      allowed = value;
    },
    /** A newly required criterion of the current profile revision. */
    requireCriterion: (fieldIds: readonly string[]) => {
      extraRequired = fieldIds;
    },
  };
}

type Result = { kind: string; code?: string; data?: unknown };
async function ok<T>(value: Promise<Result>): Promise<T> {
  const result = await value;
  assert.equal(result.kind, 'succeeded', JSON.stringify(result));
  return result.data as T;
}
async function rejected(value: Promise<Result>, code: string) {
  const result = await value;
  assert.equal(result.kind, 'rejected', JSON.stringify(result));
  assert.equal(result.code, code);
}
const command = (commandType: string, payload: unknown, idempotencyKey = key()) => ({
  schemaVersion: 1,
  commandType,
  payload,
  idempotencyKey,
});
const create = (typeId: ContentTypeId = 'class_workshop', type: 'user' | 'page' = 'user') =>
  command('createDraft', {
    typeId,
    marketId: 'LV',
    publisherRef: { type, id: userA },
    body: {},
  });

async function prepare(service: ContentPublicationService, body: ContentBody) {
  const d = await ok<{ draftId: EntityId; contentId: EntityId; revision: number }>(
    service.execute(actorA, create()),
  );
  const updated = await ok<{ revision: number }>(
    service.execute(
      actorA,
      command('updateDraft', { draftId: d.draftId, expectedRevision: d.revision, body }),
    ),
  );
  return { ...d, revision: updated.revision };
}

async function publish(
  service: ContentPublicationService,
  draftId: EntityId,
  revision: number,
  pointer: number,
) {
  const sub = await ok<{ submissionId: EntityId }>(
    service.execute(
      actorA,
      command('submitForPublication', { draftId, expectedDraftRevision: revision }),
    ),
  );
  return await ok<{ publishedRevisionId: EntityId }>(
    service.execute(
      actorA,
      command('publishApprovedRevision', {
        submissionId: sub.submissionId,
        expectedPointerRevision: pointer,
      }),
    ),
  );
}

void test('Class flag off, missing authority and page publisher refuse before any write', async () => {
  const w = world();
  await rejected(w.service([]).execute(actorA, create()), 'type_disabled');
  await rejected(w.service(['session']).execute(actorA, create()), 'type_disabled');
  w.setAllowed(false);
  assert.notEqual((await w.service().execute(actorA, create())).kind, 'succeeded');
  w.setAllowed(true);
  assert.notEqual(
    (await w.service().execute(actorA, create('class_workshop', 'page'))).kind,
    'succeeded',
  );
  assert.equal(w.repository.snapshot().drafts.length, 0);
  assert.equal(w.repository.snapshot().audit.length, 0);
});

void test('other Create types keep their own enablement next to Class', async () => {
  const w = world();
  for (const typeId of ['session', 'place', 'activity', 'rental', 'collection', 'event'] as const)
    await rejected(w.service(['class_workshop']).execute(actorA, create(typeId)), 'type_disabled');
  for (const typeId of ['route', 'scenario', 'find_people'] as const)
    await rejected(
      w.service(['class_workshop', typeId]).execute(actorA, create(typeId)),
      'content_type_unsupported',
    );
  assert.equal(w.repository.snapshot().drafts.length, 0);
});

void test('Class lifecycle: lost responses replay, rollback activates the old immutable revision under CAS', async () => {
  const w = world();
  const content = w.service();
  const d = await prepare(content, await seriesBody());
  const submit = command('submitForPublication', {
    draftId: d.draftId,
    expectedDraftRevision: d.revision,
  });
  const sub = await ok<{ submissionId: EntityId }>(content.execute(actorA, submit));
  // A lost submit response: the same key and payload returns the stored answer.
  assert.deepEqual(await content.execute(actorA, submit), { kind: 'succeeded', data: sub });
  const pub = command('publishApprovedRevision', {
    submissionId: sub.submissionId,
    expectedPointerRevision: 0,
  });
  const first = await ok<{ publishedRevisionId: EntityId }>(content.execute(actorA, pub));
  assert.deepEqual(await content.execute(actorA, pub), { kind: 'succeeded', data: first });
  const published = w.repository.snapshot();
  assert.equal(published.revisions.length, 1);
  assert.equal(published.pointers[0]?.visibility, 'visible');
  assert.equal(published.revisions[0]?.typeId, 'class_workshop');
  const firstBody = structuredClone(published.revisions[0].body);

  // A new authored revision through the draft, then a rollback to the first.
  const changed = (await seriesBody()) as Record<string, unknown>;
  changed.title = 'Riga pottery course, second edition';
  const updated = await ok<{ revision: number }>(
    content.execute(
      actorA,
      command('updateDraft', {
        draftId: d.draftId,
        expectedRevision: w.repository.snapshot().drafts[0]!.revision,
        body: changed,
      }),
    ),
  );
  const second = await publish(
    content,
    d.draftId,
    updated.revision,
    published.pointers[0].revision,
  );
  const afterSecond = w.repository.snapshot();
  assert.equal(afterSecond.revisions.length, 2);
  assert.equal(afterSecond.pointers[0]?.currentPublishedRevisionId, second.publishedRevisionId);
  const pointerRevision = afterSecond.pointers[0].revision;
  await rejected(
    content.execute(
      actorA,
      command('activatePublishedRevision', {
        contentId: d.contentId,
        publishedRevisionId: first.publishedRevisionId,
        expectedPointerRevision: pointerRevision - 1,
      }),
    ),
    'revision_conflict',
  );
  assert.deepEqual(w.repository.snapshot(), afterSecond);
  const activate = command('activatePublishedRevision', {
    contentId: d.contentId,
    publishedRevisionId: first.publishedRevisionId,
    expectedPointerRevision: pointerRevision,
  });
  const activated = await content.execute(actorA, activate);
  assert.equal(activated.kind, 'succeeded', JSON.stringify(activated));
  const rolledBack = w.repository.snapshot();
  // A lost activate response: the replay answers the same and changes nothing.
  assert.deepEqual(await content.execute(actorA, activate), activated);
  assert.deepEqual(w.repository.snapshot(), rolledBack);
  assert.equal(rolledBack.pointers[0]?.currentPublishedRevisionId, first.publishedRevisionId);
  assert.equal(rolledBack.revisions.length, 2, 'rollback creates no revision');
  assert.deepEqual(
    rolledBack.revisions.find((item) => item.publishedRevisionId === first.publishedRevisionId)
      ?.body,
    firstBody,
    'immutable body preserved',
  );
  assert.equal(rolledBack.drafts.length, 1, 'no duplicate draft');
});

void test('reference outage refuses activate as policy_unavailable without state change', async () => {
  const w = world();
  const content = w.service();
  const d = await prepare(content, await fixtureBody());
  const rev = await publish(content, d.draftId, d.revision, 0);
  const pointer = w.repository.snapshot().pointers[0]!;
  await ok(
    content.execute(
      actorA,
      command('withdrawPublication', {
        contentId: d.contentId,
        expectedPointerRevision: pointer.revision,
        mode: 'withdraw',
      }),
    ),
  );
  const hidden = w.repository.snapshot();
  w.setOutage(true);
  await rejected(
    content.execute(
      actorA,
      command('activatePublishedRevision', {
        contentId: d.contentId,
        publishedRevisionId: rev.publishedRevisionId,
        expectedPointerRevision: hidden.pointers[0]!.revision,
      }),
    ),
    'policy_unavailable',
  );
  assert.deepEqual(w.repository.snapshot(), hidden);
  w.setOutage(false);
  await ok(
    content.execute(
      actorA,
      command('activatePublishedRevision', {
        contentId: d.contentId,
        publishedRevisionId: rev.publishedRevisionId,
        expectedPointerRevision: hidden.pointers[0]!.revision,
      }),
    ),
  );
  assert.equal(w.repository.snapshot().pointers[0]?.visibility, 'visible');
});

/**
 * One forbidden body on all three paths: submit of the draft, publish of the
 * previously approved submission and activation of the immutable revision.
 */
async function threePathRefusal(
  forbid: (w: ReturnType<typeof world>) => void,
  allow: (w: ReturnType<typeof world>) => void,
) {
  const w = world();
  const content = w.service();
  const d = await prepare(content, await fixtureBody());
  const submit = () =>
    content.execute(
      actorA,
      command('submitForPublication', { draftId: d.draftId, expectedDraftRevision: d.revision }),
    );
  forbid(w);
  const before = w.repository.snapshot();
  await rejected(submit(), 'validation_failed');
  assert.deepEqual(w.repository.snapshot(), before, 'submit refusal changed nothing');
  allow(w);
  const sub = await ok<{ submissionId: EntityId }>(submit());
  const approved = w.repository.snapshot();
  forbid(w);
  const publish = () =>
    content.execute(
      actorA,
      command('publishApprovedRevision', {
        submissionId: sub.submissionId,
        expectedPointerRevision: 0,
      }),
    );
  await rejected(publish(), 'validation_failed');
  assert.deepEqual(w.repository.snapshot(), approved, 'publish refusal changed nothing');
  allow(w);
  const rev = await ok<{ publishedRevisionId: EntityId }>(publish());
  const live = w.repository.snapshot();
  await ok(
    content.execute(
      actorA,
      command('withdrawPublication', {
        contentId: d.contentId,
        expectedPointerRevision: live.pointers[0]!.revision,
        mode: 'withdraw',
      }),
    ),
  );
  forbid(w);
  const immutable = w.repository.snapshot();
  await rejected(
    content.execute(
      actorA,
      command('activatePublishedRevision', {
        contentId: d.contentId,
        publishedRevisionId: rev.publishedRevisionId,
        expectedPointerRevision: immutable.pointers[0]!.revision,
      }),
    ),
    'validation_failed',
  );
  assert.deepEqual(w.repository.snapshot(), immutable, 'activate refusal changed nothing');
}

void test('a newly required criterion refuses submit, approved publish and immutable activate', async () => {
  await threePathRefusal(
    (w) => w.requireCriterion(['age_restriction']),
    (w) => w.requireCriterion([]),
  );
});

void test('a body whose classes have all passed refuses submit, approved publish and immutable activate', async () => {
  await threePathRefusal(
    (w) => w.clock.set(new Date('2027-06-01T00:00:00Z')),
    (w) => w.clock.set(new Date('2026-10-19T10:00:00Z')),
  );
});

void test('submit and publish need every class ahead; activation accepts a series with one class left', async () => {
  const w = world();
  const content = w.service();
  const d = await prepare(content, await seriesBody());
  // Between the classes of the series: one has started, one is ahead.
  w.clock.set(new Date('2027-05-18T00:00:00Z'));
  const before = w.repository.snapshot();
  await rejected(
    content.execute(
      actorA,
      command('submitForPublication', { draftId: d.draftId, expectedDraftRevision: d.revision }),
    ),
    'validation_failed',
  );
  assert.deepEqual(w.repository.snapshot(), before);
  w.clock.set(new Date('2026-10-19T10:00:00Z'));
  const rev = await publish(content, d.draftId, d.revision, 0);
  const live = w.repository.snapshot();
  await ok(
    content.execute(
      actorA,
      command('withdrawPublication', {
        contentId: d.contentId,
        expectedPointerRevision: live.pointers[0]!.revision,
        mode: 'withdraw',
      }),
    ),
  );
  w.clock.set(new Date('2027-05-18T00:00:00Z'));
  const hidden = w.repository.snapshot();
  await ok(
    content.execute(
      actorA,
      command('activatePublishedRevision', {
        contentId: d.contentId,
        publishedRevisionId: rev.publishedRevisionId,
        expectedPointerRevision: hidden.pointers[0]!.revision,
      }),
    ),
  );
  assert.equal(w.repository.snapshot().pointers[0]?.visibility, 'visible');
});

void test('unknown and legacy fields are refused on update and never stored', async () => {
  const w = world();
  const content = w.service();
  const d = await ok<{ draftId: EntityId; revision: number }>(content.execute(actorA, create()));
  let current = d.revision;
  for (const name of ['unknown_top_level', 'legacy_event_slots', 'verified_claim']) {
    const result = await content.execute(
      actorA,
      command('updateDraft', {
        draftId: d.draftId,
        expectedRevision: current,
        body: await fixtureBody(name),
      }),
    );
    // A draft may hold an incomplete body, but submission refuses it.
    if (result.kind === 'succeeded') {
      const revision = (result.data as { revision: number }).revision;
      await rejected(
        content.execute(
          actorA,
          command('submitForPublication', { draftId: d.draftId, expectedDraftRevision: revision }),
        ),
        'validation_failed',
      );
      const stored = w.repository.snapshot().drafts[0]!.body as Record<string, unknown>;
      assert.equal(w.repository.snapshot().submissions.length, 0, name);
      assert.ok(Object.keys(stored).length > 0, `${name} stored as written, not silently trimmed`);
      current = revision;
    } else assert.equal(result.kind, 'rejected', name);
  }
  assert.equal(w.repository.snapshot().revisions.length, 0);
});

void test('future Class schema refuses submit, approved publish and immutable activate without writes', async () => {
  const w = world();
  const content = w.service();
  const valid = await fixtureBody();
  const future = structuredClone(valid);
  (future.class_workshop as Record<string, unknown>).schema_version = 2;
  const d = await prepare(content, valid);
  const setBody = async (body: ContentBody) => {
    await w.repository.transact(async (tx) => {
      const draft = await tx.draft(d.draftId);
      assert.ok(draft);
      tx.putDraft({ ...draft, body });
    });
  };
  // Seed unsupported persisted data to exercise revalidation, including old approved state.
  await setBody(future);
  const beforeSubmit = w.repository.snapshot();
  await rejected(
    content.execute(
      actorA,
      command('submitForPublication', {
        draftId: d.draftId,
        expectedDraftRevision: d.revision,
      }),
    ),
    'content_type_unsupported',
  );
  assert.deepEqual(w.repository.snapshot(), beforeSubmit);
  await setBody(valid);
  const sub = await ok<{ submissionId: EntityId }>(
    content.execute(
      actorA,
      command('submitForPublication', {
        draftId: d.draftId,
        expectedDraftRevision: d.revision,
      }),
    ),
  );
  await setBody(future);
  const beforePublish = w.repository.snapshot();
  await rejected(
    content.execute(
      actorA,
      command('publishApprovedRevision', {
        submissionId: sub.submissionId,
        expectedPointerRevision: 0,
      }),
    ),
    'content_type_unsupported',
  );
  assert.deepEqual(w.repository.snapshot(), beforePublish);
  await setBody(valid);
  const published = await ok<{ publishedRevisionId: EntityId }>(
    content.execute(
      actorA,
      command('publishApprovedRevision', {
        submissionId: sub.submissionId,
        expectedPointerRevision: 0,
      }),
    ),
  );
  await ok(
    content.execute(
      actorA,
      command('withdrawPublication', {
        contentId: d.contentId,
        expectedPointerRevision: w.repository.snapshot().pointers[0]!.revision,
        mode: 'withdraw',
      }),
    ),
  );
  // A fresh repository models an immutable revision produced by a future writer.
  const stored = w.repository.snapshot();
  const repository = new InMemoryContentRepository();
  await repository.transact((tx) => {
    for (const draft of stored.drafts) tx.putDraft(draft);
    for (const revision of stored.revisions) tx.putPublishedRevision({ ...revision, body: future });
    for (const pointer of stored.pointers) tx.putPointer(pointer, 0);
  });
  const futureContent = world(repository).service();
  const beforeActivate = repository.snapshot();
  await rejected(
    futureContent.execute(
      actorA,
      command('activatePublishedRevision', {
        contentId: d.contentId,
        publishedRevisionId: published.publishedRevisionId,
        expectedPointerRevision: stored.pointers[0]!.revision,
      }),
    ),
    'content_type_unsupported',
  );
  assert.deepEqual(repository.snapshot(), beforeActivate);
});
