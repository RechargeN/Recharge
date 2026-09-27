import assert from 'node:assert/strict';
import test from 'node:test';

import {
  LocalUnavailableAgePolicyPort,
  rejectClientDeclaredAge,
} from '../../../src/security/age_policy_port.js';
import { securityPrivacyCollectionAccess } from '../../../src/security/collection_access_matrix.js';
import { RetentionRegistry } from '../../../src/security/retention_registry.js';
import { redactSecurityMetadata } from '../../../src/security/security_redaction_policy.js';
import { createEmergencyDisabledSecurityFlag } from '../../../src/security/security_flags.js';
import { parseUtcInstant } from '../../../src/shared/utc_instant.js';
import { planRetentionDeletionDispatch } from '../../../src/modules/privacy_orchestration/application/retention_deletion_dispatch.js';

void test('age policy is unavailable and client-declared age is rejected', async () => {
  assert.deepEqual(
    await new LocalUnavailableAgePolicyPort().evaluate({
      marketId: 'LV',
      surfaceId: 'find-people',
      purposeId: 'discovery',
    }),
    { eligible: false, reason: 'policy_unavailable' },
  );
  assert.throws(
    () => rejectClientDeclaredAge({ profile: { age: 18 } }),
    /client_declared_age_authority_forbidden/,
  );
});

void test('collection matrix and retention registry fail closed', () => {
  assert.equal(securityPrivacyCollectionAccess.decision('privacyRequests').clientWrite, 'deny');
  assert.deepEqual(securityPrivacyCollectionAccess.decision('unknownCollection'), {
    collectionId: 'unknownCollection',
    clientRead: 'deny',
    clientWrite: 'deny',
    reason: 'collection_unknown',
  });
  const registry = new RetentionRegistry([
    { policyId: 'profile.personal', status: 'unresolved', legalHoldSupported: true },
  ]);
  assert.deepEqual(
    registry.decide(
      'profile.personal',
      parseUtcInstant('2026-01-01T00:00:00.000Z'),
      parseUtcInstant('2026-09-22T00:00:00.000Z'),
      false,
    ),
    { action: 'policy_unavailable', policyId: 'profile.personal' },
  );
});

void test('redaction drops PII and secrets while emergency flag stays disabled', () => {
  assert.deepEqual(
    redactSecurityMetadata({
      event: 'denied',
      email: 'user@example.com',
      authorization: 'Bearer secret',
      count: 1,
      narrative: 'private',
    }),
    { event: 'denied', count: 1 },
  );
  assert.equal(
    createEmergencyDisabledSecurityFlag({
      flagId: 'security.kill',
      revision: 1,
      marketId: 'LV',
      capabilityId: 'find-people.use',
      environmentId: 'local',
      activatedBy: 'security-owner',
      reasonCode: 'incident_containment',
      createdAtUtc: '2026-09-22T10:00:00.000Z',
    }).emergencyDisabled,
    true,
  );
});

void test('deletion dispatch emits decisions and never deletes directly', () => {
  const registry = new RetentionRegistry([
    {
      policyId: 'demo.expired',
      status: 'accepted',
      durationDays: 1,
      legalHoldSupported: true,
      evidenceRevision: 'owner-approved-v1',
    },
  ]);
  const dispatch = planRetentionDeletionDispatch(
    registry,
    [
      {
        domainId: 'demo',
        recordId: 'record-1',
        policyId: 'demo.expired',
        createdAtUtc: parseUtcInstant('2026-09-20T00:00:00.000Z'),
        legalHold: false,
      },
    ],
    parseUtcInstant('2026-09-22T00:00:00.000Z'),
  );
  assert.equal(dispatch[0]?.decision.action, 'dispatch_deletion');
});
