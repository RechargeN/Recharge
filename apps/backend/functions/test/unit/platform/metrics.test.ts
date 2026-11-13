import assert from 'node:assert/strict';
import test from 'node:test';

import { InMemoryMetricsPort } from '../../../src/platform/observability/metrics.js';

void test('metrics expose a closed low-cardinality vocabulary', () => {
  const metrics = new InMemoryMetricsPort();
  metrics.record({
    name: 'platform_pointer_swap_total',
    value: 1,
    dimensions: { environment: 'local', market: 'LV', outcome: 'success' },
  });
  assert.equal(metrics.records.length, 1);
  assert.throws(
    () =>
      metrics.record({
        name: 'user_email_metric' as never,
        value: 1,
        dimensions: { environment: 'local', market: 'LV', outcome: 'success' },
      }),
    /metric_invalid/,
  );
});
