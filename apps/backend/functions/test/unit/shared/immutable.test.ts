import assert from 'node:assert/strict';
import { test } from 'node:test';

import { deepFreeze } from '../../../src/shared/immutable.js';

void test('deep freezes nested arrays and records without cloning', () => {
  const source = { market: 'lv', flags: [{ id: 'booking', enabled: false }] };
  const frozen = deepFreeze(source);

  assert.equal(frozen, source);
  assert.equal(Object.isFrozen(frozen), true);
  assert.equal(Object.isFrozen(frozen.flags), true);
  assert.equal(Object.isFrozen(frozen.flags[0]), true);
  assert.throws(() => {
    source.flags[0]!.enabled = true;
  }, TypeError);
});

void test('handles repeated references and cycles safely', () => {
  const node: { value: number; self?: unknown } = { value: 1 };
  node.self = node;
  assert.doesNotThrow(() => deepFreeze(node));
  assert.equal(Object.isFrozen(node), true);
});
