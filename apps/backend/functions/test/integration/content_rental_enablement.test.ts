// D3.3 (RENTAL_D3_3_PUBLICATION_AMENDMENT.md §2, §3): the Content service with
// in-memory ports under the Emulator authoring sets and the TEST-ONLY Rental
// policy. Rental needs its own type in the set; Collection stays disabled; the
// cover stays required; a pair without policy fails closed; an expired
// confirmation blocks publish (Q5); only the attesting user can publish (Q3);
// re-activating a Rental revision is closed (Q4) and leaves pointer, revisions
// and effects untouched; with Rental switched off, authoring is refused while
// the owner's hide and reads keep working.
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
  ReferenceDataPort,
  ReferenceResolution,
} from '../../src/modules/content/application/ports/reference_data_port.js';
import { emulatorCompositionRules } from '../../src/modules/content/infrastructure/emulator_activity_dependencies.js';
import { emulatorActivationClosedTypes } from '../../src/modules/content/infrastructure/emulator_rental_dependencies.js';
import { EmulatorSyntheticReferenceData } from '../../src/modules/content/infrastructure/emulator_reference_data.js';
import { InMemoryContentRepository } from '../../src/modules/content/infrastructure/in_memory_content_repository.js';
import { parseEntityId, type EntityId } from '../../src/shared/ids.js';
import { plusDays, standRentalBody } from '../stand/stand_content_rental.js';
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
  #next = 7000;
  newId(): EntityId {
    this.#next += 1;
    return ulid(this.#next);
  }
}

const userA = ulid(1);
const actorA: ContentActor = { userId: userA, sessionId: ulid(2) };
// A second participant of the same Page with the publish capability (Q3).
const actorB: ContentActor = { userId: ulid(3), sessionId: ulid(4) };

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
      profileId: 'rental.default',
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

/** The Emulator reference data, with the Rental policy switchable per test step. */
class SwitchableReference implements ReferenceDataPort {
  readonly #inner = new EmulatorSyntheticReferenceData();
  mode: 'as_is' | 'policy_unavailable' | 'policy_version_changed' = 'as_is';

  async resolve(input: Parameters<ReferenceDataPort['resolve']>[0]): Promise<ReferenceResolution> {
    const resolved = await this.#inner.resolve(input);
    if (!resolved.ok || input.typeId !== 'rental' || this.mode === 'as_is') return resolved;
    const rentalPolicy =
      this.mode === 'policy_unavailable'
        ? () => undefined
        : (categoryId: string, subcategoryId: string) => {
            const policy = resolved.lookups.rentalPolicy?.(categoryId, subcategoryId);
            return policy === undefined ? undefined : { ...policy, policyVersion: '2.0' };
          };
    return { ...resolved, lookups: { ...resolved.lookups, rentalPolicy } };
  }
}

const start = new Date('2026-10-12T10:00:00.000Z');
const anchor = '2026-10-12T00:00:00.000Z';

function world(
  enabled: readonly ContentTypeId[] = ['rental'],
  options: { readonly activationClosed?: boolean } = {},
) {
  const repository = new InMemoryContentRepository();
  const clock = new FakeClock(start);
  const reference = new SwitchableReference();
  const make = (closed: boolean, types: readonly ContentTypeId[] = enabled) =>
    new ContentPublicationService({
      repository,
      eligibility: new AllowAll(),
      referenceData: reference,
      moderation: new NoReview(),
      media: new ReadyMedia(),
      clock,
      ids: new SequentialIds(),
      enabledTypes: new Set(types),
      // As composed by the Emulator authoring path (content_entry.ts).
      compositionRules: emulatorCompositionRules,
      ...(closed ? { activationClosedTypes: emulatorActivationClosedTypes } : {}),
    });
  return {
    repository,
    clock,
    reference,
    content: make(options.activationClosed ?? true),
    /** The same state without the activation closure (control only). */
    open: make(false),
    with: (types: readonly ContentTypeId[]) => make(true, types),
  };
}

let counter = 0;
const key = (label: string) => `d33-${label}-${(counter += 1)}`;
const rentalBody = (overrides: Record<string, unknown> = {}, anchorUtc = anchor) => ({
  ...standRentalBody({ actorUserId: userA, mediaRefs: ['asset-cover'], anchorUtc }),
  ...overrides,
});

type Service = ContentPublicationService;
type Result = { kind: string; data?: unknown; code?: string };

async function succeeded<T>(promise: Promise<Result>): Promise<T> {
  const result = await promise;
  assert.equal(result.kind, 'succeeded', `${result.kind}:${String(result.code)}`);
  return result.data as T;
}

async function refusedWith(promise: Promise<Result>, code: string, label: string) {
  const result = await promise;
  assert.equal(result.kind, 'rejected', `${label}: ${JSON.stringify(result)}`);
  assert.equal(result.code, code, label);
}

const create = (typeId = 'rental') => ({
  schemaVersion: 1,
  commandType: 'createDraft',
  idempotencyKey: key(`create-${typeId}`),
  payload: { typeId, publisherRef: { type: 'page', id: ulid(9) }, marketId: 'LV', body: {} },
});
const update = (draftId: EntityId, expectedRevision: number, body: unknown) => ({
  schemaVersion: 1,
  commandType: 'updateDraft',
  idempotencyKey: key('update'),
  payload: { draftId, expectedRevision, body },
});
const submit = (draftId: EntityId, expectedDraftRevision: number) => ({
  schemaVersion: 1,
  commandType: 'submitForPublication',
  idempotencyKey: key('submit'),
  payload: { draftId, expectedDraftRevision },
});
const publish = (submissionId: EntityId, expectedPointerRevision: number) => ({
  schemaVersion: 1,
  commandType: 'publishApprovedRevision',
  idempotencyKey: key('publish'),
  payload: { submissionId, expectedPointerRevision },
});
const activate = (contentId: EntityId, publishedRevisionId: EntityId, pointerRevision: number) => ({
  schemaVersion: 1,
  commandType: 'activatePublishedRevision',
  idempotencyKey: key('activate'),
  payload: { contentId, publishedRevisionId, expectedPointerRevision: pointerRevision },
});

/** A draft with the full body saved by A; returns its ids and revision. */
async function bound(content: Service, body: unknown = rentalBody()) {
  const draft = await succeeded<{ draftId: EntityId; contentId: EntityId }>(
    content.execute(actorA, create()),
  );
  const saved = await succeeded<{ revision: number }>(
    content.execute(actorA, update(draft.draftId, 1, body)),
  );
  return { ...draft, revision: saved.revision };
}

function stateOf(repository: InMemoryContentRepository, contentId: EntityId) {
  const snapshot = repository.snapshot();
  return {
    pointer: snapshot.pointers.find((item) => item.contentId === contentId) ?? null,
    revisions: snapshot.revisions.filter((item) => item.contentId === contentId),
    effects: snapshot.effects,
  };
}

const sets: readonly (readonly ContentTypeId[])[] = [
  [],
  ['event'],
  ['place', 'activity'],
  ['rental'],
  ['event', 'place', 'activity', 'rental'],
];

void test('Rental authoring needs its own type in the set; Collection stays disabled', async () => {
  for (const enabled of sets) {
    const { content } = world(enabled);
    const rental = await content.execute(actorA, create('rental'));
    if (enabled.includes('rental')) assert.equal(rental.kind, 'succeeded', JSON.stringify(enabled));
    else assert.equal((rental as Result).code, 'type_disabled', JSON.stringify(enabled));
    await refusedWith(
      content.execute(actorA, create('collection')),
      'type_disabled',
      `collection with ${JSON.stringify(enabled)}`,
    );
  }
});

void test('the cover stays required and a pair without policy fails closed', async () => {
  const { content } = world();
  for (const [label, body] of [
    ['no cover', rentalBody({ mediaRefs: [] })],
    ['pair without policy', rentalBody({ categoryId: 'sport', subcategoryId: 'yoga' })],
    [
      'category outside the whitelist',
      rentalBody({ categoryId: 'art_culture_museums', subcategoryId: 'museum' }),
    ],
    ['pair unknown to BCK-20', rentalBody({ subcategoryId: 'not_a_subcategory' })],
  ] as const) {
    const draft = await bound(content, body);
    await refusedWith(
      content.execute(actorA, submit(draft.draftId, draft.revision)),
      'validation_failed',
      label,
    );
  }
  const valid = await bound(content);
  await succeeded(content.execute(actorA, submit(valid.draftId, valid.revision)));
});

void test('Q5: an expired confirmation blocks publish and leaves the approved draft stuck (open decision)', async () => {
  const { content, clock, repository } = world();
  const draft = await bound(content);
  const first = await succeeded<{ submissionId: EntityId }>(
    content.execute(actorA, submit(draft.draftId, draft.revision)),
  );
  // Review took eight days: the confirmation is older than the policy window.
  clock.set(new Date(Date.parse(anchor) + 8 * 24 * 60 * 60 * 1000 + 10 * 60 * 60 * 1000));
  const before = stateOf(repository, draft.contentId);
  await refusedWith(
    content.execute(actorA, publish(first.submissionId, 0)),
    'validation_failed',
    'stale publish',
  );
  assert.deepEqual(stateOf(repository, draft.contentId), before);
  // Current Content lifecycle (§10 open decision): the approved submission is
  // final and the draft stays `submitted`, so it cannot take a fresh
  // confirmation for a new review.
  const current = await succeeded<{ revision: number; status: string }>(
    content.query(actorA, {
      schemaVersion: 1,
      queryType: 'getDraft',
      payload: { draftId: draft.draftId },
    }),
  );
  assert.equal(current.status, 'submitted');
  await refusedWith(
    content.execute(
      actorA,
      update(draft.draftId, current.revision, rentalBody({}, plusDays(anchor, 8))),
    ),
    'revision_conflict',
    'edit after an approved submission',
  );
  // The only path today: a new Rental draft with a fresh confirmation and review.
  const replacement = await bound(content, rentalBody({}, plusDays(anchor, 8)));
  const second = await succeeded<{ submissionId: EntityId }>(
    content.execute(actorA, submit(replacement.draftId, replacement.revision)),
  );
  await succeeded(content.execute(actorA, publish(second.submissionId, 0)));
});

void test('Q3: a second Page participant cannot publish what A attested; A can', async () => {
  const { content, repository } = world();
  const draft = await bound(content);
  const submission = await succeeded<{ submissionId: EntityId }>(
    content.execute(actorA, submit(draft.draftId, draft.revision)),
  );
  const before = stateOf(repository, draft.contentId);
  await refusedWith(
    content.execute(actorB, publish(submission.submissionId, 0)),
    'validation_failed',
    'publish by B',
  );
  assert.deepEqual(stateOf(repository, draft.contentId), before);
  // B cannot re-attest A's draft either: the draft is bound to its author.
  const rebound = await content.execute(
    actorB,
    update(draft.draftId, draft.revision, rentalBody({}, anchor)),
  );
  assert.equal(rebound.kind, 'rejected', JSON.stringify(rebound));
  await succeeded(content.execute(actorA, publish(submission.submissionId, 0)));
});

/** R1 published, then R2 published: the pointer holds R2 (revision 2). */
async function twoRevisions() {
  const scene = world();
  const { content } = scene;
  const draft = await bound(content);
  const first = await succeeded<{ submissionId: EntityId }>(
    content.execute(actorA, submit(draft.draftId, draft.revision)),
  );
  const r1 = await succeeded<{ publishedRevisionId: EntityId }>(
    content.execute(actorA, publish(first.submissionId, 0)),
  );
  const revised = await succeeded<{ revision: number }>(
    content.execute(
      actorA,
      update(draft.draftId, draft.revision, rentalBody({ title: 'Kipsala sea kayak rental (2)' })),
    ),
  );
  const second = await succeeded<{ submissionId: EntityId }>(
    content.execute(actorA, submit(draft.draftId, revised.revision)),
  );
  await succeeded(content.execute(actorA, publish(second.submissionId, 1)));
  return { ...scene, draft, r1: r1.publishedRevisionId };
}

const conditions: readonly [string, (scene: Awaited<ReturnType<typeof twoRevisions>>) => void][] = [
  ['the policy became unavailable', (scene) => (scene.reference.mode = 'policy_unavailable')],
  ['the policy version changed', (scene) => (scene.reference.mode = 'policy_version_changed')],
  [
    'the confirmation expired',
    (scene) => scene.clock.set(new Date(Date.parse(anchor) + 9 * 24 * 60 * 60 * 1000)),
  ],
];

for (const [label, change] of conditions)
  void test(`Q4: activate of an earlier Rental revision is refused when ${label}; nothing changes`, async () => {
    const scene = await twoRevisions();
    change(scene);
    const before = stateOf(scene.repository, scene.draft.contentId);
    assert.equal(before.pointer?.revision, 2);
    await refusedWith(
      scene.content.execute(actorA, activate(scene.draft.contentId, scene.r1, 2)),
      'type_disabled',
      label,
    );
    assert.deepEqual(stateOf(scene.repository, scene.draft.contentId), before);
    // Control: without the closure the same activation would go through,
    // because activation does not re-run the Rental rules.
    await succeeded(scene.open.execute(actorA, activate(scene.draft.contentId, scene.r1, 2)));
  });

void test('Q4: activation stays closed even when nothing changed; hide still works', async () => {
  const scene = await twoRevisions();
  const before = stateOf(scene.repository, scene.draft.contentId);
  await refusedWith(
    scene.content.execute(actorA, activate(scene.draft.contentId, scene.r1, 2)),
    'type_disabled',
    'activate as is',
  );
  assert.deepEqual(stateOf(scene.repository, scene.draft.contentId), before);
  await succeeded(
    scene.content.execute(actorA, {
      schemaVersion: 1,
      commandType: 'withdrawPublication',
      idempotencyKey: key('withdraw'),
      payload: { contentId: scene.draft.contentId, expectedPointerRevision: 2, mode: 'withdraw' },
    }),
  );
});

void test('with Rental switched off, authoring is refused and the owner can still hide and read', async () => {
  const scene = world(['event', 'rental']);
  const draft = await bound(scene.content);
  const first = await succeeded<{ submissionId: EntityId }>(
    scene.content.execute(actorA, submit(draft.draftId, draft.revision)),
  );
  await succeeded(scene.content.execute(actorA, publish(first.submissionId, 0)));
  const off = scene.with(['event']);
  await refusedWith(off.execute(actorA, create('rental')), 'type_disabled', 'create');
  await refusedWith(
    off.execute(actorA, update(draft.draftId, draft.revision, rentalBody())),
    'type_disabled',
    'update',
  );
  await refusedWith(
    off.execute(actorA, submit(draft.draftId, draft.revision)),
    'type_disabled',
    'submit',
  );
  await succeeded(
    off.query(actorA, {
      schemaVersion: 1,
      queryType: 'getDraft',
      payload: { draftId: draft.draftId },
    }),
  );
  await succeeded(
    off.execute(actorA, {
      schemaVersion: 1,
      commandType: 'withdrawPublication',
      idempotencyKey: key('withdraw-off'),
      payload: { contentId: draft.contentId, expectedPointerRevision: 1, mode: 'withdraw' },
    }),
  );
});
