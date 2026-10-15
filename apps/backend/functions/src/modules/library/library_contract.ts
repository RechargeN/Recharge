import { isEntityId, isIdempotencyKey } from '../../shared/ids.js';
import { canonicalJson, sha256Hex } from '../content/domain/published_revision.js';

export const libraryFlagId = 'library.self_service';
export const libraryCollections = Object.freeze({
  owners: 'libraryOwners',
  entries: 'libraryEntries',
  receipts: 'libraryCommandReceipts',
});
export const libraryTypes = [
  'place',
  'event',
  'activity',
  'route',
  'scenario',
  'session',
  'class_workshop',
  'rental',
  'collection',
  'find_people',
] as const;
export type LibraryType = (typeof libraryTypes)[number];
export interface LibraryEntry {
  schemaVersion: 1;
  entryId: string;
  ownerId: string;
  kind: 'favorite' | 'visit';
  objectId: string;
  objectType: LibraryType;
  visitedOn: string | null;
  timezoneId: string | null;
  evidence: 'selfReported' | null;
  revision: number;
  ownerRevision: number;
  status: 'active' | 'removed';
  updatedAtUtc: string;
  snapshot: { title: string; city: string; category: string };
}
export interface LibraryCommand {
  schemaVersion: 1;
  requestId: string;
  ownerContext: string;
  idempotencyKey: string;
  commandType: 'addFavorite' | 'removeFavorite' | 'recordVisit' | 'removeVisit';
  payload: {
    objectId: string;
    objectType: LibraryType;
    expectedRevision: number;
    proposedEntryId: string;
    visitedOn?: string;
  };
}
export type LibraryResult = Readonly<Record<string, unknown>>;
export const rejected = (code: string, extra: LibraryResult = {}): LibraryResult => ({
  schemaVersion: 1,
  kind: 'rejected',
  code,
  ...extra,
});
export function record(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}
export function exact(value: Record<string, unknown>, keys: readonly string[]): boolean {
  return Object.keys(value).every((key) => keys.includes(key));
}
export function parseLibraryCommand(raw: unknown): LibraryCommand | null {
  const r = record(raw),
    p = record(r?.payload);
  if (
    !r ||
    !p ||
    !exact(r, [
      'schemaVersion',
      'requestId',
      'ownerContext',
      'idempotencyKey',
      'commandType',
      'payload',
    ]) ||
    r.schemaVersion !== 1 ||
    !isEntityId(r.requestId) ||
    !isEntityId(r.ownerContext) ||
    !isIdempotencyKey(r.idempotencyKey) ||
    !['addFavorite', 'removeFavorite', 'recordVisit', 'removeVisit'].includes(
      String(r.commandType),
    ) ||
    !exact(p, ['objectId', 'objectType', 'expectedRevision', 'visitedOn', 'proposedEntryId']) ||
    !isEntityId(p.objectId) ||
    !isEntityId(p.proposedEntryId) ||
    !libraryTypes.includes(p.objectType as LibraryType) ||
    !Number.isSafeInteger(p.expectedRevision) ||
    Number(p.expectedRevision) < 0
  )
    return null;
  const visit = r.commandType === 'recordVisit' || r.commandType === 'removeVisit';
  if (visit ? p.objectType !== 'place' || !isCalendarDay(p.visitedOn) : p.visitedOn !== undefined)
    return null;
  return r as unknown as LibraryCommand;
}
export function isCalendarDay(value: unknown): value is string {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const d = new Date(value + 'T00:00:00.000Z');
  return Number.isFinite(d.getTime()) && d.toISOString().slice(0, 10) === value;
}
export function placeToday(now: Date, zone: string): string {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: zone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(now);
  const part = (name: string) => parts.find((p) => p.type === name)!.value;
  return part('year') + '-' + part('month') + '-' + part('day');
}
export function entryIdFor(c: LibraryCommand): string {
  const p = c.payload;
  return sha256Hex(
    canonicalJson([
      c.commandType.endsWith('Favorite') ? 'favorite' : 'visit',
      p.objectType,
      p.objectId,
      p.visitedOn ?? null,
    ]),
  );
}
export function commandHash(c: LibraryCommand): string {
  return sha256Hex(canonicalJson({ commandType: c.commandType, payload: c.payload }));
}
