import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import type { Firestore } from 'firebase-admin/firestore';

import {
  assertMediaChainPersistenceContext,
  ContentPersistenceEnvironmentError,
} from '../../../src/modules/content/infrastructure/firestore_content_repository.js';

const client = (projectId: string, settings: Record<string, unknown> = {}) =>
  ({ projectId, _settings: settings }) as unknown as Firestore;
const dev = { RECHARGE_DEV_RUNTIME: 'content-media', GCLOUD_PROJECT: 'recharge-dev-n2a01' };

const refused = (firestore: Firestore, environment: NodeJS.ProcessEnv, reason: string) =>
  assert.throws(
    () => assertMediaChainPersistenceContext(firestore, environment),
    (error: unknown) =>
      error instanceof ContentPersistenceEnvironmentError && error.reason === reason,
    reason,
  );

void test('dev cloud only with the switch, the exact project and the default TLS endpoint', () => {
  assertMediaChainPersistenceContext(client('recharge-dev-n2a01'), dev);
  assertMediaChainPersistenceContext(
    client('recharge-dev-n2a01', { servicePath: 'firestore.googleapis.com', port: 443, ssl: true }),
    dev,
  );
  refused(client('recharge-prod-x'), dev, 'dev_cloud_project_mismatch');
  refused(
    client('recharge-dev-n2a01'),
    { ...dev, GCLOUD_PROJECT: 'recharge-stage-x' },
    'dev_cloud_project_mismatch',
  );
  refused(
    client('recharge-dev-n2a01'),
    { RECHARGE_DEV_RUNTIME: 'content-media' },
    'dev_cloud_project_mismatch',
  );
  refused(
    client('recharge-dev-n2a01'),
    { ...dev, FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080' },
    'dev_cloud_with_emulator',
  );
  refused(
    client('recharge-dev-n2a01'),
    { ...dev, FUNCTIONS_EMULATOR: 'true' },
    'dev_cloud_with_emulator',
  );
  refused(
    client('recharge-dev-n2a01'),
    { ...dev, GOOGLE_APPLICATION_CREDENTIALS: 'key.json' },
    'dev_cloud_override',
  );
  refused(
    client('recharge-dev-n2a01', { servicePath: 'evil.example', port: 443 }),
    dev,
    'dev_cloud_override',
  );
  refused(client('recharge-dev-n2a01', { ssl: false }), dev, 'dev_cloud_override');
});

void test('without the switch the Emulator rules apply unchanged (a cloud client is refused)', () => {
  assert.throws(
    () =>
      assertMediaChainPersistenceContext(client('recharge-dev-n2a01'), {
        GCLOUD_PROJECT: 'recharge-dev-n2a01',
      }),
    ContentPersistenceEnvironmentError,
  );
  assert.throws(
    () =>
      assertMediaChainPersistenceContext(client('recharge-dev-n2a01'), {
        RECHARGE_DEV_RUNTIME: 'other',
        ...{ GCLOUD_PROJECT: 'recharge-dev-n2a01' },
      }),
    ContentPersistenceEnvironmentError,
  );
});

void test('only the Content, Media and Moderation repositories may use the dev-cloud guard', () => {
  const src = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../../src');
  const files: string[] = [];
  const walk = (dir: string) => {
    for (const name of readdirSync(dir)) {
      const full = path.join(dir, name);
      if (statSync(full).isDirectory()) walk(full);
      else if (name.endsWith('.ts')) files.push(full);
    }
  };
  walk(src);
  const users = files
    .filter((file) => /assertMediaChainPersistenceContext\(/u.test(readFileSync(file, 'utf8')))
    .map((file) => path.relative(src, file).replaceAll('\\', '/'))
    .sort();
  assert.deepEqual(users, [
    'modules/content/infrastructure/firestore_content_repository.ts',
    'modules/media/infrastructure/firestore_media_repository.ts',
    'modules/moderation/infrastructure/firestore_moderation_repository.ts',
  ]);
});
