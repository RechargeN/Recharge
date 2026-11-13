import assert from 'node:assert/strict';
import test from 'node:test';

import {
  InMemoryStructuredLogger,
  rejectSensitiveTelemetry,
} from '../../../src/platform/observability/structured_logger.js';

void test('structured logger accepts only bounded operational fields', () => {
  const logger = new InMemoryStructuredLogger();
  logger.write({
    level: 'info',
    eventName: 'platform.config.resolved',
    correlationId: 'corr-0001',
    environmentId: 'local',
    marketId: 'LV',
    capabilityId: 'platform.foundation',
    outcome: 'success',
    code: 'resolved',
    durationMs: 3,
  });
  assert.equal(logger.records.length, 1);
  assert.throws(
    () => rejectSensitiveTelemetry({ nested: { email: 'user@example.test' } }),
    /sensitive_telemetry_field_forbidden/,
  );
});
