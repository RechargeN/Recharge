import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  assessBookingScalability,
  bookingPeakProfiles,
  bookingSingleLedgerTransitionThreshold,
} from '../../src/booking/scalability.js';

void test('owner-approved load profiles and transition threshold are exact', () => {
  assert.deepEqual(bookingPeakProfiles, {
    normal: { sustainedRps: 5, burstRequests: 20 },
    popular: { sustainedRps: 25, burstRequests: 100 },
    mass: { sustainedRps: 100, burstRequests: 500 },
  });
  assert.deepEqual(bookingSingleLedgerTransitionThreshold, {
    sustainedRps: 25,
    burstRequests: 100,
    maximumP95LatencyMs: 1_500,
    minimumSuccessRatio: 0.999,
  });
});

void test('small local evidence can open only a small dev rollout', () => {
  assert.equal(
    assessBookingScalability({
      source: 'local_emulator',
      sustainedRps: 5,
      burstRequests: 20,
      observedP95LatencyMs: 500,
      successRatio: 1,
      oversellCount: 0,
    }),
    'single_ledger_eligible_for_small_dev',
  );
});

void test('popular load, latency, errors or oversell require sharded escrow', () => {
  for (const evidence of [
    {
      source: 'local_emulator' as const,
      sustainedRps: 25,
      burstRequests: 20,
      observedP95LatencyMs: 500,
      successRatio: 1,
      oversellCount: 0,
    },
    {
      source: 'dev_cloud' as const,
      sustainedRps: 5,
      burstRequests: 20,
      observedP95LatencyMs: 1_501,
      successRatio: 1,
      oversellCount: 0,
    },
    {
      source: 'stage_cloud' as const,
      sustainedRps: 5,
      burstRequests: 20,
      observedP95LatencyMs: 500,
      successRatio: 0.998,
      oversellCount: 0,
    },
    {
      source: 'stage_cloud' as const,
      sustainedRps: 5,
      burstRequests: 20,
      observedP95LatencyMs: 500,
      successRatio: 1,
      oversellCount: 1,
    },
  ]) {
    assert.equal(assessBookingScalability(evidence), 'sharded_escrow_required');
  }
});

void test('non-emulator evidence below threshold still requires production proof', () => {
  assert.equal(
    assessBookingScalability({
      source: 'dev_cloud',
      sustainedRps: 5,
      burstRequests: 20,
      observedP95LatencyMs: 500,
      successRatio: 1,
      oversellCount: 0,
    }),
    'production_evidence_required',
  );
});
