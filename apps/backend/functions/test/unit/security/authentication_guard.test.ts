import assert from 'node:assert/strict';
import test from 'node:test';

import { createServerActorContext } from '../../../src/security/actor_context.js';
import {
  evaluateAuthentication,
  LocalDenyAuthenticationGuard,
} from '../../../src/security/authentication_guard.js';
import { parseUtcInstant } from '../../../src/shared/utc_instant.js';
import { fixtureIds } from '../../support/platform_fixtures.js';

function actor(sessionState: 'active' | 'revoked' | 'expired' = 'active') {
  return createServerActorContext({
    principalType: 'user',
    actorId: fixtureIds.first,
    sessionId: fixtureIds.second,
    authenticatedAtUtc: '2026-09-22T10:00:00.000Z',
    sessionState,
    marketId: 'LV',
    workspace: { type: 'personal', id: fixtureIds.first },
    appCheckState: 'valid',
    accessSnapshotRevision: 1,
    activeAccountState: 'active',
    capabilities: ['profile.read'],
  });
}

void test('local authentication port cannot mint an actor', async () => {
  assert.deepEqual(await new LocalDenyAuthenticationGuard().resolve('client-token'), {
    authenticated: false,
    reason: 'authentication_missing',
  });
});

void test('revoked, expired and stale sessions fail closed', () => {
  const now = parseUtcInstant('2026-09-22T11:00:00.000Z');
  assert.equal(evaluateAuthentication(actor('revoked'), now, 7200).authenticated, false);
  assert.equal(evaluateAuthentication(actor('expired'), now, 7200).authenticated, false);
  assert.deepEqual(evaluateAuthentication(actor(), now, 60), {
    authenticated: false,
    reason: 'authentication_stale',
  });
  assert.equal(evaluateAuthentication(actor(), now, 7200).authenticated, true);
});
