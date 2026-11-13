import assert from 'node:assert/strict';
import { performance } from 'node:perf_hooks';
import { after, before, test } from 'node:test';
import { createInternalBooking } from '../../src/booking/create_internal_booking.js';
import { bookingPeakProfiles } from '../../src/booking/scalability.js';
import { bookingCollections, finitePoolLedgerId } from '../../src/booking/transactions.js';
import { FakeClock } from '../support/fake_clock.js';
import {
  cleanupBookingEmulator,
  emulatorFirestore,
  seedEvent,
} from '../support/booking_emulator.js';
import { createCommand, finiteEvent, fixedNow } from '../support/booking_fixtures.js';

const firestore = emulatorFirestore();
const clock = new FakeClock(fixedNow);

before(async () => cleanupBookingEmulator(firestore));
after(async () => cleanupBookingEmulator(firestore));

interface ScenarioEvidence {
  readonly profile: keyof typeof bookingPeakProfiles;
  readonly mode: 'sustained' | 'burst';
  readonly requests: number;
  readonly elapsedMs: number;
  readonly p95LatencyMs: number;
  readonly succeeded: number;
  readonly retryableFailures: number;
  readonly rejected: number;
  readonly confirmedUnits: number;
  readonly oversellCount: number;
}

void test('single-ledger local load evidence never oversells', { timeout: 600_000 }, async () => {
  const evidence: ScenarioEvidence[] = [];
  for (const [profile, target] of Object.entries(bookingPeakProfiles) as Array<
    [
      keyof typeof bookingPeakProfiles,
      (typeof bookingPeakProfiles)[keyof typeof bookingPeakProfiles],
    ]
  >) {
    evidence.push(await runScenario(profile, 'sustained', target.sustainedRps));
    evidence.push(await runScenario(profile, 'burst', target.burstRequests));
  }
  assert.equal(
    evidence.every((item) => item.oversellCount === 0),
    true,
  );
  process.stdout.write(`BOOKING_LOAD_EVIDENCE ${JSON.stringify(evidence)}\n`);
});

async function runScenario(
  profile: keyof typeof bookingPeakProfiles,
  mode: ScenarioEvidence['mode'],
  requests: number,
): Promise<ScenarioEvidence> {
  await cleanupBookingEmulator(firestore);
  const occurrenceId = `occ_load_${profile}_${mode}`;
  const poolId = `pool_${profile}_${mode}`;
  const totalCapacity = requests + 10;
  const event = finiteEvent({ occurrenceId, poolId, totalCapacity });
  await seedEvent(event, firestore);
  const startedAt = performance.now();
  const latencies: number[] = [];
  const results = await Promise.all(
    Array.from({ length: requests }, async (_, index) => {
      if (mode === 'sustained') await delay((index * 1_000) / requests);
      const requestStartedAt = performance.now();
      const result = await createInternalBooking(
        {
          firestore,
          clock,
          newBookingId: () => `load_${profile}_${mode}_${String(index).padStart(6, '0')}`,
        },
        `actor_${profile}_${mode}_${index}`,
        createCommand({
          requestId: `req_load_${profile}_${mode}_${index}`,
          idempotencyKey: `idem_load_${profile}_${mode}_${index}`,
          payload: {
            occurrenceId,
            inventoryPoolId: poolId,
            channel: 'onsite',
            participantUnits: 1,
            namedGuests: [],
          },
        }),
      );
      latencies.push(performance.now() - requestStartedAt);
      return result;
    }),
  );
  const elapsedMs = performance.now() - startedAt;
  const succeeded = results.filter((result) => result.kind === 'succeeded').length;
  const retryableFailures = results.filter((result) => result.kind === 'retryableFailure').length;
  const rejected = results.filter((result) => result.kind === 'rejected').length;
  const ledger = await firestore
    .collection(bookingCollections.poolLedgers)
    .doc(finitePoolLedgerId(occurrenceId, poolId, 'onsite'))
    .get();
  const confirmedUnits = Number(ledger.get('confirmedUnits') ?? 0);
  const bookings = await firestore.collection(bookingCollections.bookings).get();
  assert.equal(confirmedUnits, succeeded);
  assert.equal(bookings.size, succeeded);
  const oversellCount = Math.max(0, confirmedUnits - totalCapacity);
  assert.equal(oversellCount, 0);
  return {
    profile,
    mode,
    requests,
    elapsedMs: round(elapsedMs),
    p95LatencyMs: round(percentile(latencies, 0.95)),
    succeeded,
    retryableFailures,
    rejected,
    confirmedUnits,
    oversellCount,
  };
}

function percentile(values: readonly number[], percentileValue: number): number {
  const sorted = [...values].sort((left, right) => left - right);
  const index = Math.max(0, Math.ceil(sorted.length * percentileValue) - 1);
  return sorted[index] ?? 0;
}

function round(value: number): number {
  return Math.round(value * 100) / 100;
}

function delay(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
