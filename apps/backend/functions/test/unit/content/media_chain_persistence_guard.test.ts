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

void test('only the Content, Media, Moderation, Event-handoff and legal hold stores may use the dev-cloud guard', () => {
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
    // Pilot 2.3 (owner 2026-11-21, variant A): the Catalog projection in the cloud.
    'modules/catalog/infrastructure/firestore_catalog_repository.ts',
    'modules/content/infrastructure/firestore_content_repository.ts',
    // Round 2.2 (owner approval 2026-11-19): Event → Booking handoff in the cloud.
    'modules/content/infrastructure/firestore_event_booking_handoff_repository.ts',
    // Pilot 2.1 (owner 2026-11-21, variant A): the Library in the cloud.
    'modules/library/firestore_library_service.ts',
    'modules/media/infrastructure/firestore_media_repository.ts',
    'modules/moderation/infrastructure/firestore_moderation_repository.ts',
    // Step 2 (owner decision 2026-11-20): the L1 legal hold authority in the cloud.
    'modules/privacy_orchestration/infrastructure/firestore_privacy_legal_hold_service.ts',
    // Pilot 2.4 (owner 2026-11-21): Quick Plan and Scenario sync in the cloud.
    'modules/quick_plan/firestore_quick_plan_service.ts',
    'modules/quick_plan/firestore_scenario_service.ts',
    // Pilot 2.5 (owner 2026-11-21): Route sync and publication in the cloud.
    'modules/route/firestore_route_service.ts',
  ]);
});
