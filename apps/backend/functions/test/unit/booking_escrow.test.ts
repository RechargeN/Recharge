import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  allocateEscrowUnits,
  bookingEscrowModel,
  planEscrowMigration,
  reconcileEscrow,
  releaseEscrowUnits,
  transferEscrowCapacity,
} from '../../src/inventory/escrow.js';

void test('escrow model stays disabled and migration preserves all capacity and usage', () => {
  assert.equal(bookingEscrowModel.activation, 'disabled');
  assert.equal(bookingEscrowModel.popularShardCount, 16);
  assert.equal(bookingEscrowModel.massShardCount, 64);
  const plan = planEscrowMigration({
    inventoryKey: 'inventory-1',
    totalCapacity: 100,
    confirmedUnits: 37,
    shardCount: bookingEscrowModel.popularShardCount,
    migrationRevision: 1,
  });
  assert.equal(plan.root.mode, 'shadow');
  assert.equal(plan.existingBookingShardId, 'legacy');
  assert.equal(plan.shards.find((shard) => shard.shardId === 'legacy')?.confirmedUnits, 37);
  assert.deepEqual(reconcileEscrow(plan.root, plan.shards), {
    state: 'healthy',
    allocatedCapacity: 100,
    confirmedUnits: 37,
    issues: [],
  });
});

void test('fixed escrow permits exactly capacity and never oversells', () => {
  const plan = planEscrowMigration({
    inventoryKey: 'inventory-2',
    totalCapacity: 500,
    confirmedUnits: 0,
    shardCount: bookingEscrowModel.massShardCount,
    migrationRevision: 1,
  });
  let shards = plan.shards;
  let allocations = 0;
  for (let index = 0; index < 750; index += 1) {
    const result = allocateEscrowUnits(shards, `actor-${index}`, 1);
    if (result.kind === 'allocated') {
      allocations += 1;
      shards = result.shards;
    }
  }
  assert.equal(allocations, 500);
  assert.deepEqual(reconcileEscrow(plan.root, shards), {
    state: 'healthy',
    allocatedCapacity: 500,
    confirmedUnits: 500,
    issues: [],
  });
});

void test('existing bookings release from legacy shard and capacity transfers stay bounded', () => {
  const plan = planEscrowMigration({
    inventoryKey: 'inventory-3',
    totalCapacity: 20,
    confirmedUnits: 5,
    shardCount: 4,
    migrationRevision: 2,
  });
  const released = releaseEscrowUnits(plan.shards, 'legacy', 2);
  assert.equal(released.find((shard) => shard.shardId === 'legacy')?.confirmedUnits, 3);
  const transferred = transferEscrowCapacity(released, 's000', 's001', 1);
  assert.equal(
    transferred.reduce((sum, shard) => sum + shard.capacityUnits, 0),
    plan.root.totalCapacity,
  );
  assert.throws(
    () => transferEscrowCapacity(transferred, 'legacy', 's001', 3),
    /escrow_transfer_exceeds_available/u,
  );
});

void test('capacity reduction below confirmed state is cancellation-only, not corrupt', () => {
  const plan = planEscrowMigration({
    inventoryKey: 'inventory-4',
    totalCapacity: 10,
    confirmedUnits: 12,
    shardCount: 4,
    migrationRevision: 1,
  });
  assert.equal(plan.activationReadiness, 'cancel_only');
  assert.deepEqual(reconcileEscrow(plan.root, plan.shards), {
    state: 'over_capacity',
    allocatedCapacity: 10,
    confirmedUnits: 12,
    issues: [],
  });
  assert.equal(allocateEscrowUnits(plan.shards, 'new-actor', 1).kind, 'sold_out');
});

void test('reconciliation fails closed on missing, duplicate or mismatched shards', () => {
  const plan = planEscrowMigration({
    inventoryKey: 'inventory-5',
    totalCapacity: 10,
    confirmedUnits: 0,
    shardCount: 4,
    migrationRevision: 1,
  });
  const corrupt = [plan.shards[0], plan.shards[1], plan.shards[1]].filter(
    (shard) => shard !== undefined,
  );
  const reconciliation = reconcileEscrow(plan.root, corrupt);
  assert.equal(reconciliation.state, 'corrupt');
  assert.deepEqual(reconciliation.issues, [
    'shard_count_mismatch',
    'duplicate_shard_id',
    'capacity_sum_mismatch',
  ]);
});
