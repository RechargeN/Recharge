import assert from 'node:assert/strict';
import test from 'node:test';

import * as booking from '../../src/dev_booking_entry.js';
import * as contentMedia from '../../src/dev_content_media_entry.js';

// Gap plan round 1, item 1.3 (owner approval 2026-11-23). With concurrency 1 a
// second parallel app request waits for the single instance and fails with
// 500 "aborted after waiting too long for an available instance" (staging,
// contentQueryV1, 2026-11-19). These read endpoints take 10 requests per
// instance; the instance ceiling and CPU stay the same, so the cost cap is
// unchanged.

interface Endpoint {
  readonly concurrency?: number;
  readonly maxInstances?: number;
  readonly availableMemoryMb?: number;
  readonly cpu?: number | 'gcf_gen1';
}

function endpointOf(fn: unknown): Endpoint {
  return (fn as { __endpoint: Endpoint }).__endpoint;
}

const raised: readonly [string, unknown][] = [
  ['contentQueryV1', contentMedia.contentQueryV1],
  ['getMyBookingV1', booking.getMyBookingV1],
  ['getEventAvailabilityV1', booking.getEventAvailabilityV1],
];

// Neighbours on the same option sets keep one request per instance: the raise
// is limited to the three reads the owner approved.
const unchanged: readonly [string, unknown][] = [
  ['contentCommandV1', contentMedia.contentCommandV1],
  ['discoverQueryV1', contentMedia.discoverQueryV1],
  ['createInternalBookingV1', booking.createInternalBookingV1],
  ['listMyBookingsV1', booking.listMyBookingsV1],
];

void test('approved read endpoints take 10 concurrent requests on the same single instance', () => {
  for (const [name, fn] of raised) {
    const endpoint = endpointOf(fn);
    assert.equal(endpoint.concurrency, 10, `${name} concurrency`);
    assert.equal(endpoint.maxInstances, 1, `${name} maxInstances`);
    assert.equal(endpoint.cpu, 1, `${name} cpu (concurrency > 1 needs a whole CPU)`);
  }
});

void test('other endpoints keep one request per instance', () => {
  for (const [name, fn] of unchanged) {
    const endpoint = endpointOf(fn);
    assert.equal(endpoint.concurrency, 1, `${name} concurrency`);
    assert.equal(endpoint.maxInstances, 1, `${name} maxInstances`);
  }
});
