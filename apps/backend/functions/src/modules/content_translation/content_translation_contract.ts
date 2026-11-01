import { isEntityId } from '../../shared/ids.js';
import { canonicalJson, sha256Hex } from '../content/domain/published_revision.js';

/** ADR 0022 stage 1: default-off, Emulator-only on-demand translation. */
export const contentTranslationCollections = Object.freeze({
  /** Shared by all readers; no user id. The service below is the only writer. */
  entries: 'contentTranslations',
  leases: 'contentTranslationLeases',
  accountUsage: 'contentTranslationAccountUsage',
  objectUsage: 'contentTranslationObjectUsage',
  budgets: 'contentTranslationBudgets',
  costLedger: 'contentTranslationCostLedger',
});

export const contentTranslationFailureCodes = [
  'unauthenticated',
  'request_invalid',
  'translation_disabled',
  'same_language',
  'unsupported_locale',
  'source_unavailable',
  'revision_changed',
  'quota_exceeded',
  'budget_exhausted',
  'provider_unavailable',
] as const;
export type ContentTranslationFailureCode = (typeof contentTranslationFailureCodes)[number];

export const contentTranslationTargetLocales = ['lv', 'en', 'ru'] as const;
export type ContentTranslationTargetLocale = (typeof contentTranslationTargetLocales)[number];

export type TranslatedField = 'title' | 'shortDescription' | 'fullDescription';
export type TranslationFields = Partial<Record<TranslatedField, string>>;

const describedFields: readonly TranslatedField[] = Object.freeze([
  'title',
  'shortDescription',
  'fullDescription',
]);

/**
 * TR-OD-03: what may leave Content, per type. Absent types (Find People) and
 * every field not named here (terms, safety, names, addresses, contacts) are
 * never read for translation. A new type or field needs its own decision.
 */
export const contentTranslationAllowlist: Readonly<Record<string, readonly TranslatedField[]>> =
  Object.freeze({
    place: describedFields,
    event: describedFields,
    activity: describedFields,
    rental: describedFields,
    session: describedFields,
    class_workshop: describedFields,
    collection: describedFields,
    route: describedFields,
    scenario: describedFields,
  });

export function allowlistedFields(
  typeId: string,
  body: Readonly<Record<string, unknown>>,
  allowlist: Readonly<Record<string, readonly TranslatedField[]>> = contentTranslationAllowlist,
): TranslationFields | null {
  if (!Object.prototype.hasOwnProperty.call(allowlist, typeId)) return null;
  const fields: TranslationFields = {};
  for (const field of allowlist[typeId]!) {
    const value = body[field];
    if (typeof value === 'string' && value.trim().length > 0) fields[field] = value;
  }
  return Object.keys(fields).length === 0 ? null : fields;
}

/** The declared language subtag of a body; the server never guesses one (TR-OD-09). */
export function declaredSourceLocale(body: Readonly<Record<string, unknown>>): string | null {
  const declared = body.contentLocale;
  if (typeof declared !== 'string') return null;
  const match = /^([A-Za-z]{2,3})(?:[-_][A-Za-z0-9]+)*$/u.exec(declared);
  return match === null ? null : match[1]!.toLowerCase();
}

export interface ContentTranslationRequest {
  readonly schemaVersion: 1;
  readonly requestId: string;
  readonly contentId: string;
  readonly publishedRevisionId: string;
  readonly targetLocale: string;
}

const requestKeys = new Set([
  'schemaVersion',
  'requestId',
  'contentId',
  'publishedRevisionId',
  'targetLocale',
]);

/** Exact keys only, so a client can never send text to translate (invariant 3). */
export function parseContentTranslationRequest(raw: unknown): ContentTranslationRequest | null {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return null;
  const r = raw as Record<string, unknown>;
  if (
    !Object.keys(r).every((key) => requestKeys.has(key)) ||
    r.schemaVersion !== 1 ||
    typeof r.requestId !== 'string' ||
    !/^[A-Za-z0-9_.:-]{1,128}$/u.test(r.requestId) ||
    !isEntityId(r.contentId) ||
    !isEntityId(r.publishedRevisionId) ||
    typeof r.targetLocale !== 'string' ||
    !/^[A-Za-z-]{2,16}$/u.test(r.targetLocale)
  )
    return null;
  return {
    schemaVersion: 1,
    requestId: r.requestId,
    contentId: r.contentId,
    publishedRevisionId: r.publishedRevisionId,
    targetLocale: r.targetLocale,
  };
}

export interface CacheKeyParts {
  readonly contentId: string;
  readonly publishedRevisionId: string;
  readonly sourceHash: string;
  readonly sourceLocale: string;
  readonly targetLocale: string;
  readonly providerRef: string;
  readonly engineRevision: string;
}

export function sourceHashOf(fields: TranslationFields): string {
  return sha256Hex(canonicalJson(fields));
}

export function cacheKeyOf(parts: CacheKeyParts): string {
  return sha256Hex(canonicalJson({ ...parts }));
}

/**
 * Stage 1 placeholders, not decisions: TR-OD-04 (quotas), TR-OD-05 (monthly cap)
 * and TR-OD-08 (TTL) stay open until stage 2 measurements.
 */
export interface ContentTranslationLimits {
  readonly accountPerDay: number;
  readonly objectPerDay: number;
  readonly monthlyCapMinor: number;
  readonly cacheTtlDays: number;
  readonly usageTtlDays: number;
  readonly leaseMs: number;
  readonly waitAttempts: number;
  readonly waitMs: number;
}

export const contentTranslationStageOneLimits: ContentTranslationLimits = Object.freeze({
  accountPerDay: 20,
  objectPerDay: 10,
  monthlyCapMinor: 100,
  cacheTtlDays: 30,
  usageTtlDays: 2,
  leaseMs: 30_000,
  waitAttempts: 25,
  waitMs: 200,
});
