import assert from 'node:assert/strict';
import test from 'node:test';

import { createLocalPlatformApp } from '../../src/platform/bootstrap/composition_root.js';
import { buildPlatformBundle } from '../support/platform_fixtures.js';

void test('R1 composition contains platform services only and no executable API', () => {
  const app = createLocalPlatformApp(buildPlatformBundle());
  assert.deepEqual(app.apiRegistry.commandHandlers, []);
  assert.deepEqual(app.apiRegistry.queryHandlers, []);
  assert.deepEqual(app.apiRegistry.workers, []);
  assert.deepEqual(app.apiRegistry.schedules, []);
  assert.ok(app.apiRegistry.schemaIds.length >= 6);
  assert.equal(app.config.environment.cloudAllowed, false);
  assert.ok(app.config.marketCapabilities.every((entry) => entry.status === 'disabled'));
  assert.ok(app.config.featureFlags.every((entry) => entry.enabled === false));
});

void test('composition does not infer a cloud or Firebase context', () => {
  const app = createLocalPlatformApp(buildPlatformBundle());
  assert.equal(app.config.environment.identity.bindingState, 'unbound');
  assert.equal('firebase' in app, false);
  assert.equal('booking' in app.services, false);
  assert.ok(app.services.privacy);
  assert.equal(app.security.collectionAccess.decision('unknownCollection').clientWrite, 'deny');
});
