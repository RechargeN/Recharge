import assert from 'node:assert/strict';
import { test } from 'node:test';
import type { Request } from 'firebase-functions/v2/https';
import type { Response } from 'express';
import * as entry from '../../../src/dev_identity_entry.js';

void test('isolated runtime exports only Session surfaces and is closed without exact enabled configuration', async () => {
  assert.deepEqual(
    Object.keys(entry).sort(),
    [
      'establishIdentitySessionV1',
      'readIdentitySessionV1',
      'recoverIdentitySessionsV1',
      'refreshIdentitySessionV1',
      'revokeIdentitySessionV1',
    ].sort(),
  );
  const previous = process.env.N2C_DEV_AUTH_ENABLED;
  process.env.N2C_DEV_AUTH_ENABLED = 'false';
  try {
    for (const fn of Object.values(entry)) {
      let status = 0;
      let body: unknown;
      const response = {
        set: () => response,
        status: (value: number) => {
          status = value;
          return response;
        },
        json: (value: unknown) => {
          body = value;
          return response;
        },
      };
      const request = {
        headers: {},
        rawBody: Buffer.from('{}'),
        method: 'POST',
        url: '/',
        get: () => undefined,
        header: () => undefined,
      };
      await fn(request as unknown as Request, response as unknown as Response);
      assert.equal(status, 503);
      assert.deepEqual(body, { error: { status: 'UNAVAILABLE' } });
      assert.equal(fn.__endpoint?.platform, 'gcfv2');
    }
  } finally {
    if (previous === undefined) delete process.env.N2C_DEV_AUTH_ENABLED;
    else process.env.N2C_DEV_AUTH_ENABLED = previous;
  }
});
