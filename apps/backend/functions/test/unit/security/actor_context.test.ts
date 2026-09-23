import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createServerActorContext,
  rejectClientAuthority,
} from '../../../src/security/actor_context.js';
import { fixtureIds } from '../../support/platform_fixtures.js';

void test('actor context accepts only server-resolved authority', () => {
  const actor = createServerActorContext({
    principalType: 'user',
    actorId: fixtureIds.first,
    sessionId: fixtureIds.second,
    authenticatedAtUtc: '2026-09-21T10:00:00.000Z',
    sessionState: 'active',
    marketId: 'LV',
    workspace: { type: 'personal', id: fixtureIds.first },
    appCheckState: 'valid',
    accessSnapshotRevision: 4,
    activeAccountState: 'active',
    capabilities: ['platform.read', 'platform.read'],
  });
  assert.deepEqual(actor.capabilities, ['platform.read']);
  assert.ok(Object.isFrozen(actor));
  assert.throws(
    () => rejectClientAuthority({ isAdmin: true }),
    /client_declared_authority_forbidden/,
  );
  assert.throws(
    () => rejectClientAuthority({ dateOfBirth: '2010-01-01' }),
    /client_declared_authority_forbidden/,
  );
  assert.throws(
    () => rejectClientAuthority({ nested: { capabilities: ['admin'] } }),
    /client_declared_authority_forbidden/,
  );
});
