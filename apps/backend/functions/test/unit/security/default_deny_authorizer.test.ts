import assert from 'node:assert/strict';
import test from 'node:test';

import { createServerActorContext } from '../../../src/security/actor_context.js';
import { DefaultDenyAuthorizer } from '../../../src/security/default_deny_authorizer.js';
import { fixtureIds } from '../../support/platform_fixtures.js';

function actor(
  overrides: {
    readonly revision?: number;
    readonly appCheckState?: 'valid' | 'missing';
    readonly sessionState?: 'active' | 'revoked';
    readonly marketId?: 'LV' | 'EE';
  } = {},
) {
  return createServerActorContext({
    principalType: 'user',
    actorId: fixtureIds.first,
    sessionId: fixtureIds.second,
    authenticatedAtUtc: '2026-09-21T10:00:00.000Z',
    sessionState: overrides.sessionState ?? 'active',
    marketId: overrides.marketId ?? 'LV',
    workspace: { type: 'personal', id: fixtureIds.first },
    appCheckState: overrides.appCheckState ?? 'valid',
    accessSnapshotRevision: overrides.revision ?? 2,
    activeAccountState: 'active',
    capabilities: ['platform.read'],
  });
}

void test('default authorizer denies missing, stale, invalid and even known disabled capability', () => {
  const authorizer = new DefaultDenyAuthorizer();
  assert.equal(
    authorizer.authorize({
      actor: null,
      requiredCapability: 'platform.read',
      minimumAccessSnapshotRevision: 1,
    }).reason,
    'actor_missing',
  );
  assert.equal(
    authorizer.authorize({
      actor: actor({ sessionState: 'revoked' }),
      requiredCapability: 'platform.read',
      minimumAccessSnapshotRevision: 1,
    }).reason,
    'session_revoked',
  );
  assert.equal(
    authorizer.authorize({
      actor: actor({ marketId: 'EE' }),
      requiredCapability: 'platform.read',
      minimumAccessSnapshotRevision: 1,
      scope: {
        marketId: 'LV',
        ownerId: fixtureIds.first,
        workspaceType: 'personal',
        workspaceId: fixtureIds.first,
      },
    }).reason,
    'market_mismatch',
  );
  assert.equal(
    authorizer.authorize({
      actor: actor({ revision: 0 }),
      requiredCapability: 'platform.read',
      minimumAccessSnapshotRevision: 1,
    }).reason,
    'access_snapshot_stale',
  );
  assert.equal(
    authorizer.authorize({
      actor: actor({ appCheckState: 'missing' }),
      requiredCapability: 'platform.read',
      minimumAccessSnapshotRevision: 1,
    }).reason,
    'app_check_invalid',
  );
  assert.equal(
    authorizer.authorize({
      actor: actor(),
      requiredCapability: 'platform.write',
      minimumAccessSnapshotRevision: 1,
    }).reason,
    'capability_unsupported',
  );
  assert.equal(
    authorizer.authorize({
      actor: actor(),
      requiredCapability: 'platform.read',
      minimumAccessSnapshotRevision: 1,
    }).reason,
    'capability_disabled',
  );
});

void test('page scope never leaks across workspaces or revoked memberships', () => {
  const authorizer = new DefaultDenyAuthorizer();
  const pageActor = createServerActorContext({
    principalType: 'user',
    actorId: fixtureIds.first,
    sessionId: fixtureIds.second,
    authenticatedAtUtc: '2026-09-21T10:00:00.000Z',
    sessionState: 'active',
    marketId: 'LV',
    workspace: { type: 'page', id: fixtureIds.second, membershipState: 'active' },
    appCheckState: 'valid',
    accessSnapshotRevision: 2,
    activeAccountState: 'active',
    capabilities: ['page.manage'],
  });
  assert.equal(
    authorizer.authorize({
      actor: pageActor,
      requiredCapability: 'page.manage',
      minimumAccessSnapshotRevision: 1,
      scope: {
        marketId: 'LV',
        ownerId: null,
        workspaceType: 'page',
        workspaceId: fixtureIds.third,
      },
    }).reason,
    'workspace_mismatch',
  );
  const revoked = createServerActorContext({
    ...pageActor,
    actorId: pageActor.actorId,
    sessionId: pageActor.sessionId,
    authenticatedAtUtc: pageActor.authenticatedAtUtc,
    marketId: pageActor.marketId,
    workspace: { type: 'page', id: fixtureIds.second, membershipState: 'revoked' },
  });
  assert.equal(
    authorizer.authorize({
      actor: revoked,
      requiredCapability: 'page.manage',
      minimumAccessSnapshotRevision: 1,
      scope: {
        marketId: 'LV',
        ownerId: null,
        workspaceType: 'page',
        workspaceId: fixtureIds.second,
      },
    }).reason,
    'page_membership_revoked',
  );
});
