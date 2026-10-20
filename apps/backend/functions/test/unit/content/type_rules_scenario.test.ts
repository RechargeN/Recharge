import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

import {
  scenarioDistributionHash,
  validateScenarioBody,
  validateScenarioDistribution,
} from '../../../src/modules/content/domain/type_rules/scenario_rules.js';
import type { ContentValidationContext } from '../../../src/modules/content/domain/type_rules/validation_context.js';
import { mapScenarioDistribution } from '../../../src/modules/quick_plan/scenario_distribution.js';
import { i3ScenarioDraft } from '../../support/scenario_i3_world.js';

const placeId = randomUUID();
const ready = () => 'ready' as const;

function mapped(draft = i3ScenarioDraft({ placeId }), mode: 'public' | 'unlisted' = 'public') {
  const result = mapScenarioDistribution(draft, mode, ready);
  assert.equal(result.ok, true, JSON.stringify(result));
  if (!result.ok) throw new Error('unreachable');
  return result;
}

void test('the allowlist mapper drops every private, collaboration and foreign field', () => {
  const { distribution, contentHash } = mapped();
  const json = JSON.stringify(distribution);
  for (const marker of ['PRIVATE-', 'SNAPSHOT-title', 'Catalog place location', 'pace'])
    assert.equal(json.includes(marker), false, marker);
  assert.equal(contentHash, scenarioDistributionHash(distribution));
  const items = distribution.items as Record<string, unknown>[];
  // The unscheduled private stop stays private; the catalog stop is a reference.
  assert.equal(items.length, 5);
  const catalog = items.find((item) => (item.stop as { type: string }).type === 'catalog')!;
  assert.deepEqual(catalog.stop, { type: 'catalog', objectType: 'place', objectId: placeId });
  const locations = distribution.locations as {
    disclosure: string;
    point: { latitude: number };
    address: unknown;
  }[];
  assert.equal(locations.length, 3);
  const approximate = locations.find((l) => l.disclosure === 'approximate')!;
  assert.equal(approximate.point.latitude, 56.95);
  assert.equal(approximate.address, null);
  const legs = distribution.legs as { polyline: unknown[] }[];
  assert.equal(legs[0]!.polyline.length, 2, 'two own public places keep their line');
  assert.equal(legs[1]!.polyline.length, 0, 'an approximate endpoint drops the line');
  assert.deepEqual(distribution.budget, { currencyCode: 'EUR', fromMinor: 500, unknownCount: 4 });
});

void test('a private scheduled stop, a Route stop and a dated public template fail closed', () => {
  const draft = i3ScenarioDraft({ placeId }) as {
    scenario: { locations: { disclosure: string }[] };
  };
  draft.scenario.locations[0]!.disclosure = 'private';
  const priv = mapScenarioDistribution(draft, 'public', ready);
  assert.equal(priv.ok, false);
  assert.ok(!priv.ok && priv.issues.includes('scenario.private_location'));
  const route = mapScenarioDistribution(
    i3ScenarioDraft({ placeId, routeStop: randomUUID() }),
    'public',
    ready,
  );
  assert.ok(!route.ok && route.issues.includes('scenario.route_item_unsupported'));
  const dated = mapScenarioDistribution(i3ScenarioDraft({ placeId, dated: true }), 'public', ready);
  assert.ok(!dated.ok && dated.issues.includes('scenario.dated_public_unsupported'));
  // Unlisted may be dated (SP-07).
  assert.equal(
    mapScenarioDistribution(i3ScenarioDraft({ placeId, dated: true }), 'unlisted', ready).ok,
    true,
  );
});

void test('stops must be ready now; an outage is unresolved, never assumed', () => {
  const draft = i3ScenarioDraft({ placeId });
  const gone = mapScenarioDistribution(draft, 'public', () => 'unavailable');
  assert.ok(!gone.ok && gone.issues.includes('scenario.stop_unavailable'));
  const outage = mapScenarioDistribution(draft, 'public', () => undefined);
  assert.ok(!outage.ok && outage.issues.includes('scenario.stops_unresolved'));
});

void test('the validator refuses any field outside the allowlist at every level', () => {
  const { distribution } = mapped();
  const extra = structuredClone(distribution) as Record<string, unknown> & {
    items: Record<string, unknown>[];
  };
  extra.participants = ['someone'];
  extra.items[0]!.privateNote = 'x';
  const issues = validateScenarioDistribution(extra, 'public', ready);
  assert.ok(issues.includes('scenario.unknown_field:participants'));
  assert.ok(issues.includes('scenario.item.unknown_field:privateNote'));
  assert.ok(
    validateScenarioDistribution(distribution, 'unlisted', ready).includes('scenario.mode'),
  );
});

void test('fewer than two active items and an ambiguous alternative group are refused', () => {
  const { distribution } = mapped(i3ScenarioDraft({ placeId, minimal: true }));
  const one = structuredClone(distribution) as { items: unknown[]; days: { itemIds: unknown[] }[] };
  one.items = one.items.slice(0, 1);
  one.days[0]!.itemIds = one.days[0]!.itemIds.slice(0, 1);
  assert.ok(validateScenarioDistribution(one, 'public', ready).includes('scenario.min_items'));
  const alt = structuredClone(distribution) as { items: Record<string, unknown>[] };
  const group = randomUUID();
  for (const item of alt.items)
    Object.assign(item, { role: 'alternative', alternativeGroupId: group, selected: true });
  assert.ok(
    validateScenarioDistribution(alt, 'public', ready).includes('scenario.alternative_selection'),
  );
});

const context = (overrides: Partial<ContentValidationContext> = {}): ContentValidationContext => ({
  typeId: 'scenario',
  marketId: 'LV',
  publisherRef: { type: 'user', id: 'author' as never },
  createdByUserId: 'author',
  actorUserId: 'author',
  nowUtc: '2026-10-20T00:00:00.000Z',
  draftRevision: 1,
  publishedObjects: { statusOf: () => 'ready' },
  market: { currencyCode: 'EUR', timezoneId: 'Europe/Riga' },
  lookups: {
    supportsLocale: (locale) => locale === 'en',
    subcategoryApplies: () => true,
    requiredCriteria: () => [],
    pointInServiceArea: () => true,
  },
  ...overrides,
});

function body(
  distribution: Record<string, unknown>,
  hash = scenarioDistributionHash(distribution),
) {
  return {
    title: distribution.title,
    shortDescription: 'A relaxed walk through the old town',
    fullDescription: 'Five stops with lunch, a viewpoint and the cathedral.',
    contentLocale: 'en',
    media: { rightsConfirmed: true },
    scenario: {
      ref: {
        scenarioId: '0' + 'A'.repeat(25),
        scenarioRevisionId: randomUUID(),
        contentHash: hash,
      },
      distribution,
    },
  };
}

void test('the Content body is bound by hash, title and personal publisher', () => {
  const { distribution } = mapped();
  assert.deepEqual(validateScenarioBody(body(distribution), context()), []);
  assert.ok(
    validateScenarioBody(body(distribution, 'f'.repeat(64)), context()).includes(
      'scenario.distribution_hash',
    ),
  );
  assert.ok(
    validateScenarioBody({ ...body(distribution), title: 'Other title' }, context()).includes(
      'scenario.title_mismatch',
    ),
  );
  assert.ok(
    validateScenarioBody(
      body(distribution),
      context({ publisherRef: { type: 'page', id: 'p' as never } }),
    ).includes('scenario_publisher_ineligible'),
  );
  assert.ok(
    validateScenarioBody(
      body(distribution),
      context({ publishedObjects: { statusOf: () => 'unavailable' } }),
    ).includes('scenario.stop_unavailable'),
  );
});
