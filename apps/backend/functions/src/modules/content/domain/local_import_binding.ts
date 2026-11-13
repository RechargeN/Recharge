import type { LocalImportBindingV1 } from '../../../contracts/content_v1.js';
import type { EntityId } from '../../../shared/ids.js';
import { deepFreeze } from '../../../shared/immutable.js';
import { parseUtcInstant, type UtcInstant } from '../../../shared/utc_instant.js';
import { ContentDomainRefusal } from './failures.js';

/**
 * D4.1: lease of a cleanup reservation. A test constant of the local stand,
 * not a production policy. An expired lease is never taken over: only the
 * reserving installation's token completes or releases it.
 */
export const importCleanupLeaseSeconds = 900;

export interface ImportCleanup {
  readonly state: 'reserved' | 'done';
  readonly fencingToken: string;
  readonly generation: number;
  readonly installationId: string;
  readonly reservedAtUtc: UtcInstant;
  readonly leaseExpiresAtUtc: UtcInstant;
  readonly completedAtUtc?: UtcInstant;
}

/**
 * The binding of one author's local `loc_*` source to the draft of its current
 * generation. A rolled-back generation stays as a tombstone until a new import
 * opens the next one; `bindingRevision` is the compare-and-set guard (0 = never
 * written by D4.1, which is also the D4 binding without the field).
 */
export interface LocalImportBinding {
  readonly createdByUserId: string;
  readonly importSourceKey: string;
  readonly generation: number;
  readonly state: 'active' | 'rolledBack';
  readonly draftId: EntityId;
  readonly cleanup: ImportCleanup | null;
  readonly bindingRevision: number;
  readonly rolledBackAtUtc?: UtcInstant;
}

/** The generation a draft belongs to; D4 drafts without the field are generation 1. */
export function importGenerationOf(draft: { readonly importGeneration?: number }): number {
  return draft.importGeneration ?? 1;
}

/** Opens generation `previous.generation + 1` (or 1) for a freshly created draft. */
export function openImportGeneration(
  createdByUserId: string,
  importSourceKey: string,
  previous: LocalImportBinding | null,
  draftId: EntityId,
): LocalImportBinding {
  if (previous !== null && previous.state === 'active')
    throw new ContentDomainRefusal('revision_conflict');
  return deepFreeze({
    createdByUserId,
    importSourceKey,
    generation: (previous?.generation ?? 0) + 1,
    state: 'active',
    draftId,
    cleanup: null,
    bindingRevision: (previous?.bindingRevision ?? 0) + 1,
  });
}

/** The generation named by a command must be the binding's current one. */
export function assertGeneration(binding: LocalImportBinding, generation: number): void {
  if (binding.generation !== generation)
    throw new ContentDomainRefusal('import_generation_mismatch');
}

/**
 * Rollback is refused while any cleanup reservation exists, however old: an
 * expired lease may still belong to an installation that deleted the original
 * and has not completed yet.
 */
export function assertRollbackAllowed(binding: LocalImportBinding): void {
  if (binding.state === 'rolledBack') throw new ContentDomainRefusal('import_rolled_back');
  if (binding.cleanup?.state === 'done') throw new ContentDomainRefusal('original_removed');
  if (binding.cleanup?.state === 'reserved') throw new ContentDomainRefusal('cleanup_reserved');
}

export function rollBackBinding(
  binding: LocalImportBinding,
  nowUtc: UtcInstant,
): LocalImportBinding {
  assertRollbackAllowed(binding);
  return deepFreeze({
    ...structuredClone(binding),
    state: 'rolledBack',
    rolledBackAtUtc: nowUtc,
    bindingRevision: binding.bindingRevision + 1,
  });
}

/**
 * Reserves the cleanup for one installation. The same token is idempotent
 * (`null`: nothing to write); another token is refused even after the lease
 * expired.
 */
export function reserveCleanup(
  binding: LocalImportBinding,
  input: { readonly installationId: string; readonly fencingToken: string },
  nowUtc: UtcInstant,
): LocalImportBinding | null {
  if (binding.state === 'rolledBack') throw new ContentDomainRefusal('import_rolled_back');
  const current = binding.cleanup;
  if (current?.state === 'done') throw new ContentDomainRefusal('original_removed');
  if (current?.state === 'reserved') {
    if (
      current.fencingToken === input.fencingToken &&
      current.installationId === input.installationId
    )
      return null;
    throw new ContentDomainRefusal('cleanup_reserved');
  }
  const lease = new Date(Date.parse(nowUtc) + importCleanupLeaseSeconds * 1000);
  return deepFreeze({
    ...structuredClone(binding),
    cleanup: {
      state: 'reserved',
      fencingToken: input.fencingToken,
      generation: binding.generation,
      installationId: input.installationId,
      reservedAtUtc: nowUtc,
      leaseExpiresAtUtc: parseUtcInstant(lease.toISOString()),
    },
    bindingRevision: binding.bindingRevision + 1,
  });
}

/** Marks the original deleted. A repeat with the same token changes nothing (`null`). */
export function completeCleanup(
  binding: LocalImportBinding,
  fencingToken: string,
  nowUtc: UtcInstant,
): LocalImportBinding | null {
  const current = binding.cleanup;
  if (current === null) throw new ContentDomainRefusal('cleanup_not_reserved');
  if (current.fencingToken !== fencingToken)
    throw new ContentDomainRefusal('cleanup_token_mismatch');
  if (current.state === 'done') return null;
  return deepFreeze({
    ...structuredClone(binding),
    cleanup: { ...structuredClone(current), state: 'done', completedAtUtc: nowUtc },
    bindingRevision: binding.bindingRevision + 1,
  });
}

/** Lifts a reservation whose original was kept. Never after the original is gone. */
export function releaseCleanup(
  binding: LocalImportBinding,
  fencingToken: string,
): LocalImportBinding {
  const current = binding.cleanup;
  if (current === null) throw new ContentDomainRefusal('cleanup_not_reserved');
  if (current.state === 'done') throw new ContentDomainRefusal('original_removed');
  if (current.fencingToken !== fencingToken)
    throw new ContentDomainRefusal('cleanup_token_mismatch');
  return deepFreeze({
    ...structuredClone(binding),
    cleanup: null,
    bindingRevision: binding.bindingRevision + 1,
  });
}

/** The author's view: no fencing token and no other author's data. */
export function importBindingView(binding: LocalImportBinding): LocalImportBindingV1 {
  const { cleanup } = binding;
  return deepFreeze({
    importSourceKey: binding.importSourceKey,
    generation: binding.generation,
    state: binding.state,
    draftId: binding.draftId,
    bindingRevision: binding.bindingRevision,
    ...(binding.rolledBackAtUtc === undefined ? {} : { rolledBackAtUtc: binding.rolledBackAtUtc }),
    cleanup:
      cleanup === null
        ? null
        : {
            state: cleanup.state,
            generation: cleanup.generation,
            installationId: cleanup.installationId,
            reservedAtUtc: cleanup.reservedAtUtc,
            leaseExpiresAtUtc: cleanup.leaseExpiresAtUtc,
            ...(cleanup.completedAtUtc === undefined
              ? {}
              : { completedAtUtc: cleanup.completedAtUtc }),
          },
  } satisfies LocalImportBindingV1);
}

/**
 * Reads a stored binding. A D4 binding has only `draftId`: it is generation 1,
 * active, without cleanup and at binding revision 0.
 */
export function bindingFromStored(
  createdByUserId: string,
  importSourceKey: string,
  stored: Readonly<Record<string, unknown>>,
): LocalImportBinding | null {
  if (typeof stored.draftId !== 'string') return null;
  const cleanup = stored.cleanup;
  return deepFreeze({
    createdByUserId,
    importSourceKey,
    generation: typeof stored.generation === 'number' ? stored.generation : 1,
    state: stored.state === 'rolledBack' ? 'rolledBack' : 'active',
    draftId: stored.draftId as EntityId,
    cleanup:
      typeof cleanup === 'object' && cleanup !== null
        ? (structuredClone(cleanup) as ImportCleanup)
        : null,
    bindingRevision: typeof stored.bindingRevision === 'number' ? stored.bindingRevision : 0,
    ...(typeof stored.rolledBackAtUtc === 'string'
      ? { rolledBackAtUtc: stored.rolledBackAtUtc as UtcInstant }
      : {}),
  });
}
