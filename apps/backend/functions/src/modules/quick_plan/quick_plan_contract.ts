import { isEntityId, isIdempotencyKey } from '../../shared/ids.js';
import { canonicalJson, sha256Hex } from '../content/domain/published_revision.js';
import { exact, record } from '../library/library_contract.js';

export const quickPlanFlag = 'quick_plan.owner_sync';
export const quickPlanCollections = Object.freeze({
  plans: 'quickPlans',
  receipts: 'quickPlanCommandReceipts',
});
export type Result = Readonly<Record<string, unknown>>;
export const reject = (code: string, extra: Result = {}): Result => ({
  schemaVersion: 1,
  kind: 'rejected',
  code,
  ...extra,
});
const text = (v: unknown, n: number) => typeof v === 'string' && v.length <= n;
const integer = (v: unknown, max: number) =>
  Number.isSafeInteger(v) && Number(v) >= 0 && Number(v) <= max;
const number = (v: unknown, min: number, max: number) =>
  typeof v === 'number' && Number.isFinite(v) && v >= min && v <= max;
export function validDraft(raw: unknown): raw is Record<string, unknown> {
  const p = record(raw);
  if (
    !p ||
    !exact(p, [
      'id',
      'revision',
      'mood',
      'maxDurationMinutes',
      'freeOnly',
      'walkingOnly',
      'sourcePrompt',
      'currencyCode',
      'steps',
    ]) ||
    !isEntityId(p.id) ||
    !integer(p.revision, Number.MAX_SAFE_INTEGER) ||
    !['calm', 'social', 'active'].includes(String(p.mood)) ||
    !integer(p.maxDurationMinutes, 1440) ||
    typeof p.freeOnly !== 'boolean' ||
    typeof p.walkingOnly !== 'boolean' ||
    !text(p.sourcePrompt, 4096) ||
    typeof p.currencyCode !== 'string' ||
    !/^[A-Z]{3}$/.test(p.currencyCode) ||
    !Array.isArray(p.steps) ||
    p.steps.length > 32
  )
    return false;
  const ids = new Set<string>();
  for (const rawStep of p.steps) {
    const s = record(rawStep),
      money = record(s?.priceAmount);
    if (
      !s ||
      !exact(s, [
        'id',
        'sourceObjectId',
        'sourceObjectType',
        'title',
        'subtitle',
        'category',
        'durationMinutes',
        'distanceKm',
        'priceAmount',
        'isFree',
        'latitude',
        'longitude',
      ]) ||
      !isEntityId(s.id) ||
      ids.has(s.id) ||
      !text(s.title, 256) ||
      !text(s.subtitle, 1024) ||
      !text(s.category, 256) ||
      !integer(s.durationMinutes, 1440) ||
      !number(s.distanceKm, 0, 10000) ||
      typeof s.isFree !== 'boolean' ||
      !number(s.latitude, -90, 90) ||
      !number(s.longitude, -180, 180) ||
      !money ||
      !exact(money, ['minorUnits', 'currencyCode']) ||
      !integer(money.minorUnits, 100000000000) ||
      money.currencyCode !== p.currencyCode ||
      (s.sourceObjectId !== undefined &&
        s.sourceObjectId !== null &&
        !isEntityId(s.sourceObjectId)) ||
      (s.sourceObjectType !== undefined &&
        s.sourceObjectType !== null &&
        !text(s.sourceObjectType, 64))
    )
      return false;
    ids.add(s.id);
  }
  return Buffer.byteLength(JSON.stringify(p)) <= 65536;
}
export interface QuickPlanCommand {
  schemaVersion: 1;
  requestId: string;
  ownerContext: string;
  idempotencyKey: string;
  commandType:
    'save' | 'delete' | 'import' | 'invite' | 'accept' | 'decline' | 'cancel' | 'revoke' | 'leave';
  planId: string;
  expectedRevision: number;
  plan?: Record<string, unknown>;
  planOwnerId?: string;
  targetUserId?: string;
  invitationId?: string;
  generation?: number;
  previousStatus?: string;
}
export function parseCommand(raw: unknown): QuickPlanCommand | null {
  const r = record(raw);
  if (
    !r ||
    !exact(r, [
      'schemaVersion',
      'requestId',
      'ownerContext',
      'idempotencyKey',
      'commandType',
      'planId',
      'expectedRevision',
      'plan',
      'planOwnerId',
      'targetUserId',
      'invitationId',
      'generation',
      'previousStatus',
    ]) ||
    r.schemaVersion !== 1 ||
    !isEntityId(r.requestId) ||
    !isEntityId(r.ownerContext) ||
    !isIdempotencyKey(r.idempotencyKey) ||
    !isEntityId(r.planId) ||
    !integer(r.expectedRevision, Number.MAX_SAFE_INTEGER) ||
    ![
      'save',
      'delete',
      'import',
      'invite',
      'accept',
      'decline',
      'cancel',
      'revoke',
      'leave',
    ].includes(String(r.commandType))
  )
    return null;
  if (r.planOwnerId !== undefined && !isEntityId(r.planOwnerId)) return null;
  if (!['save', 'delete', 'import'].includes(String(r.commandType))) {
    if (
      !isEntityId(r.planOwnerId) ||
      !isEntityId(r.targetUserId) ||
      !isEntityId(r.invitationId) ||
      !integer(r.generation, Number.MAX_SAFE_INTEGER - 1) ||
      r.plan !== undefined
    )
      return null;
    if (
      r.commandType === 'invite'
        ? !['none', 'pending', 'accepted', 'revoked', 'left', 'cancelled', 'declined'].includes(
            String(r.previousStatus),
          )
        : r.previousStatus !== undefined
    )
      return null;
    return r as unknown as QuickPlanCommand;
  }
  if (
    r.targetUserId !== undefined ||
    r.invitationId !== undefined ||
    r.generation !== undefined ||
    r.previousStatus !== undefined
  )
    return null;
  if (
    r.commandType === 'delete'
      ? r.plan !== undefined
      : !validDraft(r.plan) || r.plan.id !== r.planId
  )
    return null;
  if (r.commandType === 'import' && r.expectedRevision !== 0) return null;
  return r as unknown as QuickPlanCommand;
}
export const hashCommand = (c: QuickPlanCommand) =>
  sha256Hex(
    canonicalJson({
      commandType: c.commandType,
      planId: c.planId,
      expectedRevision: c.expectedRevision,
      ...(c.plan ? { plan: c.plan } : {}),
      ...(c.planOwnerId ? { planOwnerId: c.planOwnerId } : {}),
      ...(c.previousStatus ? { previousStatus: c.previousStatus } : {}),
      ...(c.targetUserId
        ? { targetUserId: c.targetUserId, invitationId: c.invitationId, generation: c.generation }
        : {}),
    }),
  );
