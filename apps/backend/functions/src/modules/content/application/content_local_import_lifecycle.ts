import type {
  LocalImportBindingV1,
  LocalImportLifecycleCommandV1,
} from '../../../contracts/content_v1.js';
import type { UtcInstant } from '../../../shared/utc_instant.js';
import { rollBackImportedDraft, type ContentDraft } from '../domain/content_draft.js';
import { ContentDomainRefusal } from '../domain/failures.js';
import {
  assertGeneration,
  assertRollbackAllowed,
  completeCleanup,
  importBindingView,
  importGenerationOf,
  releaseCleanup,
  reserveCleanup,
  rollBackBinding,
  type LocalImportBinding,
} from '../domain/local_import_binding.js';
import type { ContentTransaction } from '../domain/repositories.js';

/** What the Content service lends a lifecycle command inside its transaction. */
export interface LocalImportLifecycleContext {
  readonly tx: ContentTransaction;
  /** The signed-in author; delegated modules never reach these commands. */
  readonly userId: string;
  readonly nowUtc: UtcInstant;
  /** Current Publisher authority to change this draft (type flag and `update`). */
  authorizeDraftChange(draft: ContentDraft): Promise<void>;
  audit(action: string, subjectId: string): void;
}

type Payload<Type extends LocalImportLifecycleCommandV1['commandType']> = Extract<
  LocalImportLifecycleCommandV1,
  { commandType: Type }
>['payload'];

/**
 * D4.1 rollback of a local import. Only the author's own draft of the current
 * generation, never submitted or published, at exactly the confirmed revision,
 * and only while no cleanup of the local original is reserved or done. The
 * draft and the binding generation become tombstones in one transaction.
 */
export async function rollbackImportedDraft(
  context: LocalImportLifecycleContext,
  payload: Payload<'rollbackImportedDraft'>,
): Promise<ContentDraft> {
  const { tx, nowUtc } = context;
  const binding = await ownBinding(context, payload.importSourceKey);
  const draft = await tx.draft(payload.draftId);
  if (
    draft === null ||
    draft.createdByUserId !== context.userId ||
    draft.importSourceKey !== payload.importSourceKey
  )
    throw new ContentDomainRefusal('not_found');
  await context.authorizeDraftChange(draft);
  assertGeneration(binding, payload.generation);
  if (binding.draftId !== draft.draftId || importGenerationOf(draft) !== payload.generation)
    throw new ContentDomainRefusal('import_generation_mismatch');
  assertRollbackAllowed(binding);
  // Anything that ever reached publication stays: rollback is not withdrawal.
  if (
    (await tx.submissionsForContent(draft.contentId)).length > 0 ||
    (await tx.pointer(draft.contentId)) !== null
  )
    throw new ContentDomainRefusal('import_rollback_not_allowed');
  const tombstone = rollBackImportedDraft(draft, payload.expectedRevision, nowUtc);
  tx.putImportBinding(rollBackBinding(binding, nowUtc), binding.bindingRevision);
  tx.putDraft(tombstone);
  context.audit('content.draft.import_rolled_back', draft.draftId);
  return tombstone;
}

/** Reserves the deletion of the local original for one installation and token. */
export async function reserveImportCleanup(
  context: LocalImportLifecycleContext,
  payload: Payload<'reserveImportCleanup'>,
): Promise<LocalImportBindingV1> {
  const binding = await ownBinding(context, payload.importSourceKey);
  assertGeneration(binding, payload.generation);
  if (binding.draftId !== payload.draftId) throw new ContentDomainRefusal('not_found');
  const next = reserveCleanup(
    binding,
    { installationId: payload.installationId, fencingToken: payload.fencingToken },
    context.nowUtc,
  );
  return write(context, binding, next, 'content.import.cleanup_reserved');
}

/** Records that the original was deleted under this exact reservation. */
export async function completeImportCleanup(
  context: LocalImportLifecycleContext,
  payload: Payload<'completeImportCleanup'>,
): Promise<LocalImportBindingV1> {
  const binding = await ownBinding(context, payload.importSourceKey);
  assertGeneration(binding, payload.generation);
  const next = completeCleanup(binding, payload.fencingToken, context.nowUtc);
  return write(context, binding, next, 'content.import.cleanup_completed');
}

/** Lifts a reservation whose original was kept. */
export async function releaseImportCleanup(
  context: LocalImportLifecycleContext,
  payload: Payload<'releaseImportCleanup'>,
): Promise<LocalImportBindingV1> {
  const binding = await ownBinding(context, payload.importSourceKey);
  assertGeneration(binding, payload.generation);
  const next = releaseCleanup(binding, payload.fencingToken);
  return write(context, binding, next, 'content.import.cleanup_released');
}

/** The author's binding view; how a client resolves an unknown outcome. */
export async function getImportBinding(
  tx: ContentTransaction,
  userId: string,
  importSourceKey: string,
): Promise<LocalImportBindingV1> {
  const binding = await tx.importBinding(userId, importSourceKey);
  if (binding === null) throw new ContentDomainRefusal('not_found');
  return importBindingView(binding);
}

async function ownBinding(
  context: LocalImportLifecycleContext,
  importSourceKey: string,
): Promise<LocalImportBinding> {
  // Bindings are keyed by author: another author's source simply does not exist.
  const binding = await context.tx.importBinding(context.userId, importSourceKey);
  if (binding === null) throw new ContentDomainRefusal('not_found');
  return binding;
}

function write(
  context: LocalImportLifecycleContext,
  binding: LocalImportBinding,
  next: LocalImportBinding | null,
  action: string,
): LocalImportBindingV1 {
  if (next === null) return importBindingView(binding);
  context.tx.putImportBinding(next, binding.bindingRevision);
  context.audit(action, binding.draftId);
  return importBindingView(next);
}
