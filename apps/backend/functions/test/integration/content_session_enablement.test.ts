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
  #next = 7000;
  newId(): EntityId {
    this.#next += 1;
    return ulid(this.#next);
  }
}

const userA = parseEntityId('11111111-1111-4111-8111-111111111111');
const actorA: ContentActor = { userId: userA, sessionId: ulid(2) };
// A second participant of the same Page with the publish capability (Q3).

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
      profileId: 'session.default',
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
const key = () => `session-test-${++seq}`;
async function body() {
  const f = (await readContentJson('fixtures/session_create_compat.json')) as {
    cases: { body: ContentBody }[];
  };
  return structuredClone(f.cases[0]!.body);
}
function world() {
  const repository = new InMemoryContentRepository();
  let window: number | undefined = 30;
  let allowed = true;
  let revision: string | undefined;
  let outage = false;
  const media = new ReadyMedia();
  const ref = new EmulatorSyntheticReferenceData();
  const service = (types: readonly ContentTypeId[] = ['session']) =>
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
                revisions:
                  revision === undefined
                    ? result.revisions
                    : { ...result.revisions, marketConfigRevisionId: revision },
                lookups: { ...result.lookups, sessionProjectionWindowDays: () => window },
              }
            : result;
        },
      },
      moderation: new NoReview(),
      media,
      clock: new FakeClock(new Date('2026-10-18T10:00:00Z')),
      ids: new SequentialIds(),
      enabledTypes: new Set(types),
    });
  return {
    repository,
    service,
    setOutage: (value: boolean) => {
      outage = value;
    },
    setRevision: (value: string | undefined) => {
      revision = value;
    },
    setWindow: (n: number | undefined) => {
      window = n;
    },
    setAllowed: (b: boolean) => {
      allowed = b;
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
async function prepare(service: ContentPublicationService, b: ContentBody) {
  const d = await ok<{ draftId: EntityId; contentId: EntityId; revision: number }>(
    service.execute(
      actorA,
      command('createDraft', {
        typeId: 'session',
        marketId: 'LV',
        publisherRef: { type: 'user', id: userA },
        body: {},
      }),
    ),
  );
  const updated = await ok<{ revision: number }>(
    service.execute(
      actorA,
      command('updateDraft', { draftId: d.draftId, expectedRevision: d.revision, body: b }),
    ),
  );
  return { ...d, revision: updated.revision };
}
void test('Session flag off and missing authority refuse; page cannot establish publisher scope', async () => {
  const w = world();
  const create = command('createDraft', {
    typeId: 'session',
    marketId: 'LV',
    publisherRef: { type: 'user', id: userA },
    body: {},
  });
  await rejected(w.service([]).execute(actorA, create), 'type_disabled');
  w.setAllowed(false);
  const denied = await w.service().execute(actorA, { ...create, idempotencyKey: key() });
  assert.notEqual(denied.kind, 'succeeded');
  w.setAllowed(true);
  const page = await w.service().execute(
    actorA,
    command('createDraft', {
      typeId: 'session',
      marketId: 'LV',
      publisherRef: { type: 'page', id: userA },
      body: {},
    }),
  );
  assert.notEqual(page.kind, 'succeeded');
  assert.equal(w.repository.snapshot().drafts.length, 0);
});
void test('Session lifecycle, lost response replay, immutable activation, CAS and current reference policy', async () => {
  const w = world();
  const content = w.service();
  const d = await prepare(content, await body());
  const submit = command('submitForPublication', {
    draftId: d.draftId,
    expectedDraftRevision: d.revision,
  });
  const sub = await ok<{ submissionId: EntityId }>(content.execute(actorA, submit));
  assert.deepEqual(await content.execute(actorA, submit), { kind: 'succeeded', data: sub });
  const pub = command('publishApprovedRevision', {
    submissionId: sub.submissionId,
    expectedPointerRevision: 0,
  });
  const rev = await ok<{ publishedRevisionId: EntityId }>(content.execute(actorA, pub));
  const saved = w.repository.snapshot();
  assert.equal(saved.revisions.length, 1);
  assert.equal(saved.pointers[0]?.visibility, 'visible');
  assert.deepEqual(await content.execute(actorA, pub), { kind: 'succeeded', data: rev });
  assert.equal(w.repository.snapshot().revisions.length, 1);
  const pointer = saved.pointers[0];
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
  const hidden = w.repository.snapshot().pointers[0]!;
  assert.equal(hidden.visibility, 'withdrawn');
  const activate = () =>
    command('activatePublishedRevision', {
      contentId: d.contentId,
      publishedRevisionId: rev.publishedRevisionId,
      expectedPointerRevision: hidden.revision,
    });
  const before = w.repository.snapshot();
  w.setWindow(31);
  await rejected(content.execute(actorA, activate()), 'validation_failed');
  assert.deepEqual(w.repository.snapshot(), before);
  w.setWindow(undefined);
  await rejected(content.execute(actorA, activate()), 'validation_failed');
  assert.deepEqual(w.repository.snapshot(), before);
  w.setWindow(30);
  w.setOutage(true);
  await rejected(content.execute(actorA, activate()), 'policy_unavailable');
  assert.deepEqual(w.repository.snapshot(), before);
  w.setOutage(false);
  w.setRevision('test-only-mc-lv-2');
  await rejected(content.execute(actorA, activate()), 'source_revision_stale');
  assert.deepEqual(w.repository.snapshot(), before);
  w.setRevision(undefined);
  await rejected(
    content.execute(
      actorA,
      command('activatePublishedRevision', {
        contentId: d.contentId,
        publishedRevisionId: rev.publishedRevisionId,
        expectedPointerRevision: hidden.revision - 1,
      }),
    ),
    'revision_conflict',
  );
  await ok(content.execute(actorA, activate()));
  assert.equal(w.repository.snapshot().pointers[0]?.visibility, 'visible');
  assert.deepEqual(
    w.repository.snapshot().revisions,
    saved.revisions,
    'immutable body and schedule snapshot preserved',
  );
});
void test('same current-policy violation refuses submit, approved publish and immutable activate without state changes', async () => {
  const w = world();
  const content = w.service();
  const d = await prepare(content, await body());
  w.setWindow(31);
  const before = w.repository.snapshot();
  await rejected(
    content.execute(
      actorA,
      command('submitForPublication', { draftId: d.draftId, expectedDraftRevision: d.revision }),
    ),
    'validation_failed',
  );
  assert.deepEqual(w.repository.snapshot(), before);
  w.setWindow(30);
  const sub = await ok<{ submissionId: EntityId }>(
    content.execute(
      actorA,
      command('submitForPublication', { draftId: d.draftId, expectedDraftRevision: d.revision }),
    ),
  );
  const approved = w.repository.snapshot();
  w.setWindow(31);
  await rejected(
    content.execute(
      actorA,
      command('publishApprovedRevision', {
        submissionId: sub.submissionId,
        expectedPointerRevision: 0,
      }),
    ),
    'validation_failed',
  );
  assert.deepEqual(w.repository.snapshot(), approved);
  w.setWindow(30);
  const rev = await ok<{ publishedRevisionId: EntityId }>(
    content.execute(
      actorA,
      command('publishApprovedRevision', {
        submissionId: sub.submissionId,
        expectedPointerRevision: 0,
      }),
    ),
  );
  w.setWindow(31);
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
  assert.deepEqual(w.repository.snapshot(), immutable);
});

void test('Session immutable source is owner-authorized; private exception data is never a public read', async () => {
  const w = world(),
    content = w.service();
  const source = await body();
  (source.session as Record<string, unknown>).exceptions = [
    {
      id: ulid(900),
      start_date_local: '2026-10-25',
      end_date_local: '2026-10-25',
      all_day: true,
      private_note: 'owner-only operational reason',
      created_by_user_id: userA,
      created_at_utc: '2026-10-18T00:00:00.000Z',
    },
  ];
  const d = await prepare(content, source);
  const sub = await ok<{ submissionId: EntityId }>(
    content.execute(
      actorA,
      command('submitForPublication', { draftId: d.draftId, expectedDraftRevision: d.revision }),
    ),
  );
  await ok(
    content.execute(
      actorA,
      command('publishApprovedRevision', {
        submissionId: sub.submissionId,
        expectedPointerRevision: 0,
      }),
    ),
  );
  const before = w.repository.snapshot();
  const request = {
    schemaVersion: 1,
    queryType: 'getPublishedRevision',
    payload: { contentId: d.contentId },
  };
  const foreign: ContentActor = { userId: ulid(901), sessionId: ulid(902) };
  // Even a permissive dependency cannot turn the private source into a public DTO.
  await rejected(content.query(foreign, request), 'not_found');
  const own = await ok<{ body: ContentBody; bodyHash: string }>(content.query(actorA, request));
  assert.deepEqual(own.body, source);
  assert.equal(own.bodyHash, before.revisions[0]!.bodyHash);
  w.setAllowed(false);
  assert.notEqual((await content.query(actorA, request)).kind, 'succeeded');
  assert.deepEqual(
    w.repository.snapshot(),
    before,
    'read refusal never changes the immutable source or pointer',
  );
});
