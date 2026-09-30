import test from 'node:test';

import { InMemoryContentRepository } from '../../src/modules/content/infrastructure/in_memory_content_repository.js';
import { registerContentScenarios } from '../support/content_repository_scenarios.js';

// The same scenario suite runs against the Firestore adapter in the Emulator
// tests (`test/emulator/content_firestore_repository.test.ts`).
registerContentScenarios(
  (name, run) => void test(name, run),
  'in-memory',
  (limits) => new InMemoryContentRepository(limits),
);
