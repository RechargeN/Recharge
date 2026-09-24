import { createHash } from 'node:crypto';

export const bookingEscrowModel = Object.freeze({
  schemaVersion: 1,
  modelId: 'booking_fixed_escrow_v1',
  activation: 'disabled' as const,
  popularShardCount: 16,
  massShardCount: 64,
  maximumShardCount: 128,
  legacyShardId: 'legacy',
});

export interface EscrowPoolRoot {
  readonly schemaVersion: 1;
  readonly modelId: 'booking_fixed_escrow_v1';
  readonly inventoryKey: string;
  readonly migrationRevision: number;
  readonly mode: 'shadow';
  readonly totalCapacity: number;
  readonly migratedConfirmedUnits: number;
  readonly shardCount: number;
  readonly legacyShardId: 'legacy';
}

export interface EscrowShard {
  readonly shardId: string;
  readonly revision: number;
  readonly capacityUnits: number;
  readonly confirmedUnits: number;
}

export interface EscrowMigrationPlan {
  readonly root: EscrowPoolRoot;
  readonly shards: readonly EscrowShard[];
  readonly existingBookingShardId: 'legacy';
  readonly activationReadiness: 'ready' | 'cancel_only';
  readonly rollback: 'single_ledger_remains_authority_until_atomic_pointer_swap';
}

export type EscrowAllocationResult =
  | Readonly<{
      kind: 'allocated';
      shardId: string;
      shards: readonly EscrowShard[];
    }>
  | Readonly<{ kind: 'sold_out'; shards: readonly EscrowShard[] }>;

export interface EscrowReconciliation {
  readonly state: 'healthy' | 'over_capacity' | 'corrupt';
  readonly allocatedCapacity: number;
  readonly confirmedUnits: number;
  readonly issues: readonly string[];
}

export function planEscrowMigration(input: {
  readonly inventoryKey: string;
  readonly totalCapacity: number;
  readonly confirmedUnits: number;
  readonly shardCount: number;
  readonly migrationRevision: number;
}): EscrowMigrationPlan {
  assertNonNegativeInteger(input.totalCapacity, 'total_capacity_invalid');
  assertNonNegativeInteger(input.confirmedUnits, 'confirmed_units_invalid');
  if (
    !Number.isSafeInteger(input.shardCount) ||
    input.shardCount < 2 ||
    input.shardCount > bookingEscrowModel.maximumShardCount
  ) {
    throw new TypeError('escrow_shard_count_invalid');
  }
  if (!Number.isSafeInteger(input.migrationRevision) || input.migrationRevision < 1) {
    throw new TypeError('migration_revision_invalid');
  }
  if (input.inventoryKey.trim().length === 0 || input.inventoryKey.length > 256) {
    throw new TypeError('inventory_key_invalid');
  }
  const legacyCapacity = Math.min(input.totalCapacity, input.confirmedUnits);
  const distributable = input.totalCapacity - legacyCapacity;
  const activeShardCount = input.shardCount - 1;
  const baseCapacity = Math.floor(distributable / activeShardCount);
  const remainder = distributable % activeShardCount;
  const shards: EscrowShard[] = [
    {
      shardId: bookingEscrowModel.legacyShardId,
      revision: 1,
      capacityUnits: legacyCapacity,
      confirmedUnits: input.confirmedUnits,
    },
    ...Array.from({ length: activeShardCount }, (_, index) => ({
      shardId: `s${String(index).padStart(3, '0')}`,
      revision: 1,
      capacityUnits: baseCapacity + (index < remainder ? 1 : 0),
      confirmedUnits: 0,
    })),
  ];
  return {
    root: {
      schemaVersion: 1,
      modelId: bookingEscrowModel.modelId,
      inventoryKey: input.inventoryKey,
      migrationRevision: input.migrationRevision,
      mode: 'shadow',
      totalCapacity: input.totalCapacity,
      migratedConfirmedUnits: input.confirmedUnits,
      shardCount: input.shardCount,
      legacyShardId: bookingEscrowModel.legacyShardId,
    },
    shards,
    existingBookingShardId: bookingEscrowModel.legacyShardId,
    activationReadiness: input.confirmedUnits > input.totalCapacity ? 'cancel_only' : 'ready',
    rollback: 'single_ledger_remains_authority_until_atomic_pointer_swap',
  };
}

export function allocateEscrowUnits(
  shards: readonly EscrowShard[],
  selectionSeed: string,
  units: number,
): EscrowAllocationResult {
  assertPositiveInteger(units, 'escrow_allocation_units_invalid');
  const candidates = shards.filter((shard) => shard.shardId !== bookingEscrowModel.legacyShardId);
  if (candidates.length === 0) return { kind: 'sold_out', shards };
  const start = deterministicIndex(selectionSeed, candidates.length);
  for (let offset = 0; offset < candidates.length; offset += 1) {
    const candidate = candidates[(start + offset) % candidates.length];
    if (candidate === undefined || candidate.confirmedUnits + units > candidate.capacityUnits) {
      continue;
    }
    return {
      kind: 'allocated',
      shardId: candidate.shardId,
      shards: shards.map((shard) =>
        shard.shardId === candidate.shardId
          ? { ...shard, revision: shard.revision + 1, confirmedUnits: shard.confirmedUnits + units }
          : shard,
      ),
    };
  }
  return { kind: 'sold_out', shards };
}

export function releaseEscrowUnits(
  shards: readonly EscrowShard[],
  shardId: string,
  units: number,
): readonly EscrowShard[] {
  assertPositiveInteger(units, 'escrow_release_units_invalid');
  let found = false;
  const next = shards.map((shard) => {
    if (shard.shardId !== shardId) return shard;
    found = true;
    if (shard.confirmedUnits < units) throw new TypeError('escrow_release_exceeds_confirmed');
    return {
      ...shard,
      revision: shard.revision + 1,
      confirmedUnits: shard.confirmedUnits - units,
    };
  });
  if (!found) throw new TypeError('escrow_shard_not_found');
  return next;
}

export function transferEscrowCapacity(
  shards: readonly EscrowShard[],
  fromShardId: string,
  toShardId: string,
  units: number,
): readonly EscrowShard[] {
  assertPositiveInteger(units, 'escrow_transfer_units_invalid');
  if (fromShardId === toShardId) throw new TypeError('escrow_transfer_same_shard');
  const from = shards.find((shard) => shard.shardId === fromShardId);
  const to = shards.find((shard) => shard.shardId === toShardId);
  if (from === undefined || to === undefined) throw new TypeError('escrow_shard_not_found');
  if (from.capacityUnits - from.confirmedUnits < units) {
    throw new TypeError('escrow_transfer_exceeds_available');
  }
  return shards.map((shard) => {
    if (shard.shardId === fromShardId) {
      return { ...shard, revision: shard.revision + 1, capacityUnits: shard.capacityUnits - units };
    }
    if (shard.shardId === toShardId) {
      return { ...shard, revision: shard.revision + 1, capacityUnits: shard.capacityUnits + units };
    }
    return shard;
  });
}

export function reconcileEscrow(
  root: EscrowPoolRoot,
  shards: readonly EscrowShard[],
): EscrowReconciliation {
  const issues: string[] = [];
  const ids = new Set<string>();
  if (shards.length !== root.shardCount) issues.push('shard_count_mismatch');
  for (const shard of shards) {
    if (ids.has(shard.shardId)) issues.push('duplicate_shard_id');
    ids.add(shard.shardId);
    if (
      !Number.isSafeInteger(shard.capacityUnits) ||
      shard.capacityUnits < 0 ||
      !Number.isSafeInteger(shard.confirmedUnits) ||
      shard.confirmedUnits < 0
    ) {
      issues.push('invalid_shard_units');
    }
  }
  if (!ids.has(root.legacyShardId)) issues.push('legacy_shard_missing');
  const allocatedCapacity = shards.reduce((sum, shard) => sum + shard.capacityUnits, 0);
  const confirmedUnits = shards.reduce((sum, shard) => sum + shard.confirmedUnits, 0);
  if (allocatedCapacity !== root.totalCapacity) issues.push('capacity_sum_mismatch');
  if (issues.length > 0) return { state: 'corrupt', allocatedCapacity, confirmedUnits, issues };
  const shardOverCapacity = shards.some((shard) => shard.confirmedUnits > shard.capacityUnits);
  return {
    state: shardOverCapacity || confirmedUnits > root.totalCapacity ? 'over_capacity' : 'healthy',
    allocatedCapacity,
    confirmedUnits,
    issues,
  };
}

function deterministicIndex(seed: string, modulo: number): number {
  const digest = createHash('sha256').update(seed, 'utf8').digest();
  return digest.readUInt32BE(0) % modulo;
}

function assertNonNegativeInteger(value: number, code: string): void {
  if (!Number.isSafeInteger(value) || value < 0) throw new TypeError(code);
}

function assertPositiveInteger(value: number, code: string): void {
  if (!Number.isSafeInteger(value) || value < 1) throw new TypeError(code);
}
