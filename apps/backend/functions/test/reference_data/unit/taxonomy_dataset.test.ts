import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  readLocalTaxonomy,
  taxonomyRevisionId,
  taxonomyPair,
} from '../../../src/modules/reference_data/infrastructure/local_taxonomy_reader.js';
void test('canonical generated snapshot has complete structural registry and exact revision', () => {
  const read = readLocalTaxonomy(taxonomyRevisionId);
  assert.ok(read.ok);
  assert.equal(read.dataset.categories.length, 28);
  assert.equal(
    read.dataset.categories.reduce((n, c) => n + c.subcategories.length, 0),
    530,
  );
  assert.equal(read.dataset.profiles.length, 22);
  assert.equal(
    taxonomyPair(read.dataset, 'outdoor_nature_walking', 'forest_walk')?.applicableTypes.includes(
      'activity',
    ),
    true,
  );
  assert.equal(
    taxonomyPair(read.dataset, 'wellness_recharge', 'sauna')?.applicableTypes.includes('activity'),
    false,
  );
  for (const category of read.dataset.categories) {
    assert.equal(
      new Set(category.subcategories.map((s) => s.id)).size,
      category.subcategories.length,
    );
    for (const sub of category.subcategories) {
      const profile = read.dataset.profiles.find((p) => p.id === sub.profileId);
      assert.ok(profile);
      assert.ok(profile.requiredFieldIds.every((id) => profile.fieldIds.includes(id)));
    }
  }
});
void test('unknown/unavailable/corrupt revision is explicit and never latest', () => {
  assert.deepEqual(readLocalTaxonomy('test-only-tx-activity-1'), {
    ok: false,
    code: 'taxonomy_revision_unknown',
  });
  assert.deepEqual(readLocalTaxonomy(taxonomyRevisionId, null), {
    ok: false,
    code: 'taxonomy_revision_unavailable',
  });
  assert.deepEqual(readLocalTaxonomy(taxonomyRevisionId, '{}'), {
    ok: false,
    code: 'taxonomy_integrity_failed',
  });
});
