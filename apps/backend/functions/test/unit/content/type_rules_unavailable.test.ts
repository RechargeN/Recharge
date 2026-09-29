import assert from 'node:assert/strict';
import test from 'node:test';

import { contentTypeIds, type ContentTypeId } from '../../../src/contracts/content_v1.js';
import { ContentPublicationService } from '../../../src/modules/content/application/content_publication_service.js';
import {
  isContentTypeAvailable,
  resolveContentType,
} from '../../../src/modules/content/domain/content_type_registry.js';
import { InMemoryContentRepository } from '../../../src/modules/content/infrastructure/in_memory_content_repository.js';
import { parseEntityId } from '../../../src/shared/ids.js';
import { FakeClock } from '../../support/fake_clock.js';

/**
 * Types that stay registered but unavailable after 2.2b. Each has an explicit
 * reason; none may be served by a generic or Event fallback validator.
 */
const stillUnavailable = [
  ['session', 'spec_not_approved'],
  ['class_workshop', 'spec_not_approved'],
  ['find_people', 'consent_gate_pending'],
  ['route', 'dependency_pending'],
  ['scenario', 'dependency_pending'],
] as const;

const actor = {
  userId: parseEntityId('018FQ2Z8Q9N4M7K2T6V3W1X5YA'),
  sessionId: parseEntityId('018FQ2Z8Q9N4M7K2T6V3W1X5YB'),
};

function serviceWithAllTypesEnabled() {
  const repository = new InMemoryContentRepository();
  let counter = 0;
  const service = new ContentPublicationService({
    repository,
    // Ports must never be reached for an unavailable type.
    eligibility: {
      evaluate: () => {
        throw new Error('eligibility must not be evaluated for an unavailable type');
      },
    },
    referenceData: {
      resolve: () => {
        throw new Error('reference data must not be resolved for an unavailable type');
      },
    },
    moderation: {
      verifyDisposition: () => {
        throw new Error('moderation must not be consulted for an unavailable type');
      },
      profileFor: () => {
        throw new Error('moderation must not be consulted for an unavailable type');
      },
    },
    media: {
      check: () => {
        throw new Error('media must not be checked for an unavailable type');
      },
    },
    clock: new FakeClock(new Date('2026-09-29T10:00:00.000Z')),
    ids: {
      newId: () => {
        counter += 1;
        return parseEntityId(`01HZZZZZZZZZZZZZZZZZZZ${String(counter).padStart(4, '0')}`);
      },
    },
    enabledTypes: new Set<ContentTypeId>(contentTypeIds),
  });
  return { service, repository };
}

for (const [typeId, reason] of stillUnavailable)
  void test(`${typeId} is registered but unavailable (${reason}) and has no validator`, async () => {
    const entry = resolveContentType(typeId);
    assert.ok(entry);
    assert.equal(isContentTypeAvailable(entry), false);
    assert.equal(entry.validate, undefined);
    assert.equal(entry.mediaIds, undefined);
    assert.equal(entry.validatorRevision, 'unavailable');
    assert.equal(entry.availability.status, 'unavailable');
    if (entry.availability.status === 'unavailable') {
      assert.equal(entry.availability.reason, reason);
      assert.ok((entry.availability.dependency ?? '').length > 0);
    }

    // Even with the type flag enabled and any plausible body, nothing is created
    // and no port is reached: there is no generic bypass.
    const { service, repository } = serviceWithAllTypesEnabled();
    const result = await service.execute(actor, {
      schemaVersion: 1,
      commandType: 'createDraft',
      idempotencyKey: `create-${typeId}-1`,
      payload: {
        typeId,
        publisherRef: { type: 'user', id: actor.userId },
        marketId: 'LV',
        body: { title: 'Looks valid enough', description: 'anything at all' },
      },
    });
    assert.deepEqual(result, { kind: 'rejected', code: 'content_type_unsupported' });
    assert.equal(repository.snapshot().drafts.length, 0);
    assert.equal(repository.snapshot().audit.length, 0);
  });

void test("these five types are never served by another type's rules", () => {
  const rules = new Set(
    contentTypeIds
      .map((typeId) => resolveContentType(typeId))
      .filter((item) => item !== null && item.validate !== undefined)
      .map((item) => item?.validate),
  );
  for (const [typeId] of stillUnavailable) {
    const entry = resolveContentType(typeId);
    assert.equal(entry?.validate === undefined || !rules.has(undefined), true);
    assert.equal(entry?.validate, undefined, typeId);
  }
  // Quick Plan is not a Content type at all.
  assert.equal(resolveContentType('quick_plan'), null);
});

void test('route, scenario and quick plan stay separate source authorities', () => {
  const route = resolveContentType('route');
  const scenario = resolveContentType('scenario');
  assert.ok(route && scenario);
  assert.notEqual(route.sourceAuthority, scenario.sourceAuthority);
  assert.match(route.sourceAuthority, /BCK-11/);
  assert.match(scenario.sourceAuthority, /BCK-10/);
  assert.equal(route.moderationProfileId, 'route.default');
  assert.equal(scenario.moderationProfileId, 'scenario.default');
  assert.equal(resolveContentType('quick_plan'), null);
  assert.equal(resolveContentType('route_scenario'), null);
});
