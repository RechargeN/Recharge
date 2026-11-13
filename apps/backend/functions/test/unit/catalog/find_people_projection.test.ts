// D3.7 Find People Catalog projection: only the server-built public body, the
// ~1 km cell centre as the MapObject point, never private meeting data.
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { readContentJson } from '../../../src/contracts/content_schema_registry.js';
import type { ContentBody } from '../../../src/contracts/content_v1.js';
import {
  projectFact,
  type ContentFact,
  type SourceRevision,
} from '../../../src/modules/catalog/domain/catalog_item.js';
import { parseDiscoverQuery } from '../../../src/modules/catalog/domain/discover_query.js';
import { evaluate } from '../../../src/modules/catalog/domain/evaluation.js';
import { findPeoplePublicBody } from '../../../src/modules/content/domain/type_rules/find_people_rules.js';
import { findPeoplePolicy } from '../../../src/shared/find_people_policy.js';

const policy = {
  precisionMeters: findPeoplePolicy.publicGeoPrecisionMeters,
  policyRevision: findPeoplePolicy.publicGeoPolicyRevision,
};

async function source(): Promise<ContentBody> {
  const fixture = (await readContentJson('fixtures/find_people_create_compat.json')) as {
    cases: { name: string; body: ContentBody }[];
  };
  return structuredClone(fixture.cases.find((item) => item.name === 'valid')!.body);
}

const fact: ContentFact = {
  schemaVersion: 1,
  effectId: 'effect',
  kind: 'ContentPublished',
  contentId: 'content',
  publishedRevisionId: 'revision',
  pointerRevision: 1,
  visibility: 'visible',
  typeId: 'find_people',
  publisherRef: { type: 'user', id: '11111111-1111-4111-8111-111111111111' },
  marketId: 'LV',
  referenceRevisions: {},
  occurredAtUtc: '2026-10-19T10:00:00.000Z',
};

function revision(body: ContentBody): SourceRevision {
  return {
    contentId: 'content',
    publishedRevisionId: 'revision',
    typeId: 'find_people',
    marketId: 'LV',
    referenceRevisions: {},
    publishedAtUtc: '2026-10-19T10:00:00.000Z',
    body: body,
  };
}

const project = (body: ContentBody, findPeopleEnabled = true, visibility = 'consent_limited') =>
  projectFact({
    fact,
    revision: revision(body),
    typeVisibilityPolicy: visibility,
    findPeopleEnabled,
  });

void test('the public body projects to a MapObject at the cell centre with public facts only', async () => {
  const published = findPeoplePublicBody(await source(), policy);
  const result = project(published);
  assert.equal(result.state, 'listed');
  if (result.state !== 'listed' || result.item.typeId !== 'find_people') return;
  const item = result.item;
  const location = (
    published.findPeople as { meeting: { publicLocation: { latitude: number; longitude: number } } }
  ).meeting.publicLocation;
  assert.deepEqual(item.point, { latitude: location.latitude, longitude: location.longitude });
  assert.equal(item.publicGeoPrecisionMeters, 1000);
  assert.equal(item.hostUserId, '11111111-1111-4111-8111-111111111111');
  assert.equal(item.occurrences.length, 1);
  assert.equal(item.coverMediaId, null);
  const text = JSON.stringify(item);
  for (const secret of ['56.95182', '24.08571', 'riverside steps', 'Ķīpsalas iela', 'blue bench'])
    assert.equal(text.includes(secret), false, secret);
});

void test('disabled flag, the private source or an off-grid point never reach the Catalog', async () => {
  const body = await source();
  const published = findPeoplePublicBody(body, policy);
  assert.deepEqual(project(published, false), { state: 'excluded', reason: 'type_disabled' });
  // A private source (exact meeting data) is never projected, even if it reached a revision.
  assert.deepEqual(project(body), { state: 'excluded', reason: 'invalid_projection' });
  const smuggled = structuredClone(published) as {
    findPeople: { meeting: Record<string, unknown> };
  };
  smuggled.findPeople.meeting.exact = { latitude: 56.95182, longitude: 24.08571 };
  assert.deepEqual(project(smuggled as unknown as ContentBody), {
    state: 'excluded',
    reason: 'invalid_projection',
  });
  const offGrid = structuredClone(published) as {
    findPeople: { meeting: { publicLocation: Record<string, number> } };
  };
  offGrid.findPeople.meeting.publicLocation.latitude = 56.95182;
  assert.deepEqual(project(offGrid as unknown as ContentBody), {
    state: 'excluded',
    reason: 'invalid_projection',
  });
  // Without the registry's consent-limited policy the type stays excluded.
  assert.deepEqual(project(published, true, 'private_only'), {
    state: 'excluded',
    reason: 'consent_limited',
  });
});

void test('Discover: type refused unless enabled; time, radius and text apply, price filters do not', async () => {
  const published = findPeoplePublicBody(await source(), policy);
  const listed = project(published);
  assert.equal(listed.state, 'listed');
  if (listed.state !== 'listed') return;
  const query = (extra: Record<string, unknown>) => {
    const parsed = parseDiscoverQuery(
      { schemaVersion: 1, marketId: 'LV', typeIds: ['find_people'], ...extra },
      false,
      false,
      true,
    );
    assert.ok(parsed.ok, JSON.stringify(parsed));
    return parsed.query;
  };
  assert.deepEqual(
    parseDiscoverQuery({ schemaVersion: 1, marketId: 'LV', typeIds: ['find_people'] }),
    { ok: false, kind: 'unsupported', code: 'type_disabled:find_people' },
  );
  const now = Date.parse('2026-10-19T10:00:00.000Z');
  assert.equal(evaluate(listed.item, query({}), now).eligible, true);
  const centre = { latitude: 56.9496, longitude: 24.1052 };
  const near = evaluate(listed.item, query({ geo: { center: centre, radiusKm: 5 } }), now);
  assert.equal(near.eligible, true);
  if (near.eligible) assert.ok((near.distanceMeters ?? 0) > 0);
  assert.equal(
    evaluate(listed.item, query({ geo: { center: centre, radiusKm: 0.5 } }), now).eligible,
    false,
  );
  assert.equal(evaluate(listed.item, query({ literalText: 'daugava' }), now).eligible, true);
  assert.equal(evaluate(listed.item, query({ literalText: 'tennis' }), now).eligible, false);
  assert.deepEqual(evaluate(listed.item, query({ price: { free: true } }), now), {
    eligible: false,
    reason: 'find_people_filter_inapplicable',
  });
  // The request expires with its meeting.
  assert.deepEqual(evaluate(listed.item, query({}), Date.parse('2027-05-15T08:00:00.000Z')), {
    eligible: false,
    reason: 'ended',
  });
});

void test('Scenario and Find People Catalog switches are independent on the common build', () => {
  const query = (typeIds: string[], scenario: boolean, people: boolean) =>
    parseDiscoverQuery({ schemaVersion: 1, marketId: 'LV', typeIds }, false, scenario, people);
  assert.equal(query(['scenario'], true, false).ok, true);
  assert.equal(query(['find_people'], false, true).ok, true);
  assert.equal(query(['scenario', 'find_people'], true, true).ok, true);
  assert.deepEqual(query(['find_people'], true, false), {
    ok: false,
    kind: 'unsupported',
    code: 'type_disabled:find_people',
  });
  assert.deepEqual(query(['scenario'], false, true), {
    ok: false,
    kind: 'unsupported',
    code: 'type_disabled:scenario',
  });
});
