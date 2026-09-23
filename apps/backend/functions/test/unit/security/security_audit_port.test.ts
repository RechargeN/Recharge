import assert from 'node:assert/strict';
import test from 'node:test';

import { InMemorySecurityAuditPort } from '../../../src/security/security_audit_port.js';
import { parseUtcInstant } from '../../../src/shared/utc_instant.js';

void test('security audit persists only the minimized typed record', async () => {
  const port = new InMemorySecurityAuditPort();
  await port.append({
    eventName: 'authorization.decision',
    outcome: 'denied',
    actorHash: 'a'.repeat(64),
    correlationId: 'corr-0001',
    occurredAtUtc: parseUtcInstant('2026-09-21T10:00:00.000Z'),
    reasonCode: 'feature_disabled',
  });
  assert.equal(port.records.length, 1);
  assert.equal('email' in port.records[0]!, false);
  assert.throws(
    () =>
      void port.append({
        eventName: 'authorization.decision',
        outcome: 'denied',
        actorHash: 'raw-user-id',
        correlationId: 'corr-0002',
        occurredAtUtc: parseUtcInstant('2026-09-21T10:00:00.000Z'),
        reasonCode: 'feature_disabled',
      }),
    /security_audit_actor_hash_invalid/,
  );
  assert.throws(
    () =>
      void port.append({
        eventName: 'authorization.decision',
        outcome: 'denied',
        actorHash: null,
        correlationId: 'user@example.com',
        occurredAtUtc: parseUtcInstant('2026-09-21T10:00:00.000Z'),
        reasonCode: 'feature_disabled',
      }),
    /security_audit_correlation_invalid/,
  );
});
