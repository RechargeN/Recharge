import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';

import {
  operationalRegistryGaps,
  operationalTaskRegistry,
  operationsBlockers,
  type OperationalTaskFamily,
} from '../../../src/modules/operations/operational_task_registry.js';
import { operationsEmergencySwitchIds } from '../../../src/shared/feature_flags.js';

/**
 * L2-T-REG: every background trigger and every source file with queue markers
 * (lease, dead letter, attempt budget, stop-on-poison checkpoint) belongs to a
 * registered task family, and every family either continues after a failure or
 * names the blocker that stops it.
 */
const triggerPattern =
  /export const (\w+)\s*=\s*on(?:Document\w+|Schedule|TaskDispatched|MessagePublished)\b/gu;
const workerMarkers =
  /\b(?:leaseToken|leaseUntilUtc|leaseExpiresAtUtc|leaseOwner|leaseId|deadLetter|dead_lettered|nextAttemptAtUtc|stoppedAt|maxProcessingAttempts|attemptBudget)\b/u;
const ownMarkerFiles = new Set(['modules/operations/operations_ports.ts']);

function triggersIn(source: string): string[] {
  return [...source.matchAll(triggerPattern)].map((match) => match[1]!).sort();
}

function workerFilesIn(files: ReadonlyMap<string, string>): string[] {
  return [...files]
    .filter(([name, source]) => !ownMarkerFiles.has(name) && workerMarkers.test(source))
    .map(([name]) => name)
    .sort();
}

function sourceFiles(root: string, base = root): Map<string, string> {
  const files = new Map<string, string>();
  for (const entry of readdirSync(root)) {
    const absolute = path.join(root, entry);
    if (statSync(absolute).isDirectory()) {
      for (const [name, source] of sourceFiles(absolute, base)) files.set(name, source);
    } else if (entry.endsWith('.ts')) {
      files.set(
        path.relative(base, absolute).replaceAll('\\', '/'),
        readFileSync(absolute, 'utf8'),
      );
    }
  }
  return files;
}

const src = path.resolve(process.cwd(), 'src');

void test('L2-T-REG: every trigger and queue file belongs to a family with a recovery path', () => {
  const files = sourceFiles(src);
  const triggers = triggersIn(files.get('index.ts')!);
  const workerFiles = workerFilesIn(files);
  // The scans must see the known queues, or an empty scan would pass.
  for (const known of [
    'consumeEventBookingOutboxV1',
    'releaseMissedReconfirmationsV1',
    'consumeNotificationEffectV1',
    'purgeFindPeoplePrivateLocationsV1',
  ])
    assert.ok(triggers.includes(known), known);
  for (const known of [
    'booking/event_projection_delivery.ts',
    'booking/reconfirmation_deadline_worker.ts',
    'modules/notifications/application/consume_notification_effect.ts',
    'modules/privacy_orchestration/domain/privacy_domain_task.ts',
  ])
    assert.ok(workerFiles.includes(known), known);
  assert.deepEqual(operationalRegistryGaps({ triggers, workerFiles }), []);
  // Every registered source exists, so a renamed file cannot hide behind a stale entry.
  for (const family of operationalTaskRegistry)
    for (const source of family.sources) assert.ok(files.has(source), `${family.id}: ${source}`);
});

void test('L2-T-REG positive controls: an unregistered queue or a family without recovery fails', () => {
  const phantomFiles = new Map([
    [
      'modules/phantom/phantom_worker.ts',
      "const record = { leaseToken: 'x', status: 'deadLetter' };",
    ],
    ['modules/phantom/plain.ts', 'export const value = 1;'],
  ]);
  assert.deepEqual(workerFilesIn(phantomFiles), ['modules/phantom/phantom_worker.ts']);
  assert.deepEqual(
    triggersIn(
      "export const phantomSweepV1 = onSchedule({ schedule: 'every 5 minutes' }, run);\n" +
        'export const phantomQueryV1 = onCall(options, run);',
    ),
    ['phantomSweepV1'],
  );
  assert.deepEqual(
    operationalRegistryGaps({
      triggers: ['phantomSweepV1'],
      workerFiles: ['modules/phantom/phantom_worker.ts'],
    }),
    [
      'trigger_unregistered:phantomSweepV1',
      'worker_unregistered:modules/phantom/phantom_worker.ts',
    ],
  );
  const silent: OperationalTaskFamily = {
    ...operationalTaskRegistry[0]!,
    id: 'TF-14',
    sources: [],
    triggers: [],
    recovery: ['lease_fencing', 'dead_letter'],
    blockers: [],
    console: { inspect: false, replay: true, reconcile: false },
  };
  assert.deepEqual(operationalRegistryGaps({ triggers: [], workerFiles: [], registry: [silent] }), [
    'dead_letter_without_replay:TF-14',
    'recovery_missing:TF-14',
  ]);
  assert.deepEqual(
    operationalRegistryGaps({
      triggers: [],
      workerFiles: [],
      registry: [
        { ...silent, recovery: ['retry_budget'], console: { ...silent.console, replay: true } },
      ],
    }),
    ['replay_without_dead_letter:TF-14'],
  );
});

void test('registry blockers and emergency switches are known and unique', () => {
  const ids = operationalTaskRegistry.map((family) => family.id);
  assert.equal(new Set(ids).size, ids.length);
  for (const family of operationalTaskRegistry)
    for (const blocker of family.blockers) assert.ok(operationsBlockers.includes(blocker));
  const switches = operationalTaskRegistry.flatMap((family) =>
    family.emergencySwitchId === null ? [] : [family.emergencySwitchId],
  );
  assert.deepEqual([...switches].sort(), Object.values(operationsEmergencySwitchIds).sort());
  // A family the console replays must have a dead letter and an emergency switch.
  for (const family of operationalTaskRegistry.filter((item) => item.console.replay))
    assert.notEqual(family.emergencySwitchId, null, family.id);
});
