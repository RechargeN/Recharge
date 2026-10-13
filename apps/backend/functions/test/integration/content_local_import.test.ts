// D4 §2 (LOCAL_IMPORT_D4_AMENDMENT.md): a user's local import source maps to
// exactly one Content draft. Importing it again under any key returns that
// draft; the same source for another type is a conflict; another author's
// equal local key is another draft; a type switched off is refused before any
// lookup; nothing about it changes delegated imports or plain drafts.
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
  #next = 12000;
  newId(): EntityId {
    this.#next += 1;
    return ulid(this.#next);
  }
}

const userA = ulid(1);
const userB = ulid(3);
const actorA: ContentActor = { userId: userA, sessionId: ulid(2) };
const actorB: ContentActor = { userId: userB, sessionId: ulid(4) };

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

class NoReview implements ModerationDispositionPort {
  verifyDisposition() {
    return Promise.resolve({ verified: false } as const);
  }
  profileFor() {
    return Promise.resolve({
      available: true,
      profileId: 'default',
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

function service(repository: InMemoryContentRepository, enabled: readonly ContentTypeId[]) {
  return new ContentPublicationService({
    repository,
    eligibility: new AllowAll(),
    referenceData: new EmulatorSyntheticReferenceData(),
    moderation: new NoReview(),
    media: new ReadyMedia(),
    clock: new FakeClock(new Date('2026-10-13T10:00:00.000Z')),
    ids: new SequentialIds(),
    enabledTypes: new Set(enabled),
  });
}

let counter = 0;
const create = (
  owner: EntityId,
  typeId: string,
  importSourceKey?: string,
  body: Record<string, unknown> = {},
) => ({
  schemaVersion: 1,
  commandType: 'createDraft',
  idempotencyKey: `d4-create-${(counter += 1)}`,
  payload: {
    typeId,
    publisherRef: { type: 'user', id: owner },
    marketId: 'LV',
    body,
    ...(importSourceKey === undefined ? {} : { importSourceKey }),
  },
});

async function draftOf(promise: Promise<{ kind: string; data?: unknown; code?: string }>) {
  const result = await promise;
  assert.equal(result.kind, 'succeeded', JSON.stringify(result));
  return result.data as { draftId: string; contentId: string; revision: number };
}

void test('the same local source imports into one draft; another type is a conflict', async () => {
  const repository = new InMemoryContentRepository();
  const content = service(repository, ['place', 'collection']);
  const source = 'loc_1760000000000';
  const first = await draftOf(content.execute(actorA, create(userA, 'place', source)));
  const again = await draftOf(content.execute(actorA, create(userA, 'place', source)));
  assert.equal(again.draftId, first.draftId);
  assert.deepEqual(await content.execute(actorA, create(userA, 'collection', source)), {
    kind: 'rejected',
    code: 'idempotency_conflict',
  });
  assert.equal(repository.snapshot().drafts.length, 1);
});

void test("another author's equal local key is another draft; plain drafts are never deduplicated", async () => {
  const repository = new InMemoryContentRepository();
  const content = service(repository, ['place']);
  const source = 'loc_1760000000001';
  const a = await draftOf(content.execute(actorA, create(userA, 'place', source)));
  const b = await draftOf(content.execute(actorB, create(userB, 'place', source)));
  assert.notEqual(a.draftId, b.draftId);
  const plain1 = await draftOf(content.execute(actorA, create(userA, 'place')));
  const plain2 = await draftOf(content.execute(actorA, create(userA, 'place')));
  assert.notEqual(plain1.draftId, plain2.draftId);
  assert.equal(repository.snapshot().drafts.length, 4);
});

void test('a type switched off is refused before the import lookup, and the draft stays readable', async () => {
  const repository = new InMemoryContentRepository();
  const on = service(repository, ['place']);
  const source = 'loc_1760000000002';
  const first = await draftOf(on.execute(actorA, create(userA, 'place', source)));
  const off = service(repository, ['event']);
  assert.deepEqual(await off.execute(actorA, create(userA, 'place', source)), {
    kind: 'rejected',
    code: 'type_disabled',
  });
  const read = await off.query(actorA, {
    schemaVersion: 1,
    queryType: 'getDraft',
    payload: { draftId: first.draftId },
  });
  assert.equal(read.kind, 'succeeded');
  assert.equal((read.data as { importSourceKey?: string }).importSourceKey, source);
});

void test('an imported draft keeps its body: the replay never resets it', async () => {
  const repository = new InMemoryContentRepository();
  const content = service(repository, ['place']);
  const source = 'loc_1760000000003';
  const first = await draftOf(content.execute(actorA, create(userA, 'place', source)));
  const updated = await draftOf(
    content.execute(actorA, {
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: 'd4-update-1',
      payload: { draftId: first.draftId, expectedRevision: 1, body: { title: 'Imported' } },
    }),
  );
  // A replay with a different body in the create is still the imported draft as stored.
  const replay = await draftOf(
    content.execute(actorA, create(userA, 'place', source, { title: 'Other' })),
  );
  assert.equal(replay.draftId, first.draftId);
  assert.equal(replay.revision, updated.revision);
  assert.deepEqual((replay as unknown as { body: unknown }).body, { title: 'Imported' });
});

// D4.1 §2.1: generations. A first import is generation 1 and replays as D4; after
// a rollback a new approval opens generation 2, to which the D4 rules apply again.
void test('D4.1: a rolled-back source opens the next generation; the D4 rules hold within it', async () => {
  const repository = new InMemoryContentRepository();
  const content = service(repository, ['place', 'collection']);
  const source = 'loc_1760000000004';
  const first = await draftOf(content.execute(actorA, create(userA, 'place', source)));
  assert.equal((first as { importGeneration?: number }).importGeneration, 1);
  const rolledBack = await content.execute(actorA, {
    schemaVersion: 1,
    commandType: 'rollbackImportedDraft',
    idempotencyKey: 'd4-1-rollback-1',
    payload: {
      draftId: first.draftId,
      importSourceKey: source,
      generation: 1,
      expectedRevision: 1,
    },
  });
  assert.equal(rolledBack.kind, 'succeeded');
  const second = await draftOf(content.execute(actorA, create(userA, 'place', source)));
  assert.notEqual(second.draftId, first.draftId);
  assert.equal((second as { importGeneration?: number }).importGeneration, 2);
  assert.equal(
    (await draftOf(content.execute(actorA, create(userA, 'place', source)))).draftId,
    second.draftId,
  );
  assert.deepEqual(await content.execute(actorA, create(userA, 'collection', source)), {
    kind: 'rejected',
    code: 'idempotency_conflict',
  });
  // Another author's equal key is untouched by A's generations.
  const b = await draftOf(content.execute(actorB, create(userB, 'place', source)));
  assert.equal((b as { importGeneration?: number }).importGeneration, 1);
  assert.equal(repository.snapshot().drafts.length, 3);
});
