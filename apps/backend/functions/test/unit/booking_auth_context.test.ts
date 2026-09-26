import assert from 'node:assert/strict';
import { test } from 'node:test';
import { resolveBookingActor } from '../../src/shared/auth_context.js';

void test('transport auth provides identity hints but cannot provide Booking capability authority', () => {
  assert.deepEqual(
    resolveBookingActor(
      {
        uid: 'actor-1',
        token: {
          sessionId: 'forbidden-claim',
          accountState: 'active',
          capabilities: ['booking.self_service'],
        },
      },
      {
        sessionId: 'session-1',
        sessionHandle: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        installationId: 'install-1',
      },
    ),
    {
      ok: true,
      actor: {
        firebaseUid: 'actor-1',
        sessionId: 'session-1',
        sessionHandle: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        installationId: 'install-1',
      },
    },
  );
  assert.deepEqual(
    resolveBookingActor(
      {
        uid: 'actor-1',
        token: { accountState: 'active', capabilities: ['booking.self_service'] },
      },
      undefined,
    ),
    { ok: false, code: 'permission_denied' },
  );
});
