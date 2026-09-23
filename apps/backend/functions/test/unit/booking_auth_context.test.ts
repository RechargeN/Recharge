import assert from 'node:assert/strict';
import { test } from 'node:test';
import { resolveBookingActor } from '../../src/shared/auth_context.js';

void test('transport auth provides identity hints but cannot provide Booking capability authority', () => {
  assert.deepEqual(
    resolveBookingActor({
      uid: 'actor-1',
      token: {
        sessionId: 'session-1',
        accessSnapshotRevision: 7,
        accountState: 'active',
        capabilities: ['booking.self_service'],
      },
    }),
    {
      ok: true,
      actor: { actorId: 'actor-1', sessionId: 'session-1', accessSnapshotRevision: 7 },
    },
  );
  assert.deepEqual(
    resolveBookingActor({
      uid: 'actor-1',
      token: { accountState: 'active', capabilities: ['booking.self_service'] },
    }),
    { ok: false, code: 'permission_denied' },
  );
});
